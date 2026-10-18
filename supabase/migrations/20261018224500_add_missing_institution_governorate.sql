-- Keep production schema aligned with the institution offer catalog query.
ALTER TABLE public.institutions
  ADD COLUMN IF NOT EXISTS governorate text;

CREATE INDEX IF NOT EXISTS idx_institutions_governorate_public
  ON public.institutions (governorate, status, institution_type);
