-- Keep the public avatar bucket constrained to image uploads only.
-- Authorization remains enforced by the existing UUID/path Storage policies.
UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY[
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp'
    ]::text[]
WHERE id = 'avatars';
