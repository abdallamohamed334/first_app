-- Store the institution governorate separately from the city so public offer
-- catalogs can filter reliably at governorate level.
ALTER TABLE public.institutions
  ADD COLUMN IF NOT EXISTS governorate text;

CREATE INDEX IF NOT EXISTS idx_institutions_governorate_public
  ON public.institutions (governorate, status, institution_type);
