-- Keep in-app notifications transactional with the donation row while routing
-- each lifecycle update only to the parties who need to act or be informed.
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
    IF v_charity_user_id IS NOT NULL THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, reference_id, is_read, created_at)
      VALUES
        (v_charity_user_id, 'تبرع جديد للجمعية',
         format('وصل تبرع جديد بعنوان «%s» ويحتاج إلى المراجعة.', v_donation_title),
         'system', NEW.id, false, now());
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
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
      v_body := format(
        'اعتذرت الجمعية عن قبول تبرعك «%s».%s',
        v_donation_title,
        CASE
          WHEN NULLIF(btrim(COALESCE(NEW.rejection_reason, '')), '') IS NULL THEN ''
          ELSE format(' السبب: %s', left(btrim(NEW.rejection_reason), 220))
        END
      );
      v_recipients := ARRAY[NEW.donor_id];
    WHEN 'donor_ready' THEN
      v_title := 'المتبرع جاهز للاستلام';
      v_body := format('أعلن المتبرع جاهزية «%s» للاستلام.', v_donation_title);
      v_recipients := ARRAY[v_charity_user_id];
    WHEN 'volunteer_assigned' THEN
      v_title := 'تم تعيين مندوب للتبرع';
      v_body := format(
        'تم تعيين %s لاستلام التبرع «%s».',
        COALESCE(NULLIF(left(btrim(NEW.volunteer_name), 100), ''), 'مندوب'),
        v_donation_title
      );
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
      v_recipients := ARRAY[v_charity_user_id, NEW.volunteer_id];
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
      (user_id, title, body, type, reference_id, is_read, created_at)
    VALUES
      (v_recipient_id, v_title, v_body, 'system', NEW.id, false, now());
  END LOOP;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_direct_charity_status_notifications()
  FROM PUBLIC, anon, authenticated;

-- Assignment details are meaningful events even when the donation remains in
-- accepted (for example, the donor has not confirmed readiness yet).
DROP TRIGGER IF EXISTS trg_direct_charity_status_notifications
  ON public.charity_donation_requests;
CREATE TRIGGER trg_direct_charity_status_notifications
  AFTER INSERT OR UPDATE OF status, assigned_at, volunteer_type, volunteer_id,
    charity_volunteer_id, volunteer_name, volunteer_phone
  ON public.charity_donation_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.create_direct_charity_status_notifications();
