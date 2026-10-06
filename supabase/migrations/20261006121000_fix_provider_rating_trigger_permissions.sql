-- Review inserts update provider counters through a database trigger.
-- Keep direct client UPDATE privileges restricted, but let the trigger perform
-- its server-side aggregate update with the function owner's privileges.
BEGIN;

CREATE OR REPLACE FUNCTION public.sync_provider_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_provider_id uuid;
BEGIN
  target_provider_id := COALESCE(NEW.to_provider_id, OLD.to_provider_id);

  UPDATE public.service_providers
  SET
    rating_avg = (
      SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0)
      FROM public.service_reviews
      WHERE to_provider_id = target_provider_id
    ),
    total_reviews = (
      SELECT COUNT(*)
      FROM public.service_reviews
      WHERE to_provider_id = target_provider_id
    )
  WHERE id = target_provider_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION public.sync_provider_rating() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_provider_rating() TO authenticated;

COMMIT;
