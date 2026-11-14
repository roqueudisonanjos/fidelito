-- Fidelito: suporte a múltiplas empresas e programas de fidelidade.
-- Esta migração NÃO apaga nem recria contas, pontos, transações ou resgates.
-- Execute primeiro em um projeto de teste e faça backup antes de aplicar em produção.

BEGIN;

-- 1) Localização para descoberta de empresas.
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state varchar(2);

CREATE INDEX IF NOT EXISTS companies_active_city_state_idx
  ON public.companies (city, state)
  WHERE active = true;

CREATE INDEX IF NOT EXISTS loyalty_accounts_customer_company_idx
  ON public.loyalty_accounts (customer_id, company_id);

CREATE INDEX IF NOT EXISTS loyalty_transactions_customer_company_created_idx
  ON public.loyalty_transactions (customer_id, company_id, created_at DESC);

-- 2) Descoberta: usuários autenticados podem consultar empresas ativas.
-- A política existente de proprietário continua preservada.
DROP POLICY IF EXISTS companies_public_discovery_select ON public.companies;
CREATE POLICY companies_public_discovery_select
  ON public.companies
  FOR SELECT
  TO authenticated
  USING (active = true);

-- Função SECURITY DEFINER evita recursão entre a política de companies
-- e as políticas de loyalty_accounts ao consultar empresas já aderidas.
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
  );
$function$;
REVOKE ALL ON FUNCTION public.is_customer_joined_company(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_customer_joined_company(uuid) TO authenticated;

-- Clientes que já aderiram continuam podendo consultar o perfil da empresa
-- mesmo que ela seja desativada, preservando acesso ao próprio histórico.
DROP POLICY IF EXISTS companies_joined_customer_select ON public.companies;
CREATE POLICY companies_joined_customer_select
  ON public.companies
  FOR SELECT
  TO authenticated
  USING (public.is_customer_joined_company(id));

-- 3) Nova assinatura de create_company, compatível com cidade e UF.
-- A função antiga de quatro parâmetros é mantida para compatibilidade com
-- versões anteriores do aplicativo.
CREATE OR REPLACE FUNCTION public.create_company(
  p_name text,
  p_description text,
  p_phone text,
  p_address text,
  p_city text,
  p_state text
)
RETURNS public.companies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_company public.companies;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  IF btrim(coalesce(p_name, '')) = '' THEN
    RAISE EXCEPTION 'Nome da empresa é obrigatório';
  END IF;

  IF btrim(coalesce(p_city, '')) = '' THEN
    RAISE EXCEPTION 'Cidade da empresa é obrigatória';
  END IF;

  IF p_state IS NOT NULL AND length(btrim(p_state)) <> 2 THEN
    RAISE EXCEPTION 'Informe uma UF válida com duas letras';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.companies c WHERE c.owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Usuário já possui uma empresa';
  END IF;

  INSERT INTO public.companies (
    owner_id, name, description, phone, address, city, state, active
  ) VALUES (
    auth.uid(), btrim(p_name), nullif(btrim(p_description), ''),
    nullif(btrim(p_phone), ''), nullif(btrim(p_address), ''),
    btrim(p_city), upper(btrim(p_state)), false
  )
  RETURNING * INTO v_company;

  RETURN v_company;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_company(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_company(text, text, text, text, text, text) TO authenticated;

-- 4) Adesão explícita a um programa.
-- A conta existente é preservada; nunca substitui ou zera o saldo.
CREATE OR REPLACE FUNCTION public.join_loyalty_program(p_company_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid;
  v_account public.loyalty_accounts;
BEGIN
  v_user_id := auth.uid();
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
    WHERE c.id = p_company_id AND c.active = true
      AND c.owner_id <> v_user_id
  ) THEN
    RAISE EXCEPTION 'Empresa não encontrada ou indisponível';
  END IF;

  INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
  VALUES (p_company_id, v_user_id, 0)
  ON CONFLICT (company_id, customer_id) DO NOTHING;

  SELECT * INTO v_account
  FROM public.loyalty_accounts la
  WHERE la.company_id = p_company_id
    AND la.customer_id = v_user_id;

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

