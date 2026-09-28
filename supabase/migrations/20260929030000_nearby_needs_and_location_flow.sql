-- Nearby community needs and location-aware home feed.
-- The app stores user coordinates in users.latitude/longitude.
DROP FUNCTION IF EXISTS public.list_community_needs_v2(
  text, text, text, integer, integer,
  double precision, double precision, double precision
);

CREATE FUNCTION public.list_community_needs_v2(
  p_need_category text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT 30
)
RETURNS TABLE(
  id uuid, requester_id uuid, requester_name text, requester_avatar text,
  category_id uuid, category_slug text, category_name_ar text, title text,
  description text, quantity integer, urgency text, city text, address text,
  contact_phone text, contact_whatsapp text, contact_count integer,
  phone_count integer, whatsapp_count integer, status text,
  expires_at timestamptz, created_at timestamptz, image_url text,
  latitude double precision, longitude double precision, distance_km double precision
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT n.id, n.requester_id, u.name, u.avatar_url,
    n.category_id,
    COALESCE(n.need_category, n.category_slug),
    COALESCE(c.name_ar, n.category_name_ar, 'احتياج آخر'),
    n.title, n.description, n.quantity, n.urgency, n.city, n.address,
    n.contact_phone, n.contact_whatsapp, n.contact_count,
    n.phone_count, n.whatsapp_count, n.status, n.expires_at,
    n.created_at, n.image_url, n.latitude, n.longitude,
    CASE
      WHEN p_latitude IS NULL OR p_longitude IS NULL
        OR n.latitude IS NULL OR n.longitude IS NULL THEN NULL
      ELSE 6371 * 2 * asin(sqrt(
        power(sin(radians(n.latitude - p_latitude) / 2), 2) +
        cos(radians(p_latitude)) * cos(radians(n.latitude)) *
        power(sin(radians(n.longitude - p_longitude) / 2), 2)
      ))
    END AS distance_km
  FROM public.community_needs n
  LEFT JOIN public.users u ON u.id = n.requester_id
  LEFT JOIN public.community_need_categories c
    ON c.slug = n.need_category AND c.is_active = true
  WHERE n.status = 'active'
    AND n.expires_at > now()
    AND (p_need_category IS NULL OR n.need_category = p_need_category)
    AND (p_city IS NULL OR n.city = p_city)
    AND (p_search IS NULL OR p_search = ''
      OR n.title ILIKE '%' || p_search || '%'
      OR n.description ILIKE '%' || p_search || '%')
    AND n.requester_id != auth.uid()
    AND (
      p_latitude IS NULL OR p_longitude IS NULL
      OR (n.latitude IS NOT NULL AND n.longitude IS NOT NULL
        AND 6371 * 2 * asin(sqrt(
        power(sin(radians(n.latitude - p_latitude) / 2), 2) +
        cos(radians(p_latitude)) * cos(radians(n.latitude)) *
        power(sin(radians(n.longitude - p_longitude) / 2), 2)
        )) <= COALESCE(p_radius_km, 30))
    )
  ORDER BY
    CASE WHEN p_latitude IS NOT NULL AND p_longitude IS NOT NULL
      THEN CASE WHEN n.latitude IS NULL OR n.longitude IS NULL THEN 1 ELSE 0 END
      ELSE 0 END,
    25 NULLS LAST,
    CASE n.urgency WHEN 'urgent' THEN 1 WHEN 'high' THEN 2
      WHEN 'normal' THEN 3 WHEN 'low' THEN 4 ELSE 5 END,
    n.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 50)
  OFFSET GREATEST(p_offset, 0);
$$;

REVOKE ALL ON FUNCTION public.list_community_needs_v2(text, text, text, integer, integer, double precision, double precision, double precision) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_community_needs_v2(text, text, text, integer, integer, double precision, double precision, double precision) TO authenticated;
