BEGIN;

UPDATE public.service_providers
SET profile_locked_at = COALESCE(profile_locked_at, now())
WHERE profile_locked_at IS NULL
  AND NULLIF(trim(id_card_front_url), '') IS NOT NULL
  AND NULLIF(trim(id_card_back_url), '') IS NOT NULL;

CREATE OR REPLACE FUNCTION public.prevent_locked_provider_profile_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.profile_locked_at IS NOT NULL THEN
    IF NEW.category_id IS DISTINCT FROM OLD.category_id
      OR NEW.provider_type IS DISTINCT FROM OLD.provider_type
      OR NEW.display_name IS DISTINCT FROM OLD.display_name
      OR NEW.bio IS DISTINCT FROM OLD.bio
      OR NEW.experience_years IS DISTINCT FROM OLD.experience_years
      OR NEW.skills IS DISTINCT FROM OLD.skills
      OR NEW.address IS DISTINCT FROM OLD.address
      OR NEW.latitude IS DISTINCT FROM OLD.latitude
      OR NEW.longitude IS DISTINCT FROM OLD.longitude
      OR NEW.max_distance_km IS DISTINCT FROM OLD.max_distance_km
      OR NEW.pricing_type IS DISTINCT FROM OLD.pricing_type
      OR NEW.price_from IS DISTINCT FROM OLD.price_from
      OR NEW.price_currency IS DISTINCT FROM OLD.price_currency
      OR NEW.accepts_installments IS DISTINCT FROM OLD.accepts_installments
      OR NEW.phone IS DISTINCT FROM OLD.phone
      OR NEW.whatsapp IS DISTINCT FROM OLD.whatsapp
      OR NEW.email IS DISTINCT FROM OLD.email
      OR NEW.website IS DISTINCT FROM OLD.website
      OR NEW.company_legal_name IS DISTINCT FROM OLD.company_legal_name
      OR NEW.founded_year IS DISTINCT FROM OLD.founded_year
      OR NEW.employees_count IS DISTINCT FROM OLD.employees_count
      OR NEW.branches IS DISTINCT FROM OLD.branches
      OR NEW.cover_image_url IS DISTINCT FROM OLD.cover_image_url
      OR NEW.id_card_front_url IS DISTINCT FROM OLD.id_card_front_url
      OR NEW.id_card_back_url IS DISTINCT FROM OLD.id_card_back_url
      OR NEW.profile_locked_at IS DISTINCT FROM OLD.profile_locked_at
    THEN
      RAISE EXCEPTION 'provider_profile_locked';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMIT;
