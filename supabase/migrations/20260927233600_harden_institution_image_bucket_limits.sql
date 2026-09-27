-- Keep institution-images public for profile display, but limit uploads to images.
UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY[
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp'
    ]::text[]
WHERE id = 'institution-images';
