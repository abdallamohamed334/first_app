BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Generate a single-use QR token only for the authenticated owner of the
-- booking. The raw token is returned once; only its SHA-256 digest is stored.
CREATE OR REPLACE FUNCTION public.generate_food_offer_pickup_token(
  p_request_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, extensions, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_request public.offer_requests%ROWTYPE;
  v_token text;
BEGIN
  IF v_user_id IS NULL OR p_request_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_request
  FROM public.offer_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_request.user_id <> v_user_id
     OR v_request.restaurant_id IS NULL
     OR v_request.status <> 'ready_for_pickup' THEN
    RETURN NULL;
  END IF;

  v_token := 'LQ-' || upper(replace(gen_random_uuid()::text, '-', ''));

  UPDATE public.offer_requests
  SET pickup_token_hash = encode(digest(v_token, 'sha256'), 'hex'),
      pickup_token = NULL,
      pickup_token_expires_at = now() + interval '5 minutes',
      pickup_token_used_at = NULL,
      updated_at = now()
  WHERE id = p_request_id
    AND user_id = v_user_id
    AND restaurant_id = v_request.restaurant_id
    AND status = 'ready_for_pickup';

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN v_token;
END;
$function$;

REVOKE ALL ON FUNCTION public.generate_food_offer_pickup_token(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_food_offer_pickup_token(uuid)
  TO authenticated;

-- The old verifier was callable by any authenticated user and delegated to a
-- service-role-only SECURITY DEFINER routine without checking restaurant owner.
CREATE OR REPLACE FUNCTION public.verify_pickup_token(
  p_token text,
  p_restaurant_id uuid
)
RETURNS TABLE(
  success boolean,
  request_id uuid,
  user_id uuid,
  offer_id uuid,
  points_earned integer,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, extensions, pg_temp
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN QUERY SELECT false, NULL::uuid, NULL::uuid, NULL::uuid, 0,
      'يجب تسجيل الدخول أولًا'::text;
    RETURN;
  END IF;

  IF p_restaurant_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.restaurants r
    WHERE r.id = p_restaurant_id
      AND r.user_id = auth.uid()
      AND r.status = 'active'
  ) THEN
    RETURN QUERY SELECT false, NULL::uuid, NULL::uuid, NULL::uuid, 0,
      'غير مصرح لك بتأكيد استلام هذا الطلب'::text;
    RETURN;
  END IF;

  v_result := public.complete_pickup_by_qr(
    trim(coalesce(p_token, '')),
    p_restaurant_id
  );

  RETURN QUERY SELECT
    coalesce((v_result->>'success')::boolean, false),
    NULLIF(v_result->>'request_id', '')::uuid,
    NULLIF(v_result->>'user_id', '')::uuid,
    NULLIF(v_result->>'offer_id', '')::uuid,
    coalesce(NULLIF(v_result->>'user_points_added', '')::integer, 0),
    coalesce(v_result->>'message', 'تعذر التحقق من رمز الاستلام');
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_pickup_token(text, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_pickup_token(text, uuid)
  TO authenticated, service_role;

COMMIT;
