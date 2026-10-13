-- Close the legacy overload that could still request an independent volunteer.
REVOKE ALL ON FUNCTION public.charity_accept_donation(uuid, text)
  FROM PUBLIC, anon, authenticated;

-- Remove the historical app-user volunteer branch from the active transition.
CREATE OR REPLACE FUNCTION public.volunteer_mark_in_transit(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_charity_vol_id uuid;
  v_updated public.charity_donation_requests%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT id INTO v_charity_vol_id
  FROM public.charity_volunteers
  WHERE user_id = v_user_id
    AND status = 'active'
  LIMIT 1;

  UPDATE public.charity_donation_requests
  SET status = 'in_transit', updated_at = now()
  WHERE id = p_request_id
    AND status = 'picked_up_from_donor'
    AND (
      (charity_volunteer_id = v_charity_vol_id AND volunteer_type = 'charity_volunteer')
      OR (volunteer_type = 'external' AND EXISTS (
        SELECT 1 FROM public.charities c
        WHERE c.id = charity_donation_requests.charity_id
          AND c.user_id = v_user_id
          AND c.status = 'active'
      ))
    )
  RETURNING * INTO v_updated;

  IF v_updated.id IS NULL THEN
    RAISE EXCEPTION 'لا يمكن تحديث الحالة';
  END IF;

  RETURN jsonb_build_object('success', true, 'status', 'in_transit');
END;
$function$;

-- The charity must be owned by the current authenticated charity account;
-- p_charity_id is only an optional consistency check, never an authority grant.
CREATE OR REPLACE FUNCTION public.confirm_charity_delivery_with_code(
  p_request_id uuid,
  p_code text,
  p_charity_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_code text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  IF p_code IS NULL OR length(btrim(p_code)) = 0 OR length(btrim(p_code)) > 32 THEN
    RAISE EXCEPTION 'يرجى إدخال كود التسليم';
  END IF;

  SELECT r.charity_pickup_code INTO v_stored_code
  FROM public.charity_donation_requests r
  JOIN public.charities c ON c.id = r.charity_id
  WHERE r.id = p_request_id
    AND r.status = 'in_transit'
    AND r.deleted_at IS NULL
    AND r.charity_pickup_code_expires_at > now()
    AND (p_charity_id IS NULL OR r.charity_id = p_charity_id)
    AND c.user_id = v_user_id
    AND c.status = 'active'
  FOR UPDATE;

  IF NOT FOUND OR v_stored_code IS NULL THEN
    RAISE EXCEPTION 'لا يمكن تأكيد وصول هذا التبرع';
  END IF;
  IF btrim(v_stored_code) <> btrim(p_code) THEN
    RAISE EXCEPTION 'كود التسليم غير صحيح';
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'completed',
      completed_at = now(),
      charity_received_at = now(),
      updated_at = now()
  WHERE id = p_request_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.volunteer_mark_in_transit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_charity_delivery_with_code(uuid, text, uuid) TO authenticated;
