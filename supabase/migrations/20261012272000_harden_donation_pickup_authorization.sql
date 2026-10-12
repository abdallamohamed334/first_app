-- Harden the donor-pickup confirmation RPC used by the volunteer flow.
-- The old function checked only request id and code; an authenticated user
-- who obtained both could confirm a pickup without being the assigned volunteer.
CREATE OR REPLACE FUNCTION public.confirm_pickup_from_donor(
  p_request_id uuid,
  p_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_request public.charity_donation_requests%ROWTYPE;
  v_user_id uuid := auth.uid();
  v_code text := btrim(coalesce(p_code, ''));
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول');
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND volunteer_id = v_user_id
    AND volunteer_type = 'app_user'
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'هذا التبرع غير مسند إلى حسابك');
  END IF;

  IF v_request.status <> 'volunteer_assigned' THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تأكيد الاستلام من الحالة الحالية');
  END IF;

  IF v_request.donor_pickup_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ينتظر التبرع تأكيد جاهزية المتبرع');
  END IF;

  IF v_request.pickup_token_expires_at IS NOT NULL
     AND v_request.pickup_token_expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'انتهت صلاحية كود الاستلام');
  END IF;

  IF v_code = ''
     OR (v_request.pickup_token_hash IS NOT NULL
         AND v_request.pickup_token_hash <> md5(v_code))
     OR (v_request.pickup_token_hash IS NULL
         AND v_request.pickup_token IS DISTINCT FROM v_code) THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الاستلام غير صحيح');
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'picked_up_from_donor',
      donor_pickup_confirmed_at = coalesce(donor_pickup_confirmed_at, now()),
      updated_at = now()
  WHERE id = p_request_id
    AND status = 'volunteer_assigned'
    AND volunteer_id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'تم تحديث التبرع من جهاز آخر');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'picked_up_from_donor',
    'error', null
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.confirm_pickup_from_donor(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_pickup_from_donor(uuid, text)
  TO authenticated;
