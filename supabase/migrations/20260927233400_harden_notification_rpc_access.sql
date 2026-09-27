-- Notification delivery is backend-only; prevent client roles from invoking it directly.
REVOKE EXECUTE ON FUNCTION public.send_push_notification(uuid, text, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_push_notification(uuid, text, text)
TO service_role;

-- Only the restaurant owning the booking may create its status notification.
CREATE OR REPLACE FUNCTION public.notify_booking_response(
  p_request_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid;
  v_offer_id uuid;
  v_restaurant_id uuid;
  v_title text;
  v_body text;
  v_type text;
BEGIN
  SELECT user_id, offer_id, restaurant_id
  INTO v_user_id, v_offer_id, v_restaurant_id
  FROM public.offer_requests
  WHERE id = p_request_id;

  IF v_user_id IS NULL OR v_offer_id IS NULL OR v_restaurant_id IS NULL THEN
    RAISE EXCEPTION 'Booking request not found';
  END IF;

  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.restaurants
    WHERE id = v_restaurant_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not authorized to notify this booking';
  END IF;

  IF p_status = 'accepted' THEN
    v_title := 'تم قبول طلبك';
    v_body := 'وافق المطعم على طلب حجز العرض. يمكنك متابعة تفاصيل الاستلام.';
    v_type := 'booking_accepted';
  ELSIF p_status = 'cancelled' THEN
    v_title := 'تم رفض طلبك';
    v_body := 'نعتذر، لم يوافق المطعم على طلب حجز العرض.';
    v_type := 'booking_rejected';
  ELSIF p_status = 'ready_for_pickup' THEN
    v_title := 'الطلب جاهز للاستلام';
    v_body := 'جهّز المطعم طلبك. يمكنك التوجه للاستلام واستخدام رمز الاستلام.';
    v_type := 'booking_ready_for_pickup';
  ELSIF p_status = 'completed' THEN
    v_title := 'تم إكمال الاستلام';
    v_body := 'تم تسجيل استلام عرض الطعام بنجاح.';
    v_type := 'booking_completed';
  ELSE
    RAISE EXCEPTION 'Unsupported booking status: %', p_status;
  END IF;

  INSERT INTO public.notifications (
    user_id, title, body, type, reference_id, reference_type, is_read, created_at
  ) VALUES (
    v_user_id, v_title, v_body, v_type, v_offer_id, 'food_offer', false, now()
  );
END;
$function$;
