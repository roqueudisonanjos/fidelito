-- QR Codes permanentes: cada leitura gera uma solicitação de pontos que a empresa aprova.
-- O cliente pode repetir leituras do mesmo QR após solicitações anteriores serem decididas.
BEGIN;

CREATE TABLE IF NOT EXISTS public.qr_point_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qr_code_id uuid NOT NULL REFERENCES public.qr_codes(id) ON DELETE CASCADE,
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points integer NOT NULL CHECK (points > 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);


CREATE INDEX IF NOT EXISTS qr_point_requests_company_status_created_idx
  ON public.qr_point_requests (company_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS qr_point_requests_customer_created_idx
  ON public.qr_point_requests (customer_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS qr_point_requests_one_pending_per_customer_qr_idx
  ON public.qr_point_requests (qr_code_id, customer_id)
  WHERE status = 'pending';


ALTER TABLE public.qr_point_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_point_requests FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.qr_point_requests TO authenticated;
GRANT ALL ON TABLE public.qr_point_requests TO service_role;
DROP POLICY IF EXISTS qr_point_requests_customer_read ON public.qr_point_requests;
CREATE POLICY qr_point_requests_customer_read ON public.qr_point_requests
  FOR SELECT TO authenticated USING (customer_id = auth.uid());
DROP POLICY IF EXISTS qr_point_requests_company_read ON public.qr_point_requests;
CREATE POLICY qr_point_requests_company_read ON public.qr_point_requests
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.companies c
           WHERE c.id = qr_point_requests.company_id AND c.owner_id = auth.uid())
  );


CREATE OR REPLACE FUNCTION public.request_static_qr_points(p_code uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_customer uuid := auth.uid();
  v_qr public.qr_codes%ROWTYPE;
  v_company public.companies%ROWTYPE;
  v_profile_name text;
  v_account public.loyalty_accounts%ROWTYPE;
  v_request public.qr_point_requests%ROWTYPE;
  v_existing public.qr_point_requests%ROWTYPE;
BEGIN
  IF v_customer IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  SELECT * INTO v_qr FROM public.qr_codes WHERE code = p_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'QR Code não encontrado'; END IF;
  IF v_qr.active IS DISTINCT FROM true THEN RAISE EXCEPTION 'QR Code inativo'; END IF;
  IF NOT COALESCE(v_qr.is_static, false) THEN RAISE EXCEPTION 'Este QR Code não é permanente'; END IF;
  IF v_qr.points IS NULL OR v_qr.points <= 0 THEN RAISE EXCEPTION 'Quantidade de pontos inválida'; END IF;
  SELECT * INTO v_company FROM public.companies WHERE id = v_qr.company_id AND active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Esta empresa não está disponível'; END IF;
  IF v_company.owner_id = v_customer THEN RAISE EXCEPTION 'O proprietário não pode escanear o QR Code da própria empresa'; END IF;

  -- Mantém a adesão automática que o fluxo de QR anterior oferecia.
  INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
  VALUES (v_qr.company_id, v_customer, 0)
  ON CONFLICT (company_id, customer_id) DO NOTHING;
  SELECT * INTO v_account FROM public.loyalty_accounts
    WHERE company_id = v_qr.company_id AND customer_id = v_customer FOR UPDATE;
  IF v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você saiu do programa desta empresa. Entre novamente pelo aplicativo para voltar a acumular pontos.';
  END IF;

  SELECT * INTO v_existing FROM public.qr_point_requests
    WHERE qr_code_id = v_qr.id AND customer_id = v_customer AND status = 'pending'
    ORDER BY created_at DESC LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('success', true, 'request_pending', true, 'already_pending', true,
      'request_id', v_existing.id, 'points', v_existing.points, 'company_name', v_company.name);
  END IF;

  INSERT INTO public.qr_point_requests (qr_code_id, company_id, customer_id, points)
  VALUES (v_qr.id, v_qr.company_id, v_customer, v_qr.points)
  ON CONFLICT (qr_code_id, customer_id) WHERE status = 'pending' DO NOTHING
  RETURNING * INTO v_request;
  IF NOT FOUND THEN
    SELECT * INTO v_existing FROM public.qr_point_requests
      WHERE qr_code_id = v_qr.id AND customer_id = v_customer AND status = 'pending'
      ORDER BY created_at DESC LIMIT 1;
    RETURN jsonb_build_object('success', true, 'request_pending', true, 'already_pending', true,
      'request_id', v_existing.id, 'points', v_existing.points, 'company_name', v_company.name);
  END IF;

  SELECT full_name INTO v_profile_name FROM public.profiles WHERE id = v_customer;
  INSERT INTO public.user_notifications (user_id, company_id, title, message, notification_type)
  VALUES (v_company.owner_id, v_company.id, 'Solicitação de pontos pendente',
    COALESCE(NULLIF(v_profile_name, ''), 'Um cliente') || ' escaneou um QR Code permanente e solicitou ' || v_qr.points || ' pontos. Aprove ou rejeite no portal da empresa.',
    'static_qr_points_request');

  RETURN jsonb_build_object('success', true, 'request_pending', true, 'already_pending', false,
    'request_id', v_request.id, 'points', v_request.points, 'company_name', v_company.name);
END;
$function$;
REVOKE ALL ON FUNCTION public.request_static_qr_points(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_static_qr_points(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_company_qr_point_requests()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_owner uuid := auth.uid();
  v_company_id uuid;
  v_result jsonb;
BEGIN
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  SELECT id INTO v_company_id FROM public.companies WHERE owner_id = v_owner AND active = true LIMIT 1;
  IF v_company_id IS NULL THEN RAISE EXCEPTION 'Empresa ativa não encontrada'; END IF;
  SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb) INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'id', r.id, 'qr_code_id', r.qr_code_id, 'customer_id', r.customer_id,
      'customer_name', COALESCE(NULLIF(p.full_name, ''), 'Cliente'),
      'points', r.points, 'status', r.status, 'created_at', r.created_at
    ) AS row_data, r.created_at
    FROM public.qr_point_requests r
    LEFT JOIN public.profiles p ON p.id = r.customer_id
    WHERE r.company_id = v_company_id AND r.status = 'pending'
  ) pending_rows;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_company_qr_point_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_company_qr_point_requests() TO authenticated;


