-- Let an institution see only the display name and avatar for customers
-- whose requests belong to that institution. The users table intentionally
-- restricts direct reads to each user's own profile.
CREATE OR REPLACE FUNCTION public.get_institution_offer_requesters(
  p_request_ids uuid[]
)
RETURNS TABLE (
  request_id uuid,
  requester jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    r.id AS request_id,
    jsonb_build_object(
      'id', u.id,
      'name', u.name,
      'avatar_url', u.avatar_url
    ) AS requester
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  JOIN public.institutions i ON i.id = o.institution_id
  JOIN public.users u ON u.id = r.requester_id
  WHERE i.user_id = auth.uid()
    AND i.status = 'approved'
    AND r.id = ANY(COALESCE(p_request_ids, ARRAY[]::uuid[]));
$function$;

REVOKE ALL ON FUNCTION public.get_institution_offer_requesters(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_institution_offer_requesters(uuid[]) TO authenticated;
