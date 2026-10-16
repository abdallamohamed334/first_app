BEGIN;

-- PostGIS owns spatial_ref_sys in the managed database; its RLS warning is
-- documented in the release report because this project role cannot alter it.
-- Do not attempt to change ownership or the extension from an application migration.

-- Trigger-only functions must not be callable through /rest/v1/rpc.
REVOKE ALL ON FUNCTION public.create_direct_charity_status_notifications() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_institution_offer_type() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_offer_request_integrity() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_community_need_insert() FROM PUBLIC, anon, authenticated;

-- PostGIS implementation helper used by the advisor finding is not part of the app API.
REVOKE ALL ON FUNCTION public.st_estimatedextent(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.st_estimatedextent(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.st_estimatedextent(text, text, text, boolean) FROM PUBLIC, anon, authenticated;

-- Make the trigger execution environment deterministic.
ALTER FUNCTION public.set_home_ads_updated_at()
  SET search_path = public, pg_temp;

-- Identity documents remain private to the owner; admins may review them explicitly.
DROP POLICY IF EXISTS provider_documents_admin_read ON storage.objects;
CREATE POLICY provider_documents_admin_read
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'provider-documents'
    AND public.is_admin_actor()
  );

NOTIFY pgrst, 'reload schema';
COMMIT;
