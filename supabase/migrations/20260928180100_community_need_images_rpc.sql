DROP FUNCTION IF EXISTS public.list_community_needs(uuid, text, text, integer, integer);

CREATE FUNCTION public.list_community_needs(
  p_category_id uuid DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid, requester_id uuid, requester_name text, requester_avatar text,
  category_id uuid, category_slug text, category_name_ar text, title text,
  description text, quantity integer, urgency text, city text, address text,
  contact_phone text, contact_whatsapp text, contact_count integer,
  phone_count integer, whatsapp_count integer, status text,
  expires_at timestamptz, created_at timestamptz, image_url text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN QUERY
  SELECT n.id, n.requester_id, u.name, u.avatar_url,
    n.category_id, n.category_slug, n.category_name_ar, n.title,
    n.description, n.quantity, n.urgency, n.city, n.address,
    n.contact_phone, n.contact_whatsapp, n.contact_count,
    n.phone_count, n.whatsapp_count, n.status, n.expires_at,
    n.created_at, n.image_url
  FROM public.community_needs n
  LEFT JOIN public.users u ON u.id = n.requester_id
  WHERE n.status = 'active' AND n.expires_at > now()
    AND (p_category_id IS NULL OR n.category_id = p_category_id)
    AND (p_city IS NULL OR n.city = p_city)
    AND (p_search IS NULL OR p_search = '' OR n.title ILIKE '%' || p_search || '%' OR n.description ILIKE '%' || p_search || '%')
    AND n.requester_id != auth.uid()
  ORDER BY CASE n.urgency WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 WHEN 'low' THEN 4 END, n.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 50) OFFSET GREATEST(p_offset, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.list_community_needs(uuid, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_community_needs(uuid, text, text, integer, integer) TO authenticated;
