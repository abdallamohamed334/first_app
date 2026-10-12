-- Close inventory leaks and unsafe offer edits in the institution-offer lifecycle.
BEGIN;

CREATE OR REPLACE FUNCTION public.cancel_institution_offer(p_offer_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_institution_id uuid;
  v_status text;
  v_restore integer := 0;
BEGIN
  SELECT institution_id, status
    INTO v_institution_id, v_status
  FROM public.institution_offers
  WHERE id = p_offer_id AND deleted_at IS NULL
  FOR UPDATE;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'العرض غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بإلغاء هذا العرض');
  END IF;
  IF v_status = 'cancelled' THEN
    RETURN json_build_object('success', true, 'message', 'العرض ملغي بالفعل');
  END IF;

  SELECT COALESCE(SUM(quantity), 0)::integer
    INTO v_restore
  FROM public.institution_offer_requests
  WHERE offer_id = p_offer_id
    AND status IN ('pending', 'accepted', 'ready_for_pickup');

  UPDATE public.institution_offer_requests
  SET status = 'cancelled', updated_at = now()
  WHERE offer_id = p_offer_id
    AND status IN ('pending', 'accepted', 'ready_for_pickup');

  UPDATE public.institution_offers
  SET status = 'cancelled',
      deleted_at = now(),
      remaining_quantity = LEAST(quantity, remaining_quantity + v_restore),
      reserved_quantity = GREATEST(0, reserved_quantity - v_restore),
      updated_at = now()
  WHERE id = p_offer_id;

  RETURN json_build_object(
    'success', true,
    'message', 'تم إلغاء العرض وجميع الطلبات المعلقة',
    'status', 'cancelled',
    'released_quantity', v_restore
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.institution_verify_offer_request_pickup_code(
  p_request_id uuid,
  p_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_institution_id uuid;
  v_offer_id uuid;
  v_quantity integer;
  v_status text;
  v_stored_code text;
  v_generated_at timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'يجب تسجيل الدخول أولًا');
  END IF;

  SELECT o.institution_id, r.offer_id, r.quantity, r.status,
         r.pickup_code, r.pickup_code_generated_at
    INTO v_institution_id, v_offer_id, v_quantity, v_status,
         v_stored_code, v_generated_at
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id
  FOR UPDATE OF r, o;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;
  IF v_status <> 'ready_for_pickup' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن التحقق من كود استلام لطلب في حالة ' || v_status);
  END IF;
  IF v_stored_code IS NULL OR v_stored_code = '' THEN
    RETURN json_build_object('success', false, 'message', 'لم يتم إنشاء كود استلام لهذا الطلب');
  END IF;
  IF v_generated_at IS NULL OR now() >= v_generated_at + interval '30 minutes' THEN
    RETURN json_build_object('success', false, 'message', 'انتهت صلاحية كود الاستلام');
  END IF;
  IF p_code IS NULL OR p_code <> v_stored_code THEN
    RETURN json_build_object('success', false, 'message', 'كود الاستلام غير صحيح');
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'picked_up', picked_up_at = now(), pickup_code = NULL, updated_at = now()
  WHERE id = p_request_id;

  -- The stock is no longer reserved after physical pickup.
  UPDATE public.institution_offers
  SET reserved_quantity = GREATEST(0, reserved_quantity - v_quantity),
      updated_at = now()
  WHERE id = v_offer_id;

  RETURN json_build_object('success', true, 'message', 'تم تأكيد استلام الطلب بنجاح', 'status', 'picked_up');
END;
$$;

CREATE OR REPLACE FUNCTION public.update_institution_offer(
  p_offer_id uuid,
  p_title text,
  p_description text,
  p_category text,
  p_quantity integer,
  p_remaining_quantity integer,
  p_symbolic_price numeric,
  p_original_price numeric,
  p_images text[],
  p_pickup_location text,
  p_expires_at timestamptz,
  p_pickup_end timestamptz,
  p_status text,
  p_food_type text,
  p_is_halal boolean,
  p_is_vegetarian boolean,
  p_food_condition text,
  p_requires_refrigeration boolean,
  p_pickup_notes text,
  p_contact_phone text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_offer public.institution_offers%rowtype;
  v_new_quantity integer;
  v_new_remaining integer;
  v_new_symbolic numeric;
  v_new_original numeric;
  v_has_active_requests boolean;
BEGIN
  SELECT * INTO v_offer
  FROM public.institution_offers
  WHERE id = p_offer_id AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'العرض غير موجود');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_offer.institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتعديل هذا العرض');
  END IF;
  IF v_offer.status IN ('expired', 'cancelled') THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تعديل عرض ' || v_offer.status);
  END IF;
  IF p_status = 'cancelled' THEN
    RETURN json_build_object('success', false, 'message', 'استخدم مسار إلغاء العرض المخصص');
  END IF;

  v_new_quantity := COALESCE(p_quantity, v_offer.quantity);
  v_new_symbolic := COALESCE(p_symbolic_price, v_offer.symbolic_price);
  v_new_original := COALESCE(p_original_price, v_offer.original_price);
  v_has_active_requests := EXISTS (
    SELECT 1 FROM public.institution_offer_requests
    WHERE offer_id = p_offer_id
      AND status IN ('pending', 'accepted', 'ready_for_pickup')
  );

  IF v_new_quantity <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'الكمية يجب أن تكون أكبر من صفر');
  END IF;
  IF v_new_symbolic < 0 OR (v_new_original IS NOT NULL AND v_new_original < 0)
     OR (v_new_original IS NOT NULL AND v_new_symbolic > v_new_original) THEN
    RETURN json_build_object('success', false, 'message', 'السعر الرمزي لا يمكن أن يكون أكبر من السعر الأصلي');
  END IF;
  IF v_has_active_requests AND p_quantity IS NOT NULL AND p_quantity <> v_offer.quantity THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تغيير الكمية لأن هناك طلبات نشطة على هذا العرض');
  END IF;
  IF v_has_active_requests AND p_symbolic_price IS NOT NULL AND p_symbolic_price <> v_offer.symbolic_price THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تغيير السعر لأن هناك طلبات نشطة على هذا العرض');
  END IF;
  IF p_expires_at IS NOT NULL AND p_expires_at <= now() THEN
    RETURN json_build_object('success', false, 'message', 'صلاحية العرض يجب أن تكون في المستقبل');
  END IF;
  IF p_pickup_end IS NOT NULL AND p_pickup_end > COALESCE(p_expires_at, v_offer.expires_at) THEN
    RETURN json_build_object('success', false, 'message', 'وقت الاستلام لا يمكن أن يتجاوز صلاحية العرض');
  END IF;
  IF p_status = 'active' AND COALESCE(p_expires_at, v_offer.expires_at) <= now() THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن تشغيل عرض منتهي الصلاحية');
  END IF;

  IF p_remaining_quantity IS NOT NULL THEN
    IF p_remaining_quantity < 0 OR p_remaining_quantity > v_new_quantity - v_offer.reserved_quantity THEN
      RETURN json_build_object('success', false, 'message', 'الكمية المتاحة غير متوافقة مع الكمية المحجوزة');
    END IF;
    v_new_remaining := p_remaining_quantity;
  ELSIF p_quantity IS NOT NULL AND p_quantity <> v_offer.quantity THEN
    IF v_new_quantity < v_offer.reserved_quantity THEN
      RETURN json_build_object('success', false, 'message', 'الكمية الجديدة أقل من الكمية المحجوزة');
    END IF;
    v_new_remaining := v_new_quantity - v_offer.reserved_quantity;
  ELSE
    v_new_remaining := v_offer.remaining_quantity;
  END IF;

  UPDATE public.institution_offers
  SET title = COALESCE(p_title, title),
      description = COALESCE(p_description, description),
      category = COALESCE(p_category, category),
      quantity = v_new_quantity,
      remaining_quantity = v_new_remaining,
      symbolic_price = v_new_symbolic,
      original_price = v_new_original,
      images = COALESCE(p_images, images),
      pickup_location = COALESCE(p_pickup_location, pickup_location),
      expires_at = COALESCE(p_expires_at, expires_at),
      pickup_end = COALESCE(p_pickup_end, pickup_end),
      status = CASE
        WHEN p_status IS NOT NULL THEN p_status
        WHEN v_new_remaining = 0 THEN 'sold_out'
        WHEN status = 'sold_out' AND v_new_remaining > 0 THEN 'active'
        ELSE status
      END,
      food_type = COALESCE(p_food_type, food_type),
      is_halal = COALESCE(p_is_halal, is_halal),
      is_vegetarian = COALESCE(p_is_vegetarian, is_vegetarian),
      food_condition = COALESCE(p_food_condition, food_condition),
      requires_refrigeration = COALESCE(p_requires_refrigeration, requires_refrigeration),
      pickup_notes = COALESCE(p_pickup_notes, pickup_notes),
      contact_phone = COALESCE(p_contact_phone, contact_phone),
      updated_at = now()
  WHERE id = p_offer_id;

  RETURN json_build_object('success', true, 'message', 'تم تحديث العرض بنجاح', 'has_requests', v_has_active_requests);
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_institution_offer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_institution_offer(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.institution_verify_offer_request_pickup_code(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.institution_verify_offer_request_pickup_code(uuid, text) TO authenticated;
REVOKE ALL ON FUNCTION public.update_institution_offer(uuid, text, text, text, integer, integer, numeric, numeric, text[], text, timestamptz, timestamptz, text, text, boolean, boolean, text, boolean, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_institution_offer(uuid, text, text, text, integer, integer, numeric, numeric, text[], text, timestamptz, timestamptz, text, text, boolean, boolean, text, boolean, text, text) TO authenticated;

COMMIT;