-- 5) QR Code: mantém o comportamento atual de criar a conta no primeiro
-- escaneamento, mas valida que a empresa ainda está ativa e evita corrida
-- na criação de duas contas simultâneas para o mesmo cliente/empresa.
CREATE OR REPLACE FUNCTION public.redeem_qr_code(p_code uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid;
  v_qr public.qr_codes;
  v_account public.loyalty_accounts;
  v_transaction public.loyalty_transactions;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT * INTO v_qr
  FROM public.qr_codes
  WHERE code = p_code
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Code não encontrado';
  END IF;
  IF v_qr.active IS DISTINCT FROM true OR v_qr.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR Code inativo ou já utilizado';
  END IF;
  IF v_qr.expires_at IS NOT NULL AND v_qr.expires_at <= now() THEN
    RAISE EXCEPTION 'QR Code expirado';
  END IF;
  IF v_qr.points IS NULL OR v_qr.points <= 0 THEN
    RAISE EXCEPTION 'Quantidade de pontos inválida';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id = v_qr.company_id AND c.active = true
  ) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id = v_qr.company_id AND c.owner_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'O proprietário da empresa não pode utilizar o próprio QR Code';
  END IF;

  INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
  VALUES (v_qr.company_id, v_user_id, 0)
  ON CONFLICT (company_id, customer_id) DO NOTHING;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_qr.company_id AND customer_id = v_user_id
  FOR UPDATE;

  UPDATE public.loyalty_accounts
  SET points = points + v_qr.points, updated_at = now()
  WHERE id = v_account.id
  RETURNING * INTO v_account;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points,
    qr_code_id, description
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

