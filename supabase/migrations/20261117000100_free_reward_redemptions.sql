-- Permite recompensas promocionais com resgate gratuito (zero pontos).
-- Não altera saldos, resgates ou transações já existentes.
BEGIN;

DO $migration$
DECLARE
  v_constraint record;
  v_definition text;
BEGIN
  -- Remove apenas CHECKs antigos que exigiam points_required > 0 / >= 1.
  FOR v_constraint IN
    SELECT conname, pg_get_constraintdef(oid) AS definition
    FROM pg_constraint
    WHERE conrelid = 'public.promotions'::regclass
      AND contype = 'c'
  LOOP
    v_definition := lower(v_constraint.definition);
    IF v_definition LIKE '%points_required%'
       AND (v_definition LIKE '%> 0%' OR v_definition LIKE '%>= 1%') THEN
      EXECUTE format(
        'ALTER TABLE public.promotions DROP CONSTRAINT %I',
        v_constraint.conname
      );
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.promotions'::regclass
      AND conname = 'promotions_points_required_nonnegative_check'
  ) THEN
    ALTER TABLE public.promotions
      ADD CONSTRAINT promotions_points_required_nonnegative_check
      CHECK (points_required >= 0);
  END IF;

  -- Os registros de resgate também podem registrar points_spent = 0.
  FOR v_constraint IN
    SELECT conname, pg_get_constraintdef(oid) AS definition
    FROM pg_constraint
    WHERE conrelid = 'public.promotion_redemptions'::regclass
      AND contype = 'c'
  LOOP
    v_definition := lower(v_constraint.definition);
    IF v_definition LIKE '%points_spent%'
       AND (v_definition LIKE '%> 0%' OR v_definition LIKE '%>= 1%') THEN
      EXECUTE format(
        'ALTER TABLE public.promotion_redemptions DROP CONSTRAINT %I',
        v_constraint.conname
      );
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.promotion_redemptions'::regclass
      AND conname = 'promotion_redemptions_points_spent_nonnegative_check'
  ) THEN
    ALTER TABLE public.promotion_redemptions
      ADD CONSTRAINT promotion_redemptions_points_spent_nonnegative_check
      CHECK (points_spent >= 0);
  END IF;
END;
$migration$;

-- O resgate continua transacional. Para recompensa gratuita, não cria uma
-- transação financeira de 0 pontos; apenas registra o resgate com points_spent=0.
CREATE OR REPLACE FUNCTION public.redeem_promotion(p_promotion_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_customer_id uuid := auth.uid();
  v_promotion public.promotions%ROWTYPE;
  v_account public.loyalty_accounts%ROWTYPE;
  v_redemption_id uuid;
  v_new_balance integer;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  SELECT * INTO v_promotion
  FROM public.promotions
  WHERE id = p_promotion_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Promoção não encontrada.';
  END IF;
  IF v_promotion.active IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Esta promoção não está disponível.';
  END IF;
  IF v_promotion.starts_at IS NOT NULL AND now() < v_promotion.starts_at THEN
    RAISE EXCEPTION 'Esta promoção ainda não começou.';
  END IF;
  IF v_promotion.ends_at IS NOT NULL AND now() > v_promotion.ends_at THEN
    RAISE EXCEPTION 'Esta promoção já expirou.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.companies c
    WHERE c.id = v_promotion.company_id AND c.active = true
  ) THEN
    RAISE EXCEPTION 'Esta empresa não está disponível.';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts
  WHERE company_id = v_promotion.company_id
    AND customer_id = v_customer_id
  FOR UPDATE;
  IF NOT FOUND OR v_account.left_at IS NOT NULL THEN
    RAISE EXCEPTION 'Você não participa mais do programa de fidelidade desta empresa.';
  END IF;
  IF v_account.points < v_promotion.points_required THEN
    RAISE EXCEPTION 'Pontos insuficientes. Você possui % pontos e precisa de %.',
      v_account.points, v_promotion.points_required;
  END IF;

  v_new_balance := v_account.points - v_promotion.points_required;
  IF v_promotion.points_required > 0 THEN
    UPDATE public.loyalty_accounts
    SET points = v_new_balance, updated_at = now()
    WHERE id = v_account.id;

    INSERT INTO public.loyalty_transactions (
      loyalty_account_id, customer_id, company_id, type, points,
      promotion_id, description
    ) VALUES (
      v_account.id, v_customer_id, v_promotion.company_id, 'redeem',
      -v_promotion.points_required, v_promotion.id,
      'Resgate: ' || v_promotion.title
    );
  END IF;

  INSERT INTO public.promotion_redemptions (
    promotion_id, company_id, customer_id, points_spent, status
  ) VALUES (
    v_promotion.id, v_promotion.company_id, v_customer_id,
    v_promotion.points_required, 'available'
  ) RETURNING id INTO v_redemption_id;

  RETURN json_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'promotion_id', v_promotion.id,
    'title', v_promotion.title,
    'points_spent', v_promotion.points_required,
    'new_balance', v_new_balance,
    'status', 'available'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.redeem_promotion(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_promotion(uuid) TO authenticated;

COMMIT;
