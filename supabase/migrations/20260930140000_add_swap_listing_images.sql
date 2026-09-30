BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('swap-images', 'swap-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp']::text[])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS swap_images_public_read ON storage.objects;
CREATE POLICY swap_images_public_read
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'swap-images');

DROP POLICY IF EXISTS swap_images_owner_insert ON storage.objects;
CREATE POLICY swap_images_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'swap-images'
  AND (storage.foldername(name))[1] = (select auth.uid())::text
);

DROP POLICY IF EXISTS swap_images_owner_update ON storage.objects;
CREATE POLICY swap_images_owner_update
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'swap-images'
  AND owner_id::text = (select auth.uid())::text
)
WITH CHECK (
  bucket_id = 'swap-images'
  AND owner_id::text = (select auth.uid())::text
);

DROP POLICY IF EXISTS swap_images_owner_delete ON storage.objects;
CREATE POLICY swap_images_owner_delete
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'swap-images'
  AND owner_id::text = (select auth.uid())::text
);

COMMIT;
