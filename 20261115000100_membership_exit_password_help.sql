-- Fidelito: saída de programa de fidelidade, perda de pontos e validação de adesão.
-- Execute no Supabase SQL Editor APÓS as migrações multiempresa e pontos manuais.
-- A migração preserva transações e benefícios já resgatados. O saldo é zerado ao sair.

BEGIN;

ALTER TABLE public.loyalty_accounts
  ADD COLUMN IF NOT EXISTS left_at timestamptz;

CREATE INDEX IF NOT EXISTS loyalty_accounts_active_customer_company_idx
  ON public.loyalty_accounts (customer_id, company_id)
  WHERE left_at IS NULL;

-- A checagem usada pelas políticas de companies considera somente adesões ativas.
CREATE OR REPLACE FUNCTION public.is_customer_joined_company(target_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.loyalty_accounts la
    WHERE la.company_id = target_company_id
      AND la.customer_id = auth.uid()
      AND la.left_at IS NULL
  );
$function$;
REVOKE ALL ON FUNCTION public.is_customer_joined_company(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_customer_joined_company(uuid) TO authenticated;

-- Entrar novamente reativa a conta, mas nunca restaura pontos perdidos.
CREATE OR REPLACE FUNCTION public.join_loyalty_program(p_company_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_account public.loyalty_accounts%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_user_id AND p.role::text = 'customer'
  ) THEN
    RAISE EXCEPTION 'Somente clientes podem participar de programas de fidelidade';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id = p_company_id AND c.active = true AND c.owner_id <> v_user_id
  ) THEN
    RAISE EXCEPTION 'Empresa não encontrada ou indisponível';
  END IF;

  INSERT INTO public.loyalty_accounts AS existing_account
    (company_id, customer_id, points, left_at)
  VALUES (p_company_id, v_user_id, 0, NULL)
  ON CONFLICT (company_id, customer_id) DO UPDATE
    SET points = CASE
          WHEN existing_account.left_at IS NOT NULL THEN 0
          ELSE existing_account.points
        END,
        left_at = NULL,
        updated_at = now();

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = p_company_id AND customer_id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_account.id,
    'company_id', v_account.company_id,
    'customer_id', v_account.customer_id,
    'points', v_account.points,
    'created_at', v_account.created_at
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.join_loyalty_program(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_loyalty_program(uuid) TO authenticated;

-- Saída voluntária: saldo zerado; trilha de transações e resgates anteriores preservada.
CREATE OR REPLACE FUNCTION public.leave_loyalty_program(p_company_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_account public.loyalty_accounts%ROWTYPE;
  v_points_lost integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_user_id AND p.role::text = 'customer'
  ) THEN
    RAISE EXCEPTION 'Somente clientes podem sair de um programa de fidelidade';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = p_company_id
    AND customer_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Você não participa ativamente deste programa';
  END IF;
  IF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você não participa ativamente deste programa';
  END IF;

  v_points_lost := v_account.points;

  UPDATE public.loyalty_accounts
  SET points = 0,
      left_at = now(),
      updated_at = now()
  WHERE id = v_account.id;

  RETURN jsonb_build_object(
    'success', true,
    'company_id', p_company_id,
    'points_lost', v_points_lost
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.leave_loyalty_program(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.leave_loyalty_program(uuid) TO authenticated;

-- QR: impede que alguém que saiu continue recebendo pontos pelo QR da empresa.
-- A primeira leitura ainda cria a adesão, como no comportamento anterior.
CREATE OR REPLACE FUNCTION public.redeem_qr_code(p_code uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_qr public.qr_codes%ROWTYPE;
  v_account public.loyalty_accounts%ROWTYPE;
  v_transaction public.loyalty_transactions%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT * INTO v_qr
  FROM public.qr_codes
  WHERE code = p_code
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'QR Code não encontrado'; END IF;
  IF v_qr.active IS DISTINCT FROM true OR v_qr.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR Code inativo ou já utilizado';
  END IF;
  IF v_qr.expires_at IS NOT NULL AND v_qr.expires_at <= now() THEN
    RAISE EXCEPTION 'QR Code expirado';
  END IF;
  IF v_qr.points IS NULL OR v_qr.points <= 0 THEN
    RAISE EXCEPTION 'Quantidade de pontos inválida';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.companies c WHERE c.id = v_qr.company_id AND c.active = true) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível';
  END IF;
  IF EXISTS (SELECT 1 FROM public.companies c WHERE c.id = v_qr.company_id AND c.owner_id = v_user_id) THEN
    RAISE EXCEPTION 'O proprietário da empresa não pode utilizar o próprio QR Code';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_qr.company_id AND customer_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
    VALUES (v_qr.company_id, v_user_id, 0)
    RETURNING * INTO v_account;
  ELSIF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você saiu do programa desta empresa. Entre novamente pelo aplicativo para voltar a acumular pontos.';
  END IF;

  UPDATE public.loyalty_accounts
  SET points = points + v_qr.points, updated_at = now()
  WHERE id = v_account.id
  RETURNING * INTO v_account;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points, qr_code_id, description
  ) VALUES (
    v_account.id, v_user_id, v_qr.company_id, 'earn', v_qr.points,
    v_qr.id, 'Pontos recebidos através de QR Code'
  ) RETURNING * INTO v_transaction;

  UPDATE public.qr_codes
  SET active = false, used_at = now(), used_by = v_user_id
  WHERE id = v_qr.id;

  RETURN jsonb_build_object(
    'success', true,
    'points_earned', v_qr.points,
    'new_balance', v_account.points,
    'company_id', v_qr.company_id,
    'qr_code_id', v_qr.id,
    'transaction_id', v_transaction.id
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.redeem_qr_code(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_qr_code(uuid) TO authenticated;

-- Resgate somente por quem ainda participa ativamente do programa.
CREATE OR REPLACE FUNCTION public.redeem_promotion(p_promotion_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_promotion public.promotions%ROWTYPE;
  v_account public.loyalty_accounts%ROWTYPE;
  v_redemption_id uuid;
  v_new_balance integer;
BEGIN
  IF v_customer_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;

  SELECT * INTO v_promotion FROM public.promotions WHERE id = p_promotion_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Promoção não encontrada.'; END IF;
  IF v_promotion.active IS DISTINCT FROM true THEN RAISE EXCEPTION 'Esta promoção não está disponível.'; END IF;
  IF v_promotion.starts_at IS NOT NULL AND now() < v_promotion.starts_at THEN RAISE EXCEPTION 'Esta promoção ainda não começou.'; END IF;
  IF v_promotion.ends_at IS NOT NULL AND now() > v_promotion.ends_at THEN RAISE EXCEPTION 'Esta promoção já expirou.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.companies c WHERE c.id = v_promotion.company_id AND c.active = true) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível.';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_promotion.company_id AND customer_id = v_customer_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Você não participa mais do programa de fidelidade desta empresa.';
  END IF;
  IF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você não participa mais do programa de fidelidade desta empresa.';
  END IF;
  IF v_account.points < v_promotion.points_required THEN
    RAISE EXCEPTION 'Pontos insuficientes. Você possui % pontos e precisa de %.', v_account.points, v_promotion.points_required;
  END IF;

  v_new_balance := v_account.points - v_promotion.points_required;
  UPDATE public.loyalty_accounts SET points = v_new_balance, updated_at = now() WHERE id = v_account.id;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points, promotion_id, description
  ) VALUES (
    v_account.id, v_customer_id, v_promotion.company_id, 'redeem',
    -v_promotion.points_required, v_promotion.id, 'Resgate: ' || v_promotion.title
  );

  INSERT INTO public.promotion_redemptions (
    promotion_id, company_id, customer_id, points_spent, status
  ) VALUES (
    v_promotion.id, v_promotion.company_id, v_customer_id, v_promotion.points_required, 'available'
  ) RETURNING id INTO v_redemption_id;

  RETURN json_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'promotion_id', v_promotion.id,
    'title', v_promotion.title,
    'points_spent', v_promotion.points_required,
    'new_balance', v_new_balance,
    'status', 'available'
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.redeem_promotion(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_promotion(uuid) TO authenticated;

-- Pontuação manual: não permite à empresa pontuar clientes que saíram do programa.
CREATE OR REPLACE FUNCTION public.award_customer_points(
  p_customer_id uuid,
  p_points integer,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_account public.loyalty_accounts%ROWTYPE;
  v_transaction_id uuid;
  v_description text;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;
  IF p_customer_id IS NULL THEN RAISE EXCEPTION 'Cliente inválido.'; END IF;
  IF p_points IS NULL OR p_points <= 0 OR p_points > 10000 THEN
    RAISE EXCEPTION 'A quantidade de pontos deve estar entre 1 e 10.000.';
  END IF;

  SELECT c.id INTO v_company_id
  FROM public.companies c
  WHERE c.owner_id = v_user_id AND c.active = true
  LIMIT 1;
  IF v_company_id IS NULL THEN RAISE EXCEPTION 'Empresa ativa não encontrada para este usuário.'; END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts la
  WHERE la.company_id = v_company_id AND la.customer_id = p_customer_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este cliente não participa mais da fidelidade da sua empresa.';
  END IF;
  IF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Este cliente não participa mais da fidelidade da sua empresa.';
  END IF;

  UPDATE public.loyalty_accounts
  SET points = points + p_points, updated_at = now()
  WHERE id = v_account.id
  RETURNING * INTO v_account;

  v_description := 'Pontos adicionados manualmente pela empresa';
  IF NULLIF(trim(coalesce(p_description, '')), '') IS NOT NULL THEN
    v_description := v_description || ': ' || trim(p_description);
  END IF;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points, description
  ) VALUES (
    v_account.id, p_customer_id, v_company_id, 'earn', p_points, v_description
  ) RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'points_added', p_points,
    'new_balance', v_account.points,
    'company_id', v_company_id,
    'transaction_id', v_transaction_id
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.award_customer_points(uuid, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.award_customer_points(uuid, integer, text) TO authenticated;

COMMIT;
