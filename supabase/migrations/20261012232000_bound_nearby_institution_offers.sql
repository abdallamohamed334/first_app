-- Keep the nearby map RPC bounded at the database boundary.
BEGIN;

DROP FUNCTION IF EXISTS public.get_nearby_institution_offers(double precision, double precision, integer);

CREATE OR REPLACE FUNCTION public.get_nearby_institution_offers(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters integer
)
RETURNS TABLE (
  id uuid, institution_id uuid, institution_name text, institution_type text,
  institution_is_verified boolean, title text, description text, category text,
  quantity integer, remaining_quantity integer, original_price numeric,
  symbolic_price numeric, images text[], pickup_location text,
  expires_at timestamptz, pickup_before timestamptz, status text,
  created_at timestamptz, updated_at timestamptz, food_type text,
  is_halal boolean, is_vegetarian boolean, food_condition text,
  requires_refrigeration boolean, pickup_notes text, contact_phone text,
  pickup_time text, pickup_start timestamptz, pickup_end timestamptz,
  distance_meters double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_location geography(Point, 4326);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude < -90 OR p_latitude > 90
     OR p_longitude < -180 OR p_longitude > 180 THEN
    RAISE EXCEPTION 'Invalid latitude/longitude';
  END IF;
  IF p_radius_meters IS NULL OR p_radius_meters <= 0 OR p_radius_meters > 50000 THEN
    RAISE EXCEPTION 'Radius must be between 1 and 50000 meters';
  END IF;

  v_user_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

  RETURN QUERY
  SELECT o.id, o.institution_id, i.name, i.institution_type, i.is_verified,
         o.title, o.description, o.category, o.quantity, o.remaining_quantity,
         o.original_price, o.symbolic_price, o.images, o.pickup_location,
         o.expires_at, o.pickup_before, o.status, o.created_at, o.updated_at,
         o.food_type, o.is_halal, o.is_vegetarian, o.food_condition,
         o.requires_refrigeration, o.pickup_notes, o.contact_phone,
         o.pickup_time, o.pickup_start, o.pickup_end,
         ST_Distance(i.location, v_user_location)
  FROM public.institution_offers o
  JOIN public.institutions i ON i.id = o.institution_id
  WHERE o.status = 'active'
    AND o.deleted_at IS NULL
    AND o.remaining_quantity > 0
    AND o.expires_at > now()
    AND i.status = 'approved'
    AND i.location IS NOT NULL
    AND ST_DWithin(i.location, v_user_location, p_radius_meters)
  ORDER BY ST_Distance(i.location, v_user_location), o.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.get_nearby_institution_offers(double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_institution_offers(double precision, double precision, integer) TO authenticated;

COMMIT;
