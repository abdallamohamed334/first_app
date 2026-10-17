-- Ensure institution offer bookings notify the institution account and the
-- requester receives subsequent status changes. The live offer requests FK
-- references public.institution_offers (not institution_offers_core).
CREATE OR REPLACE FUNCTION public.notify_institution_offer_request_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_user_id uuid;
  v_offer_title text;
  v_recipient_user_id uuid;
  v_secret text;
  v_type text;
  v_title text;
  v_body text;
  v_screen text;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  SELECT i.user_id, o.title
    INTO v_institution_user_id, v_offer_title
  FROM public.institution_offers o
  JOIN public.institutions i ON i.id = o.institution_id
  WHERE o.id = NEW.offer_id;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'notification_internal_secret';

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'pending' OR v_institution_user_id IS NULL THEN
      RETURN NEW;
    END IF;
    v_recipient_user_id := v_institution_user_id;
    v_type := 'offer_request';
    v_title := 'حجز جديد على عرضك';
    v_body := format(
      'قام أحد المستخدمين بحجز كمية %s من عرض «%s». راجع الطلب من لوحة المؤسسة.',
      NEW.quantity,
      coalesce(v_offer_title, 'المؤسسة')
    );
    v_screen := 'institution_request_details';
  ELSE
    v_recipient_user_id := NEW.requester_id;
    IF v_recipient_user_id IS NULL THEN
      RETURN NEW;
    END IF;

    CASE NEW.status
      WHEN 'accepted' THEN
        v_type := 'request_accepted';
        v_title := 'تم قبول طلب عرض المؤسسة';
        v_body := format('تم قبول طلبك على عرض «%s».', coalesce(v_offer_title, 'المؤسسة'));
      WHEN 'rejected' THEN
        v_type := 'request_rejected';
        v_title := 'تم رفض طلب عرض المؤسسة';
        v_body := format('تم رفض طلبك على عرض «%s».', coalesce(v_offer_title, 'المؤسسة'));
      WHEN 'ready_for_pickup' THEN
        v_type := 'delivery_assigned';
        v_title := 'العرض جاهز للاستلام';
        v_body := format('عرض «%s» أصبح جاهزًا للاستلام.', coalesce(v_offer_title, 'المؤسسة'));
      WHEN 'completed' THEN
        v_type := 'delivery_completed';
        v_title := 'اكتمل طلب عرض المؤسسة';
        v_body := format('اكتمل طلبك على عرض «%s».', coalesce(v_offer_title, 'المؤسسة'));
      ELSE
        v_type := 'system';
        v_title := 'تحديث على طلب عرض المؤسسة';
        v_body := format('تم تحديث حالة طلب عرض «%s».', coalesce(v_offer_title, 'المؤسسة'));
    END CASE;
    v_screen := 'my_institution_requests';
  END IF;

  INSERT INTO public.notifications
    (user_id, title, body, type, reference_id, reference_type, is_read, created_at)
  VALUES
    (v_recipient_user_id, v_title, v_body, v_type, NEW.id,
     'institution_offer_request', false, now());

  IF v_secret IS NOT NULL AND length(btrim(v_secret)) > 0 THEN
    PERFORM net.http_post(
      url := 'https://gsrhoqdtcyfdmvgahqvl.supabase.co/functions/v1/send-push-notification',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-notification-secret', v_secret
      ),
      body := jsonb_build_object(
        'userId', v_recipient_user_id::text,
        'title', v_title,
        'body', v_body,
        'data', jsonb_build_object(
          'type', 'institution_offer_request',
          'reference_id', NEW.id::text,
          'reference_type', 'institution_offer_request',
          'screen', v_screen
        )
      )
    );
  END IF;

  RETURN NEW;
END;
$function$;
