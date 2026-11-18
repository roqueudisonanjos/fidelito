-- Limita recompensas gratuitas a um único resgate por cliente.
-- Resgates pagos com pontos continuam podendo ser repetidos.
BEGIN;

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

  -- Recompensas gratuitas podem ser resgatadas apenas uma vez por cliente.
  -- A verificação ocorre no banco para impedir chamadas repetidas ou concorrentes.
  IF v_promotion.points_required = 0 AND EXISTS (
    SELECT 1
    FROM public.promotion_redemptions pr
    WHERE pr.promotion_id = v_promotion.id
      AND pr.customer_id = v_customer_id
  ) THEN
    RAISE EXCEPTION 'Você já resgatou esta recompensa gratuita. Cada cliente pode resgatá-la apenas uma vez.';
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
