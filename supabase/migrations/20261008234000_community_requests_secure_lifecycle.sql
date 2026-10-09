BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.community_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL REFERENCES public.community_offers(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  charity_id uuid REFERENCES public.charities(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'ready_for_pickup', 'completed')),
  message text,
  price_snapshot numeric(12, 2) NOT NULL DEFAULT 0,
  pickup_location_snapshot text,
  charity_notes text,
  pickup_scheduled_at timestamptz,
  pickup_token_hash text,
  pickup_token_expires_at timestamptz,
  pickup_token_used_at timestamptz,
  requested_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS community_requests_requester_idx
  ON public.community_requests (requester_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS community_requests_owner_idx
  ON public.community_requests (owner_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS community_requests_charity_idx
  ON public.community_requests (charity_id, requested_at DESC)
  WHERE charity_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS community_requests_active_pickup_token_hash_idx
  ON public.community_requests (pickup_token_hash)
  WHERE pickup_token_hash IS NOT NULL AND pickup_token_used_at IS NULL;

ALTER TABLE public.community_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS community_requests_party_read ON public.community_requests;
CREATE POLICY community_requests_party_read
  ON public.community_requests FOR SELECT TO authenticated
  USING (
    requester_id = auth.uid()
    OR owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.charities c
      WHERE c.id = community_requests.charity_id
        AND c.user_id = auth.uid()
        AND c.status = 'active'
    )
  );

REVOKE ALL ON TABLE public.community_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.community_requests TO authenticated;

CREATE OR REPLACE FUNCTION public.community_create_request(
  p_offer_id uuid,
  p_message text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_offer public.community_offers%ROWTYPE;
  v_request public.community_requests%ROWTYPE;
BEGIN
  IF v_user_id IS NULL OR p_offer_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول واختيار العرض';
  END IF;

  SELECT * INTO v_offer
  FROM public.community_offers
  WHERE id = p_offer_id
  FOR UPDATE;

  IF NOT FOUND OR v_offer.status <> 'available'
     OR (v_offer.expires_at IS NOT NULL AND v_offer.expires_at <= now()) THEN
    RAISE EXCEPTION 'العرض غير متاح حاليًا';
  END IF;
  IF v_offer.owner_id = v_user_id THEN
    RAISE EXCEPTION 'لا يمكنك طلب عرضك الخاص';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.community_requests r
    WHERE r.offer_id = p_offer_id
      AND r.requester_id = v_user_id
      AND r.status IN ('pending', 'accepted', 'ready_for_pickup')
  ) THEN
    RAISE EXCEPTION 'لديك بالفعل طلب نشط على هذا العرض';
  END IF;

  INSERT INTO public.community_requests (
    offer_id, requester_id, owner_id, charity_id, status, message,
    price_snapshot, pickup_location_snapshot
  ) VALUES (
    p_offer_id, v_user_id, v_offer.owner_id, v_offer.charity_id, 'pending',
    nullif(btrim(p_message), ''), coalesce(v_offer.price, 0), v_offer.pickup_location
  )
  RETURNING * INTO v_request;

  RETURN jsonb_build_object(
    'id', v_request.id,
    'offer_id', v_request.offer_id,
    'requester_id', v_request.requester_id,
    'owner_id', v_request.owner_id,
    'charity_id', v_request.charity_id,
    'status', v_request.status,
    'message', v_request.message,
    'price_snapshot', v_request.price_snapshot,
    'pickup_location_snapshot', v_request.pickup_location_snapshot,
    'requested_at', v_request.requested_at,
    'updated_at', v_request.updated_at,
    'offer_title', v_offer.title
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.community_update_request_status(
  p_request_id uuid,
  p_next_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_request public.community_requests%ROWTYPE;
  v_offer_title text;
  v_is_owner boolean;
  v_is_requester boolean;
BEGIN
  IF v_user_id IS NULL OR p_request_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  IF coalesce(p_next_status, '') NOT IN ('accepted', 'rejected', 'cancelled', 'ready_for_pickup') THEN
    RAISE EXCEPTION 'حالة الطلب غير مسموحة لهذا المسار';
  END IF;

  SELECT * INTO v_request
  FROM public.community_requests
  WHERE id = p_request_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'الطلب غير موجود'; END IF;

  v_is_owner := v_request.owner_id = v_user_id;
  v_is_requester := v_request.requester_id = v_user_id;

  IF p_next_status IN ('accepted', 'rejected') THEN
    IF NOT v_is_owner OR v_request.status <> 'pending' THEN
      RAISE EXCEPTION 'فقط صاحب العرض يستطيع قبول أو رفض طلب معلق';
    END IF;
  ELSIF p_next_status = 'ready_for_pickup' THEN
    IF NOT v_is_owner OR v_request.status <> 'accepted' THEN
      RAISE EXCEPTION 'فقط صاحب العرض يستطيع تجهيز طلب مقبول';
    END IF;
  ELSIF p_next_status = 'cancelled' THEN
    IF NOT v_is_requester OR v_request.status NOT IN ('pending', 'accepted') THEN
      RAISE EXCEPTION 'لا يمكنك إلغاء هذا الطلب في حالته الحالية';
    END IF;
  END IF;

  UPDATE public.community_requests
  SET status = p_next_status,
      accepted_at = CASE WHEN p_next_status = 'accepted' THEN now() ELSE accepted_at END,
      updated_at = now(),
      pickup_token_hash = CASE WHEN p_next_status <> 'ready_for_pickup' THEN NULL ELSE pickup_token_hash END,
      pickup_token_expires_at = CASE WHEN p_next_status <> 'ready_for_pickup' THEN NULL ELSE pickup_token_expires_at END,
      pickup_token_used_at = CASE WHEN p_next_status <> 'ready_for_pickup' THEN NULL ELSE pickup_token_used_at END
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  SELECT o.title INTO v_offer_title
  FROM public.community_offers o
  WHERE o.id = v_request.offer_id;

  RETURN jsonb_build_object(
    'id', v_request.id,
    'requester_id', v_request.requester_id,
    'owner_id', v_request.owner_id,
    'offer_id', v_request.offer_id,
    'status', v_request.status,
    'offer_title', v_offer_title
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.community_generate_pickup_token(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text;
  v_expires timestamptz := now() + interval '15 minutes';
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'الطلب غير موجود'; END IF;

  v_token := encode(gen_random_bytes(24), 'hex');

  UPDATE public.community_requests
  SET pickup_token_hash = encode(digest(v_token, 'sha256'), 'hex'),
      pickup_token_expires_at = v_expires,
      pickup_token_used_at = NULL,
      updated_at = now()
  WHERE id = p_request_id
    AND requester_id = v_user_id
    AND status = 'ready_for_pickup';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الطلب غير موجود أو لم يتم تجهيزه للاستلام';
  END IF;

  RETURN jsonb_build_object('token', v_token, 'expires_at', v_expires);
END;
$function$;

CREATE OR REPLACE FUNCTION public.community_complete_by_pickup_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_request public.community_requests%ROWTYPE;
  v_now timestamptz := now();
  v_hash text;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  IF coalesce(btrim(p_token), '') = '' THEN RAISE EXCEPTION 'رمز الاستلام غير صحيح'; END IF;
  v_hash := encode(digest(btrim(p_token), 'sha256'), 'hex');

  SELECT * INTO v_request
  FROM public.community_requests
  WHERE pickup_token_hash = v_hash
    AND owner_id = v_user_id
    AND status = 'ready_for_pickup'
    AND pickup_token_used_at IS NULL
    AND pickup_token_expires_at > v_now
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'رمز الاستلام غير صحيح أو منتهي أو غير مخصص لحسابك';
  END IF;

  UPDATE public.community_requests
  SET status = 'completed',
      completed_at = v_now,
      pickup_token_used_at = v_now,
      updated_at = v_now
  WHERE id = v_request.id
    AND status = 'ready_for_pickup'
    AND pickup_token_used_at IS NULL;

  IF NOT FOUND THEN RAISE EXCEPTION 'تم استخدام الرمز من جهاز آخر'; END IF;

  RETURN jsonb_build_object('success', true, 'request_id', v_request.id, 'status', 'completed');
END;
$function$;

REVOKE ALL ON FUNCTION public.community_create_request(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.community_update_request_status(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.community_generate_pickup_token(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.community_complete_by_pickup_token(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.community_create_request(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_update_request_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_generate_pickup_token(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.community_complete_by_pickup_token(text) TO authenticated;

COMMIT;
