BEGIN;

-- Existing active symbolic offers get the same one-week lifetime as new offers.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.community_offers'::regclass
      AND tgname = 'trg_guard_community_offer_single_edit'
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.community_offers
      DISABLE TRIGGER trg_guard_community_offer_single_edit;
  END IF;
END;
$$;

UPDATE public.community_offers
SET expires_at = COALESCE(created_at, now()) + interval '7 days',
    updated_at = now()
WHERE charity_id IS NULL
  AND listing_type = 'symbolic_sale'
  AND status IN ('available', 'active');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.community_offers'::regclass
      AND tgname = 'trg_guard_community_offer_single_edit'
      AND NOT tgisinternal
  ) THEN
    ALTER TABLE public.community_offers
      ENABLE TRIGGER trg_guard_community_offer_single_edit;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_community_offer_weekly_expiry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.charity_id IS NULL AND NEW.listing_type = 'symbolic_sale' THEN
    IF TG_OP = 'INSERT' THEN
      NEW.created_at := now();
      NEW.expires_at := NEW.created_at + interval '7 days';
    ELSIF NEW.expires_at IS DISTINCT FROM OLD.expires_at THEN
      IF OLD.status = 'expired'
         AND NEW.status = 'available'
         AND COALESCE(OLD.expires_at, OLD.created_at + interval '7 days') <= now()
         AND NEW.expires_at > now() THEN
        NEW.expires_at := now() + interval '7 days';
      ELSE
        NEW.expires_at := LEAST(
          COALESCE(NEW.expires_at, NEW.created_at + interval '7 days'),
          NEW.created_at + interval '7 days'
        );
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.set_community_offer_weekly_expiry()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_community_offer_weekly_expiry
  ON public.community_offers;
CREATE TRIGGER trg_community_offer_weekly_expiry
BEFORE INSERT OR UPDATE OF expires_at, status, listing_type, charity_id
ON public.community_offers
FOR EACH ROW
EXECUTE FUNCTION public.set_community_offer_weekly_expiry();

-- Renewal is a lifecycle action, not a content edit. It gets a fresh week
-- without consuming the existing single-content-edit allowance.
CREATE OR REPLACE FUNCTION public.guard_community_offer_single_edit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  renewal_change boolean;
  substantive_change boolean;
BEGIN
  renewal_change := OLD.status = 'expired'
    AND NEW.status = 'available'
    AND NEW.expires_at > now()
    AND COALESCE(OLD.expires_at, OLD.created_at + interval '7 days') <= now();

  substantive_change :=
    NEW.edit_count IS DISTINCT FROM OLD.edit_count
    OR NEW.title IS DISTINCT FROM OLD.title
    OR NEW.description IS DISTINCT FROM OLD.description
    OR NEW.category IS DISTINCT FROM OLD.category
    OR NEW.category_id IS DISTINCT FROM OLD.category_id
    OR NEW.marketplace_category_id IS DISTINCT FROM OLD.marketplace_category_id
    OR NEW.listing_type IS DISTINCT FROM OLD.listing_type
    OR NEW.item_condition IS DISTINCT FROM OLD.item_condition
    OR NEW.quantity IS DISTINCT FROM OLD.quantity
    OR NEW.price IS DISTINCT FROM OLD.price
    OR NEW.image IS DISTINCT FROM OLD.image
    OR NEW.images IS DISTINCT FROM OLD.images
    OR NEW.pickup_location IS DISTINCT FROM OLD.pickup_location
    OR NEW.latitude IS DISTINCT FROM OLD.latitude
    OR NEW.longitude IS DISTINCT FROM OLD.longitude
    OR NEW.phone IS DISTINCT FROM OLD.phone
    OR NEW.whatsapp IS DISTINCT FROM OLD.whatsapp
    OR (NEW.expires_at IS DISTINCT FROM OLD.expires_at AND NOT renewal_change);

  NEW.edit_count := OLD.edit_count;
  IF substantive_change THEN
    IF OLD.edit_count >= 1 THEN
      RAISE EXCEPTION 'community offer edit limit reached';
    END IF;
    NEW.edit_count := OLD.edit_count + 1;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_community_offer_single_edit
  ON public.community_offers;
