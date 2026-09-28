-- Use the location selected for the offer when it is present.
-- The previous trigger rejected valid offers when the user's profile location
-- had not been saved yet, even though the offer payload contained coordinates.
CREATE OR REPLACE FUNCTION public.set_community_offer_owner_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  owner_latitude double precision;
  owner_longitude double precision;
BEGIN
  IF NEW.latitude IS NOT NULL
     AND NEW.longitude IS NOT NULL
     AND NEW.latitude BETWEEN -90 AND 90
     AND NEW.longitude BETWEEN -180 AND 180 THEN
    RETURN NEW;
  END IF;

  SELECT u.latitude, u.longitude
    INTO owner_latitude, owner_longitude
  FROM public.users u
  WHERE u.id = NEW.owner_id;

  IF owner_latitude IS NULL OR owner_longitude IS NULL THEN
    RAISE EXCEPTION 'Owner location is required before creating a community offer';
  END IF;

  NEW.latitude := owner_latitude;
  NEW.longitude := owner_longitude;
  RETURN NEW;
END;
$$;
