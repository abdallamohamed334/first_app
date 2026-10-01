BEGIN;

ALTER TABLE public.swap_listings
  ADD COLUMN IF NOT EXISTS categories text[] NOT NULL DEFAULT '{}';

UPDATE public.swap_listings
SET categories = ARRAY[category]
WHERE (categories IS NULL OR cardinality(categories) = 0)
  AND category IS NOT NULL
  AND btrim(category) <> '';

CREATE INDEX IF NOT EXISTS swap_listings_categories_gin_idx
  ON public.swap_listings USING gin (categories);

COMMIT;
