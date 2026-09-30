BEGIN;

ALTER TABLE public.swap_listings
  ADD COLUMN IF NOT EXISTS contact_phone text,
  ADD COLUMN IF NOT EXISTS contact_whatsapp text;

CREATE OR REPLACE FUNCTION public.validate_swap_listing_contacts()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.contact_phone IS NULL OR btrim(NEW.contact_phone) = '' THEN
    RAISE EXCEPTION 'swap_contact_phone_required';
  END IF;
  IF NEW.contact_whatsapp IS NULL OR btrim(NEW.contact_whatsapp) = '' THEN
    RAISE EXCEPTION 'swap_contact_whatsapp_required';
  END IF;
  IF btrim(NEW.contact_phone) !~ '^[0-9+ ()-]{8,20}$' THEN
    RAISE EXCEPTION 'swap_contact_phone_invalid';
  END IF;
  IF btrim(NEW.contact_whatsapp) !~ '^[0-9+ ()-]{8,20}$' THEN
    RAISE EXCEPTION 'swap_contact_whatsapp_invalid';
  END IF;
  NEW.contact_phone = btrim(NEW.contact_phone);
  NEW.contact_whatsapp = btrim(NEW.contact_whatsapp);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS swap_listing_contacts_validation ON public.swap_listings;
CREATE TRIGGER swap_listing_contacts_validation
BEFORE INSERT OR UPDATE OF contact_phone, contact_whatsapp ON public.swap_listings
FOR EACH ROW EXECUTE FUNCTION public.validate_swap_listing_contacts();

CREATE INDEX IF NOT EXISTS swap_listings_contact_idx
  ON public.swap_listings (contact_phone, contact_whatsapp);

COMMIT;
