BEGIN;

ALTER TABLE public.institution_offers
  ADD COLUMN IF NOT EXISTS product_expiry_at timestamptz,
  ADD COLUMN IF NOT EXISTS storage_condition text NOT NULL DEFAULT 'no_cooling',
  ADD COLUMN IF NOT EXISTS product_subcategory text,
  ADD COLUMN IF NOT EXISTS meat_cut text,
  ADD COLUMN IF NOT EXISTS product_weight numeric(10,3),
  ADD COLUMN IF NOT EXISTS product_prepared_at date,
  ADD COLUMN IF NOT EXISTS min_booking_quantity integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS max_booking_quantity integer;

UPDATE public.institution_offers
SET storage_condition = CASE
  WHEN requires_refrigeration IS TRUE THEN 'needs_refrigeration'
  ELSE 'no_cooling'
END
WHERE storage_condition IS NULL OR storage_condition = 'no_cooling';

ALTER TABLE public.institution_offers
  ADD CONSTRAINT institution_offers_storage_condition_check
    CHECK (storage_condition IN ('needs_refrigeration', 'needs_freezing', 'no_cooling')),
  ADD CONSTRAINT institution_offers_min_booking_quantity_check
    CHECK (min_booking_quantity >= 1 AND min_booking_quantity <= quantity),
  ADD CONSTRAINT institution_offers_max_booking_quantity_check
    CHECK (max_booking_quantity IS NULL OR
      (max_booking_quantity >= min_booking_quantity AND max_booking_quantity <= quantity)),
  ADD CONSTRAINT institution_offers_product_weight_check
    CHECK (product_weight IS NULL OR product_weight > 0);

