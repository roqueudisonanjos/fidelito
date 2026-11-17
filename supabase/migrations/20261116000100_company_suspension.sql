-- Suspensão administrativa de empresa no Fidelito.
-- Notifica clientes ativos e preserva seus saldos; nenhuma adesão é encerrada.
-- Execute no Supabase SQL Editor após backup e validação em ambiente de teste.

BEGIN;

ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz;

CREATE OR REPLACE FUNCTION public.set_company_active_with_notifications(
  p_company_id uuid,
  p_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_company public.companies%ROWTYPE;
  v_customers_notified integer := 0;
BEGIN
  IF p_company_id IS NULL OR p_active IS NULL THEN
    RAISE EXCEPTION 'Empresa ou status inválido.';
  END IF;

  SELECT * INTO v_company
  FROM public.companies
  WHERE id = p_company_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa não encontrada.';
  END IF;

  IF p_active = false AND v_company.active IS DISTINCT FROM false THEN
    INSERT INTO public.user_notifications (
      user_id, company_id, title, message, notification_type
    )
    SELECT DISTINCT
      la.customer_id,
      v_company.id,
      'Programa de fidelidade suspenso',
      'O programa de fidelidade da empresa ' || v_company.name ||
      ' está suspenso. Enquanto estiver suspenso, você não poderá utilizar seus pontos nem realizar novos resgates. Seu saldo permanece registrado e poderá voltar a ser utilizado se o programa for reativado.',
      'loyalty_program_suspended'
    FROM public.loyalty_accounts la
    WHERE la.company_id = v_company.id
      AND la.left_at IS NULL;

    GET DIAGNOSTICS v_customers_notified = ROW_COUNT;
  END IF;

  UPDATE public.companies
  SET active = p_active,
      suspended_at = CASE WHEN p_active THEN NULL ELSE COALESCE(suspended_at, now()) END
  WHERE id = p_company_id
  RETURNING * INTO v_company;

  -- Não zeramos pontos, não encerramos adesões e não desativamos definitivamente
  -- benefícios/QRs. As operações já validam companies.active e ficam bloqueadas
  -- durante a suspensão; ao reativar, os dados e saldos preservados voltam a valer.

  RETURN jsonb_build_object(
    'company', jsonb_build_object(
      'id', v_company.id,
      'name', v_company.name,
      'active', v_company.active,
      'suspended_at', v_company.suspended_at
    ),
    'customers_notified', v_customers_notified
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.set_company_active_with_notifications(uuid, boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_company_active_with_notifications(uuid, boolean)
  TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
