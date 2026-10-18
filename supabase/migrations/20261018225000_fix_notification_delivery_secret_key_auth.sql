-- Supabase sb_secret keys use the service_role database privilege but do not
-- expose the legacy request.jwt.claim.role JWT claim. Authorization remains
-- enforced by EXECUTE privileges: only service_role may call these functions.
CREATE OR REPLACE FUNCTION public.claim_charity_notification_delivery(p_delivery_key text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_row public.charity_notification_delivery_log;
  v_key text := left(trim(p_delivery_key), 300);
  v_inserted boolean := false;
BEGIN
  INSERT INTO public.charity_notification_delivery_log(delivery_key,state,attempts)
  VALUES(v_key,'sending',1)
  ON CONFLICT(delivery_key) DO NOTHING
  RETURNING true INTO v_inserted;
  IF v_inserted THEN RETURN true; END IF;
  SELECT * INTO v_row
  FROM public.charity_notification_delivery_log
  WHERE delivery_key=v_key;
  IF v_row.state='delivered' THEN RETURN false; END IF;
  IF v_row.state='sending' AND v_row.last_attempt_at>now()-interval '30 seconds' THEN RETURN false; END IF;
  IF v_row.attempts>=3 THEN RETURN false; END IF;
  UPDATE public.charity_notification_delivery_log
  SET state='sending', attempts=attempts+1, last_attempt_at=now(), updated_at=now()
  WHERE delivery_key=v_row.delivery_key;
  RETURN true;
END;
$function$;

CREATE OR REPLACE FUNCTION public.finish_charity_notification_delivery(
  p_delivery_key text,
  p_delivered boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  UPDATE public.charity_notification_delivery_log
  SET state=CASE WHEN p_delivered THEN 'delivered' ELSE 'failed' END,
      delivered_at=CASE WHEN p_delivered THEN now() ELSE delivered_at END,
      updated_at=now()
  WHERE delivery_key=left(trim(p_delivery_key),300);
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_charity_notification_delivery(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_charity_notification_delivery(text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_charity_notification_delivery(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_charity_notification_delivery(text, boolean) TO service_role;
