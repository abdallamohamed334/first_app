BEGIN;

-- Remove broad table grants and any column grants from browser roles.
REVOKE ALL PRIVILEGES ON TABLE public.charity_donation_requests FROM anon, authenticated;
REVOKE SELECT (
  id, donor_id, charity_id, title, description, category, quantity, condition,
  images, pickup_address, donor_phone, donor_notes, charity_notes, status,
  pickup_scheduled_at, pickup_token_hash, pickup_token_expires_at, accepted_at,
  completed_at, created_at, updated_at, volunteer_type, volunteer_id,
  volunteer_name, volunteer_phone, donor_pickup_confirmed_at, charity_received_at,
  assigned_at, pickup_token, charity_volunteer_id, deleted_at, rejection_reason,
  pickup_city, pickup_latitude, pickup_longitude, expires_at, charity_accepted_at,
  volunteer_accepted_at, open_to_independent_volunteers, delivery_type,
  volunteer_open_until, charity_pickup_code, charity_pickup_code_expires_at
) ON public.charity_donation_requests FROM anon, authenticated;
REVOKE INSERT (
  id, donor_id, charity_id, title, description, category, quantity, condition,
  images, pickup_address, donor_phone, donor_notes, charity_notes, status,
  pickup_scheduled_at, pickup_token_hash, pickup_token_expires_at, accepted_at,
  completed_at, created_at, updated_at, volunteer_type, volunteer_id,
  volunteer_name, volunteer_phone, donor_pickup_confirmed_at, charity_received_at,
  assigned_at, pickup_token, charity_volunteer_id, deleted_at, rejection_reason,
  pickup_city, pickup_latitude, pickup_longitude, expires_at, charity_accepted_at,
  volunteer_accepted_at, open_to_independent_volunteers, delivery_type,
  volunteer_open_until, charity_pickup_code, charity_pickup_code_expires_at
) ON public.charity_donation_requests FROM anon, authenticated;
REVOKE UPDATE (
  id, donor_id, charity_id, title, description, category, quantity, condition,
  images, pickup_address, donor_phone, donor_notes, charity_notes, status,
  pickup_scheduled_at, pickup_token_hash, pickup_token_expires_at, accepted_at,
  completed_at, created_at, updated_at, volunteer_type, volunteer_id,
  volunteer_name, volunteer_phone, donor_pickup_confirmed_at, charity_received_at,
  assigned_at, pickup_token, charity_volunteer_id, deleted_at, rejection_reason,
  pickup_city, pickup_latitude, pickup_longitude, expires_at, charity_accepted_at,
  volunteer_accepted_at, open_to_independent_volunteers, delivery_type,
  volunteer_open_until, charity_pickup_code, charity_pickup_code_expires_at
) ON public.charity_donation_requests FROM anon, authenticated;

-- Direct reads are limited to non-secret columns. RLS below restricts row access.
GRANT SELECT (
  id, donor_id, charity_id, title, description, category, quantity, condition,
  images, pickup_address, donor_phone, donor_notes, charity_notes, status,
  pickup_scheduled_at, pickup_token_expires_at, accepted_at, completed_at,
  created_at, updated_at, volunteer_type, volunteer_id, volunteer_name,
  volunteer_phone, donor_pickup_confirmed_at, charity_received_at, assigned_at,
  charity_volunteer_id, deleted_at, rejection_reason, pickup_city, pickup_latitude,
  pickup_longitude, expires_at, charity_accepted_at, volunteer_accepted_at,
  open_to_independent_volunteers, delivery_type, volunteer_open_until,
  charity_pickup_code_expires_at
) ON public.charity_donation_requests TO authenticated;

-- New donation rows receive their database-default 'pending' status; callers cannot
-- set status, assignment fields, timestamps, or any pickup secret at INSERT time.
GRANT INSERT (
  donor_id, charity_id, title, description, category, quantity, condition,
  images, pickup_address, donor_phone, donor_notes
) ON public.charity_donation_requests TO authenticated;

-- Notes remain directly editable only for the active charity owner via RLS.
GRANT UPDATE (charity_notes) ON public.charity_donation_requests TO authenticated;

-- Remove broad volunteer reads and broad direct row updates. Marketplace listings
-- are returned only through the sanitized, authenticated SECURITY DEFINER RPC below.
DROP POLICY IF EXISTS charity_donation_select_v2 ON public.charity_donation_requests;
DROP POLICY IF EXISTS volunteer_open_requests_authenticated ON public.charity_donation_requests;
DROP POLICY IF EXISTS charity_donation_update_v2 ON public.charity_donation_requests;
DROP POLICY IF EXISTS charity_donation_charity_notes_update ON public.charity_donation_requests;

CREATE POLICY charity_donation_charity_notes_update
  ON public.charity_donation_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = charity_donation_requests.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = charity_donation_requests.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    )
  );

