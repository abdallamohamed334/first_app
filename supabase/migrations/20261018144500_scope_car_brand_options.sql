-- Keep vehicle brands separate from the global brand attribute.
-- The old shared attribute contained phone, appliance, food and clothing brands.
DO $$
DECLARE
  v_brand_id uuid;
  v_car_brand_id uuid;
BEGIN
  SELECT id INTO v_brand_id
  FROM public.marketplace_attributes
  WHERE slug = 'brand'
  LIMIT 1;

  IF v_brand_id IS NULL THEN
    RAISE EXCEPTION 'brand attribute not found';
  END IF;

  INSERT INTO public.marketplace_attributes
    (slug, name_ar, name_en, description, input_type, is_active)
  VALUES
    ('car_brand', 'ماركة السيارة', 'Car brand', 'ماركات السيارات فقط', 'select', true)
  ON CONFLICT (slug) DO UPDATE
    SET is_active = true,
        name_ar = 'ماركة السيارة',
        name_en = 'Car brand';

  SELECT id INTO v_car_brand_id
  FROM public.marketplace_attributes
  WHERE slug = 'car_brand'
  LIMIT 1;

  INSERT INTO public.marketplace_attribute_options
    (attribute_id, parent_option_id, value, label_ar, label_en,
     sort_order, is_active, metadata)
  SELECT
    v_car_brand_id, NULL, o.value, o.label_ar, o.label_en,
    o.sort_order, true, o.metadata
  FROM public.marketplace_attribute_options o
  WHERE o.attribute_id = v_brand_id
    AND o.value IN (
      'toyota', 'honda', 'nissan', 'hyundai', 'kia', 'mitsubishi',
      'mazda', 'chevrolet', 'ford', 'bmw', 'mercedes', 'audi',
      'volkswagen', 'renault', 'peugeot', 'fiat', 'skoda', 'chery',
      'mg', 'byd', 'other'
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.marketplace_attribute_options existing
      WHERE existing.attribute_id = v_car_brand_id
        AND existing.value = o.value
    );

  UPDATE public.marketplace_category_attributes mca
  SET attribute_id = v_car_brand_id
  FROM public.marketplace_categories mc
  WHERE mca.category_id = mc.id
    AND mca.attribute_id = v_brand_id
    AND mc.slug IN ('passenger-cars', 'trucks', 'motorcycles');
END $$;
