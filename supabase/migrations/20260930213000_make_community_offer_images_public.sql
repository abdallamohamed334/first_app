BEGIN;

UPDATE storage.buckets
SET public = true
WHERE id = 'community-offers';

DROP POLICY IF EXISTS community_offer_images_public_read ON storage.objects;
CREATE POLICY community_offer_images_public_read
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'community-offers');

COMMIT;
