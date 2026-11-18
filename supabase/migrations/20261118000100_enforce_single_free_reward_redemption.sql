-- Impede definitivamente que o mesmo cliente resgate mais de uma vez
-- a mesma recompensa gratuita, inclusive por inserções fora da RPC.
-- O bloqueio da linha da promoção serializa tentativas concorrentes.

BEGIN;

CREATE OR REPLACE FUNCTION public.prevent_duplicate_free_reward_redemption()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_points_required integer;
BEGIN
  SELECT p.points_required
    INTO v_points_required
    FROM public.promotions p
   WHERE p.id = NEW.promotion_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Recompensa não encontrada.';
  END IF;

  IF v_points_required = 0 AND EXISTS (
    SELECT 1
      FROM public.promotion_redemptions pr
     WHERE pr.promotion_id = NEW.promotion_id
       AND pr.customer_id = NEW.customer_id
  ) THEN
    RAISE EXCEPTION 'Você já resgatou esta recompensa gratuita. Cada cliente pode resgatá-la apenas uma vez.';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_prevent_duplicate_free_reward_redemption
  ON public.promotion_redemptions;

CREATE TRIGGER trg_prevent_duplicate_free_reward_redemption
BEFORE INSERT ON public.promotion_redemptions
FOR EACH ROW
EXECUTE FUNCTION public.prevent_duplicate_free_reward_redemption();

REVOKE ALL ON FUNCTION public.prevent_duplicate_free_reward_redemption() FROM PUBLIC;

COMMIT;

NOTIFY pgrst, 'reload schema';
