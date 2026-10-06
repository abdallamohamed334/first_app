-- Harden the user <-> institution offer-request lifecycle.
-- Every transition locks the request row, validates the current status, and
-- records its server-side timestamp. Pickup-code generation is user-owned;
-- the institution can only read and verify the existing code.

CREATE OR REPLACE FUNCTION public.institution_update_offer_request(
  p_request_id uuid,
  p_accept boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_offer_id uuid;
  v_current_status text;
  v_booking_code text;
  v_quantity integer;
BEGIN
  SELECT o.institution_id, r.offer_id, r.status, r.booking_code, r.quantity
  INTO v_institution_id, v_offer_id, v_current_status, v_booking_code, v_quantity
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_current_status <> 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تحديث طلب في حالة ' || v_current_status);
  END IF;

  UPDATE public.institution_offer_requests
  SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
      accepted_at = CASE WHEN p_accept THEN COALESCE(accepted_at, now()) ELSE accepted_at END,
      updated_at = now()
  WHERE id = p_request_id;

  IF NOT p_accept THEN
    UPDATE public.institution_offers
    SET remaining_quantity = remaining_quantity + v_quantity,
        reserved_quantity = GREATEST(0, reserved_quantity - v_quantity),
        updated_at = now()
    WHERE id = v_offer_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN p_accept THEN 'تم قبول الطلب' ELSE 'تم رفض الطلب' END,
    'status', CASE WHEN p_accept THEN 'accepted' ELSE 'rejected' END,
    'booking_code', v_booking_code
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.institution_mark_offer_request_ready(
  p_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_current_status text;
BEGIN
  SELECT o.institution_id, r.status
  INTO v_institution_id, v_current_status
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_current_status <> 'accepted' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تجهيز طلب في حالة ' || v_current_status);
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'ready_for_pickup', ready_at = now(), updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object('success', true, 'message', 'تم تجهيز الطلب للاستلام', 'status', 'ready_for_pickup');
END;
$function$;

CREATE OR REPLACE FUNCTION public.user_generate_pickup_code(
  p_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_existing_code text;
  v_generated_at timestamptz;
  v_new_code text;
  v_requester_id uuid;
  v_request_status text;
  v_code_validity interval := interval '30 minutes';
  v_is_expired boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'يجب تسجيل الدخول أولًا', 'is_new', false);
  END IF;

  SELECT pickup_code, pickup_code_generated_at, requester_id, status
  INTO v_existing_code, v_generated_at, v_requester_id, v_request_status
  FROM public.institution_offer_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود', 'is_new', false);
  END IF;
  IF v_requester_id <> auth.uid() THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بالوصول لهذا الطلب', 'is_new', false);
  END IF;
  IF v_request_status <> 'ready_for_pickup' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن إنشاء كود استلام في هذه الحالة', 'is_new', false);
  END IF;

  v_is_expired := v_generated_at IS NULL OR now() - v_generated_at >= v_code_validity;
  IF v_existing_code IS NOT NULL AND v_existing_code <> '' AND NOT v_is_expired THEN
    RETURN json_build_object(
      'success', true,
      'message', 'كود الاستلام الحالي',
      'pickup_code', v_existing_code,
      'is_new', false,
      'expires_in_seconds', EXTRACT(EPOCH FROM (v_code_validity - (now() - v_generated_at)))::integer
    );
  END IF;

  v_new_code := lpad(floor(random() * 1000000)::text, 6, '0');
  UPDATE public.institution_offer_requests
  SET pickup_code = v_new_code, pickup_code_generated_at = now(), updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN v_is_expired AND v_existing_code IS NOT NULL THEN 'انتهت صلاحية الكود السابق، تم إنشاء كود جديد' ELSE 'تم إنشاء كود الاستلام بنجاح' END,
    'pickup_code', v_new_code,
    'is_new', true,
    'expires_in_seconds', EXTRACT(EPOCH FROM v_code_validity)::integer
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.institution_generate_offer_request_pickup_code(
  p_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_current_status text;
  v_pickup_code text;
  v_generated_at timestamptz;
BEGIN
  SELECT o.institution_id, r.status, r.pickup_code, r.pickup_code_generated_at
  INTO v_institution_id, v_current_status, v_pickup_code, v_generated_at
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_current_status <> 'ready_for_pickup' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن قراءة كود استلام لطلب في حالة ' || v_current_status);
  END IF;
  IF v_pickup_code IS NULL OR v_pickup_code = '' THEN
    RETURN json_build_object('success', false, 'message', 'لم ينشئ المستخدم كود الاستلام بعد');
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'تم استرجاع كود الاستلام الحالي',
    'pickup_code', v_pickup_code,
    'pickup_code_generated_at', v_generated_at
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.institution_verify_offer_request_pickup_code(
  p_request_id uuid,
  p_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_current_status text;
  v_stored_code text;
  v_generated_at timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'يجب تسجيل الدخول أولًا');
  END IF;

  SELECT o.institution_id, r.status, r.pickup_code, r.pickup_code_generated_at
  INTO v_institution_id, v_current_status, v_stored_code, v_generated_at
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_current_status <> 'ready_for_pickup' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن التحقق من كود استلام لطلب في حالة ' || v_current_status);
  END IF;
  IF v_stored_code IS NULL OR v_stored_code = '' THEN
    RETURN json_build_object('success', false, 'message', 'لم يتم إنشاء كود استلام لهذا الطلب');
  END IF;
  IF v_generated_at IS NULL OR now() >= v_generated_at + interval '30 minutes' THEN
    RETURN json_build_object('success', false, 'message', 'انتهت صلاحية كود الاستلام');
  END IF;
  IF p_code IS NULL OR p_code <> v_stored_code THEN
    RETURN json_build_object('success', false, 'message', 'كود الاستلام غير صحيح');
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'picked_up', picked_up_at = now(), pickup_code = NULL, updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object('success', true, 'message', 'تم تأكيد استلام الطلب بنجاح', 'status', 'picked_up');
END;
$function$;

CREATE OR REPLACE FUNCTION public.institution_complete_offer_request(
  p_request_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_current_status text;
BEGIN
  SELECT o.institution_id, r.status
  INTO v_institution_id, v_current_status
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_current_status <> 'picked_up' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن إكمال الطلب قبل تأكيد الاستلام');
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'completed', completed_at = now(), updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object('success', true, 'message', 'تم إكمال الطلب بنجاح', 'status', 'completed');
END;
$function$;
