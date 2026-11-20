-- Fidelito: redes sociais opcionais das empresas (Instagram e TikTok).
BEGIN;
ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS instagram_username text,
  ADD COLUMN IF NOT EXISTS tiktok_username text;

DROP FUNCTION IF EXISTS public.update_my_company(text, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.update_my_company(
  p_name text, p_description text, p_phone text, p_address text,
  p_city text, p_state text, p_logo_url text DEFAULT NULL,
  p_instagram_username text DEFAULT NULL, p_tiktok_username text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;
  IF NULLIF(btrim(coalesce(p_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'O nome da empresa é obrigatório.';
  END IF;
  UPDATE public.companies
  SET name = btrim(p_name),
      description = NULLIF(btrim(coalesce(p_description, '')), ''),
      phone = NULLIF(btrim(coalesce(p_phone, '')), ''),
      address = NULLIF(btrim(coalesce(p_address, '')), ''),
      city = NULLIF(btrim(coalesce(p_city, '')), ''),
      state = NULLIF(upper(btrim(coalesce(p_state, ''))), ''),
      logo_url = p_logo_url,
      instagram_username = NULLIF(regexp_replace(btrim(coalesce(p_instagram_username, '')), '^@+', ''), ''),
      tiktok_username = NULLIF(regexp_replace(btrim(coalesce(p_tiktok_username, '')), '^@+', ''), ''),
      updated_at = now()
  WHERE owner_id = v_user_id AND deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Empresa não encontrada para este usuário.'; END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.update_my_company(text, text, text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_company(text, text, text, text, text, text, text, text, text) TO authenticated;
COMMIT;
NOTIFY pgrst, 'reload schema';
