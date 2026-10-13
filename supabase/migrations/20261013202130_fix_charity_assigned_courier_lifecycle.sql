-- Keep independent volunteers disabled while allowing the charity-appointed
-- courier (internal charity volunteer or external courier managed by the charity)
-- to complete the donor pickup and charity delivery lifecycle.

CREATE OR REPLACE FUNCTION public.volunteer_confirm_pickup_with_code(
  p_request_id uuid,
  p_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_donation public.charity_donation_requests%ROWTYPE;
  v_authorized boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول');
  END IF;

  SELECT * INTO v_donation
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'التبرع غير موجود');
  END IF;

  -- Internal courier: the courier account is linked to the charity volunteer.
  IF v_donation.volunteer_type = 'charity_volunteer'
     AND v_donation.charity_volunteer_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.charity_volunteers cv
      WHERE cv.id = v_donation.charity_volunteer_id
        AND cv.user_id = auth.uid()
        AND cv.status = 'active'
    ) INTO v_authorized;
  END IF;

  -- External courier: the charity owner is the operator of this handoff.
  IF NOT v_authorized AND v_donation.volunteer_type = 'external' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.charities c
      WHERE c.id = v_donation.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    ) INTO v_authorized;
  END IF;

  IF NOT v_authorized THEN
    RETURN jsonb_build_object('success', false, 'error', 'هذا التبرع غير مسند إلى حسابك');
  END IF;

  IF v_donation.status NOT IN ('volunteer_assigned', 'ready_for_pickup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تأكيد الاستلام من الحالة الحالية');
  END IF;

  IF v_donation.donor_pickup_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ينتظر التبرع تأكيد جاهزية المتبرع');
  END IF;

  IF v_donation.pickup_token_expires_at IS NOT NULL
     AND v_donation.pickup_token_expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'انتهت صلاحية كود الاستلام');
  END IF;

  IF (v_donation.pickup_token_hash IS NOT NULL
      AND v_donation.pickup_token_hash <> md5(btrim(COALESCE(p_code, ''))))
     OR (v_donation.pickup_token_hash IS NULL
         AND v_donation.pickup_token IS DISTINCT FROM btrim(COALESCE(p_code, ''))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الاستلام غير صحيح');
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'picked_up_from_donor',
      donor_pickup_confirmed_at = COALESCE(donor_pickup_confirmed_at, now()),
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'status', 'picked_up_from_donor', 'error', null);
END;
$function$;

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
  v_authorized boolean := false;
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
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'التبرع غير موجود');
  END IF;

  IF v_request.volunteer_type = 'charity_volunteer'
     AND v_request.charity_volunteer_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.charity_volunteers cv
      WHERE cv.id = v_request.charity_volunteer_id
        AND cv.user_id = auth.uid()
        AND cv.status = 'active'
    ) INTO v_authorized;
  END IF;

  IF NOT v_authorized AND v_request.volunteer_type = 'external' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = v_request.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    ) INTO v_authorized;
  END IF;

  IF NOT v_authorized THEN
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
      'success', true, 'status', 'in_transit',
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

CREATE OR REPLACE FUNCTION public.volunteer_deliver_to_charity(
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_request public.charity_donation_requests%ROWTYPE;
  v_authorized boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'التبرع غير موجود';
  END IF;

  IF v_request.volunteer_type = 'charity_volunteer'
     AND v_request.charity_volunteer_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.charity_volunteers cv
      WHERE cv.id = v_request.charity_volunteer_id
        AND cv.user_id = auth.uid()
        AND cv.status = 'active'
    ) INTO v_authorized;
  END IF;

  IF NOT v_authorized AND v_request.volunteer_type = 'external' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = v_request.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    ) INTO v_authorized;
  END IF;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'هذا التبرع غير مسند إلى حسابك';
  END IF;
  IF v_request.status <> 'in_transit' THEN
    RAISE EXCEPTION 'لا يمكن تأكيد التسليم من الحالة الحالية';
  END IF;
  IF v_request.charity_pickup_code IS NULL
     OR v_request.charity_pickup_code_expires_at <= now() THEN
    RAISE EXCEPTION 'كود تسليم الجمعية غير متاح أو منتهي';
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'completed',
      charity_received_at = now(),
      completed_at = now(),
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'status', 'completed');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.volunteer_confirm_pickup_with_code(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.volunteer_generate_charity_code(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.volunteer_deliver_to_charity(uuid) TO authenticated;
