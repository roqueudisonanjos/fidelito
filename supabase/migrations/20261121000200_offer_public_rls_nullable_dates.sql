-- Permite ofertas públicas autenticadas com início/fim opcional.
BEGIN;
DROP POLICY IF EXISTS company_offers_public_read ON public.company_offers;
CREATE POLICY company_offers_public_read ON public.company_offers
  FOR SELECT TO authenticated USING (
    active = true
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at IS NULL OR ends_at >= now())
  );
COMMIT;
NOTIFY pgrst, 'reload schema';
