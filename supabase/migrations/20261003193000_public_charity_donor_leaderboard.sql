-- Public, privacy-safe leaderboard for donors whose charity donations were completed.
-- Do not expose the users table directly to the client.
CREATE OR REPLACE FUNCTION public.list_public_charity_donors()
RETURNS TABLE(
  id uuid,
  name text,
  avatar_url text,
  donation_count bigint,
  items_count bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    u.id,
    COALESCE(NULLIF(btrim(u.name), ''), 'متبرع') AS name,
    u.avatar_url,
    COUNT(r.id)::bigint AS donation_count,
    COALESCE(SUM(GREATEST(COALESCE(r.quantity, 1), 1)), 0)::bigint AS items_count
  FROM public.charity_donation_requests r
  JOIN public.users u ON u.id = r.donor_id
  WHERE COALESCE(u.is_active, true) = true
    AND r.deleted_at IS NULL
    AND r.status = 'completed'
  GROUP BY u.id, u.name, u.avatar_url
  ORDER BY COUNT(r.id) DESC, SUM(GREATEST(COALESCE(r.quantity, 1), 1)) DESC,
           MIN(r.completed_at) ASC
  LIMIT 10;
$$;

REVOKE ALL ON FUNCTION public.list_public_charity_donors() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_public_charity_donors() TO authenticated;
