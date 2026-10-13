BEGIN;

-- The institution marketplace now has two publishing tracks:
-- symbolic-price sales for grocery/supermarket/bakery/butcher, and
-- institutional surplus for hotels/wedding halls.
CREATE OR REPLACE FUNCTION public.enforce_institution_offer_type()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type text;
BEGIN
  SELECT lower(trim(institution_type))
    INTO v_type
  FROM public.institutions
  WHERE id = NEW.institution_id;

  IF v_type IS NULL OR v_type NOT IN (
    'grocery', 'supermarket', 'bakery', 'butcher', 'meat_shop',
    'hotel', 'wedding_hall'
  ) THEN
    RAISE EXCEPTION 'institution type cannot publish offers';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_institution_offer_type_trigger
  ON public.institution_offers;
CREATE TRIGGER enforce_institution_offer_type_trigger
  BEFORE INSERT OR UPDATE OF institution_id
  ON public.institution_offers
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_institution_offer_type();

REVOKE ALL ON FUNCTION public.enforce_institution_offer_type() FROM PUBLIC;

DROP POLICY IF EXISTS institution_offers_public_select
  ON public.institution_offers;
CREATE POLICY institution_offers_public_select
  ON public.institution_offers
  FOR SELECT
  TO authenticated
  USING (
    status = 'active'
    AND expires_at > now()
    AND EXISTS (
      SELECT 1
      FROM public.institutions i
      WHERE i.id = institution_offers.institution_id
        AND i.status = 'approved'
        AND lower(trim(i.institution_type)) IN (
          'grocery', 'supermarket', 'bakery', 'butcher', 'meat_shop',
          'hotel', 'wedding_hall'
        )
    )
  );

NOTIFY pgrst, 'reload schema';
COMMIT;
