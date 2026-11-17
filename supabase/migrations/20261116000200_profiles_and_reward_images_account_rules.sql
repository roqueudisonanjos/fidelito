-- Fotos de perfil/empresa/recompensas e confirmação de desativação antes de excluir empresa.
BEGIN;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.promotions ADD COLUMN IF NOT EXISTS image_url text;

-- A empresa precisa estar desativada antes da exclusão definitiva da conta.
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
    RETURN jsonb_build_object('success', true, 'companies_deleted', 0, 'customers_notified', 0);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.companies
    WHERE owner_id = p_user_id AND active = true
  ) THEN
    RAISE EXCEPTION 'Antes de excluir a conta, desative a empresa na área administrativa.';
  END IF;

  INSERT INTO public.user_notifications (user_id, company_id, title, message, notification_type)
  SELECT DISTINCT la.customer_id, c.id,
    'Programa de fidelidade encerrado',
    'A empresa ' || c.name || ' encerrou sua conta no Fidelito. O programa foi encerrado e o saldo de pontos desta empresa foi zerado.',
    'company_account_closed'
  FROM public.loyalty_accounts la
  JOIN public.companies c ON c.id = la.company_id
  WHERE la.company_id = ANY(v_company_ids) AND la.left_at IS NULL;
  GET DIAGNOSTICS v_customer_count = ROW_COUNT;

  UPDATE public.promotions SET active = false WHERE company_id = ANY(v_company_ids);
  UPDATE public.loyalty_accounts
    SET points = 0, left_at = now(), updated_at = now()
    WHERE company_id = ANY(v_company_ids) AND left_at IS NULL;

  UPDATE public.companies
    SET active = false, deleted_at = now(), owner_id = NULL
    WHERE id = ANY(v_company_ids);

  RETURN jsonb_build_object('success', true, 'companies_deleted', v_company_count, 'customers_notified', v_customer_count);
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_company_account_deletion(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prepare_company_account_deletion(uuid) TO service_role;

-- Bucket público para exibir as imagens nos cards; gravação restrita à pasta do próprio usuário.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('fidelito-images', 'fidelito-images', true, 5242880, ARRAY['image/jpeg','image/png','image/webp','image/heic'])
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp','image/heic'];

DROP POLICY IF EXISTS "Fidelito images public read" ON storage.objects;
CREATE POLICY "Fidelito images public read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'fidelito-images');
DROP POLICY IF EXISTS "Fidelito images owner insert" ON storage.objects;
CREATE POLICY "Fidelito images owner insert" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'fidelito-images' AND (storage.foldername(name))[2] = auth.uid()::text
  );
DROP POLICY IF EXISTS "Fidelito images owner update" ON storage.objects;
CREATE POLICY "Fidelito images owner update" ON storage.objects
  FOR UPDATE TO authenticated USING (
    bucket_id = 'fidelito-images' AND (storage.foldername(name))[2] = auth.uid()::text
  ) WITH CHECK (
    bucket_id = 'fidelito-images' AND (storage.foldername(name))[2] = auth.uid()::text
  );
DROP POLICY IF EXISTS "Fidelito images owner delete" ON storage.objects;
CREATE POLICY "Fidelito images owner delete" ON storage.objects
  FOR DELETE TO authenticated USING (
    bucket_id = 'fidelito-images' AND (storage.foldername(name))[2] = auth.uid()::text
  );

COMMIT;
NOTIFY pgrst, 'reload schema';
