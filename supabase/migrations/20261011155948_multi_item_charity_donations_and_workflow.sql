-- Multi-item direct donations plus lifecycle fixes for both delivery paths.
-- Additive/backward-compatible: legacy clients that only submit category/quantity
-- are normalized into a one-item payload by the trigger below.

ALTER TABLE public.charity_donation_requests
  ADD COLUMN IF NOT EXISTS categories text[] NOT NULL DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS items jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Backfill legacy rows before installing constraints and normalization.
UPDATE public.charity_donation_requests
SET categories = ARRAY[category],
    items = jsonb_build_array(jsonb_build_object(
      'category', category,
      'quantity', quantity,
      'unit', 'وحدة',
      'condition', condition,
      'details', ''
    ))
WHERE COALESCE(cardinality(categories), 0) = 0
   OR jsonb_typeof(items) IS DISTINCT FROM 'array'
   OR jsonb_array_length(items) = 0;

ALTER TABLE public.charity_donation_requests
  DROP CONSTRAINT IF EXISTS charity_donation_requests_category_check,
  ADD CONSTRAINT charity_donation_requests_category_check
    CHECK (category = ANY (ARRAY[
      'food', 'clothing', 'furniture', 'electronics', 'books',
      'toys', 'household', 'hygiene', 'medical', 'other'
    ]::text[])),
  ADD CONSTRAINT charity_donation_requests_categories_check
    CHECK (cardinality(categories) BETWEEN 1 AND 10 AND categories <@ ARRAY[
      'food', 'clothing', 'furniture', 'electronics', 'books',
      'toys', 'household', 'hygiene', 'medical', 'other'
    ]::text[]),
  ADD CONSTRAINT charity_donation_requests_items_check
    CHECK (jsonb_typeof(items) = 'array' AND jsonb_array_length(items) BETWEEN 1 AND 10);

CREATE OR REPLACE FUNCTION public.normalize_charity_donation_items()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_item jsonb;
  v_category text;
  v_quantity integer;
  v_first_quantity integer;
  v_total bigint := 0;
  v_categories text[] := ARRAY[]::text[];
  v_condition text;
  v_allowed text[] := ARRAY[
    'food', 'clothing', 'furniture', 'electronics', 'books',
    'toys', 'household', 'hygiene', 'medical', 'other'
  ]::text[];
BEGIN
  IF NEW.items IS NULL
     OR jsonb_typeof(NEW.items) IS DISTINCT FROM 'array' THEN
    NEW.items := jsonb_build_array(jsonb_build_object(
      'category', NEW.category,
      'quantity', GREATEST(COALESCE(NEW.quantity, 1), 1),
      'unit', 'وحدة',
      'condition', COALESCE(NEW.condition, 'good'),
      'details', ''
    ));
  ELSIF jsonb_array_length(NEW.items) = 0 THEN
    NEW.items := jsonb_build_array(jsonb_build_object(
      'category', NEW.category,
      'quantity', GREATEST(COALESCE(NEW.quantity, 1), 1),
      'unit', 'وحدة',
      'condition', COALESCE(NEW.condition, 'good'),
      'details', ''
    ));
  END IF;

  IF jsonb_array_length(NEW.items) > 10 THEN
    RAISE EXCEPTION 'يمكن إضافة عشرة أصناف كحد أقصى';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(NEW.items) LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'بيانات الصنف غير صالحة';
    END IF;

    v_category := lower(btrim(COALESCE(v_item->>'category', '')));
    IF NOT (v_category = ANY(v_allowed)) THEN
      RAISE EXCEPTION 'تصنيف التبرع غير مدعوم: %', v_category;
    END IF;

    IF COALESCE(v_item->>'quantity', '') !~ '^[0-9]{1,9}$' THEN
      RAISE EXCEPTION 'أدخل كمية صحيحة لكل صنف';
    END IF;
    v_quantity := (v_item->>'quantity')::integer;
    IF v_quantity <= 0 THEN
      RAISE EXCEPTION 'كمية كل صنف يجب أن تكون أكبر من صفر';
    END IF;

    v_total := v_total + v_quantity;
    IF v_total > 2147483647 THEN
      RAISE EXCEPTION 'إجمالي الكمية أكبر من المسموح';
    END IF;

    IF cardinality(v_categories) = 0 THEN
      v_first_quantity := v_quantity;
    END IF;
    IF NOT (v_category = ANY(v_categories)) THEN
      v_categories := array_append(v_categories, v_category);
    END IF;
    IF v_condition IS NULL THEN
      v_condition := NULLIF(btrim(COALESCE(v_item->>'condition', '')), '');
    END IF;
  END LOOP;

  NEW.categories := v_categories;
  NEW.category := v_categories[1];
  -- The legacy scalar quantity matches the primary category. Per-item
  -- quantities/units remain authoritative in NEW.items.
  NEW.quantity := GREATEST(COALESCE(v_first_quantity, 1), 1);
  NEW.condition := COALESCE(v_condition, NEW.condition, 'good');
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS normalize_charity_donation_items
  ON public.charity_donation_requests;
