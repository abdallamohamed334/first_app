-- Keep offer/request transitions atomic. A failed inventory transition rolls
-- back the request status change in the same database transaction.
CREATE OR REPLACE FUNCTION public.update_food_offer_request_status(
  p_request_id uuid,
  p_next_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  r public.offer_requests%ROWTYPE;
  business_owner_id uuid;
  next_status text := lower(trim(coalesce(p_next_status, '')));
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول أولًا';
  END IF;

  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'معرف طلب الحجز غير صالح';
  END IF;

  IF next_status NOT IN ('accepted', 'rejected', 'ready_for_pickup', 'cancelled') THEN
    RAISE EXCEPTION 'حالة الحجز غير مسموحة: %', p_next_status;
  END IF;

  SELECT *
  INTO r
  FROM public.offer_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'طلب الحجز غير موجود';
  END IF;

  SELECT b.user_id
  INTO business_owner_id
  FROM public.food_offers f
  JOIN public.businesses b ON b.id = f.business_id
  WHERE f.id = r.offer_id;

  IF next_status = 'cancelled' THEN
    IF r.user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'لا تملك صلاحية إلغاء هذا الطلب';
    END IF;

    IF r.status NOT IN ('pending', 'accepted') THEN
      RAISE EXCEPTION 'لا يمكن إلغاء الطلب من الحالة الحالية: %', r.status;
    END IF;

    IF r.status = 'accepted' THEN
      UPDATE public.food_offers
      SET status = 'available',
          reserved_by = NULL,
          reserved_at = NULL,
          is_paused = false,
          paused_at = NULL,
          paused_reason = NULL,
          updated_at = now()
      WHERE id = r.offer_id
        AND status = 'reserved'
        AND reserved_by = r.user_id;
    END IF;
  ELSE
    IF business_owner_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'لا تملك صلاحية تغيير حالة هذا الطلب';
    END IF;

    IF r.status = 'pending'
       AND next_status IN ('accepted', 'rejected') THEN
      NULL;
    ELSIF r.status = 'accepted'
       AND next_status = 'ready_for_pickup' THEN
      NULL;
    ELSE
      RAISE EXCEPTION 'لا يمكن الانتقال من % إلى %', r.status, next_status;
    END IF;

    IF next_status = 'accepted' THEN
      UPDATE public.food_offers
      SET status = 'reserved',
          reserved_by = r.user_id,
          reserved_at = now(),
          is_paused = true,
          paused_at = now(),
          paused_reason = 'تم قبول طلب استلام',
          updated_at = now()
      WHERE id = r.offer_id
        AND status = 'available'
        AND (expiry_time IS NULL OR expiry_time > now());

      IF NOT FOUND THEN
        RAISE EXCEPTION 'العرض لم يعد متاحًا أو انتهت صلاحيته';
      END IF;
    END IF;
  END IF;

  UPDATE public.offer_requests
  SET status = next_status,
      updated_at = now(),
      notified_at = CASE
        WHEN next_status = 'accepted' THEN now()
        ELSE notified_at
      END
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'status', next_status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.update_food_offer_request_status(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_food_offer_request_status(uuid, text)
  TO authenticated;