-- 6) Resgate: exige conta/adesão da pessoa à empresa e empresa ativa.
-- Mantém débito, transação e registro do benefício na mesma transação SQL.
CREATE OR REPLACE FUNCTION public.redeem_promotion(p_promotion_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_customer_id uuid;
  v_promotion public.promotions%ROWTYPE;
  v_account public.loyalty_accounts%ROWTYPE;
  v_redemption_id uuid;
  v_new_balance integer;
BEGIN
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  SELECT * INTO v_promotion
  FROM public.promotions
  WHERE id = p_promotion_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Promoção não encontrada.';
  END IF;
  IF v_promotion.active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Esta promoção não está disponível.';
  END IF;
  IF v_promotion.starts_at IS NOT NULL AND now() < v_promotion.starts_at THEN
    RAISE EXCEPTION 'Esta promoção ainda não começou.';
  END IF;
  IF v_promotion.ends_at IS NOT NULL AND now() > v_promotion.ends_at THEN
    RAISE EXCEPTION 'Esta promoção já expirou.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id = v_promotion.company_id AND c.active = true
  ) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível.';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_promotion.company_id
    AND customer_id = v_customer_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Você ainda não participa do programa de fidelidade desta empresa.';
  END IF;
  IF v_account.points < v_promotion.points_required THEN
    RAISE EXCEPTION 'Pontos insuficientes. Você possui % pontos e precisa de %.',
      v_account.points, v_promotion.points_required;
  END IF;

  v_new_balance := v_account.points - v_promotion.points_required;
  UPDATE public.loyalty_accounts
  SET points = v_new_balance, updated_at = now()
  WHERE id = v_account.id;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points,
    promotion_id, description
  ) VALUES (
    v_account.id, v_customer_id, v_promotion.company_id, 'redeem',
    -v_promotion.points_required, v_promotion.id,
    'Resgate: ' || v_promotion.title
  );

  INSERT INTO public.promotion_redemptions (
    promotion_id, company_id, customer_id, points_spent, status
  ) VALUES (
    v_promotion.id, v_promotion.company_id, v_customer_id,
    v_promotion.points_required, 'available'
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


-- 7) O caminho antigo earn_points também delega ao processamento seguro
-- de QR Code, impedindo reutilização de um mesmo código.
CREATE OR REPLACE FUNCTION public.earn_points(p_qr_code uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  RETURN public.redeem_qr_code(p_qr_code)::json;
END;
$function$;
REVOKE ALL ON FUNCTION public.earn_points(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.earn_points(uuid) TO authenticated;

-- 8) Serializa a validação/baixa de benefícios para que duas leituras
-- simultâneas não consigam consumir o mesmo benefício.
CREATE OR REPLACE FUNCTION public.validate_promotion_redemption(p_redemption_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid;
  v_redemption record;
  v_company_id uuid;
  v_used_at timestamptz;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  SELECT pr.id, pr.promotion_id, pr.company_id, pr.customer_id,
         pr.points_spent, pr.status, p.title
    INTO v_redemption
    FROM public.promotion_redemptions pr
    JOIN public.promotions p ON p.id = pr.promotion_id
   WHERE pr.id = p_redemption_id
   FOR UPDATE OF pr;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Benefício não encontrado.';
  END IF;

  SELECT c.id INTO v_company_id
    FROM public.companies c
   WHERE c.id = v_redemption.company_id
     AND c.owner_id = v_user_id
     AND c.active = true;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Você não tem permissão para validar este benefício.';
  END IF;
  IF v_redemption.status = 'used' THEN
    RAISE EXCEPTION 'Este benefício já foi utilizado.';
  END IF;
  IF v_redemption.status = 'cancelled' THEN
    RAISE EXCEPTION 'Este benefício foi cancelado.';
  END IF;
  IF v_redemption.status <> 'available' THEN
    RAISE EXCEPTION 'Este benefício não está disponível para utilização.';
  END IF;

  UPDATE public.promotion_redemptions
     SET status = 'used', used_at = now()
   WHERE id = p_redemption_id AND status = 'available'
   RETURNING used_at INTO v_used_at;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este benefício não está mais disponível.';
  END IF;

  RETURN json_build_object(
    'success', true,
    'id', v_redemption.id,
    'title', v_redemption.title,
    'points_spent', v_redemption.points_spent,
    'status', 'used',
    'used_at', v_used_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.use_promotion_redemption(p_redemption_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid;
  v_redemption public.promotion_redemptions%ROWTYPE;
  v_company_id uuid;
  v_used_at timestamptz;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  SELECT * INTO v_redemption
    FROM public.promotion_redemptions
   WHERE id = p_redemption_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Benefício não encontrado.';
  END IF;

  SELECT c.id INTO v_company_id
    FROM public.companies c
   WHERE c.id = v_redemption.company_id
     AND c.owner_id = v_user_id
     AND c.active = true;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Você não tem permissão para validar este benefício.';
  END IF;
  IF v_redemption.status = 'used' THEN
    RAISE EXCEPTION 'Este benefício já foi utilizado.';
  END IF;
  IF v_redemption.status = 'cancelled' THEN
    RAISE EXCEPTION 'Este benefício foi cancelado.';
  END IF;
  IF v_redemption.status <> 'available' THEN
    RAISE EXCEPTION 'Este benefício não está disponível para utilização.';
  END IF;

  UPDATE public.promotion_redemptions
     SET status = 'used', used_at = now()
   WHERE id = p_redemption_id AND status = 'available'
   RETURNING used_at INTO v_used_at;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este benefício não está mais disponível.';
  END IF;

  RETURN json_build_object(
    'success', true,
    'redemption_id', v_redemption.id,
    'status', 'used',
    'used_at', v_used_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.validate_promotion_redemption(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_promotion_redemption(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.use_promotion_redemption(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.use_promotion_redemption(uuid) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Após a migração:
-- 1. Atualize cidade/UF da empresa antiga pela tela de Dados da empresa.
-- 2. Confirme que a empresa está ativa para aparecer em Explorar.
-- 3. Faça os testes descritos em MIGRACAO_E_TESTES.md.