CREATE TRIGGER normalize_charity_donation_items
BEFORE INSERT OR UPDATE OF category, quantity, condition, categories, items
ON public.charity_donation_requests
FOR EACH ROW EXECUTE FUNCTION public.normalize_charity_donation_items();

-- New client fields are granted explicitly; existing column-level grants remain intact.
GRANT SELECT (categories, items)
  ON public.charity_donation_requests TO authenticated;
GRANT INSERT (pickup_city, categories, items)
  ON public.charity_donation_requests TO authenticated;

COMMENT ON COLUMN public.charity_donation_requests.categories IS
  'All selected donation category slugs; kept in sync with items by trigger.';
COMMENT ON COLUMN public.charity_donation_requests.items IS
  'Per-category donation detail: quantity, unit, condition, details and optional food date.';

-- Assignment may happen before or after the donor confirms readiness.
-- Keep the request in accepted until ready; this permits either order safely.
CREATE OR REPLACE FUNCTION public.charity_assign_volunteer(
  p_request_id uuid,
  p_volunteer_id uuid DEFAULT NULL::uuid,
  p_external_name text DEFAULT NULL::text,
  p_external_phone text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_charity_id uuid;
  v_request public.charity_donation_requests%ROWTYPE;
  v_updated public.charity_donation_requests%ROWTYPE;
  v_vol_name text;
  v_vol_phone text;
  v_next_status text;
BEGIN
  SELECT id INTO v_charity_id
  FROM public.charities
  WHERE user_id = auth.uid() AND status = 'active'
  LIMIT 1;

  IF v_charity_id IS NULL THEN
    RAISE EXCEPTION 'لا توجد جمعية نشطة مرتبطة بالحساب';
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND charity_id = v_charity_id
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND OR v_request.status NOT IN ('accepted', 'donor_ready') THEN
    RAISE EXCEPTION 'لا يمكن تعيين مندوب في هذه المرحلة';
  END IF;
  IF v_request.assigned_at IS NOT NULL OR v_request.volunteer_type IS NOT NULL THEN
    RAISE EXCEPTION 'تم تعيين مندوب لهذا التبرع بالفعل';
  END IF;
  IF p_volunteer_id IS NULL
     AND (NULLIF(btrim(COALESCE(p_external_name, '')), '') IS NULL
          OR NULLIF(btrim(COALESCE(p_external_phone, '')), '') IS NULL) THEN
    RAISE EXCEPTION 'لازم تحدد مندوب من الجمعية أو مندوب خارجي';
  END IF;

  v_next_status := CASE
    WHEN v_request.status = 'donor_ready' THEN 'volunteer_assigned'
    ELSE 'accepted'
  END;

  IF p_volunteer_id IS NOT NULL THEN
    SELECT name, phone INTO v_vol_name, v_vol_phone
    FROM public.charity_volunteers
    WHERE id = p_volunteer_id
      AND charity_id = v_charity_id
      AND status = 'active';
    IF v_vol_name IS NULL THEN
      RAISE EXCEPTION 'المتطوع غير موجود أو غير نشط';
    END IF;

    UPDATE public.charity_donation_requests
    SET volunteer_type = 'charity_volunteer',
        charity_volunteer_id = p_volunteer_id,
        volunteer_id = NULL,
        volunteer_name = btrim(v_vol_name),
        volunteer_phone = btrim(COALESCE(v_vol_phone, '')),
        delivery_type = 'charity_volunteer',
        open_to_independent_volunteers = false,
        assigned_at = now(),
        status = v_next_status,
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_updated;
  ELSE
    UPDATE public.charity_donation_requests
    SET volunteer_type = 'external',
        volunteer_id = NULL,
        charity_volunteer_id = NULL,
        volunteer_name = btrim(p_external_name),
        volunteer_phone = btrim(p_external_phone),
        delivery_type = 'charity_volunteer',
        open_to_independent_volunteers = false,
        assigned_at = now(),
        status = v_next_status,
        updated_at = now()
    WHERE id = p_request_id
    RETURNING * INTO v_updated;
  END IF;

  IF v_updated.id IS NULL THEN
    RAISE EXCEPTION 'تعذر تعيين المندوب';
  END IF;
  RETURN jsonb_build_object(
    'success', true,
    'status', v_updated.status,
    'volunteer_type', v_updated.volunteer_type,
    'volunteer_name', v_updated.volunteer_name,
    'volunteer_phone', v_updated.volunteer_phone
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.charity_assign_volunteer(uuid, uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.charity_assign_volunteer(uuid, uuid, text, text)
  TO authenticated;

-- Donor readiness is idempotent, cannot hide independent-volunteer requests, and
-- completes correctly whether readiness or assignment comes first.
CREATE OR REPLACE FUNCTION public.mark_donor_ready(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_request public.charity_donation_requests%ROWTYPE;
  v_new_code text;
  v_next_status text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;

  SELECT * INTO v_request
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND donor_id = auth.uid()
    AND deleted_at IS NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'التبرع غير موجود أو لا يخص حسابك';
  END IF;

  IF v_request.status NOT IN (
    'accepted', 'volunteer_needed', 'volunteer_assigned', 'donor_ready'
  ) THEN
    RAISE EXCEPTION 'لا يمكن إعلان الجاهزية من الحالة: %', v_request.status;
  END IF;

  IF v_request.donor_pickup_confirmed_at IS NOT NULL
     AND NULLIF(btrim(COALESCE(v_request.pickup_token, '')), '') IS NOT NULL
     AND (v_request.pickup_token_expires_at IS NULL
          OR v_request.pickup_token_expires_at > now()) THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', v_request.status,
      'already_ready', true,
      'pickup_code', v_request.pickup_token
    );
  END IF;

  v_new_code := CASE
    WHEN NULLIF(btrim(COALESCE(v_request.pickup_token, '')), '') IS NOT NULL
      AND (v_request.pickup_token_expires_at IS NULL
           OR v_request.pickup_token_expires_at > now())
    THEN v_request.pickup_token
    ELSE lpad(floor(random() * 1000000)::text, 6, '0')
  END;

  v_next_status := CASE
    WHEN v_request.status = 'volunteer_needed' THEN 'volunteer_needed'
    WHEN v_request.status = 'volunteer_assigned' THEN 'volunteer_assigned'
    WHEN v_request.volunteer_type IS NOT NULL OR v_request.assigned_at IS NOT NULL
      THEN 'volunteer_assigned'
    ELSE 'donor_ready'
  END;

  UPDATE public.charity_donation_requests
  SET status = v_next_status,
      pickup_token = v_new_code,
      pickup_token_hash = md5(v_new_code),
      pickup_token_expires_at = COALESCE(
        CASE WHEN pickup_token_expires_at > now() THEN pickup_token_expires_at END,
        now() + interval '7 days'
      ),
      donor_pickup_confirmed_at = COALESCE(donor_pickup_confirmed_at, now()),
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_next_status,
    'already_ready', false,
    'pickup_code', v_new_code
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_donor_ready(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mark_donor_ready(uuid) TO authenticated;

-- The independent-volunteer pickup confirmation is restricted to the assigned
-- volunteer and the correct state/code/expiry (older RPC lacked these checks).
CREATE OR REPLACE FUNCTION public.volunteer_confirm_pickup_with_code(
  p_request_id uuid,
  p_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_donation public.charity_donation_requests%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول');
  END IF;

  SELECT * INTO v_donation
  FROM public.charity_donation_requests
  WHERE id = p_request_id
    AND volunteer_id = auth.uid()
    AND volunteer_type = 'app_user'
    AND deleted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'هذا التبرع غير مسند إلى حسابك');
  END IF;
  IF v_donation.status <> 'volunteer_assigned' THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تأكيد الاستلام من الحالة الحالية');
  END IF;
  IF v_donation.donor_pickup_confirmed_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ينتظر التبرع تأكيد جاهزية المتبرع');
  END IF;
  IF v_donation.pickup_token_expires_at IS NOT NULL
     AND v_donation.pickup_token_expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'انتهت صلاحية كود الاستلام');
  END IF;
  IF (v_donation.pickup_token_hash IS NOT NULL
      AND v_donation.pickup_token_hash <> md5(btrim(COALESCE(p_code, ''))))
     OR (v_donation.pickup_token_hash IS NULL
         AND v_donation.pickup_token IS DISTINCT FROM btrim(COALESCE(p_code, ''))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'كود الاستلام غير صحيح');
  END IF;

  UPDATE public.charity_donation_requests
  SET status = 'picked_up_from_donor',
      donor_pickup_confirmed_at = COALESCE(donor_pickup_confirmed_at, now()),
      updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true, 'status', 'picked_up_from_donor', 'error', null);
END;
$function$;

REVOKE ALL ON FUNCTION public.volunteer_confirm_pickup_with_code(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.volunteer_confirm_pickup_with_code(uuid, text)
  TO authenticated;

-- Adding item data to the anonymous-to-volunteers feed is safe; donor ID,
-- address and precise coordinates remain redacted exactly as before.
DROP FUNCTION IF EXISTS public.list_open_donations_for_volunteers(text);
CREATE FUNCTION public.list_open_donations_for_volunteers(p_city text DEFAULT NULL::text)
RETURNS TABLE(
  id uuid,
  donor_id uuid,
  charity_id uuid,
  title text,
  description text,
  category text,
  categories text[],
  items jsonb,
  quantity integer,
  condition text,
  images text[],
  pickup_address text,
  pickup_city text,
  pickup_latitude double precision,
  pickup_longitude double precision,
  status text,
  created_at timestamptz,
  expires_at timestamptz,
  charity_name text,
  charity_logo text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  RETURN QUERY
  SELECT r.id, NULL::uuid, r.charity_id, r.title, r.description, r.category,
         r.categories, r.items, r.quantity, r.condition, r.images,
         NULL::text, r.pickup_city, NULL::double precision, NULL::double precision,
         r.status, r.created_at, r.expires_at, c.name, c.logo
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
REVOKE ALL ON FUNCTION public.list_open_donations_for_volunteers(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_open_donations_for_volunteers(text)
  TO authenticated;

-- Assigned volunteers only; do not expose donor phone/name through this RPC.
DROP FUNCTION IF EXISTS public.list_my_volunteer_donations();
CREATE FUNCTION public.list_my_volunteer_donations()
RETURNS TABLE(
  id uuid,
  title text,
  description text,
  category text,
  categories text[],
  items jsonb,
  quantity integer,
  images text[],
  pickup_address text,
  pickup_city text,
  status text,
  volunteer_name text,
  volunteer_phone text,
  donor_pickup_confirmed_at timestamptz,
  charity_received_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  charity_name text,
  charity_address text,
  charity_phone text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  RETURN QUERY
  SELECT r.id, r.title, r.description, r.category, r.categories, r.items,
         r.quantity, r.images, r.pickup_address, r.pickup_city, r.status,
         r.volunteer_name, r.volunteer_phone, r.donor_pickup_confirmed_at,
         r.charity_received_at, r.created_at, r.updated_at,
         c.name, c.address, c.phone
  FROM public.charity_donation_requests r
  LEFT JOIN public.charities c ON c.id = r.charity_id
  WHERE r.volunteer_id = v_user_id
    AND r.deleted_at IS NULL
  ORDER BY r.updated_at DESC
  LIMIT 100;
END;
$function$;
REVOKE ALL ON FUNCTION public.list_my_volunteer_donations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_volunteer_donations() TO authenticated;

NOTIFY pgrst, 'reload schema';
