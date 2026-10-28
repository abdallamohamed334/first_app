BEGIN;

-- Keep provider-code lookup on the same sanitized public projection used by
-- the rest of the customer app. This keeps the lookup independent of a
-- service category without exposing private provider fields.
DROP VIEW IF EXISTS public.published_service_providers;

CREATE VIEW public.published_service_providers
WITH (security_invoker = true)
AS
SELECT
  id,
  provider_code,
  category_id,
  provider_type,
  display_name,
  bio,
  experience_years,
  skills,
  profile_image_url,
  cover_image_url,
  portfolio_images,
  governorate,
  city,
  service_areas,
  available_days,
  latitude,
  longitude,
  max_distance_km,
  pricing_type,
  price_from,
  price_currency,
  accepts_installments,
  NULL::text AS phone,
  NULL::text AS whatsapp,
  NULL::text AS email,
  NULL::text AS website,
  NULL::text AS address,
  verification_status,
  is_active,
  is_available,
  availability_note,
  NULL::integer AS total_jobs,
  NULL::integer AS completed_jobs,
  NULL::integer AS cancelled_jobs,
  NULL::integer AS volunteer_jobs,
  rating_avg,
  total_reviews,
  NULL::integer AS response_time_minutes,
  created_at,
  updated_at,
  category_name,
  category_icon,
  category_slug
FROM public.published_service_provider_cards
WHERE verification_status = 'approved'
  AND is_active IS TRUE
  AND is_available IS TRUE;

REVOKE ALL ON public.published_service_providers FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.published_service_providers TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
