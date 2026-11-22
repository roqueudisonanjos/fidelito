-- Atualização atômica dos dados de cliente e das categorias de interesse.
BEGIN;
CREATE OR REPLACE FUNCTION public.update_my_profile_with_interests(
  p_full_name text,
  p_whatsapp text,
  p_city text,
  p_state text,
  p_avatar_url text,
  p_customer_interests text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_allowed text[] := ARRAY[
    'Beleza e estética', 'Restaurantes', 'Cafés e lanchonetes',
    'Moda e acessórios', 'Academias e esportes', 'Saúde e bem-estar',
    'Pet shops', 'Automóveis', 'Casa e decoração', 'Educação',
    'Tecnologia', 'Outros'
  ];
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;
  IF EXISTS (
    SELECT 1
    FROM unnest(COALESCE(p_customer_interests, ARRAY[]::text[])) AS category(value)
    WHERE NOT (value = ANY(v_allowed))
  ) THEN
    RAISE EXCEPTION 'Categoria de interesse inválida.';
  END IF;
  UPDATE public.profiles
  SET full_name = NULLIF(btrim(p_full_name), ''),
      whatsapp = NULLIF(regexp_replace(coalesce(p_whatsapp, ''), '[^0-9]', '', 'g'), ''),
      city = NULLIF(btrim(coalesce(p_city, '')), ''),
      state = NULLIF(upper(btrim(coalesce(p_state, ''))), ''),
      avatar_url = p_avatar_url,
      customer_interests = ARRAY(
        SELECT DISTINCT value
        FROM unnest(COALESCE(p_customer_interests, ARRAY[]::text[])) AS category(value)
      )
  WHERE id = v_user_id AND role = 'customer';
  IF NOT FOUND THEN RAISE EXCEPTION 'Perfil de cliente não encontrado.'; END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.update_my_profile_with_interests(text,text,text,text,text,text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_profile_with_interests(text,text,text,text,text,text[]) TO authenticated;

-- Reforça no banco a remoção das recompensas sem pontos: antigas ficam
-- inativas e não podem ser reativadas nem resgatadas como fidelidade.
CREATE OR REPLACE FUNCTION public.require_positive_reward_points()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.points_required IS NULL OR NEW.points_required <= 0 THEN
    IF TG_OP = 'INSERT' OR NEW.active IS DISTINCT FROM false THEN
      RAISE EXCEPTION 'Recompensas devem exigir pelo menos 1 ponto. Use Ofertas para promoções sem pontos.';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS promotions_positive_points_check ON public.promotions;
CREATE TRIGGER promotions_positive_points_check
BEFORE INSERT OR UPDATE OF points_required, active ON public.promotions
FOR EACH ROW EXECUTE FUNCTION public.require_positive_reward_points();


-- Mantém a lógica transacional já existente, mas bloqueia resgates de zero pontos.
ALTER FUNCTION public.redeem_promotion(uuid) RENAME TO redeem_promotion_legacy;
REVOKE ALL ON FUNCTION public.redeem_promotion_legacy(uuid) FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.redeem_promotion(p_promotion_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_points_required integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Usuário não autenticado.'; END IF;
  SELECT points_required INTO v_points_required
  FROM public.promotions
  WHERE id = p_promotion_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recompensa não encontrada.'; END IF;
  IF v_points_required IS NULL OR v_points_required <= 0 THEN
    RAISE EXCEPTION 'Recompensas devem exigir pontos. Promoções sem pontos estão disponíveis na área de Ofertas.';
  END IF;
  RETURN public.redeem_promotion_legacy(p_promotion_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.redeem_promotion(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_promotion(uuid) TO authenticated;
COMMIT;
NOTIFY pgrst, 'reload schema';
