-- Unify charity-donation notifications around the single canonical trigger
-- and the notify-charity-donation-event Edge Function.

DROP TRIGGER IF EXISTS trg_direct_charity_status_notification
  ON public.charity_donation_requests;
DROP TRIGGER IF EXISTS trigger_notify_charity_new_donation
  ON public.charity_donation_requests;
DROP TRIGGER IF EXISTS trigger_notify_donor_donation_decision
  ON public.charity_donation_requests;
DROP TRIGGER IF EXISTS send_push_on_notification_in_donation
  ON public.charity_donation_requests;

-- The canonical trigger is the only writer of in-app donation notifications.
CREATE OR REPLACE FUNCTION public.create_direct_charity_status_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_charity_user_id uuid;
  v_recipient_id uuid;
  v_recipients uuid[];
  v_donation_title text := COALESCE(NULLIF(left(btrim(NEW.title), 120), ''), 'التبرع');
  v_title text;
  v_body text;
BEGIN
  SELECT user_id INTO v_charity_user_id
  FROM public.charities
  WHERE id = NEW.charity_id;

  IF TG_OP = 'INSERT' THEN
    v_recipients := ARRAY[v_charity_user_id];
    v_title := 'تبرع جديد للجمعية';
    v_body := format('وصل تبرع جديد بعنوان «%s» ويحتاج إلى المراجعة.', v_donation_title);
  ELSIF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    IF NEW.assigned_at IS NOT DISTINCT FROM OLD.assigned_at
       AND NEW.volunteer_type IS NOT DISTINCT FROM OLD.volunteer_type
       AND NEW.volunteer_id IS NOT DISTINCT FROM OLD.volunteer_id
       AND NEW.charity_volunteer_id IS NOT DISTINCT FROM OLD.charity_volunteer_id
       AND NEW.volunteer_name IS NOT DISTINCT FROM OLD.volunteer_name
       AND NEW.volunteer_phone IS NOT DISTINCT FROM OLD.volunteer_phone THEN
      RETURN NEW;
    END IF;
    v_title := 'تم تعيين مندوب للتبرع';
    v_body := format(
      'تم تعيين %s لاستلام التبرع «%s».',
      COALESCE(NULLIF(left(btrim(NEW.volunteer_name), 100), ''), 'مندوب'),
      v_donation_title
    );
    v_recipients := ARRAY[NEW.donor_id, NEW.volunteer_id];
  ELSE
    CASE NEW.status
    WHEN 'accepted' THEN
      v_title := 'تم قبول التبرع';
      v_body := format('وافقت الجمعية على تبرعك «%s». راجع التطبيق لمعرفة الخطوة التالية.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id];
    WHEN 'rejected' THEN
      v_title := 'تم رفض التبرع';
      v_body := format('اعتذرت الجمعية عن قبول تبرعك «%s».', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id];
    WHEN 'donor_ready' THEN
      v_title := 'المتبرع جاهز للاستلام';
      v_body := format('أعلن المتبرع جاهزية «%s» للاستلام.', v_donation_title);
      v_recipients := ARRAY[v_charity_user_id];
    WHEN 'ready_for_pickup' THEN
      v_title := 'التبرع جاهز للاستلام';
      v_body := format('التبرع «%s» جاهز للاستلام. راجع التطبيق لمعرفة كود الاستلام.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id];
    WHEN 'volunteer_assigned' THEN
      v_title := 'تم تعيين مندوب للتبرع';
      v_body := format('تم تعيين %s لاستلام التبرع «%s».', COALESCE(NULLIF(left(btrim(NEW.volunteer_name), 100), ''), 'مندوب'), v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, NEW.volunteer_id];
    WHEN 'picked_up_from_donor' THEN
      v_title := 'تم استلام التبرع من المتبرع';
      v_body := format('تم استلام «%s» من المتبرع وهو في طريقه إلى الجمعية.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, v_charity_user_id];
    WHEN 'in_transit' THEN
      v_title := 'التبرع في الطريق';
      v_body := format('التبرع «%s» في طريقه إلى الجمعية.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, v_charity_user_id];
    WHEN 'completed' THEN
      v_title := 'وصل التبرع للجمعية';
      v_body := format('أكدت الجمعية استلام تبرعك «%s». شكرًا لمساهمتك.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id];
    WHEN 'cancelled' THEN
      v_title := 'تم إلغاء التبرع';
      v_body := format('تم إلغاء التبرع «%s».', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, v_charity_user_id, NEW.volunteer_id];
    WHEN 'expired' THEN
      v_title := 'انتهت مهلة التبرع';
      v_body := format('انتهت مهلة متابعة التبرع «%s».', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, v_charity_user_id];
    WHEN 'volunteer_needed' THEN
      v_title := 'التبرع يحتاج مندوبًا';
      v_body := format('التبرع «%s» يحتاج إلى مندوب للتوصيل.', v_donation_title);
      v_recipients := ARRAY[v_charity_user_id];
    ELSE
      v_title := 'تحديث التبرع';
      v_body := format('تم تحديث حالة التبرع «%s». افتح التطبيق لمعرفة التفاصيل.', v_donation_title);
      v_recipients := ARRAY[NEW.donor_id, v_charity_user_id, NEW.volunteer_id];
    END CASE;
  END IF;

  FOR v_recipient_id IN
    SELECT DISTINCT recipient_id
    FROM unnest(v_recipients) AS recipients(recipient_id)
    WHERE recipient_id IS NOT NULL
  LOOP
    INSERT INTO public.notifications
      (user_id, title, body, type, reference_id, reference_type, is_read, created_at)
    SELECT v_recipient_id, v_title, v_body, 'system', NEW.id, 'charity_donation', false, now()
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.user_id = v_recipient_id
        AND n.reference_id = NEW.id
        AND n.reference_type = 'charity_donation'
        AND n.title = v_title
        AND n.body = v_body
        AND n.created_at > now() - interval '10 seconds'
    );
  END LOOP;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_direct_charity_status_notifications()
  FROM PUBLIC, anon, authenticated;

-- Delivery claims prevent client retries from sending the same Push/WhatsApp
-- event twice. Claims are only callable by the service role.
CREATE TABLE IF NOT EXISTS public.charity_notification_delivery_log (
  delivery_key text PRIMARY KEY,
  state text NOT NULL CHECK (state IN ('sending', 'delivered', 'failed')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_attempt_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.charity_notification_delivery_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.charity_notification_delivery_log FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.charity_notification_delivery_log TO service_role;

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
  IF coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required';
  END IF;
  INSERT INTO public.charity_notification_delivery_log(delivery_key, state, attempts)
  VALUES (v_key, 'sending', 1)
  ON CONFLICT (delivery_key) DO NOTHING
  RETURNING true INTO v_inserted;
  IF v_inserted THEN RETURN true; END IF;
  SELECT * INTO v_row FROM public.charity_notification_delivery_log WHERE delivery_key = v_key;
  IF v_row.state = 'delivered' THEN RETURN false; END IF;
  IF v_row.state = 'sending' AND v_row.last_attempt_at > now() - interval '30 seconds' THEN RETURN false; END IF;
  IF v_row.attempts >= 3 THEN RETURN false; END IF;
  UPDATE public.charity_notification_delivery_log
  SET state = 'sending', attempts = attempts + 1, last_attempt_at = now(), updated_at = now()
  WHERE delivery_key = v_row.delivery_key;
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
  IF coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required';
  END IF;
  UPDATE public.charity_notification_delivery_log
  SET state = CASE WHEN p_delivered THEN 'delivered' ELSE 'failed' END,
      delivered_at = CASE WHEN p_delivered THEN now() ELSE delivered_at END,
      updated_at = now()
  WHERE delivery_key = left(trim(p_delivery_key), 300);
END;
$function$;

REVOKE ALL ON FUNCTION public.claim_charity_notification_delivery(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_charity_notification_delivery(text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_charity_notification_delivery(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_charity_notification_delivery(text, boolean) TO service_role;
