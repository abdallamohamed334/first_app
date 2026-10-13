-- Generate the code the assigned independent volunteer presents to the charity.
-- This is intentionally a single atomic transition: picked_up_from_donor -> in_transit.
CREATE OR REPLACE FUNCTION public.volunteer_generate_charity_code(
  p_request_id uuid,
  p_expires_in_hours integer DEFAULT 12
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_request public.charity_donation_requests%ROWTYPE;
  v_code text;
  v_expiry timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول');
  END IF;

  IF p_expires_in_hours IS NULL OR p_expires_in_hours < 1 OR p_expires_in_hours > 72 THEN
    RETURN jsonb_build_object('success', false, 'error', 'مدة صلاحية الكود غير صحيحة');
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND deleted_at IS NULL
    AND volunteer_id = auth.uid()
    AND volunteer_type = 'app_user'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'هذا التبرع غير مسند إلى حسابك');
  END IF;

  IF v_request.status NOT IN ('picked_up_from_donor', 'in_transit') THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إنشاء كود التسليم من الحالة الحالية');
  END IF;

  IF v_request.donor_pickup_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'لم يتم تأكيد استلام التبرع من المتبرع');
  END IF;

  IF v_request.status = 'in_transit'
     AND v_request.charity_pickup_code IS NOT NULL
     AND v_request.charity_pickup_code_expires_at > now() THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', 'in_transit',
      'charity_code', v_request.charity_pickup_code,
      'expires_at', v_request.charity_pickup_code_expires_at,
      'already_generated', true
    );
  END IF;

  v_code := lpad((floor(random() * 1000000))::bigint::text, 6, '0');
  v_expiry := now() + make_interval(hours => p_expires_in_hours);

  UPDATE public.charity_donation_requests
  SET charity_pickup_code = v_code,
      charity_pickup_code_expires_at = v_expiry,
      status = 'in_transit',
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'in_transit',
    'charity_code', v_code,
    'expires_at', v_expiry,
    'already_generated', false
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.volunteer_generate_charity_code(uuid, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.volunteer_generate_charity_code(uuid, integer)
  TO authenticated;
