-- The direct charity donation flow is handled by the charity's own courier
-- (internal or externally assigned by the charity). Independent volunteers are
-- no longer a supported route.
ALTER TABLE public.charity_donation_requests
  ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Never allow a new donation to be opened to independent volunteers.
CREATE OR REPLACE FUNCTION public.charity_accept_donation(
  p_request_id uuid,
  p_open_to_volunteers boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_charity_id uuid;
  v_request public.charity_donation_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT id INTO v_charity_id
  FROM public.charities
  WHERE user_id = auth.uid()
    AND status = 'active'
  LIMIT 1;

  IF v_charity_id IS NULL THEN
    RAISE EXCEPTION 'لا توجد جمعية نشطة مرتبطة بالحساب';
  END IF;

  IF p_open_to_volunteers IS TRUE THEN
    RAISE EXCEPTION 'التطوع المستقل غير متاح في مسار التبرعات';
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND charity_id = v_charity_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND OR v_request.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن قبول التبرع من الحالة الحالية';
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'accepted',
      charity_accepted_at = now(),
      open_to_independent_volunteers = false,
      delivery_type = 'charity_volunteer',
      rejection_reason = NULL,
      cancellation_reason = NULL
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'status', 'accepted');
END;
$function$;

-- Disable the old independent-volunteer API surface. Existing historical rows
-- remain visible for audit, but no new user can claim or progress them.
REVOKE ALL ON FUNCTION public.list_open_donations_for_volunteers(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_open_donations_for_volunteers(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_my_volunteer_donations() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.volunteer_claim_charity_donation(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.volunteer_generate_charity_code(uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.volunteer_confirm_charity_delivery(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.volunteer_deliver_to_charity(uuid) FROM PUBLIC, anon, authenticated;

-- Donors can cancel their own donation while it is active. The operation is
-- atomic and can race safely with acceptance/assignment/pickup transitions.
CREATE OR REPLACE FUNCTION public.cancel_direct_charity_donation(
  p_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_request public.charity_donation_requests%ROWTYPE;
  v_reason text := NULLIF(left(btrim(COALESCE(p_reason, '')), 500), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND donor_id = auth.uid()
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'التبرع غير موجود أو غير تابع لحسابك';
  END IF;

  IF v_request.status IN ('completed', 'rejected', 'cancelled', 'expired') THEN
    RAISE EXCEPTION 'لا يمكن إلغاء التبرع بعد انتهاء مساره';
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'cancelled',
      cancellation_reason = COALESCE(v_reason, 'تم الإلغاء بواسطة المتبرع'),
      pickup_token = NULL,
      pickup_token_hash = NULL,
      pickup_token_expires_at = NULL,
      charity_pickup_code = NULL,
      charity_pickup_code_expires_at = NULL,
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'cancelled',
    'cancellation_reason', COALESCE(v_reason, 'تم الإلغاء بواسطة المتبرع')
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_direct_charity_donation(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_direct_charity_donation(uuid, text)
  TO authenticated;

-- Persist a local notification for both sides on every status transition.
-- Existing push triggers remain in place; this closes the in-app notification gap
-- and does not depend on a client-side Edge Function call succeeding.
CREATE OR REPLACE FUNCTION public.create_direct_charity_status_notifications()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_charity_user_id uuid;
  v_label text;
  v_title text;
  v_body text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT user_id INTO v_charity_user_id
    FROM public.charities
    WHERE id = NEW.charity_id;

    IF v_charity_user_id IS NOT NULL THEN
      INSERT INTO public.notifications
        (user_id, title, body, type, reference_id, is_read, created_at)
      VALUES
        (v_charity_user_id, 'طلب تبرع جديد',
         'وصلك طلب تبرع جديد يحتاج إلى المراجعة.', 'system', NEW.id, false, now());
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_label := CASE NEW.status
    WHEN 'accepted' THEN 'تم قبول التبرع'
    WHEN 'donor_ready' THEN 'المتبرع أعلن جاهزية التبرع'
    WHEN 'volunteer_assigned' THEN 'تم تعيين مندوب للتبرع'
    WHEN 'picked_up_from_donor' THEN 'تم استلام التبرع من المتبرع'
    WHEN 'in_transit' THEN 'التبرع في الطريق إلى الجمعية'
    WHEN 'completed' THEN 'تم استلام التبرع في الجمعية'
    WHEN 'rejected' THEN 'تم رفض التبرع'
    WHEN 'cancelled' THEN 'تم إلغاء التبرع'
    WHEN 'expired' THEN 'انتهت صلاحية التبرع'
    ELSE 'تم تحديث حالة التبرع'
  END;

  v_title := v_label;
  v_body := format('تغيرت حالة التبرع من %s إلى %s.', OLD.status, NEW.status);

  IF NEW.donor_id IS NOT NULL THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, reference_id, is_read, created_at)
    VALUES
      (NEW.donor_id, v_title, v_body, 'system', NEW.id, false, now());
  END IF;

  SELECT user_id INTO v_charity_user_id
  FROM public.charities
  WHERE id = NEW.charity_id;

  IF v_charity_user_id IS NOT NULL
     AND v_charity_user_id IS DISTINCT FROM NEW.donor_id THEN
    INSERT INTO public.notifications
      (user_id, title, body, type, reference_id, is_read, created_at)
    VALUES
      (v_charity_user_id, v_title, v_body, 'system', NEW.id, false, now());
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_direct_charity_status_notifications
  ON public.charity_donation_requests;
CREATE TRIGGER trg_direct_charity_status_notifications
  AFTER INSERT OR UPDATE OF status ON public.charity_donation_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.create_direct_charity_status_notifications();
