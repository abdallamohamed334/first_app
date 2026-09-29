BEGIN;

ALTER TABLE public.service_providers
  ADD COLUMN IF NOT EXISTS id_card_front_url text,
  ADD COLUMN IF NOT EXISTS id_card_back_url text,
  ADD COLUMN IF NOT EXISTS profile_locked_at timestamptz;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'provider-documents',
  'provider-documents',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[];

DROP POLICY IF EXISTS "Providers upload own identity documents" ON storage.objects;
CREATE POLICY "Providers upload own identity documents"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'provider-documents'
  AND name ~ '^[0-9a-fA-F-]{36}/id_card_(front|back)_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

DROP POLICY IF EXISTS "Providers read own identity documents" ON storage.objects;
CREATE POLICY "Providers read own identity documents"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'provider-documents'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE OR REPLACE FUNCTION public.prevent_locked_provider_profile_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.profile_locked_at IS NOT NULL THEN
    IF NEW.display_name IS DISTINCT FROM OLD.display_name
      OR NEW.bio IS DISTINCT FROM OLD.bio
      OR NEW.experience_years IS DISTINCT FROM OLD.experience_years
      OR NEW.skills IS DISTINCT FROM OLD.skills
      OR NEW.address IS DISTINCT FROM OLD.address
      OR NEW.pricing_type IS DISTINCT FROM OLD.pricing_type
      OR NEW.price_from IS DISTINCT FROM OLD.price_from
      OR NEW.accepts_installments IS DISTINCT FROM OLD.accepts_installments
      OR NEW.whatsapp IS DISTINCT FROM OLD.whatsapp
      OR NEW.website IS DISTINCT FROM OLD.website
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

DROP TRIGGER IF EXISTS service_provider_profile_lock ON public.service_providers;
CREATE TRIGGER service_provider_profile_lock
BEFORE UPDATE ON public.service_providers
FOR EACH ROW EXECUTE FUNCTION public.prevent_locked_provider_profile_changes();

COMMIT;
