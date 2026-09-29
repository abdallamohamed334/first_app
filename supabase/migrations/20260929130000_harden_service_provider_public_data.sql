-- Final hardening for the service-provider public surface.
-- Public provider cards must never expose KYC or moderation-only fields.
BEGIN;

-- The app's pre-OTP lookup uses this minimal RPC, not a direct table read.
CREATE OR REPLACE FUNCTION public.find_provider_by_phone(p_phone text)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  verification_status text,
  is_active boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    sp.id,
    sp.user_id,
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

-- Direct table reads are owner-only. Public discovery goes through the safe view below.
DROP POLICY IF EXISTS "Anyone views approved providers" ON public.service_providers;
CREATE POLICY "Providers view own profile"
  ON public.service_providers
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

REVOKE ALL ON TABLE public.service_providers FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.service_providers TO authenticated;

-- Recreate the public view with only fields used by public provider cards/details.
DROP VIEW IF EXISTS public.published_service_providers;
CREATE VIEW public.published_service_providers
WITH (security_invoker = false)
AS
SELECT
  sp.id,
  sp.user_id,
  sp.category_id,
  sp.provider_type,
  sp.display_name,
  sp.bio,
  sp.experience_years,
  sp.skills,
  sp.profile_image_url,
  sp.cover_image_url,
  sp.portfolio_images,
  sp.city,
  sp.address,
  sp.service_areas,
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

-- Restrict provider uploads to images and cap storage consumption.
UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY[
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp'
    ]::text[]
WHERE id = 'provider-images';

DROP POLICY IF EXISTS "Providers upload own images" ON storage.objects;
DROP POLICY IF EXISTS "Providers update own images" ON storage.objects;
DROP POLICY IF EXISTS "Providers delete own images" ON storage.objects;

CREATE POLICY "Providers upload own images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'provider-images'
  AND name ~ '^[0-9a-fA-F-]{36}/(profile|cover|portfolio)_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY "Providers update own images"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'provider-images'
  AND name ~ '^[0-9a-fA-F-]{36}/(profile|cover|portfolio)_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'provider-images'
  AND name ~ '^[0-9a-fA-F-]{36}/(profile|cover|portfolio)_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY "Providers delete own images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'provider-images'
  AND name ~ '^[0-9a-fA-F-]{36}/(profile|cover|portfolio)_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

COMMIT;
