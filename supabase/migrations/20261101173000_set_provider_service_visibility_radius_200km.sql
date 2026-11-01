BEGIN;

ALTER TABLE public.service_providers
  ALTER COLUMN max_distance_km SET DEFAULT 200;

UPDATE public.service_providers
SET max_distance_km = 200,
    updated_at = now()
WHERE max_distance_km IS DISTINCT FROM 200;

ALTER TABLE public.published_service_provider_cards
  ALTER COLUMN max_distance_km SET DEFAULT 200;

UPDATE public.published_service_provider_cards
SET max_distance_km = 200,
    updated_at = now()
WHERE max_distance_km IS DISTINCT FROM 200;

NOTIFY pgrst, 'reload schema';
COMMIT;
