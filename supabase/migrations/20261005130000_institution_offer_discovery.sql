BEGIN;

-- Keep empty legacy institution types filterable under "other".
UPDATE public.institutions
SET institution_type = 'other'
WHERE institution_type IS NULL OR btrim(institution_type) = '';

-- Normalize the common grocery alias without changing supported business types.
UPDATE public.institutions
SET institution_type = 'supermarket'
WHERE lower(btrim(institution_type)) = 'grocery';

CREATE INDEX IF NOT EXISTS idx_institutions_public_type_location
  ON public.institutions (institution_type, status, latitude, longitude);

CREATE INDEX IF NOT EXISTS idx_institution_offers_public_discovery
  ON public.institution_offers (institution_id, status, expires_at, created_at DESC)
  WHERE deleted_at IS NULL;

COMMIT;
