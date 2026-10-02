-- Production hardening: cap public image uploads and reject non-image files.
-- Review existing clients and rollout on staging before applying to Production.
UPDATE storage.buckets
SET file_size_limit = 5 * 1024 * 1024,
    allowed_mime_types = ARRAY[
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp'
    ]::text[]
WHERE id IN ('charity-images', 'home-banners', 'restaurant-offers');
