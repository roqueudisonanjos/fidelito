-- Fidelito: atualizacao segura dos dados cadastrais por RPC.
-- Evita depender de GRANT UPDATE direto nas tabelas expostas pelo PostgREST.
-- Cada funcao altera somente o registro pertencente ao usuario autenticado
-- e somente os campos cadastrais explicitamente permitidos.

BEGIN;

CREATE OR REPLACE FUNCTION public.update_my_profile(
  p_full_name text,
  p_whatsapp text,
  p_city text,
  p_state text,
  p_avatar_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  UPDATE public.profiles
  SET full_name = NULLIF(btrim(p_full_name), ''),
      whatsapp = NULLIF(regexp_replace(coalesce(p_whatsapp, ''), '[^0-9]', '', 'g'), ''),
      city = NULLIF(btrim(coalesce(p_city, '')), ''),
      state = NULLIF(upper(btrim(coalesce(p_state, ''))), ''),
      avatar_url = p_avatar_url
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil do usuário não encontrado.';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_my_company(
  p_name text,
  p_description text,
  p_phone text,
  p_address text,
  p_city text,
  p_state text,
  p_logo_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

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
      updated_at = now()
  WHERE owner_id = v_user_id
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa não encontrada para este usuário.';
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.update_my_profile(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_my_company(text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_company(text, text, text, text, text, text, text) TO authenticated;

COMMIT;
NOTIFY pgrst, 'reload schema';
