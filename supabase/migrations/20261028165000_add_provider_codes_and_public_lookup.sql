BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.service_provider_code_seq;

ALTER TABLE public.service_providers
  ADD COLUMN IF NOT EXISTS provider_code text;

CREATE OR REPLACE FUNCTION public.assign_service_provider_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.provider_code IS NULL OR btrim(NEW.provider_code) = '' THEN
    NEW.provider_code := 'KHD-' || lpad(nextval('public.service_provider_code_seq')::text, 6, '0');
  ELSE
    NEW.provider_code := upper(btrim(NEW.provider_code));
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assign_service_provider_code ON public.service_providers;
CREATE TRIGGER trg_assign_service_provider_code
BEFORE INSERT ON public.service_providers
FOR EACH ROW EXECUTE FUNCTION public.assign_service_provider_code();

WITH missing AS (
  SELECT id,
         row_number() OVER (ORDER BY created_at NULLS LAST, id) AS row_no
  FROM public.service_providers
  WHERE provider_code IS NULL OR btrim(provider_code) = ''
)
UPDATE public.service_providers sp
SET provider_code = 'KHD-' || lpad(nextval('public.service_provider_code_seq')::text, 6, '0')
FROM missing
WHERE sp.id = missing.id;

SELECT setval(
  'public.service_provider_code_seq',
  COALESCE(
    (SELECT max((substring(provider_code FROM 5))::bigint)
     FROM public.service_providers
     WHERE provider_code ~ '^KHD-[0-9]+$'),
    0
  ) + 1,
  false
);

ALTER TABLE public.service_providers
  ALTER COLUMN provider_code SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS service_providers_provider_code_uidx
  ON public.service_providers(provider_code);

ALTER TABLE public.published_service_provider_cards
  ADD COLUMN IF NOT EXISTS provider_code text;

UPDATE public.published_service_provider_cards pc
SET provider_code = sp.provider_code
FROM public.service_providers sp
WHERE pc.id = sp.id
  AND pc.provider_code IS DISTINCT FROM sp.provider_code;

CREATE INDEX IF NOT EXISTS published_provider_cards_provider_code_idx
  ON public.published_service_provider_cards(provider_code);

GRANT SELECT (provider_code)
  ON public.published_service_provider_cards TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.sync_published_service_provider_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP <> 'DELETE' THEN
    UPDATE public.published_service_provider_cards
    SET provider_code = NEW.provider_code
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_published_service_provider_code() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS zz_sync_published_service_provider_code ON public.service_providers;
CREATE TRIGGER zz_sync_published_service_provider_code
AFTER INSERT OR UPDATE OF provider_code ON public.service_providers
FOR EACH ROW EXECUTE FUNCTION public.sync_published_service_provider_code();

NOTIFY pgrst, 'reload schema';
COMMIT;
