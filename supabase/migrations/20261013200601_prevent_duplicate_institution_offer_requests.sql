-- Prevent the same user from reserving the same institution offer more than once
-- while an earlier request is still active. The offer row is already locked,
-- so concurrent requests are serialized before this check.
CREATE OR REPLACE FUNCTION public.reserve_institution_offer_safe(
  p_offer_id uuid,
  p_requester_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_offer RECORD;
  v_offer_institution_id uuid;
  v_request_id uuid;
  v_booking_code text;
BEGIN
  IF auth.uid() IS NULL OR p_requester_id IS DISTINCT FROM auth.uid() THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح بإنشاء الطلب');
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'الكمية المطلوبة غير صحيحة');
  END IF;

  SELECT o.id, o.institution_id, o.quantity, o.remaining_quantity,
         o.reserved_quantity, o.status, o.expires_at, o.deleted_at
  INTO v_offer
  FROM public.institution_offers o
  WHERE o.id = p_offer_id
    AND o.status = 'active'
    AND o.deleted_at IS NULL
  FOR UPDATE;

  IF v_offer IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'العرض غير موجود أو غير نشط');
  END IF;

  IF v_offer.expires_at < now() THEN
    RETURN json_build_object('success', false, 'message', 'انتهت صلاحية العرض');
  END IF;

  IF v_offer.remaining_quantity < p_quantity THEN
    RETURN json_build_object('success', false, 'message', 'الكمية المطلوبة غير متاحة');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.institution_offer_requests r
    WHERE r.offer_id = p_offer_id
      AND r.requester_id = auth.uid()
      AND r.status IN ('pending', 'accepted', 'ready_for_pickup')
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'لديك طلب نشط بالفعل على هذا العرض'
    );
  END IF;

  v_offer_institution_id := v_offer.institution_id;
  IF EXISTS (
    SELECT 1
    FROM public.institutions
    WHERE id = v_offer_institution_id
      AND user_id = auth.uid()
  ) THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكنك طلب عرضك الخاص');
  END IF;

  v_booking_code := public.generate_booking_code();

  INSERT INTO public.institution_offer_requests (
    offer_id, requester_id, quantity, status, booking_code, created_at, updated_at
  ) VALUES (
    p_offer_id, auth.uid(), p_quantity, 'pending', v_booking_code, now(), now()
  )
  RETURNING id INTO v_request_id;

  UPDATE public.institution_offers
  SET remaining_quantity = remaining_quantity - p_quantity,
      reserved_quantity = reserved_quantity + p_quantity,
      updated_at = now()
  WHERE id = p_offer_id;

  RETURN json_build_object(
    'success', true,
    'message', 'تم إنشاء طلب العرض بنجاح',
    'request_id', v_request_id,
    'booking_code', v_booking_code
  );
END;
$function$;
