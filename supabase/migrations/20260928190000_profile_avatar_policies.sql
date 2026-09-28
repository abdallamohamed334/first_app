-- Profile avatars use the UUID/file-name path: <auth.uid>/avatar_<timestamp>.<ext>
-- Keep charity avatar policies separate; these policies cover normal user profiles.

DROP POLICY IF EXISTS profile_avatar_public_read ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_insert ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_update ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_delete ON storage.objects;

CREATE POLICY profile_avatar_public_read
ON storage.objects FOR SELECT TO public
USING (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/[^/]+$'
);

CREATE POLICY profile_avatar_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/avatar_[0-9]+\\.(jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY profile_avatar_owner_update
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/avatar_[0-9]+\\.(jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/avatar_[0-9]+\\.(jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY profile_avatar_owner_delete
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/avatar_[0-9]+\\.(jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

UPDATE storage.buckets
SET file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
WHERE id = 'avatars';
