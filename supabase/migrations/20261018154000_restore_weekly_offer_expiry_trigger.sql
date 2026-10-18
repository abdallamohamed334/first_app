-- Enforce the one-week lifetime at the database boundary as well as in Flutter.
CREATE OR REPLACE FUNCTION public.set_community_offer_weekly_expiry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.charity_id IS NULL AND NEW.listing_type = 'symbolic_sale' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.created_at := COALESCE(NEW.created_at, now());
      NEW.expires_at := NEW.created_at + interval '7 days';
    ELSIF NEW.expires_at IS DISTINCT FROM OLD.expires_at THEN
      IF OLD.status = 'expired'
         AND NEW.status = 'available'
         AND COALESCE(OLD.expires_at, OLD.created_at + interval '7 days') <= now()
         AND NEW.expires_at > now() THEN
        NEW.expires_at := now() + interval '7 days';
      ELSE
        NEW.expires_at := LEAST(
          COALESCE(NEW.expires_at, NEW.created_at + interval '7 days'),
          NEW.created_at + interval '7 days'
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.set_community_offer_weekly_expiry()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_community_offer_weekly_expiry
  ON public.community_offers;

CREATE TRIGGER trg_community_offer_weekly_expiry
BEFORE INSERT OR UPDATE OF expires_at, status, listing_type, charity_id
ON public.community_offers
FOR EACH ROW
EXECUTE FUNCTION public.set_community_offer_weekly_expiry();
