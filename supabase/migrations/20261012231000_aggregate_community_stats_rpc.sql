-- Return aggregate community counters without transferring every matching row.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_community_stats()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'meals_saved', COALESCE((SELECT SUM(quantity) FROM public.donations WHERE status = 'completed'), 0),
    'active_volunteers', COALESCE((SELECT COUNT(*) FROM public.users WHERE role = 'user' AND is_active IS TRUE), 0),
    'participating_restaurants', COALESCE((SELECT COUNT(*) FROM public.restaurants WHERE status = 'active'), 0),
    'beneficiary_charities', COALESCE((SELECT COUNT(*) FROM public.charities WHERE status = 'active'), 0)
  );
$$;

REVOKE ALL ON FUNCTION public.get_community_stats() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_stats() TO anon, authenticated;

COMMIT;
