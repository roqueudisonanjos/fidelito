-- Uma visualização por cliente/publicação e avaliações únicas por cliente/empresa.
ALTER TABLE public.publication_views
  ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS publication_views_customer_once_idx
  ON public.publication_views(publication_type, publication_id, customer_id)
  WHERE customer_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.record_publication_view(
  p_publication_type text,
  p_publication_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_visible boolean := false;
BEGIN
  IF v_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_user_id AND p.role::text='customer') THEN RETURN; END IF;
  IF p_publication_type = 'offer' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.company_offers o JOIN public.companies c ON c.id=o.company_id
      WHERE o.id=p_publication_id AND o.active=true AND c.active=true
        AND (o.starts_at IS NULL OR o.starts_at<=now()) AND (o.ends_at IS NULL OR o.ends_at>=now())
    ) INTO v_visible;
  ELSIF p_publication_type = 'story' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.company_stories s JOIN public.companies c ON c.id=s.company_id
      WHERE s.id=p_publication_id AND s.active=true AND s.expires_at>now() AND c.active=true
    ) INTO v_visible;
  ELSE
    RAISE EXCEPTION 'Tipo de publicação inválido';
  END IF;
  IF v_visible THEN
    INSERT INTO public.publication_views(publication_type, publication_id, customer_id)
    VALUES (p_publication_type, p_publication_id, v_user_id)
    ON CONFLICT (publication_type, publication_id, customer_id) WHERE customer_id IS NOT NULL DO NOTHING;
  END IF;
END; $$;
REVOKE ALL ON FUNCTION public.record_publication_view(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_publication_view(text, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_customer_viewed_stories()
RETURNS SETOF uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public, pg_temp AS $$
  SELECT DISTINCT publication_id FROM public.publication_views
  WHERE publication_type='story' AND customer_id=auth.uid();
$$;
REVOKE ALL ON FUNCTION public.get_customer_viewed_stories() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_customer_viewed_stories() TO authenticated;

CREATE TABLE IF NOT EXISTS public.company_ratings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(company_id, customer_id)
);
ALTER TABLE public.company_ratings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.company_ratings FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_company_rating(p_company_id uuid, p_stars integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public, pg_temp AS $$
DECLARE v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Faça login para avaliar'; END IF;
  IF p_stars < 1 OR p_stars > 5 THEN RAISE EXCEPTION 'A avaliação deve ser de 1 a 5 estrelas'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=v_user_id AND p.role::text='customer') THEN
    RAISE EXCEPTION 'Somente clientes podem avaliar empresas';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.loyalty_accounts la WHERE la.company_id=p_company_id AND la.customer_id=v_user_id AND la.left_at IS NULL) THEN
    RAISE EXCEPTION 'Somente clientes fidelizados podem avaliar esta empresa';
  END IF;
  INSERT INTO public.company_ratings(company_id, customer_id, stars) VALUES (p_company_id, v_user_id, p_stars);
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'Você já avaliou esta empresa. Cada cliente pode avaliar uma única vez';
END; $$;
REVOKE ALL ON FUNCTION public.submit_company_rating(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_company_rating(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_company_rating_stats(p_company_ids uuid[])
RETURNS TABLE(company_id uuid, average_rating numeric, rating_count bigint, my_rating integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public, pg_temp AS $$
  SELECT r.company_id, round(avg(r.stars)::numeric, 1), count(*)::bigint,
    max(r.stars) FILTER (WHERE r.customer_id=auth.uid())::integer
  FROM public.company_ratings r
  WHERE r.company_id = ANY(p_company_ids)
  GROUP BY r.company_id;
$$;
REVOKE ALL ON FUNCTION public.get_company_rating_stats(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_company_rating_stats(uuid[]) TO authenticated;
