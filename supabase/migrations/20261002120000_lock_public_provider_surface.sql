-- Restrict the provider discovery contract without breaking authenticated clients.
-- Anonymous users may browse safe profile/discovery fields only. Contact, address,
-- business details and operational metrics are returned only to authenticated users.
BEGIN;

DROP FUNCTION IF EXISTS public.find_provider_by_phone(text);
CREATE FUNCTION public.find_provider_by_phone(p_phone text)
RETURNS TABLE(
  verification_status text,
  is_active boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    sp.verification_status::text,
    sp.is_active
  FROM public.service_providers AS sp
  WHERE right(regexp_replace(coalesce(sp.phone, ''), '[^0-9]', '', 'g'), 10) =
        right(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 10)
     OR right(regexp_replace(coalesce(sp.whatsapp, ''), '[^0-9]', '', 'g'), 10) =
        right(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 10)
  ORDER BY sp.updated_at DESC NULLS LAST
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.find_provider_by_phone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.find_provider_by_phone(text) TO anon, authenticated;

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
  sp.service_areas,
  sp.available_days,
  sp.latitude,
  sp.longitude,
  sp.max_distance_km,
  sp.pricing_type,
  sp.price_from,
  sp.price_currency,
  sp.accepts_installments,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.phone END AS phone,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.whatsapp END AS whatsapp,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.email END AS email,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.website END AS website,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.address END AS address,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.branches END AS branches,
  sp.verification_status,
  sp.is_active,
  sp.is_available,
  sp.availability_note,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.total_jobs END AS total_jobs,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.completed_jobs END AS completed_jobs,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.cancelled_jobs END AS cancelled_jobs,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.volunteer_jobs END AS volunteer_jobs,
  sp.rating_avg,
  sp.total_reviews,
  CASE WHEN auth.uid() IS NOT NULL THEN sp.response_time_minutes END AS response_time_minutes,
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

REVOKE ALL ON public.published_service_providers FROM PUBLIC;
GRANT SELECT ON public.published_service_providers TO anon, authenticated;

COMMIT;
