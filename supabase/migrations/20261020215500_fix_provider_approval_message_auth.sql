CREATE OR REPLACE FUNCTION public.notify_provider_approved()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, vault, net, pg_temp
AS $$
DECLARE
  v_secret text;
BEGIN
  -- Send only on a transition into the approved state.
  IF NEW.verification_status = 'approved'
     AND OLD.verification_status IS DISTINCT FROM 'approved' THEN
    SELECT decrypted_secret
      INTO v_secret
    FROM vault.decrypted_secrets
    WHERE name = 'notification_internal_secret'
    LIMIT 1;

    IF v_secret IS NULL OR length(btrim(v_secret)) = 0 THEN
      RAISE WARNING 'Provider approval message was not queued: notification secret is unavailable';
      RETURN NEW;
    END IF;

    PERFORM net.http_post(
      url := 'https://gsrhoqdtcyfdmvgahqvl.supabase.co/functions/v1/notify-provider-approved',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notification-secret', v_secret
      ),
      body := jsonb_build_object(
        'type', 'UPDATE',
        'table', 'service_providers',
        'record', row_to_json(NEW),
        'old_record', row_to_json(OLD)
      ),
      timeout_milliseconds := 10000
    );

    RAISE NOTICE 'Provider approval message queued for provider id %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
