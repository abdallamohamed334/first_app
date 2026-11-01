BEGIN;

CREATE OR REPLACE FUNCTION public.enforce_provider_visibility_requirements()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.is_available IS TRUE THEN
    IF NEW.category_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM public.service_categories c WHERE c.id = NEW.category_id AND c.is_active IS TRUE)
       OR NULLIF(trim(NEW.display_name), '') IS NULL
       OR length(trim(coalesce(NEW.bio, ''))) < 10
       OR NULLIF(trim(NEW.governorate), '') IS NULL
       OR NULLIF(trim(NEW.city), '') IS NULL
       OR NEW.latitude IS NULL OR NEW.longitude IS NULL
       OR cardinality(coalesce(NEW.service_areas, '{}'::text[])) = 0
       OR cardinality(coalesce(NEW.available_days, '{}'::text[])) = 0
       OR cardinality(coalesce(NEW.skills, '{}'::text[])) = 0
       OR coalesce(NEW.experience_years, 0) < 1
       OR NULLIF(trim(NEW.profile_image_url), '') IS NULL
       OR NULLIF(trim(NEW.id_card_front_url), '') IS NULL
       OR NULLIF(trim(NEW.id_card_back_url), '') IS NULL
       OR (NULLIF(trim(NEW.phone), '') IS NULL AND NULLIF(trim(NEW.whatsapp), '') IS NULL)
    THEN
      RAISE EXCEPTION 'provider_profile_incomplete'
        USING HINT = 'اكمل بيانات الملف والموقع ومستندات الهوية قبل تفعيل الظهور';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_provider_visibility_requirements ON public.service_providers;
CREATE TRIGGER enforce_provider_visibility_requirements
BEFORE INSERT OR UPDATE OF category_id, display_name, bio, experience_years, skills,
  governorate, city, service_areas, available_days, latitude, longitude,
  profile_image_url, id_card_front_url, id_card_back_url, phone, whatsapp, is_available
ON public.service_providers FOR EACH ROW
EXECUTE FUNCTION public.enforce_provider_visibility_requirements();

UPDATE public.service_providers
SET is_available = false, updated_at = now()
WHERE is_available IS TRUE
  AND (
    category_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.service_categories c WHERE c.id = service_providers.category_id AND c.is_active IS TRUE)
    OR NULLIF(trim(display_name), '') IS NULL OR length(trim(coalesce(bio, ''))) < 10
    OR NULLIF(trim(governorate), '') IS NULL OR NULLIF(trim(city), '') IS NULL
    OR latitude IS NULL OR longitude IS NULL
    OR cardinality(coalesce(service_areas, '{}'::text[])) = 0
    OR cardinality(coalesce(available_days, '{}'::text[])) = 0
    OR cardinality(coalesce(skills, '{}'::text[])) = 0 OR coalesce(experience_years, 0) < 1
    OR NULLIF(trim(profile_image_url), '') IS NULL
    OR NULLIF(trim(id_card_front_url), '') IS NULL OR NULLIF(trim(id_card_back_url), '') IS NULL
    OR (NULLIF(trim(phone), '') IS NULL AND NULLIF(trim(whatsapp), '') IS NULL)
  );

NOTIFY pgrst, 'reload schema';
COMMIT;
