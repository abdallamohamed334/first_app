BEGIN;

-- Keep the provider counter in sync with the actual completed-work records.
CREATE OR REPLACE FUNCTION public.sync_provider_completed_jobs_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_provider_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_provider_id := OLD.provider_id;
  ELSE
    v_provider_id := NEW.provider_id;
  END IF;

  UPDATE public.service_providers
  SET completed_jobs = (
        SELECT count(*)::integer
        FROM public.provider_completed_works
        WHERE provider_id = v_provider_id
      ),
      updated_at = now()
  WHERE id = v_provider_id;

  IF TG_OP = 'UPDATE' AND OLD.provider_id IS DISTINCT FROM NEW.provider_id THEN
    UPDATE public.service_providers
    SET completed_jobs = (
          SELECT count(*)::integer
          FROM public.provider_completed_works
          WHERE provider_id = OLD.provider_id
        ),
        updated_at = now()
    WHERE id = OLD.provider_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS provider_completed_works_sync_count
  ON public.provider_completed_works;
CREATE TRIGGER provider_completed_works_sync_count
AFTER INSERT OR UPDATE OF provider_id OR DELETE
ON public.provider_completed_works
FOR EACH ROW
EXECUTE FUNCTION public.sync_provider_completed_jobs_count();

-- Backfill providers created before the trigger existed.
UPDATE public.service_providers AS sp
SET completed_jobs = counts.completed_jobs,
    updated_at = now()
FROM (
  SELECT provider_id, count(*)::integer AS completed_jobs
  FROM public.provider_completed_works
  GROUP BY provider_id
) AS counts
WHERE sp.id = counts.provider_id;

UPDATE public.service_providers AS sp
SET completed_jobs = 0,
    updated_at = now()
WHERE NOT EXISTS (
  SELECT 1
  FROM public.provider_completed_works AS work
  WHERE work.provider_id = sp.id
)
AND sp.completed_jobs IS DISTINCT FROM 0;

-- The public card already stores these fields. Authenticated users may use
-- them for the call and WhatsApp buttons; anonymous users still receive NULL.
CREATE OR REPLACE VIEW public.published_service_providers AS
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
  CASE WHEN auth.uid() IS NOT NULL THEN phone END AS phone,
  CASE WHEN auth.uid() IS NOT NULL THEN whatsapp END AS whatsapp,
  CASE WHEN auth.uid() IS NOT NULL THEN email END AS email,
  CASE WHEN auth.uid() IS NOT NULL THEN website END AS website,
  CASE WHEN auth.uid() IS NOT NULL THEN address END AS address,
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

REVOKE ALL ON public.published_service_providers FROM PUBLIC, anon;
GRANT SELECT ON public.published_service_providers TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
