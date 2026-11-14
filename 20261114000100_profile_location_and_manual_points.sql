-- Fidelito: localização do cliente e pontuação manual pela empresa
-- Execute no Supabase SQL Editor após backup/teste.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text;

-- Permissões SQL necessárias. Concessões por coluna evitam liberar a
-- alteração de campos sensíveis como role, owner_id ou active.
-- As políticas RLS continuam limitando as linhas que cada usuário atualiza.
REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (full_name, whatsapp, city, state)
  ON TABLE public.profiles TO authenticated;

REVOKE UPDATE ON TABLE public.companies FROM authenticated;
GRANT UPDATE (name, description, phone, address, city, state, updated_at)
  ON TABLE public.companies TO authenticated;

CREATE OR REPLACE FUNCTION public.award_customer_points(
  p_customer_id uuid,
  p_points integer,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id uuid;
  v_company_id uuid;
  v_account public.loyalty_accounts%ROWTYPE;
  v_transaction_id uuid;
  v_description text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado.';
  END IF;

  IF p_customer_id IS NULL THEN
    RAISE EXCEPTION 'Cliente inválido.';
  END IF;

  IF p_points IS NULL OR p_points <= 0 OR p_points > 10000 THEN
    RAISE EXCEPTION 'A quantidade de pontos deve estar entre 1 e 10.000.';
  END IF;

  SELECT c.id INTO v_company_id
  FROM public.companies c
  WHERE c.owner_id = v_user_id
    AND c.active = true
  LIMIT 1;

  IF v_company_id IS NULL THEN
    RAISE EXCEPTION 'Empresa ativa não encontrada para este usuário.';
  END IF;

  SELECT * INTO v_account
  FROM public.loyalty_accounts la
  WHERE la.company_id = v_company_id
    AND la.customer_id = p_customer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este cliente ainda não participa da fidelidade da sua empresa.';
  END IF;

  UPDATE public.loyalty_accounts
  SET points = points + p_points,
      updated_at = now()
  WHERE id = v_account.id
  RETURNING * INTO v_account;

  v_description := 'Pontos adicionados manualmente pela empresa';
  IF NULLIF(trim(coalesce(p_description, '')), '') IS NOT NULL THEN
    v_description := v_description || ': ' || trim(p_description);
  END IF;

  INSERT INTO public.loyalty_transactions (
    loyalty_account_id,
    customer_id,
    company_id,
    type,
    points,
    description
  ) VALUES (
    v_account.id,
    p_customer_id,
    v_company_id,
    'earn',
    p_points,
    v_description
  ) RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'points_added', p_points,
    'new_balance', v_account.points,
    'company_id', v_company_id,
    'transaction_id', v_transaction_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.award_customer_points(uuid, integer, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.award_customer_points(uuid, integer, text) TO authenticated;
