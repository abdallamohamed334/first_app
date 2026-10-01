-- Close provider privilege escalation and RPC/row-level access gaps found by the
-- 2026-10-01 security audit.
BEGIN;

-- Authenticated clients may edit profile-only fields, never role, status,
-- moderation, ownership, counters, or credential fields.
REVOKE UPDATE ON TABLE public.users FROM anon, authenticated;
GRANT UPDATE (
  name, email, avatar_url, city, address, latitude, longitude,
  language, notifications_enabled, gender, whatsapp, governorate,
  lat, lng, fcm_token
) ON TABLE public.users TO authenticated;

-- Providers may edit their profile and availability only. Approval, ownership,
-- moderation notes, activity state, phone identity, and counters are backend/admin
-- controlled and cannot be changed through PostgREST by an authenticated client.
REVOKE UPDATE ON TABLE public.service_providers FROM anon, authenticated;
GRANT UPDATE (
  display_name, bio, experience_years, skills, city, governorate, address,
  service_areas, available_days, latitude, longitude, max_distance_km,
  pricing_type, price_from, accepts_installments, profile_image_url,
  portfolio_images, cover_image_url, whatsapp, website, is_available,
  availability_note, id_card_front_url, id_card_back_url,
  profile_locked_at, updated_at
) ON TABLE public.service_providers TO authenticated;

-- This RPC is used only after Supabase Auth has established a session. It must
-- never accept an arbitrary user UUID from an untrusted caller.
DROP FUNCTION IF EXISTS public.get_provider_auth_state(uuid);
CREATE OR REPLACE FUNCTION public.get_provider_auth_state()
RETURNS TABLE(
  id uuid,
  verification_status text,
  is_active boolean,
  verification_notes text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    sp.id,
    sp.verification_status::text,
    sp.is_active,
    sp.verification_notes
  FROM public.service_providers AS sp
  WHERE sp.user_id = auth.uid()
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.get_provider_auth_state() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_provider_auth_state() TO authenticated;

-- The pre-OTP lookup is intentionally anonymous for login routing, but it must
-- not disclose the internal Auth UUID. Keep only the minimum routing state.
DROP FUNCTION IF EXISTS public.find_provider_by_phone(text);
CREATE OR REPLACE FUNCTION public.find_provider_by_phone(p_phone text)
RETURNS TABLE(
  id uuid,
  verification_status text,
  is_active boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    sp.id,
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

-- Keep public provider cards limited to presentation data. Internal Auth and
-- KYC/moderation columns are deliberately absent from this view.
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
