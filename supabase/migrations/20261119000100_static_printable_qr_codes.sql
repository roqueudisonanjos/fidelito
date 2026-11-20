-- QR codes permanentes para impressão: podem ser escaneados por múltiplos clientes.
ALTER TABLE public.qr_codes
  ADD COLUMN IF NOT EXISTS is_static boolean NOT NULL DEFAULT false;


CREATE OR REPLACE FUNCTION public.create_static_qr_code(p_points integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_qr public.qr_codes%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;
  IF p_points IS NULL OR p_points <= 0 THEN
    RAISE EXCEPTION 'Quantidade de pontos inválida';
  END IF;

  SELECT id INTO v_company_id
  FROM public.companies
  WHERE owner_id = v_user_id AND active = true
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Nenhuma empresa ativa encontrada para este usuário';
  END IF;

  INSERT INTO public.qr_codes (company_id, code, points, active, expires_at, is_static)
  VALUES (v_company_id, gen_random_uuid(), p_points, true, NULL, true)
  RETURNING * INTO v_qr;


  RETURN jsonb_build_object(
    'id', v_qr.id,
    'code', v_qr.code,
    'points', v_qr.points,
    'expires_at', v_qr.expires_at,
    'is_static', v_qr.is_static
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.create_static_qr_code(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_static_qr_code(integer) TO authenticated;


-- Recompõe o resgate: QR temporário continua de uso único; QR estático permanece ativo.
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
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;

  SELECT * INTO v_qr FROM public.qr_codes WHERE code = p_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'QR Code não encontrado'; END IF;
  IF v_qr.active IS DISTINCT FROM true THEN RAISE EXCEPTION 'QR Code inativo'; END IF;
  IF NOT COALESCE(v_qr.is_static, false) AND v_qr.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR Code já utilizado';
  END IF;
  IF v_qr.expires_at IS NOT NULL AND v_qr.expires_at <= now() THEN
    RAISE EXCEPTION 'QR Code expirado';
  END IF;
  IF v_qr.points IS NULL OR v_qr.points <= 0 THEN RAISE EXCEPTION 'Quantidade de pontos inválida'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.companies c WHERE c.id = v_qr.company_id AND c.active = true) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível';
  END IF;
  IF EXISTS (SELECT 1 FROM public.companies c WHERE c.id = v_qr.company_id AND c.owner_id = v_user_id) THEN
    RAISE EXCEPTION 'O proprietário da empresa não pode utilizar o próprio QR Code';
  END IF;
  IF COALESCE(v_qr.is_static, false) AND EXISTS (
    SELECT 1 FROM public.loyalty_transactions lt
    WHERE lt.qr_code_id = v_qr.id AND lt.customer_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Você já utilizou este QR Code permanente';
  END IF;

  SELECT * INTO v_account FROM public.loyalty_accounts
  WHERE company_id = v_qr.company_id AND customer_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
    VALUES (v_qr.company_id, v_user_id, 0) RETURNING * INTO v_account;
  ELSIF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você saiu do programa desta empresa. Entre novamente pelo aplicativo para voltar a acumular pontos.';
  END IF;

  UPDATE public.loyalty_accounts
  SET points = points + v_qr.points, updated_at = now()
  WHERE id = v_account.id RETURNING * INTO v_account;


  INSERT INTO public.loyalty_transactions (
    loyalty_account_id, customer_id, company_id, type, points, qr_code_id, description
  ) VALUES (
    v_account.id, v_user_id, v_qr.company_id, 'earn', v_qr.points,
    v_qr.id, CASE WHEN COALESCE(v_qr.is_static, false)
      THEN 'Pontos recebidos através de QR Code permanente'
      ELSE 'Pontos recebidos através de QR Code' END
  ) RETURNING * INTO v_transaction;


  IF NOT COALESCE(v_qr.is_static, false) THEN
    UPDATE public.qr_codes SET active = false, used_at = now(), used_by = v_user_id WHERE id = v_qr.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'points_earned', v_qr.points,
    'new_balance', v_account.points,
    'company_id', v_qr.company_id,
    'qr_code_id', v_qr.id,
    'transaction_id', v_transaction.id,
    'is_static', COALESCE(v_qr.is_static, false)
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.redeem_qr_code(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_qr_code(uuid) TO authenticated;
