BEGIN;

-- Keep the trigger function deterministic when invoked by a service-role write.
ALTER FUNCTION public.prevent_user_account_field_escalation()
  SET search_path = public, pg_temp;

-- Public discovery exposes only the approved, non-secret card contract.
-- Contact and operational fields are intentionally absent from the public API.
REVOKE ALL ON public.published_service_provider_cards FROM PUBLIC, anon, authenticated;
GRANT SELECT (
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
  verification_status,
  is_active,
  is_available,
  availability_note,
  rating_avg,
  total_reviews,
  created_at,
  updated_at,
  category_name,
  category_icon,
  category_slug
) ON public.published_service_provider_cards TO anon, authenticated;

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

-- All public upload buckets accept images only and have a bounded payload.
UPDATE storage.buckets
SET file_size_limit = CASE
      WHEN id IN ('community-offers', 'institution-images', 'provider-images')
        THEN 10 * 1024 * 1024
      ELSE 5 * 1024 * 1024
    END,
    allowed_mime_types = CASE
      WHEN id IN ('community-needs', 'swap-images')
        THEN ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
      ELSE ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
    END
WHERE public IS TRUE;

-- These tables are service-role/RPC-only by design. Explicit deny policies
-- document that intent and make the security posture visible to advisors.
DO $policies$
DECLARE
  item record;
  policy_name text;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('public', 'admin_audit_logs'),
      ('public', 'direct_charity_points_awards'),
      ('public', 'institution_pickup_codes'),
      ('public', 'otp_codes'),
      ('public', 'otp_rate_limits'),
      ('public', 'partner_login_otp_challenges'),
      ('public', 'pending_signup_profiles'),
      ('public', 'points_transactions'),
      ('public', 'restaurant_charity_email_outbox'),
      ('public', 'restaurant_charity_pickup_codes'),
      ('public', 'services'),
      ('public', 'swap_proposals'),
      ('public', 'volunteer_profiles'),
      ('private', 'charity_login_secrets'),
      ('private', 'institution_login_secrets')
    ) AS v(schema_name, table_name)
  LOOP
    policy_name := 'deny_direct_client_access_' || item.table_name;
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', policy_name, item.schema_name, item.table_name);
    EXECUTE format(
      'CREATE POLICY %I ON %I.%I FOR ALL TO anon, authenticated USING (false) WITH CHECK (false)',
      policy_name, item.schema_name, item.table_name
    );
  END LOOP;
END;
$policies$;

NOTIFY pgrst, 'reload schema';
COMMIT;
