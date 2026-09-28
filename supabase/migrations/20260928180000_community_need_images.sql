-- Reference images for community needs.
-- Public read is intentional because active needs are public listings;
-- writes remain restricted to the authenticated owner path.
ALTER TABLE public.community_needs
  ADD COLUMN IF NOT EXISTS image_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'community-needs',
  'community-needs',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS community_needs_images_read ON storage.objects;
DROP POLICY IF EXISTS community_needs_images_insert ON storage.objects;
DROP POLICY IF EXISTS community_needs_images_update ON storage.objects;
DROP POLICY IF EXISTS community_needs_images_delete ON storage.objects;

CREATE POLICY community_needs_images_read
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'community-needs');

CREATE POLICY community_needs_images_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'community-needs'
  AND split_part(name, '/', 1) = auth.uid()::text
  AND array_length(string_to_array(name, '/'), 1) = 2
);

CREATE POLICY community_needs_images_update
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'community-needs'
  AND split_part(name, '/', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'community-needs'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY community_needs_images_delete
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'community-needs'
  AND split_part(name, '/', 1) = auth.uid()::text
);
