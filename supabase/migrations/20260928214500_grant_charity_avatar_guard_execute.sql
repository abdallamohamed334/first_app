-- Storage policies call these SECURITY DEFINER guards while evaluating an
-- authenticated upload. The guard itself still verifies auth.uid() and the
-- charity ownership/status, so granting EXECUTE does not bypass ownership.
REVOKE ALL ON FUNCTION public.can_manage_charity_avatar_uuid_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_charity_avatar_uuid_path(text)
  TO authenticated, supabase_storage_admin;

REVOKE ALL ON FUNCTION public.can_manage_charity_avatar_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_charity_avatar_path(text)
  TO authenticated, supabase_storage_admin;
