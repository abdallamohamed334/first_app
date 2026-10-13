-- Contact actions are an intentional part of the public provider card.
-- Keep internal identity and address fields private, but expose the provider's
-- published phone/WhatsApp channels already stored in the sanitized projection.
DROP VIEW IF EXISTS public.published_service_providers;

CREATE VIEW public.published_service_providers
WITH (security_invoker = true)
AS
SELECT
  id,
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
  phone,
  whatsapp,
  email,
  website,
  NULL::text AS address,
  verification_status,
  is_active,
  is_available,
  availability_note,
  total_jobs,
  completed_jobs,
  cancelled_jobs,
  volunteer_jobs,
  rating_avg,
  total_reviews,
  response_time_minutes,
  created_at,
  updated_at,
  category_name,
  category_icon,
  category_slug
FROM public.published_service_provider_cards
WHERE verification_status = 'approved'
  AND is_active IS TRUE
  AND is_available IS TRUE;

REVOKE ALL ON public.published_service_providers FROM PUBLIC;
GRANT SELECT ON public.published_service_providers TO anon, authenticated;
