-- Keep the public provider projection consistent when service providers are
-- removed with TRUNCATE (row-level DELETE triggers do not fire for TRUNCATE).
BEGIN;

-- Remove any published cards whose source provider no longer exists.
DELETE FROM public.published_service_provider_cards AS card
WHERE NOT EXISTS (
  SELECT 1
  FROM public.service_providers AS provider
  WHERE provider.id = card.id
);

CREATE OR REPLACE FUNCTION public.cleanup_orphaned_published_service_provider_cards()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $function$
BEGIN
  DELETE FROM public.published_service_provider_cards AS card
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.service_providers AS provider
    WHERE provider.id = card.id
  );
  RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.cleanup_orphaned_published_service_provider_cards()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_cleanup_orphaned_published_provider_cards
  ON public.service_providers;
CREATE TRIGGER trg_cleanup_orphaned_published_provider_cards
AFTER TRUNCATE ON public.service_providers
FOR EACH STATEMENT
EXECUTE FUNCTION public.cleanup_orphaned_published_service_provider_cards();

COMMENT ON FUNCTION public.cleanup_orphaned_published_service_provider_cards() IS
  'Removes orphaned public provider cards after TRUNCATE on service_providers.';

COMMIT;
