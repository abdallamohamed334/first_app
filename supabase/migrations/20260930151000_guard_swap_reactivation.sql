BEGIN;

CREATE OR REPLACE FUNCTION public.guard_swap_listing_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.expires_at > OLD.expires_at THEN
    RAISE EXCEPTION 'Swap expiry cannot be extended';
  END IF;
  IF OLD.status IN ('cancelled', 'closed', 'expired') AND NEW.status <> OLD.status THEN
    RAISE EXCEPTION 'This swap listing cannot be reactivated';
  END IF;
  IF OLD.expires_at <= now() AND NEW.status = 'open' THEN
    RAISE EXCEPTION 'This swap listing has expired';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS swap_listing_lifecycle_guard ON public.swap_listings;
CREATE TRIGGER swap_listing_lifecycle_guard
BEFORE UPDATE ON public.swap_listings
FOR EACH ROW EXECUTE FUNCTION public.guard_swap_listing_lifecycle();

COMMIT;
