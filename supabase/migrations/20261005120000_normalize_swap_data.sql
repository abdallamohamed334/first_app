BEGIN;

-- Normalize legacy location values so exact governorate/city filters remain reliable.
UPDATE public.swap_listings
SET governorate = NULLIF(btrim(governorate), ''),
    city = NULLIF(btrim(city), '')
WHERE governorate IS DISTINCT FROM NULLIF(btrim(governorate), '')
   OR city IS DISTINCT FROM NULLIF(btrim(city), '');

-- Keep legacy category values searchable in both the scalar and array columns.
UPDATE public.swap_listings
SET category = CASE
                 WHEN category IS NULL OR btrim(category) = '' THEN 'other'
                 ELSE btrim(category)
               END,
    categories = ARRAY(
      SELECT DISTINCT value
      FROM unnest(
        COALESCE(categories, '{}'::text[]) ||
        CASE
          WHEN category IS NULL OR btrim(category) = '' THEN '{}'::text[]
          ELSE ARRAY[btrim(category)]
        END
      ) AS v(value)
      WHERE btrim(value) <> ''
    )
WHERE category IS DISTINCT FROM CASE
                                  WHEN category IS NULL OR btrim(category) = '' THEN 'other'
                                  ELSE btrim(category)
                                END
   OR categories IS NULL
   OR cardinality(categories) = 0
   OR NOT (ARRAY[btrim(category)] <@ COALESCE(categories, '{}'::text[]));

-- Repair rows that were left open after their expiry time.
UPDATE public.swap_listings
SET status = 'expired', updated_at = now()
WHERE status IN ('open', 'paused')
  AND expires_at <= now();

CREATE INDEX IF NOT EXISTS swap_listings_governorate_created_idx
  ON public.swap_listings (governorate, created_at DESC)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS swap_listings_city_created_idx
  ON public.swap_listings (city, created_at DESC)
  WHERE status = 'open';

COMMIT;
