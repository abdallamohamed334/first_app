BEGIN;

-- Identity documents remain supported and can still be uploaded, but they are
-- optional for provider visibility. Profile, location, availability, skills,
-- contact, and service category requirements remain enforced.
CREATE OR REPLACE FUNCTION public.enforce_provider_visibility_requirements()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.is_available IS TRUE THEN
    IF NEW.category_id IS NULL
       OR NOT EXISTS (
         SELECT 1
         FROM public.service_categories c
         WHERE c.id = NEW.category_id
           AND c.is_active IS TRUE
       )
       OR NULLIF(trim(NEW.display_name), '') IS NULL
       OR length(trim(coalesce(NEW.bio, ''))) < 10
       OR NULLIF(trim(NEW.governorate), '') IS NULL
       OR NULLIF(trim(NEW.city), '') IS NULL
       OR NEW.latitude IS NULL
       OR NEW.longitude IS NULL
       OR cardinality(coalesce(NEW.service_areas, '{}'::text[])) = 0
       OR cardinality(coalesce(NEW.available_days, '{}'::text[])) = 0
       OR cardinality(coalesce(NEW.skills, '{}'::text[])) = 0
       OR coalesce(NEW.experience_years, 0) < 1
       OR NULLIF(trim(NEW.profile_image_url), '') IS NULL
       OR (NULLIF(trim(NEW.phone), '') IS NULL AND NULLIF(trim(NEW.whatsapp), '') IS NULL)
    THEN
      RAISE EXCEPTION 'provider_profile_incomplete'
        USING HINT = 'اكمل بيانات الملف والموقع والتخصص والتواصل قبل تفعيل الظهور';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