CREATE OR REPLACE FUNCTION public.get_donor_donation_pickup_token(p_request_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_token text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT r.pickup_token INTO v_token
  FROM public.charity_donation_requests r
  WHERE r.id = p_request_id
    AND r.donor_id = auth.uid()
    AND r.deleted_at IS NULL
    AND r.status IN ('volunteer_assigned', 'donor_ready', 'picked_up_from_donor', 'in_transit')
    AND (r.status <> 'donor_ready' OR NULLIF(btrim(r.volunteer_name), '') IS NOT NULL)
    AND (r.pickup_token_expires_at IS NULL OR r.pickup_token_expires_at > now());

  IF v_token IS NULL OR v_token = '' THEN
    RAISE EXCEPTION 'كود الاستلام غير متاح لهذا التبرع';
  END IF;
  RETURN v_token;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_assigned_donation_pickup_token(p_request_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_token text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT r.pickup_token INTO v_token
  FROM public.charity_donation_requests r
  WHERE r.id = p_request_id
    AND r.volunteer_id = auth.uid()
    AND r.deleted_at IS NULL
    AND r.status IN ('volunteer_assigned', 'donor_ready', 'picked_up_from_donor', 'in_transit')
    AND (r.pickup_token_expires_at IS NULL OR r.pickup_token_expires_at > now());

  IF v_token IS NULL OR v_token = '' THEN
    RAISE EXCEPTION 'كود الاستلام غير متاح لهذا التبرع';
  END IF;
  RETURN v_token;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_charity_donation_pickup_code(p_request_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_code text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT r.charity_pickup_code INTO v_code
  FROM public.charity_donation_requests r
  WHERE r.id = p_request_id
    AND r.status = 'in_transit'
    AND r.deleted_at IS NULL
    AND r.charity_pickup_code IS NOT NULL
    AND (r.charity_pickup_code_expires_at IS NULL OR r.charity_pickup_code_expires_at > now())
    AND (
      r.volunteer_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.charities c
        WHERE c.id = r.charity_id
          AND c.user_id = auth.uid()
          AND c.status = 'active'
      )
    );

  IF v_code IS NULL OR v_code = '' THEN
    RAISE EXCEPTION 'كود التسليم غير متاح لهذا التبرع';
  END IF;
  RETURN v_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_charity_delivery_with_code(
  p_request_id uuid,
  p_code text,
  p_charity_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_stored_code text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  IF p_code IS NULL OR length(btrim(p_code)) = 0 OR length(btrim(p_code)) > 32 THEN
    RAISE EXCEPTION 'يرجى إدخال كود المتطوع';
  END IF;

  SELECT r.charity_pickup_code INTO v_stored_code
  FROM public.charity_donation_requests r
  WHERE r.id = p_request_id
    AND r.status = 'in_transit'
    AND r.deleted_at IS NULL
    AND r.charity_pickup_code_expires_at > now()
    AND (
      p_charity_id IS NULL OR r.charity_id = p_charity_id
    )
    AND EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = r.charity_id
        AND c.user_id = v_user_id
        AND c.status = 'active'
    )
  FOR UPDATE;

  IF NOT FOUND OR v_stored_code IS NULL THEN
    RAISE EXCEPTION 'لا يمكن تأكيد وصول هذا التبرع';
  END IF;
  IF btrim(v_stored_code) <> btrim(p_code) THEN
    RAISE EXCEPTION 'كود المتطوع غير صحيح';
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'completed',
      completed_at = now(),
      charity_received_at = now(),
      updated_at = now()
  WHERE id = p_request_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_donor_donation_pickup_token(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_donor_donation_pickup_token(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_assigned_donation_pickup_token(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_assigned_donation_pickup_token(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.get_charity_donation_pickup_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_charity_donation_pickup_code(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.confirm_charity_delivery_with_code(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_charity_delivery_with_code(uuid, text, uuid) TO authenticated;

-- There are two historical overloads. The UUID form returns donor contact details
-- and is not used by the app; remove browser-role execution. The text form is the
-- current app contract and no longer reveals donor identity or exact pickup point.
DO $revoke_legacy_overload$
BEGIN
  IF to_regprocedure('public.list_open_donations_for_volunteers(uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE EXECUTE ON FUNCTION public.list_open_donations_for_volunteers(uuid) FROM PUBLIC, anon, authenticated';
  END IF;
END;
$revoke_legacy_overload$;
CREATE OR REPLACE FUNCTION public.list_open_donations_for_volunteers(p_city text DEFAULT NULL::text)
RETURNS TABLE(
  id uuid, donor_id uuid, charity_id uuid, title text, description text,
  category text, quantity integer, condition text, images text[],
  pickup_address text, pickup_city text, pickup_latitude double precision,
  pickup_longitude double precision, status text, created_at timestamptz,
  expires_at timestamptz, charity_name text, charity_logo text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  RETURN QUERY
  SELECT r.id,
         NULL::uuid AS donor_id,
         r.charity_id,
         r.title,
         r.description,
         r.category,
         r.quantity,
         r.condition,
         r.images,
         NULL::text AS pickup_address,
         r.pickup_city,
         NULL::double precision AS pickup_latitude,
         NULL::double precision AS pickup_longitude,
         r.status,
         r.created_at,
         r.expires_at,
         c.name AS charity_name,
         c.logo AS charity_logo
  FROM public.charity_donation_requests r
  JOIN public.charities c ON c.id = r.charity_id
  WHERE r.status = 'volunteer_needed'
    AND r.delivery_type = 'independent_volunteer'
    AND r.open_to_independent_volunteers = true
    AND r.volunteer_id IS NULL
    AND r.deleted_at IS NULL
    AND (r.expires_at IS NULL OR r.expires_at > now())
    AND r.donor_id <> auth.uid()
    AND (p_city IS NULL OR r.pickup_city = p_city)
  ORDER BY r.created_at DESC
  LIMIT 100;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.list_open_donations_for_volunteers(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_open_donations_for_volunteers(text) TO authenticated;

COMMIT;
