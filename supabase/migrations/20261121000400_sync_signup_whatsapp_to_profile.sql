-- Copia o WhatsApp informado no cadastro (Auth metadata: phone) para profiles.whatsapp.
-- Não sobrescreve números já preenchidos no perfil.
BEGIN;

CREATE OR REPLACE FUNCTION public.sync_signup_preferences_to_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_meta jsonb;
BEGIN
  SELECT raw_user_meta_data INTO v_meta FROM auth.users WHERE id = NEW.id;
  IF v_meta IS NOT NULL THEN
    NEW.customer_interests := COALESCE(
      ARRAY(SELECT jsonb_array_elements_text(v_meta->'customer_interests')),
      '{}'
    );
    IF NULLIF(btrim(coalesce(NEW.whatsapp, '')), '') IS NULL THEN
      NEW.whatsapp := NULLIF(regexp_replace(coalesce(v_meta->>'phone', ''), '[^0-9]', '', 'g'), '');
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;


-- Corrige também perfis criados anteriormente cujo telefone ficou apenas nos metadados.
UPDATE public.profiles p
SET whatsapp = NULLIF(regexp_replace(coalesce(u.raw_user_meta_data->>'phone', ''), '[^0-9]', '', 'g'), '')
FROM auth.users u
WHERE u.id = p.id
  AND NULLIF(btrim(coalesce(p.whatsapp, '')), '') IS NULL
  AND NULLIF(regexp_replace(coalesce(u.raw_user_meta_data->>'phone', ''), '[^0-9]', '', 'g'), '') IS NOT NULL;

COMMIT;
