-- Fidelito: categorias, interesses, cadastro empresarial sem aprovação e ofertas.
BEGIN;

ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS category text;
UPDATE public.companies SET active = true WHERE suspended_at IS NULL AND deleted_at IS NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS customer_interests text[] NOT NULL DEFAULT '{}';
UPDATE public.companies SET category = 'Outros' WHERE category IS NULL OR btrim(category) = '';

CREATE INDEX IF NOT EXISTS companies_category_active_idx
  ON public.companies(category) WHERE active = true;

-- Categorias e interesses iniciais do app.
-- O trigger usa metadados do cadastro; não altera perfis existentes além de
-- preenchê-los quando o usuário tiver escolhido interesses no signup.
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
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS profiles_signup_preferences_sync ON public.profiles;
CREATE TRIGGER profiles_signup_preferences_sync
BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_signup_preferences_to_profile();

-- Empresa recém-cadastrada fica ativa imediatamente. Mantém os parâmetros
-- anteriores e adiciona categoria obrigatória.
CREATE OR REPLACE FUNCTION public.create_company(
  p_name text,
  p_description text,
  p_phone text,
  p_address text,
  p_city text,
  p_state text,
  p_category text
)
RETURNS public.companies
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_company public.companies;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado'; END IF;
  IF btrim(coalesce(p_name, '')) = '' THEN RAISE EXCEPTION 'Nome da empresa é obrigatório'; END IF;
  IF btrim(coalesce(p_city, '')) = '' THEN RAISE EXCEPTION 'Cidade da empresa é obrigatória'; END IF;
  IF btrim(coalesce(p_category, '')) = '' THEN RAISE EXCEPTION 'Categoria da empresa é obrigatória'; END IF;
  IF p_state IS NOT NULL AND length(btrim(p_state)) <> 2 THEN RAISE EXCEPTION 'Informe uma UF válida com duas letras'; END IF;
  IF EXISTS (SELECT 1 FROM public.companies c WHERE c.owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'Usuário já possui uma empresa';
  END IF;

  INSERT INTO public.companies (
    owner_id, name, description, phone, address, city, state, category, active
  ) VALUES (
    auth.uid(), btrim(p_name), nullif(btrim(p_description), ''),
    nullif(btrim(p_phone), ''), nullif(btrim(p_address), ''),
    btrim(p_city), upper(btrim(p_state)), btrim(p_category), true
  )
  RETURNING * INTO v_company;
  RETURN v_company;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_company(text,text,text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_company(text,text,text,text,text,text,text) TO authenticated;

-- Ofertas promocionais são separadas de recompensas e não movimentam pontos.
CREATE TABLE IF NOT EXISTS public.company_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (length(trim(title)) > 0),
  description text,
  image_url text,
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
);
-- Migra recompensas sem pontos para ofertas, preservando o texto, imagem e datas.
INSERT INTO public.company_offers(company_id,title,description,image_url,starts_at,ends_at,active,created_at,updated_at)
SELECT company_id,title,description,image_url,starts_at,ends_at,active,created_at,COALESCE(updated_at,created_at)
FROM public.promotions
WHERE points_required = 0
ON CONFLICT DO NOTHING;
UPDATE public.promotions SET active = false, updated_at = now() WHERE points_required = 0;

CREATE OR REPLACE FUNCTION public.require_positive_reward_points()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
  IF NEW.points_required IS NULL OR NEW.points_required <= 0 THEN
    RAISE EXCEPTION 'Recompensas devem exigir pelo menos 1 ponto. Use Ofertas para promoções sem pontos.';
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS promotions_positive_points_check ON public.promotions;
CREATE TRIGGER promotions_positive_points_check
BEFORE INSERT OR UPDATE OF points_required ON public.promotions
FOR EACH ROW EXECUTE FUNCTION public.require_positive_reward_points();

CREATE INDEX IF NOT EXISTS company_offers_active_period_idx
  ON public.company_offers(active, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS company_offers_company_created_idx
  ON public.company_offers(company_id, created_at DESC);
ALTER TABLE public.company_offers ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.company_offers TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.company_offers TO authenticated;
DROP POLICY IF EXISTS company_offers_public_read ON public.company_offers;
CREATE POLICY company_offers_public_read ON public.company_offers
  FOR SELECT TO authenticated USING (
    active = true AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at >= now())
  );
DROP POLICY IF EXISTS company_offers_owner_all ON public.company_offers;
CREATE POLICY company_offers_owner_all ON public.company_offers
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.companies c
      WHERE c.id = company_offers.company_id AND c.owner_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.companies c
      WHERE c.id = company_offers.company_id AND c.owner_id = auth.uid())
  );

-- Atualização cadastral agora permite editar categoria.
DROP FUNCTION IF EXISTS public.update_my_company(text,text,text,text,text,text,text,text,text);
CREATE OR REPLACE FUNCTION public.update_my_company(
  p_name text, p_description text, p_phone text, p_address text,
  p_city text, p_state text, p_logo_url text DEFAULT NULL,
  p_instagram_username text DEFAULT NULL, p_tiktok_username text DEFAULT NULL,
  p_category text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;
  IF NULLIF(btrim(coalesce(p_name, '')), '') IS NULL THEN RAISE EXCEPTION 'O nome da empresa é obrigatório.'; END IF;
  IF NULLIF(btrim(coalesce(p_category, '')), '') IS NULL THEN RAISE EXCEPTION 'A categoria da empresa é obrigatória.'; END IF;
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
      category = btrim(p_category),
      updated_at = now()
  WHERE owner_id = v_user_id AND deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Empresa não encontrada para este usuário.'; END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.update_my_company(text,text,text,text,text,text,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_company(text,text,text,text,text,text,text,text,text,text) TO authenticated;

COMMIT;
NOTIFY pgrst, 'reload schema';