CREATE OR REPLACE FUNCTION public.approve_static_qr_points_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_owner uuid := auth.uid();
  v_request public.qr_point_requests%ROWTYPE;
  v_company public.companies%ROWTYPE;
  v_account public.loyalty_accounts%ROWTYPE;
  v_transaction public.loyalty_transactions%ROWTYPE;
BEGIN
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  SELECT * INTO v_request FROM public.qr_point_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitação não encontrada'; END IF;
  SELECT * INTO v_company FROM public.companies WHERE id = v_request.company_id AND owner_id = v_owner AND active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Você não tem permissão para aprovar esta solicitação'; END IF;
  IF v_request.status <> 'pending' THEN RAISE EXCEPTION 'Esta solicitação já foi processada'; END IF;
  SELECT * INTO v_account FROM public.loyalty_accounts
    WHERE company_id = v_request.company_id AND customer_id = v_request.customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Conta de fidelidade não encontrada'; END IF;
  IF v_account.left_at IS NOT NULL THEN RAISE EXCEPTION 'Cliente não participa mais deste programa'; END IF;
  UPDATE public.loyalty_accounts SET points = points + v_request.points, updated_at = now()
    WHERE id = v_account.id RETURNING * INTO v_account;
  INSERT INTO public.loyalty_transactions (loyalty_account_id, customer_id, company_id, type, points, qr_code_id, description)
  VALUES (v_account.id, v_request.customer_id, v_request.company_id, 'earn', v_request.points,
    v_request.qr_code_id, 'Pontos creditados após aprovação de leitura de QR Code permanente')
  RETURNING * INTO v_transaction;
  UPDATE public.qr_point_requests SET status = 'approved', decided_at = now(), decided_by = v_owner WHERE id = v_request.id;
  INSERT INTO public.user_notifications (user_id, company_id, title, message, notification_type)
  VALUES (v_request.customer_id, v_company.id, 'Pontos recebidos!',
    'Você ganhou ' || v_request.points || ' pontos no programa de fidelidade da empresa ' || v_company.name || '. Os pontos já estão disponíveis no seu saldo.',
    'static_qr_points_approved');
  RETURN jsonb_build_object('success', true, 'points_added', v_request.points, 'new_balance', v_account.points, 'customer_id', v_request.customer_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.approve_static_qr_points_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_static_qr_points_request(uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.reject_static_qr_points_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_owner uuid := auth.uid();
  v_request public.qr_point_requests%ROWTYPE;
  v_company public.companies%ROWTYPE;
BEGIN
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  SELECT * INTO v_request FROM public.qr_point_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Solicitação não encontrada'; END IF;
  SELECT * INTO v_company FROM public.companies WHERE id = v_request.company_id AND owner_id = v_owner AND active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Você não tem permissão para rejeitar esta solicitação'; END IF;
  IF v_request.status <> 'pending' THEN RAISE EXCEPTION 'Esta solicitação já foi processada'; END IF;
  UPDATE public.qr_point_requests SET status = 'rejected', decided_at = now(), decided_by = v_owner WHERE id = v_request.id;
  INSERT INTO public.user_notifications (user_id, company_id, title, message, notification_type)
  VALUES (v_request.customer_id, v_company.id, 'Solicitação de pontos não aprovada',
    'Sua solicitação de ' || v_request.points || ' pontos no programa de fidelidade da empresa ' || v_company.name || ' não foi aprovada.',
    'static_qr_points_rejected');
  RETURN jsonb_build_object('success', true, 'rejected', true);
END;
$function$;
REVOKE ALL ON FUNCTION public.reject_static_qr_points_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_static_qr_points_request(uuid) TO authenticated;


-- QR temporário permanece creditando imediatamente. QR permanente passa a abrir solicitação pendente.
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
  v_company public.companies%ROWTYPE;
  v_request jsonb;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  SELECT * INTO v_qr FROM public.qr_codes WHERE code = p_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'QR Code não encontrado'; END IF;
  IF v_qr.active IS DISTINCT FROM true THEN RAISE EXCEPTION 'QR Code inativo'; END IF;
  IF v_qr.expires_at IS NOT NULL AND v_qr.expires_at <= now() THEN RAISE EXCEPTION 'QR Code expirado'; END IF;
  IF v_qr.points IS NULL OR v_qr.points <= 0 THEN RAISE EXCEPTION 'Quantidade de pontos inválida'; END IF;
  SELECT * INTO v_company FROM public.companies WHERE id = v_qr.company_id AND active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'Esta empresa não está disponível'; END IF;
  IF v_company.owner_id = v_user_id THEN RAISE EXCEPTION 'O proprietário da empresa não pode utilizar o próprio QR Code'; END IF;

  IF COALESCE(v_qr.is_static, false) THEN
    -- Delegamos para a função que registra uma solicitação sem creditar pontos.
    v_request := public.request_static_qr_points(p_code);
    RETURN v_request;
  END IF;

  IF v_qr.used_at IS NOT NULL THEN RAISE EXCEPTION 'QR Code já utilizado'; END IF;
  INSERT INTO public.loyalty_accounts (company_id, customer_id, points)
  VALUES (v_qr.company_id, v_user_id, 0) ON CONFLICT (company_id, customer_id) DO NOTHING;
  SELECT * INTO v_account FROM public.loyalty_accounts
    WHERE company_id = v_qr.company_id AND customer_id = v_user_id FOR UPDATE;
  IF v_account.left_at IS NOT NULL THEN RAISE EXCEPTION 'Você saiu do programa desta empresa. Entre novamente pelo aplicativo para voltar a acumular pontos.'; END IF;
  UPDATE public.loyalty_accounts SET points = points + v_qr.points, updated_at = now()
    WHERE id = v_account.id RETURNING * INTO v_account;
  INSERT INTO public.loyalty_transactions (loyalty_account_id, customer_id, company_id, type, points, qr_code_id, description)
  VALUES (v_account.id, v_user_id, v_qr.company_id, 'earn', v_qr.points, v_qr.id, 'Pontos recebidos através de QR Code')
  RETURNING * INTO v_transaction;
  UPDATE public.qr_codes SET active = false, used_at = now(), used_by = v_user_id WHERE id = v_qr.id;
  RETURN jsonb_build_object('success', true, 'points_earned', v_qr.points, 'new_balance', v_account.points,
    'company_id', v_qr.company_id, 'qr_code_id', v_qr.id, 'transaction_id', v_transaction.id, 'is_static', false);
END;
$function$;
REVOKE ALL ON FUNCTION public.redeem_qr_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_qr_code(uuid) TO authenticated;

COMMIT;
