BEGIN;

-- Restore the RPC used by My Offers > Edit offer.
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

NOTIFY pgrst, 'reload schema';
COMMIT;
