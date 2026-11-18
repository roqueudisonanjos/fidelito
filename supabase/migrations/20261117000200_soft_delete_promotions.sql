-- Fidelito: exclusão lógica de recompensas.
-- Mantém promotions para preservar as referências e o histórico em
-- promotion_redemptions; remove a recompensa das listagens e impede novos resgates.

BEGIN;

ALTER TABLE public.promotions
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

CREATE INDEX IF NOT EXISTS promotions_company_not_deleted_idx
  ON public.promotions (company_id, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.delete_promotion(p_promotion_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_company_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  -- Só permite excluir recompensas pertencentes à empresa do usuário.
  -- O bloqueio da linha evita concorrência com operações simultâneas.
  SELECT p.company_id
    INTO v_company_id
    FROM public.promotions p
    JOIN public.companies c ON c.id = p.company_id
   WHERE p.id = p_promotion_id
     AND c.owner_id = v_user_id
   FOR UPDATE OF p;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Recompensa não encontrada ou você não tem permissão para excluí-la.';
  END IF;

  UPDATE public.promotions
     SET active = false,
         deleted_at = COALESCE(deleted_at, now()),
         updated_at = now()
   WHERE id = p_promotion_id
     AND company_id = v_company_id;

  RETURN jsonb_build_object(
    'success', true,
    'promotion_id', p_promotion_id,
    'deleted', true
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.delete_promotion(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_promotion(uuid) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