CREATE TRIGGER trg_guard_community_offer_single_edit
BEFORE UPDATE ON public.community_offers
FOR EACH ROW
EXECUTE FUNCTION public.guard_community_offer_single_edit();

REVOKE ALL ON FUNCTION public.guard_community_offer_single_edit()
  FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.offer_renewals_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id uuid NOT NULL,
  user_id uuid NOT NULL,
  renewed_at timestamptz NOT NULL DEFAULT now(),
  old_expires_at timestamptz,
  new_expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_offer_renewals_user_time
  ON public.offer_renewals_log (user_id, renewed_at DESC);
ALTER TABLE public.offer_renewals_log ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_renew_offer(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_renewals_last_day integer;
BEGIN
  SELECT count(*)::integer INTO v_renewals_last_day
  FROM public.offer_renewals_log
  WHERE user_id = p_user_id
    AND renewed_at > now() - interval '24 hours';
  RETURN v_renewals_last_day < 5;
END;
$$;
REVOKE ALL ON FUNCTION public.can_renew_offer(uuid)
  FROM PUBLIC, anon, authenticated;

-- Expired rows stay in My Offers with status=available in some deployments;
-- allow those, as well as explicitly expired rows, to renew for exactly a week.
CREATE OR REPLACE FUNCTION public.renew_community_offer(
  p_offer_id uuid,
  p_user_id uuid,
  p_days integer DEFAULT 7
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_owner uuid;
  v_status text;
  v_old_expires timestamptz;
  v_created_at timestamptz;
  v_charity_id uuid;
  v_listing_type text;
  v_new_expiry timestamptz;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Authenticated user mismatch';
  END IF;
  IF p_days <> 7 THEN
    RAISE EXCEPTION 'Community offers can only be renewed for seven days';
  END IF;
  IF NOT public.can_renew_offer(p_user_id) THEN
    RAISE EXCEPTION 'تم الوصول للحد الأقصى من تجديدات العروض اليوم.';
  END IF;

  SELECT owner_id, status, expires_at, created_at, charity_id, listing_type
  INTO v_owner, v_status, v_old_expires, v_created_at, v_charity_id, v_listing_type
  FROM public.community_offers
  WHERE id = p_offer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'العرض غير موجود';
  END IF;
  IF v_owner <> p_user_id THEN
    RAISE EXCEPTION 'لا تملك صلاحية تعديل هذا العرض';
  END IF;
  IF v_charity_id IS NOT NULL OR v_listing_type <> 'symbolic_sale' THEN
    RAISE EXCEPTION 'هذا المسار مخصص للعروض المجتمعية للبيع فقط';
  END IF;
  IF v_status NOT IN ('expired', 'available', 'active')
     OR COALESCE(v_old_expires, v_created_at + interval '7 days') > now() THEN
    RAISE EXCEPTION 'لا يمكن تجديد عرض ما زال متاحًا أو تم بيعه/إلغاؤه';
  END IF;

  -- Transition through expired so the expiry trigger can distinguish a real
  -- renewal from an attempt to extend an active listing.
  IF v_status <> 'expired' THEN
    UPDATE public.community_offers
    SET status = 'expired', updated_at = now()
    WHERE id = p_offer_id;
  END IF;

  v_new_expiry := now() + interval '7 days';
  UPDATE public.community_offers
  SET status = 'available', expires_at = v_new_expiry, updated_at = now()
  WHERE id = p_offer_id;

  INSERT INTO public.offer_renewals_log
    (offer_id, user_id, old_expires_at, new_expires_at)
  VALUES (p_offer_id, p_user_id, v_old_expires, v_new_expiry);

  RETURN v_new_expiry;
END;
$$;

REVOKE ALL ON FUNCTION public.renew_community_offer(uuid, uuid, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_community_offer(uuid, uuid, integer)
  TO authenticated;

-- The app supports select, text and numeric category specifications. The
-- previous RPC accepted only option_id, which made text/number specs fail.
CREATE OR REPLACE FUNCTION public.upsert_marketplace_offer_attributes(
  p_marketplace_offer_id uuid,
  p_attributes jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_source_type text;
  v_source_id uuid;
  v_category_id uuid;
  v_attribute_id uuid;
  v_option_id uuid;
  v_input_type text;
  v_required boolean;
  v_item jsonb;
  v_value_text text;
  v_value_number numeric;
  v_value_boolean boolean;
  v_saved_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF p_marketplace_offer_id IS NULL THEN
    RAISE EXCEPTION 'Marketplace offer ID is required';
  END IF;
  IF p_attributes IS NULL OR jsonb_typeof(p_attributes) <> 'array' THEN
    RAISE EXCEPTION 'Attributes must be a JSON array';
  END IF;

  SELECT mo.source_type, mo.source_id, mo.marketplace_category_id
  INTO v_source_type, v_source_id, v_category_id
  FROM public.marketplace_offers mo
  WHERE mo.id = p_marketplace_offer_id AND mo.is_active = true
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Marketplace offer not found or inactive';
  END IF;

  IF v_source_type = 'community' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.community_offers co
      WHERE co.id = v_source_id AND co.owner_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'You are not allowed to modify this offer';
    END IF;
  ELSIF v_source_type = 'institution' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.institution_offers io
      JOIN public.institutions i ON i.id = io.institution_id
      WHERE io.id = v_source_id AND i.user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'You are not allowed to modify this offer';
    END IF;
  ELSE
    RAISE EXCEPTION 'Unsupported marketplace source type: %', v_source_type;
  END IF;

  IF v_category_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.marketplace_categories mc
    WHERE mc.id = v_category_id AND mc.is_active = true
  ) THEN
    RAISE EXCEPTION 'Offer category is invalid or inactive';
  END IF;

  IF EXISTS (
    SELECT item ->> 'attribute_id'
    FROM jsonb_array_elements(p_attributes) AS entries(item)
    GROUP BY item ->> 'attribute_id'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate offer attributes are not allowed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.marketplace_category_attributes mca
    JOIN public.marketplace_attributes ma ON ma.id = mca.attribute_id
    WHERE v_source_type = 'community'
      AND mca.category_id = v_category_id
      AND mca.is_for_offer_creation = true
      AND mca.is_for_display = true
      AND mca.is_required = true
      AND ma.is_active = true
      AND NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_attributes) AS entries(item)
        WHERE item ->> 'attribute_id' = mca.attribute_id::text
      )
  ) THEN
    RAISE EXCEPTION 'All required category specifications must be provided';
  END IF;

  DELETE FROM public.marketplace_offer_attributes
  WHERE marketplace_offer_id = p_marketplace_offer_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_attributes)
  LOOP
    v_attribute_id := NULLIF(btrim(v_item ->> 'attribute_id'), '')::uuid;
    IF v_attribute_id IS NULL THEN
      RAISE EXCEPTION 'attribute_id is required';
    END IF;

    SELECT lower(COALESCE(ma.input_type, 'text')), mca.is_required
    INTO v_input_type, v_required
    FROM public.marketplace_attributes ma
    JOIN public.marketplace_category_attributes mca
      ON mca.attribute_id = ma.id
    WHERE ma.id = v_attribute_id
      AND ma.is_active = true
      AND mca.category_id = v_category_id
      AND mca.is_for_offer_creation = true
      AND mca.is_for_display = true;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Attribute is not allowed for this category';
    END IF;

    v_option_id := NULLIF(btrim(v_item ->> 'option_id'), '')::uuid;
    v_value_text := NULLIF(btrim(v_item ->> 'value_text'), '');
    v_value_number := NULL;
    v_value_boolean := NULL;

    IF v_input_type = 'select' THEN
      IF v_option_id IS NULL THEN
        IF v_required THEN RAISE EXCEPTION 'A required selection is missing'; END IF;
        CONTINUE;
      END IF;
      IF NOT EXISTS (
        SELECT 1 FROM public.marketplace_attribute_options mao
        WHERE mao.id = v_option_id
          AND mao.attribute_id = v_attribute_id
          AND mao.is_active = true
      ) THEN
        RAISE EXCEPTION 'Invalid option for this attribute';
      END IF;
      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, option_id)
      VALUES (p_marketplace_offer_id, v_attribute_id, v_option_id);

    ELSIF v_input_type IN ('number', 'decimal') THEN
      IF NULLIF(btrim(v_item ->> 'value_number'), '') IS NULL THEN
        IF v_required THEN RAISE EXCEPTION 'A required numeric specification is missing'; END IF;
        CONTINUE;
      END IF;
      BEGIN
        v_value_number := (v_item ->> 'value_number')::numeric;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid numeric specification';
      END;
      IF v_value_number::text IN ('NaN', 'Infinity', '-Infinity')
         OR (v_required AND v_value_number <= 0) THEN
        RAISE EXCEPTION 'Numeric specifications must be finite and greater than zero';
      END IF;
      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_number)
      VALUES (p_marketplace_offer_id, v_attribute_id, v_value_number);

    ELSIF v_input_type IN ('boolean', 'checkbox', 'toggle') THEN
      IF NULLIF(btrim(v_item ->> 'value_boolean'), '') IS NULL THEN
        IF v_required THEN RAISE EXCEPTION 'A required boolean specification is missing'; END IF;
        CONTINUE;
      END IF;
      BEGIN
        v_value_boolean := (v_item ->> 'value_boolean')::boolean;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid boolean specification';
      END;
      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_boolean)
      VALUES (p_marketplace_offer_id, v_attribute_id, v_value_boolean);

    ELSE
      IF v_value_text IS NULL THEN
        IF v_required THEN RAISE EXCEPTION 'A required text specification is missing'; END IF;
        CONTINUE;
      END IF;
      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_text)
      VALUES (p_marketplace_offer_id, v_attribute_id, v_value_text);
    END IF;

    v_saved_count := v_saved_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'marketplace_offer_id', p_marketplace_offer_id,
    'saved_attributes', v_saved_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.upsert_marketplace_offer_attributes(uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upsert_marketplace_offer_attributes(uuid, jsonb)
  TO authenticated;

-- A single authenticated owner operation updates only the title and values
-- for the offer's existing category. Category/price/contact/images are untouched.
CREATE OR REPLACE FUNCTION public.update_community_offer_display_details(
  p_offer_id uuid,
  p_title text,
  p_attributes jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_marketplace_offer_id uuid;
  v_category_id uuid;
  v_attribute_id uuid;
  v_option_id uuid;
  v_input_type text;
  v_required boolean;
  v_item jsonb;
  v_value_text text;
  v_value_number numeric;
  v_value_boolean boolean;
  v_saved_count integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_offer_id IS NULL THEN
    RAISE EXCEPTION 'Offer ID is required';
  END IF;

  IF p_title IS NULL OR length(btrim(p_title)) < 3 OR length(btrim(p_title)) > 120 THEN
    RAISE EXCEPTION 'Offer title must contain between 3 and 120 characters';
  END IF;

  IF p_attributes IS NULL OR jsonb_typeof(p_attributes) <> 'array' THEN
    RAISE EXCEPTION 'Attributes must be a JSON array';
  END IF;

  SELECT mo.id, mo.marketplace_category_id
  INTO v_marketplace_offer_id, v_category_id
  FROM public.community_offers co
  JOIN public.marketplace_offers mo
    ON mo.source_type = 'community' AND mo.source_id = co.id
  WHERE co.id = p_offer_id
    AND co.owner_id = v_user_id
    AND co.charity_id IS NULL
    AND co.listing_type = 'symbolic_sale'
    AND co.status IN ('available', 'active')
    AND co.expires_at > now()
  FOR UPDATE OF co, mo;

  IF NOT FOUND OR v_category_id IS NULL THEN
    RAISE EXCEPTION 'Offer is unavailable or not owned by the current user';
  END IF;

  IF EXISTS (
    SELECT item ->> 'attribute_id'
    FROM jsonb_array_elements(p_attributes) AS entries(item)
    GROUP BY item ->> 'attribute_id'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate offer attributes are not allowed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.marketplace_category_attributes mca
    JOIN public.marketplace_attributes ma ON ma.id = mca.attribute_id
    WHERE mca.category_id = v_category_id
      AND mca.is_for_offer_creation = true
      AND mca.is_for_display = true
      AND mca.is_required = true
      AND ma.is_active = true
      AND NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_attributes) AS entries(item)
        WHERE item ->> 'attribute_id' = mca.attribute_id::text
      )
  ) THEN
    RAISE EXCEPTION 'All required category specifications must be provided';
  END IF;

  -- This is the only community_offers field changed by this operation.
  UPDATE public.community_offers
  SET title = btrim(p_title), updated_at = now()
  WHERE id = p_offer_id AND owner_id = v_user_id;

  DELETE FROM public.marketplace_offer_attributes
  WHERE marketplace_offer_id = v_marketplace_offer_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_attributes)
  LOOP
    v_attribute_id := NULLIF(btrim(v_item ->> 'attribute_id'), '')::uuid;
    IF v_attribute_id IS NULL THEN
      RAISE EXCEPTION 'attribute_id is required';
    END IF;

    SELECT lower(COALESCE(ma.input_type, 'text')), mca.is_required
    INTO v_input_type, v_required
    FROM public.marketplace_attributes ma
    JOIN public.marketplace_category_attributes mca
      ON mca.attribute_id = ma.id
    WHERE ma.id = v_attribute_id
      AND ma.is_active = true
      AND mca.category_id = v_category_id
      AND mca.is_for_offer_creation = true
      AND mca.is_for_display = true;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Attribute is not allowed for this offer category';
    END IF;

    v_option_id := NULLIF(btrim(v_item ->> 'option_id'), '')::uuid;
    v_value_text := NULLIF(btrim(v_item ->> 'value_text'), '');
    v_value_number := NULL;
    v_value_boolean := NULL;

    IF v_input_type = 'select' THEN
      IF v_option_id IS NULL THEN
        IF v_required THEN
          RAISE EXCEPTION 'A required selection is missing';
        END IF;
        CONTINUE;
      END IF;

      IF NOT EXISTS (
        SELECT 1
        FROM public.marketplace_attribute_options mao
        WHERE mao.id = v_option_id
          AND mao.attribute_id = v_attribute_id
          AND mao.is_active = true
      ) THEN
        RAISE EXCEPTION 'Invalid option for this attribute';
      END IF;

      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, option_id)
      VALUES (v_marketplace_offer_id, v_attribute_id, v_option_id);

    ELSIF v_input_type IN ('number', 'decimal') THEN
      IF NULLIF(btrim(v_item ->> 'value_number'), '') IS NULL THEN
        IF v_required THEN
          RAISE EXCEPTION 'A required numeric specification is missing';
        END IF;
        CONTINUE;
      END IF;

      BEGIN
        v_value_number := (v_item ->> 'value_number')::numeric;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid numeric specification';
      END;

      IF v_value_number::text IN ('NaN', 'Infinity', '-Infinity')
         OR (v_required AND v_value_number <= 0) THEN
        RAISE EXCEPTION 'Numeric specifications must be finite and greater than zero';
      END IF;

      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_number)
      VALUES (v_marketplace_offer_id, v_attribute_id, v_value_number);

    ELSIF v_input_type IN ('boolean', 'checkbox', 'toggle') THEN
      IF NULLIF(btrim(v_item ->> 'value_boolean'), '') IS NULL THEN
        IF v_required THEN
          RAISE EXCEPTION 'A required boolean specification is missing';
        END IF;
        CONTINUE;
      END IF;

      BEGIN
        v_value_boolean := (v_item ->> 'value_boolean')::boolean;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Invalid boolean specification';
      END;

      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_boolean)
      VALUES (v_marketplace_offer_id, v_attribute_id, v_value_boolean);

    ELSE
      IF v_value_text IS NULL THEN
        IF v_required THEN
          RAISE EXCEPTION 'A required text specification is missing';
        END IF;
        CONTINUE;
      END IF;

      INSERT INTO public.marketplace_offer_attributes
        (marketplace_offer_id, attribute_id, value_text)
      VALUES (v_marketplace_offer_id, v_attribute_id, v_value_text);
    END IF;

    v_saved_count := v_saved_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'offer_id', p_offer_id,
    'marketplace_offer_id', v_marketplace_offer_id,
    'saved_attributes', v_saved_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_community_offer_display_details(uuid, text, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_community_offer_display_details(uuid, text, jsonb)
  TO authenticated;

COMMIT;
