-- Enforce the 30-minute pickup-code lifetime at verification time.
-- A successful verification consumes the plaintext legacy code.

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
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً');
  END IF;

  SELECT o.institution_id, r.status, r.pickup_code, r.pickup_code_generated_at
  INTO v_institution_id, v_current_status, v_stored_code, v_generated_at
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id
      AND user_id = v_user_id
      AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;

  IF v_current_status <> 'ready_for_pickup' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'لا يمكن التحقق من كود استلام لطلب في حالة ' || v_current_status
    );
  END IF;

  IF v_stored_code IS NULL OR v_stored_code = '' THEN
    RETURN json_build_object('success', false, 'message', 'لم يتم إنشاء كود استلام لهذا الطلب');
  END IF;

  IF v_generated_at IS NULL OR now() >= v_generated_at + interval '30 minutes' THEN
    RETURN json_build_object('success', false, 'message', 'انتهت صلاحية كود الاستلام');
  END IF;

  IF p_code IS NULL OR p_code <> v_stored_code THEN
    RETURN json_build_object('success', false, 'message', '❌ كود الاستلام غير صحيح');
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'picked_up',
      pickup_code = NULL,
      updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object(
    'success', true,
    'message', '✅ تم تأكيد استلام الطلب بنجاح',
    'status', 'picked_up'
  );
END;
$function$;
