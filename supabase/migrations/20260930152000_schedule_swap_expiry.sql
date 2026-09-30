BEGIN;

CREATE OR REPLACE FUNCTION public.expire_swap_listings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE changed integer;
BEGIN
  UPDATE public.swap_listings
  SET status = 'expired', updated_at = now()
  WHERE status IN ('open', 'paused') AND expires_at <= now();
  GET DIAGNOSTICS changed = ROW_COUNT;
  RETURN changed;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_swap_listings() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  PERFORM cron.unschedule('expire-swap-listings');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule('expire-swap-listings', '*/15 * * * *', $$SELECT public.expire_swap_listings();$$);

COMMIT;
