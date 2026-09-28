-- Community needs are an authenticated feature; do not expose the SECURITY DEFINER RPC anonymously.
REVOKE EXECUTE ON FUNCTION public.list_community_needs(uuid, text, text, integer, integer) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_community_needs(uuid, text, text, integer, integer) TO authenticated;
