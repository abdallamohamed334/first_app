-- Expand symbolic community offers from a 10 km radius to a governorate-sized radius.
-- 70 km covers the Gharbia governorate from Tanta while retaining distance ordering.

CREATE OR REPLACE FUNCTION public.get_nearby_community_offers(
  p_latitude double precision,
  p_longitude double precision,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  owner_id uuid,
  charity_id uuid,
  title text,
  description text,
  category text,
  listing_type text,
  item_condition text,
  quantity integer,
  price numeric,
  image text,
  images text[],
  pickup_location text,
  latitude double precision,
  longitude double precision,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  expires_at timestamptz,
  phone text,
  whatsapp text,
  category_id uuid,
  distance_meters double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_current_user uuid := auth.uid();
BEGIN
  RETURN QUERY
  SELECT co.id, co.owner_id, co.charity_id, co.title, co.description,
    co.category, co.listing_type, co.item_condition, co.quantity, co.price,
    co.image, co.images, co.pickup_location,
    co.latitude::double precision, co.longitude::double precision,
    co.status, co.created_at, co.updated_at, co.expires_at,
    co.phone, co.whatsapp, co.category_id,
    ST_Distance(
      ST_SetSRID(ST_MakePoint(co.longitude, co.latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
    ) AS distance_meters
  FROM public.community_offers co
  WHERE co.status = 'available'
    AND co.listing_type = 'symbolic_sale'
    AND co.charity_id IS NULL
    AND co.latitude IS NOT NULL
    AND co.longitude IS NOT NULL
    AND (co.expires_at IS NULL OR co.expires_at > now())
    AND (
      v_current_user IS NULL
      OR NOT EXISTS (
        SELECT 1 FROM public.blocked_users bu
        WHERE bu.blocker_id = v_current_user
          AND bu.blocked_id = co.owner_id
      )
    )
    AND ST_DWithin(
      ST_SetSRID(ST_MakePoint(co.longitude, co.latitude), 4326)::geography,
      ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
      70000
    )
  ORDER BY distance_meters ASC, co.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 100)
  OFFSET GREATEST(p_offset, 0);
END;
$function$;
