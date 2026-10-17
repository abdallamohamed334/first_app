BEGIN;

ALTER TABLE public.institution_offers
  ADD COLUMN IF NOT EXISTS is_bookable boolean NOT NULL DEFAULT true;

GRANT SELECT (is_bookable)
  ON public.institution_offers TO anon, authenticated;

COMMENT ON COLUMN public.institution_offers.is_bookable IS
  'When false, the offer is view-only and cannot receive customer booking requests.';

CREATE OR REPLACE FUNCTION public.create_institution_offer_v3(
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
  p_max_booking_quantity integer DEFAULT NULL,
  p_is_bookable boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_offer_id uuid;
  v_is_bookable boolean := COALESCE(p_is_bookable, true);
BEGIN
  v_offer_id := public.create_institution_offer_v2(
    p_institution_id => p_institution_id,
    p_title => p_title,
    p_description => p_description,
    p_category => p_category,
    p_quantity => p_quantity,
    p_original_price => p_original_price,
    p_symbolic_price => p_symbolic_price,
    p_images => p_images,
    p_pickup_location => p_pickup_location,
    p_expires_at => p_expires_at,
    p_pickup_start => p_pickup_start,
    p_pickup_end => p_pickup_end,
    p_food_type => p_food_type,
    p_is_halal => p_is_halal,
    p_is_vegetarian => p_is_vegetarian,
    p_food_condition => p_food_condition,
    p_requires_refrigeration => p_requires_refrigeration,
    p_pickup_notes => p_pickup_notes,
    p_contact_phone => p_contact_phone,
    p_pickup_time => p_pickup_time,
    p_storage_condition => p_storage_condition,
    p_product_subcategory => p_product_subcategory,
    p_meat_cut => p_meat_cut,
    p_product_weight => p_product_weight,
    p_product_prepared_at => p_product_prepared_at,
    p_product_expiry_at => p_product_expiry_at,
    p_min_booking_quantity => CASE
      WHEN v_is_bookable THEN p_min_booking_quantity
      ELSE 1
    END,
    p_max_booking_quantity => CASE
      WHEN v_is_bookable THEN p_max_booking_quantity
      ELSE NULL
    END
  );

  UPDATE public.institution_offers
  SET is_bookable = v_is_bookable
  WHERE id = v_offer_id;

  RETURN v_offer_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_institution_offer_v3(
  uuid, text, text, text, integer, numeric, numeric, text[], text,
  timestamptz, timestamptz, timestamptz, text, boolean, boolean, text,
  boolean, text, text, text, text, text, text, numeric, date, timestamptz,
  integer, integer, boolean
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_institution_offer_v3(
  uuid, text, text, text, integer, numeric, numeric, text[], text,
  timestamptz, timestamptz, timestamptz, text, boolean, boolean, text,
  boolean, text, text, text, text, text, text, numeric, date, timestamptz,
  integer, integer, boolean
) TO authenticated;

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
         o.min_booking_quantity, o.max_booking_quantity, o.is_bookable
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
  IF v_offer.is_bookable IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'هذا العرض للمشاهدة فقط ولا يقبل الحجز');
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

CREATE OR REPLACE FUNCTION public.reject_non_bookable_institution_offer_request()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.institution_offers o
    WHERE o.id = NEW.offer_id
      AND o.is_bookable IS TRUE
      AND o.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'هذا العرض للمشاهدة فقط ولا يقبل الحجز';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.reject_non_bookable_institution_offer_request() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_reject_non_bookable_institution_offer_request
  ON public.institution_offer_requests;
CREATE TRIGGER trg_reject_non_bookable_institution_offer_request
  BEFORE INSERT ON public.institution_offer_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.reject_non_bookable_institution_offer_request();

DROP FUNCTION IF EXISTS public.get_nearby_institution_offers(double precision, double precision, integer);
CREATE FUNCTION public.get_nearby_institution_offers(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters integer
)
RETURNS TABLE (
  id uuid,
  institution_id uuid,
  institution_name text,
  institution_type text,
  institution_is_verified boolean,
  title text,
  description text,
  category text,
  quantity integer,
  remaining_quantity integer,
  original_price numeric,
  symbolic_price numeric,
  images text[],
  pickup_location text,
  expires_at timestamptz,
  pickup_before timestamptz,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  food_type text,
  is_halal boolean,
  is_vegetarian boolean,
  food_condition text,
  requires_refrigeration boolean,
  pickup_notes text,
  contact_phone text,
  pickup_time text,
  pickup_start timestamptz,
  pickup_end timestamptz,
  is_bookable boolean,
  distance_meters double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_location geography(Point, 4326);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude < -90 OR p_latitude > 90
     OR p_longitude < -180 OR p_longitude > 180 THEN
    RAISE EXCEPTION 'Invalid latitude/longitude';
  END IF;
  IF p_radius_meters IS NULL OR p_radius_meters <= 0 OR p_radius_meters > 50000 THEN
    RAISE EXCEPTION 'Radius must be between 1 and 50000 meters';
  END IF;

  v_user_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
  RETURN QUERY
  SELECT o.id, o.institution_id, i.name, i.institution_type, i.is_verified,
         o.title, o.description, o.category, o.quantity, o.remaining_quantity,
         o.original_price, o.symbolic_price, o.images, o.pickup_location,
         o.expires_at, o.pickup_before, o.status, o.created_at, o.updated_at,
         o.food_type, o.is_halal, o.is_vegetarian, o.food_condition,
         o.requires_refrigeration, o.pickup_notes, o.contact_phone,
         o.pickup_time, o.pickup_start, o.pickup_end, o.is_bookable,
         ST_Distance(i.location, v_user_location)
  FROM public.institution_offers o
  JOIN public.institutions i ON i.id = o.institution_id
  WHERE o.status = 'active'
    AND o.deleted_at IS NULL
    AND o.remaining_quantity > 0
    AND o.expires_at > now()
    AND i.status = 'approved'
    AND i.location IS NOT NULL
    AND ST_DWithin(i.location, v_user_location, p_radius_meters)
  ORDER BY ST_Distance(i.location, v_user_location), o.created_at DESC
  LIMIT 100;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_nearby_institution_offers(double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nearby_institution_offers(double precision, double precision, integer) TO authenticated;

DROP FUNCTION IF EXISTS public.get_all_institution_offers(double precision, double precision, integer, integer);
CREATE FUNCTION public.get_all_institution_offers(
  p_latitude double precision,
  p_longitude double precision,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  institution_id uuid,
  institution_name text,
  institution_type text,
  institution_is_verified boolean,
  title text,
  description text,
  category text,
  quantity integer,
  remaining_quantity integer,
  original_price numeric,
  symbolic_price numeric,
  images text[],
  pickup_location text,
  expires_at timestamptz,
  pickup_before timestamptz,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  food_type text,
  is_halal boolean,
  is_vegetarian boolean,
  food_condition text,
  requires_refrigeration boolean,
  pickup_notes text,
  contact_phone text,
  pickup_time text,
  pickup_start timestamptz,
  pickup_end timestamptz,
  is_bookable boolean,
  distance_meters double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_user_location geography(Point, 4326);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_latitude IS NULL OR p_longitude IS NULL
     OR p_latitude < -90 OR p_latitude > 90
     OR p_longitude < -180 OR p_longitude > 180 THEN
    RAISE EXCEPTION 'Latitude and longitude are required';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'Limit must be between 1 and 100';
  END IF;
  IF p_offset IS NULL OR p_offset < 0 THEN
    RAISE EXCEPTION 'Offset cannot be negative';
  END IF;

  v_user_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
  RETURN QUERY
  SELECT o.id, o.institution_id, i.name, i.institution_type, i.is_verified,
         o.title, o.description, o.category, o.quantity, o.remaining_quantity,
         o.original_price, o.symbolic_price, o.images, o.pickup_location,
         o.expires_at, o.pickup_before, o.status, o.created_at, o.updated_at,
         o.food_type, o.is_halal, o.is_vegetarian, o.food_condition,
         o.requires_refrigeration, o.pickup_notes, o.contact_phone,
         o.pickup_time, o.pickup_start, o.pickup_end, o.is_bookable,
         CASE WHEN i.location IS NOT NULL
              THEN ST_Distance(i.location, v_user_location)
              ELSE NULL
         END AS distance_meters
  FROM public.institution_offers o
  INNER JOIN public.institutions i ON i.id = o.institution_id
  WHERE o.status = 'active'
    AND o.deleted_at IS NULL
    AND o.remaining_quantity > 0
    AND o.expires_at > now()
    AND i.status = 'approved'
  ORDER BY distance_meters NULLS LAST, o.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_all_institution_offers(double precision, double precision, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_all_institution_offers(double precision, double precision, integer, integer) TO authenticated;

COMMIT;