GRANT SELECT (
  product_expiry_at,
  storage_condition,
  product_subcategory,
  meat_cut,
  product_weight,
  product_prepared_at,
  min_booking_quantity,
  max_booking_quantity
) ON public.institution_offers TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_institution_offer_v2(
  p_institution_id uuid,
  p_title text,
  p_description text DEFAULT NULL,
  p_category text DEFAULT 'other',
  p_quantity integer DEFAULT 1,
  p_original_price numeric DEFAULT NULL,
  p_symbolic_price numeric DEFAULT 0,
  p_images text[] DEFAULT '{}',
  p_pickup_location text DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_pickup_start timestamptz DEFAULT NULL,
  p_pickup_end timestamptz DEFAULT NULL,
  p_food_type text DEFAULT 'وجبات',
  p_is_halal boolean DEFAULT true,
  p_is_vegetarian boolean DEFAULT false,
  p_food_condition text DEFAULT 'good',
  p_requires_refrigeration boolean DEFAULT false,
  p_pickup_notes text DEFAULT NULL,
  p_contact_phone text DEFAULT NULL,
  p_pickup_time text DEFAULT NULL,
  p_storage_condition text DEFAULT 'no_cooling',
  p_product_subcategory text DEFAULT NULL,
  p_meat_cut text DEFAULT NULL,
  p_product_weight numeric DEFAULT NULL,
  p_product_prepared_at date DEFAULT NULL,
  p_product_expiry_at timestamptz DEFAULT NULL,
  p_min_booking_quantity integer DEFAULT 1,
  p_max_booking_quantity integer DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_offer_id uuid;
  v_requires_refrigeration boolean;
BEGIN
  IF p_storage_condition NOT IN ('needs_refrigeration', 'needs_freezing', 'no_cooling') THEN
    RAISE EXCEPTION 'Invalid storage condition';
  END IF;
  IF p_min_booking_quantity IS NULL OR p_min_booking_quantity < 1
     OR p_min_booking_quantity > p_quantity THEN
    RAISE EXCEPTION 'Minimum booking quantity must be between 1 and total quantity';
  END IF;
  IF p_max_booking_quantity IS NOT NULL AND
     (p_max_booking_quantity < p_min_booking_quantity OR p_max_booking_quantity > p_quantity) THEN
    RAISE EXCEPTION 'Maximum booking quantity must be between minimum and total quantity';
  END IF;
  IF p_product_expiry_at IS NOT NULL AND p_product_expiry_at <= now() THEN
    RAISE EXCEPTION 'Product expiration date must be in the future';
  END IF;
  IF p_product_weight IS NOT NULL AND p_product_weight <= 0 THEN
    RAISE EXCEPTION 'Product weight must be greater than zero';
  END IF;

  v_requires_refrigeration := p_storage_condition IN ('needs_refrigeration', 'needs_freezing');
  v_offer_id := public.create_institution_offer(
    p_institution_id, p_title, p_description, p_category, p_quantity,
    p_original_price, p_symbolic_price, p_images, p_pickup_location,
    p_expires_at, p_pickup_start, p_pickup_end, p_food_type, p_is_halal,
    p_is_vegetarian, p_food_condition, v_requires_refrigeration,
    p_pickup_notes, p_contact_phone, p_pickup_time
  );

  UPDATE public.institution_offers
  SET storage_condition = p_storage_condition,
      product_subcategory = nullif(trim(p_product_subcategory), ''),
      meat_cut = nullif(trim(p_meat_cut), ''),
      product_weight = p_product_weight,
      product_prepared_at = p_product_prepared_at,
      product_expiry_at = p_product_expiry_at,
      min_booking_quantity = p_min_booking_quantity,
      max_booking_quantity = p_max_booking_quantity
  WHERE id = v_offer_id;

  RETURN v_offer_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_institution_offer_v2(uuid,text,text,text,integer,numeric,numeric,text[],text,timestamptz,timestamptz,timestamptz,text,boolean,boolean,text,boolean,text,text,text,text,text,text,numeric,date,timestamptz,integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_institution_offer_v2(uuid,text,text,text,integer,numeric,numeric,text[],text,timestamptz,timestamptz,timestamptz,text,boolean,boolean,text,boolean,text,text,text,text,text,text,numeric,date,timestamptz,integer,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.reserve_institution_offer_safe(
  p_offer_id uuid,
  p_requester_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_offer RECORD;
  v_offer_institution_id uuid;
  v_request_id uuid;
  v_booking_code text;
BEGIN
  IF auth.uid() IS NULL OR p_requester_id IS DISTINCT FROM auth.uid() THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح بإنشاء الطلب');
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'الكمية المطلوبة غير صحيحة');
  END IF;
  SELECT o.id, o.institution_id, o.quantity, o.remaining_quantity,
         o.reserved_quantity, o.status, o.expires_at, o.deleted_at,
         o.min_booking_quantity, o.max_booking_quantity
  INTO v_offer
  FROM public.institution_offers o
  WHERE o.id = p_offer_id AND o.status = 'active' AND o.deleted_at IS NULL
  FOR UPDATE;
  IF v_offer IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'العرض غير موجود أو غير نشط');
  END IF;
  IF v_offer.expires_at < now() THEN
    RETURN json_build_object('success', false, 'message', 'انتهت صلاحية العرض');
  END IF;
  IF p_quantity < v_offer.min_booking_quantity THEN
    RETURN json_build_object('success', false, 'message', 'الحد الأدنى للحجز هو ' || v_offer.min_booking_quantity);
  END IF;
  IF v_offer.max_booking_quantity IS NOT NULL AND p_quantity > v_offer.max_booking_quantity THEN
    RETURN json_build_object('success', false, 'message', 'الحد الأقصى للحجز هو ' || v_offer.max_booking_quantity);
  END IF;
  IF v_offer.remaining_quantity < p_quantity THEN
    RETURN json_build_object('success', false, 'message', 'الكمية المطلوبة غير متاحة');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.institution_offer_requests r
    WHERE r.offer_id = p_offer_id
      AND r.requester_id = auth.uid()
      AND r.status IN ('pending', 'accepted', 'ready_for_pickup')
  ) THEN
    RETURN json_build_object('success', false, 'message', 'لديك طلب نشط بالفعل على هذا العرض');
  END IF;
  v_offer_institution_id := v_offer.institution_id;
  IF EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_offer_institution_id AND user_id = auth.uid()
  ) THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكنك طلب عرضك الخاص');
  END IF;
  v_booking_code := public.generate_booking_code();
  INSERT INTO public.institution_offer_requests
    (offer_id, requester_id, quantity, status, booking_code, created_at, updated_at)
  VALUES (p_offer_id, auth.uid(), p_quantity, 'pending', v_booking_code, now(), now())
  RETURNING id INTO v_request_id;
  UPDATE public.institution_offers
  SET remaining_quantity = remaining_quantity - p_quantity,
      reserved_quantity = reserved_quantity + p_quantity,
      updated_at = now()
  WHERE id = p_offer_id;
  RETURN json_build_object(
    'success', true,
    'message', 'تم إنشاء طلب العرض بنجاح',
    'request_id', v_request_id,
    'booking_code', v_booking_code
  );
END;
$function$;

COMMIT;
