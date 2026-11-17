-- Encerramento de contas e notificações aos clientes afetados.
-- Execute após as migrações 20261115000100 e 20261115000200.

BEGIN;

ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Permite preservar o registro empresarial desativado sem manter vínculo com
-- a identidade Auth que será excluída ao encerrar a conta do responsável.
ALTER TABLE public.companies
  ALTER COLUMN owner_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL,
  title text NOT NULL,
  message text NOT NULL,
  notification_type text NOT NULL DEFAULT 'general',
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_notifications_user_created_idx
  ON public.user_notifications (user_id, created_at DESC);

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_notifications FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.user_notifications TO authenticated;
REVOKE UPDATE ON TABLE public.user_notifications FROM authenticated;
GRANT UPDATE (read_at) ON TABLE public.user_notifications TO authenticated;
GRANT ALL ON TABLE public.user_notifications TO service_role;

DROP POLICY IF EXISTS "Users read own notifications" ON public.user_notifications;
CREATE POLICY "Users read own notifications"
  ON public.user_notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users mark own notifications as read" ON public.user_notifications;
CREATE POLICY "Users mark own notifications as read"
  ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- Operações de banco executadas pela Edge Function com service_role.
-- Cada função roda em uma transação PostgreSQL, evitando encerramentos parciais.
CREATE OR REPLACE FUNCTION public.prepare_customer_account_deletion(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  DELETE FROM public.promotion_redemptions WHERE customer_id = p_user_id;
  DELETE FROM public.loyalty_transactions WHERE customer_id = p_user_id;
  DELETE FROM public.loyalty_accounts WHERE customer_id = p_user_id;
  RETURN jsonb_build_object('success', true);
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_customer_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_customer_account_deletion(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.prepare_company_account_deletion(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_company_ids uuid[];
  v_company_count integer;
  v_customer_count integer;
BEGIN
  SELECT array_agg(id), count(*)::integer
    INTO v_company_ids, v_company_count
  FROM public.companies
  WHERE owner_id = p_user_id;

  IF v_company_ids IS NULL OR cardinality(v_company_ids) = 0 THEN
    RETURN jsonb_build_object('success', true, 'companies_deactivated', 0, 'customers_notified', 0);
  END IF;

  INSERT INTO public.user_notifications (
    user_id, company_id, title, message, notification_type
  )
  SELECT
    la.customer_id,
    c.id,
    'Programa de fidelidade encerrado',
    'A empresa ' || c.name || ' encerrou sua conta no Fidelito. O programa foi desativado e o saldo de pontos desta empresa foi zerado. Sua participação foi encerrada.',
    'company_account_closed'
  FROM public.loyalty_accounts la
  JOIN public.companies c ON c.id = la.company_id
  WHERE la.company_id = ANY(v_company_ids)
    AND la.left_at IS NULL;

  GET DIAGNOSTICS v_customer_count = ROW_COUNT;

  UPDATE public.promotions
  SET active = false
  WHERE company_id = ANY(v_company_ids);

  UPDATE public.loyalty_accounts
  SET points = 0,
      left_at = now(),
      updated_at = now()
  WHERE company_id = ANY(v_company_ids)
    AND left_at IS NULL;

  -- owner_id torna-se nulo para preservar a empresa sem manter dados de Auth.
  UPDATE public.companies
  SET active = false,
      deleted_at = now(),
      owner_id = NULL
  WHERE id = ANY(v_company_ids);

  RETURN jsonb_build_object(
    'success', true,
    'companies_deactivated', v_company_count,
    'customers_notified', v_customer_count
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_company_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_company_account_deletion(uuid) TO service_role;

COMMIT;
