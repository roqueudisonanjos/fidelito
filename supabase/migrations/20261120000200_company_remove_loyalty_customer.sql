-- Permite que uma empresa remova um cliente do próprio programa de fidelidade.
-- O histórico é preservado; o saldo remanescente é zerado ao encerrar o vínculo.
BEGIN;

CREATE OR REPLACE FUNCTION public.company_remove_customer_from_loyalty(p_customer_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_company_id uuid;
  v_company_name text;
  v_account public.loyalty_accounts%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  SELECT id, name INTO v_company_id, v_company_name
  FROM public.companies
  WHERE owner_id = auth.uid() AND active = true AND deleted_at IS NULL
  ORDER BY created_at
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Empresa ativa não encontrada para esta conta';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_company_id
    AND customer_id = p_customer_id
    AND left_at IS NULL
  FOR UPDATE;


  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este cliente não participa ativamente do programa';
  END IF;

  UPDATE public.loyalty_accounts
  SET points = 0,
      left_at = now(),
      updated_at = now()
  WHERE id = v_account.id;


  INSERT INTO public.user_notifications (
    user_id, company_id, title, message, notification_type
  ) VALUES (
    p_customer_id,
    v_company_id,
    'Participação no programa encerrada',
    'Sua participação no programa de fidelidade da empresa ' || v_company_name || ' foi encerrada pela empresa. Seu saldo deste programa foi zerado. Seu histórico permanece registrado.',
    'loyalty_membership_removed'
  );


  RETURN jsonb_build_object('success', true, 'company_id', v_company_id, 'customer_id', p_customer_id);
END;
$function$;


REVOKE ALL ON FUNCTION public.company_remove_customer_from_loyalty(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.company_remove_customer_from_loyalty(uuid) TO authenticated;


COMMIT;
