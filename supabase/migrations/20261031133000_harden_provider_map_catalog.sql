BEGIN;

-- A provider is publicly mappable only while its category is active.
DROP POLICY IF EXISTS published_provider_cards_read
  ON public.published_service_provider_cards;
CREATE POLICY published_provider_cards_read
  ON public.published_service_provider_cards
  FOR SELECT TO anon, authenticated
  USING (
    verification_status = 'approved'
    AND is_active IS TRUE
    AND is_available IS TRUE
    AND EXISTS (
      SELECT 1
      FROM public.service_categories AS category
      WHERE category.id = published_service_provider_cards.category_id
        AND category.is_active IS TRUE
    )
  );

-- The public card is a denormalized projection, so keep category labels in
-- sync when the category itself changes.
CREATE OR REPLACE FUNCTION public.sync_published_cards_for_category()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.published_service_provider_cards
  SET category_name = NEW.name_ar,
      category_icon = NEW.icon,
      category_slug = NEW.slug,
      updated_at = now()
  WHERE category_id = NEW.id;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_published_cards_for_category() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_sync_published_cards_for_category
  ON public.service_categories;
CREATE TRIGGER trg_sync_published_cards_for_category
AFTER UPDATE OF slug, name_ar, name_en, icon, is_active
ON public.service_categories
FOR EACH ROW
EXECUTE FUNCTION public.sync_published_cards_for_category();

-- Support the current region prefilter and the server-side coordinate box.
CREATE INDEX IF NOT EXISTS published_provider_cards_region_idx
  ON public.published_service_provider_cards (governorate, city)
  WHERE verification_status = 'approved'
    AND is_active IS TRUE
    AND is_available IS TRUE;
CREATE INDEX IF NOT EXISTS published_provider_cards_location_idx
  ON public.published_service_provider_cards (latitude, longitude)
  WHERE verification_status = 'approved'
    AND is_active IS TRUE
    AND is_available IS TRUE
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'service_providers_latitude_valid'
      AND conrelid = 'public.service_providers'::regclass
  ) THEN
    ALTER TABLE public.service_providers
      ADD CONSTRAINT service_providers_latitude_valid
      CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'service_providers_longitude_valid'
      AND conrelid = 'public.service_providers'::regclass
  ) THEN
    ALTER TABLE public.service_providers
      ADD CONSTRAINT service_providers_longitude_valid
      CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'published_cards_latitude_valid'
      AND conrelid = 'public.published_service_provider_cards'::regclass
  ) THEN
    ALTER TABLE public.published_service_provider_cards
      ADD CONSTRAINT published_cards_latitude_valid
      CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'published_cards_longitude_valid'
      AND conrelid = 'public.published_service_provider_cards'::regclass
  ) THEN
    ALTER TABLE public.published_service_provider_cards
      ADD CONSTRAINT published_cards_longitude_valid
      CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180);
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
