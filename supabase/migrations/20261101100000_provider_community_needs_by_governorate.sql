-- Allow approved, active service providers to browse active service requests
-- by the requester's profile governorate. Existing public-feed behavior is
-- unchanged; this additional listing RPC is restricted to approved, active
-- providers. Contact fields follow the app's existing authenticated detail flow.
BEGIN;

DROP FUNCTION IF EXISTS public.list_provider_community_needs_by_governorate(
  text, text, text, integer, integer
);

CREATE FUNCTION public.list_provider_community_needs_by_governorate(
  p_governorate text,
  p_need_category text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  requester_id uuid,
  requester_name text,
  requester_avatar text,
  category_id uuid,
  category_slug text,
  category_name_ar text,
  title text,
  description text,
  quantity integer,
  urgency text,
  city text,
  status text,
  expires_at timestamptz,
  created_at timestamptz,
  image_url text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    n.id,
    n.requester_id,
    u.name,
    u.avatar_url,
    n.category_id,
    COALESCE(n.need_category, n.category_slug),
    COALESCE(c.name_ar, n.category_name_ar, 'احتياج آخر'),
    n.title,
    n.description,
    n.quantity,
    n.urgency,
    n.city,
    n.status,
    n.expires_at,
    n.created_at,
    n.image_url
  FROM public.community_needs AS n
  JOIN public.users AS u ON u.id = n.requester_id
  LEFT JOIN public.service_categories AS c
    ON c.slug = COALESCE(n.need_category, n.category_slug)
   AND c.is_active = true
  WHERE auth.uid() IS NOT NULL
    AND NULLIF(BTRIM(p_governorate), '') IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.service_providers AS sp
      WHERE sp.user_id = auth.uid()
        AND sp.is_active = true
        AND sp.verification_status = 'approved'
    )
    AND n.requester_id <> auth.uid()
    AND n.status = 'active'
    AND n.expires_at > now()
    AND LOWER(BTRIM(u.governorate)) = LOWER(BTRIM(p_governorate))
    AND (
      p_need_category IS NULL
      OR COALESCE(n.need_category, n.category_slug) = p_need_category
    )
    AND (
      p_search IS NULL OR BTRIM(p_search) = ''
      OR n.title ILIKE '%' || BTRIM(p_search) || '%'
      OR n.description ILIKE '%' || BTRIM(p_search) || '%'
    )
  ORDER BY
    CASE n.urgency
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    n.created_at DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50)
  OFFSET GREATEST(COALESCE(p_offset, 0), 0);
$$;

REVOKE ALL ON FUNCTION public.list_provider_community_needs_by_governorate(
  text, text, text, integer, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_provider_community_needs_by_governorate(
  text, text, text, integer, integer
) TO authenticated;

COMMIT;
