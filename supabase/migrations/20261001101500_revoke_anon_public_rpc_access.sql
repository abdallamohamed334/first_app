-- These read endpoints are authenticated application features, not public APIs.
BEGIN;
REVOKE EXECUTE ON FUNCTION public.list_community_needs_v2(
  text, text, text, integer, integer, double precision, double precision, double precision
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_community_needs_v2(
  text, text, text, integer, integer, double precision, double precision, double precision
) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.list_public_volunteers() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_public_volunteers() TO authenticated;
COMMIT;
