BEGIN;

ALTER TABLE public.service_providers
  ADD COLUMN IF NOT EXISTS governorate text,
  ADD COLUMN IF NOT EXISTS available_days text[] NOT NULL DEFAULT '{}';

DROP VIEW IF EXISTS public.published_service_providers;
CREATE VIEW public.published_service_providers
WITH (security_invoker = false)
AS
SELECT
  sp.id,
  sp.category_id,
  sp.provider_type,
  sp.display_name,
  sp.bio,
  sp.experience_years,
  sp.skills,
  sp.profile_image_url,
  sp.cover_image_url,
  sp.portfolio_images,
  sp.governorate,
  sp.city,
  sp.address,
  sp.service_areas,
  sp.available_days,
  sp.latitude,
  sp.longitude,
  sp.max_distance_km,
  sp.pricing_type,
  sp.price_from,
  sp.price_currency,
  sp.accepts_installments,
  sp.phone,
  sp.whatsapp,
  sp.email,
  sp.website,
  sp.company_legal_name,
  sp.founded_year,
  sp.employees_count,
  sp.branches,
  sp.verification_status,
  sp.is_active,
  sp.is_available,
  sp.availability_note,
  sp.total_jobs,
  sp.completed_jobs,
  sp.cancelled_jobs,
  sp.volunteer_jobs,
  sp.rating_avg,
  sp.total_reviews,
  sp.response_time_minutes,
  sp.created_at,
  sp.updated_at,
  sc.name_ar AS category_name,
  sc.icon AS category_icon,
  sc.slug AS category_slug,
  u.name AS owner_name,
  u.avatar_url AS owner_avatar
FROM public.service_providers AS sp
JOIN public.service_categories AS sc ON sc.id = sp.category_id
LEFT JOIN public.users AS u ON u.id = sp.user_id
WHERE sp.verification_status = 'approved'
  AND sp.is_active = true
  AND sp.is_available = true;

GRANT SELECT ON public.published_service_providers TO anon, authenticated;
COMMIT;
