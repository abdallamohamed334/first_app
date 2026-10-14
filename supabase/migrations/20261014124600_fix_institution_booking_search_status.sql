BEGIN;

-- Institution records are approved after review; the legacy RPCs checked for
-- the obsolete 'active' status and therefore rejected every current institution.
CREATE OR REPLACE FUNCTION public.find_booking_by_code(p_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking RECORD;
  v_institution_id UUID;
  v_offer_institution_id UUID;
BEGIN
  SELECT id INTO v_institution_id
  FROM public.institutions
  WHERE user_id = auth.uid()
    AND status = 'approved';

  IF v_institution_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'غير مصرح لك بالبحث عن الحجوزات',
      'code', 'UNAUTHORIZED'
    );
  END IF;

  SELECT
    r.id,
    r.offer_id,
    r.requester_id,
    r.quantity,
    r.status,
    r.booking_code,
    r.created_at,
    r.updated_at,
    json_build_object(
      'id', o.id,
      'title', o.title,
      'description', o.description,
      'category', o.category,
      'quantity', o.quantity,
      'symbolic_price', o.symbolic_price,
      'original_price', o.original_price,
      'images', o.images,
      'status', o.status,
      'expires_at', o.expires_at,
      'pickup_location', o.pickup_location,
      'institution_id', o.institution_id
    ) AS offer,
    json_build_object(
      'id', u.id,
      'name', u.name,
      'phone', u.phone,
      'email', u.email,
      'avatar_url', u.avatar_url,
      'city', u.city
    ) AS requester
  INTO v_booking
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  JOIN public.users u ON u.id = r.requester_id
  WHERE r.booking_code = p_code;

  IF v_booking IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'لا يوجد حجز بهذا الكود',
      'code', 'NOT_FOUND'
    );
  END IF;

  v_offer_institution_id := (v_booking.offer->>'institution_id')::UUID;

  IF v_offer_institution_id != v_institution_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'هذا الحجز لا يخص مؤسستك',
      'code', 'NOT_OWNER'
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'id', v_booking.id,
    'offer_id', v_booking.offer_id,
    'requester_id', v_booking.requester_id,
    'quantity', v_booking.quantity,
    'status', v_booking.status,
    'booking_code', v_booking.booking_code,
    'created_at', v_booking.created_at,
    'updated_at', v_booking.updated_at,
    'offer', v_booking.offer,
    'requester', v_booking.requester,
    'institution_id', v_institution_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.find_booking_by_id(p_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking RECORD;
  v_institution_id UUID;
  v_offer_institution_id UUID;
BEGIN
  SELECT id INTO v_institution_id
  FROM public.institutions
  WHERE user_id = auth.uid()
    AND status = 'approved';

  IF v_institution_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'غير مصرح لك بالبحث عن الحجوزات'
    );
  END IF;

  SELECT
    r.id,
    r.offer_id,
    r.requester_id,
    r.quantity,
    r.status,
    r.booking_code,
    r.created_at,
    r.updated_at,
    json_build_object(
      'id', o.id,
      'title', o.title,
      'description', o.description,
      'category', o.category,
      'quantity', o.quantity,
      'symbolic_price', o.symbolic_price,
      'original_price', o.original_price,
      'images', o.images,
      'status', o.status,
      'expires_at', o.expires_at,
      'pickup_location', o.pickup_location,
      'institution_id', o.institution_id
    ) AS offer,
    json_build_object(
      'id', u.id,
      'name', u.name,
      'phone', u.phone,
      'email', u.email,
      'avatar_url', u.avatar_url,
      'city', u.city
    ) AS requester
  INTO v_booking
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  JOIN public.users u ON u.id = r.requester_id
  WHERE r.id = p_request_id;

  IF v_booking IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'الحجز غير موجود'
    );
  END IF;

  v_offer_institution_id := (v_booking.offer->>'institution_id')::UUID;

  IF v_offer_institution_id != v_institution_id THEN
    RETURN json_build_object(
      'success', false,
      'error', 'هذا الحجز لا يخص مؤسستك'
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'id', v_booking.id,
    'offer_id', v_booking.offer_id,
    'requester_id', v_booking.requester_id,
    'quantity', v_booking.quantity,
    'status', v_booking.status,
    'booking_code', v_booking.booking_code,
    'created_at', v_booking.created_at,
    'updated_at', v_booking.updated_at,
    'offer', v_booking.offer,
    'requester', v_booking.requester,
    'institution_id', v_institution_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.find_booking_by_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_booking_by_code(text) TO authenticated;
REVOKE ALL ON FUNCTION public.find_booking_by_id(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_booking_by_id(uuid) TO authenticated;

COMMIT;
