-- Keep each category domain on a relevant brand list.
-- The generic brand attribute remains available for domains not migrated yet,
-- while the high-risk mixed domains use scoped attributes.

DO $$
DECLARE
  v_brand uuid;
  v_scoped uuid;
  v_category record;
BEGIN
  SELECT id INTO v_brand FROM public.marketplace_attributes WHERE slug = 'brand' LIMIT 1;

  -- Helper pattern: create a scoped attribute, copy only approved values from
  -- the legacy brand list, move category links, then remove the generic link.
  FOR v_category IN
    SELECT * FROM (VALUES
      ('mobile_brand', 'ماركة الموبايل أو التابلت', ARRAY['mobile-tablets']::text[], ARRAY['apple','samsung','xiaomi','huawei','oppo','vivo','realme','honor','nokia','sony','lg','microsoft','other']::text[]),
      ('computer_brand', 'ماركة الكمبيوتر', ARRAY['computers']::text[], ARRAY['apple','samsung','dell','hp','lenovo','asus','acer','msi','microsoft','sony','lg','toshiba','other']::text[]),
      ('appliance_brand', 'ماركة الأجهزة', ARRAY['electrical-appliances','home-appliances']::text[], ARRAY['lg','samsung','toshiba','bosch','philips','braun','tefal','kenwood','moulinex','black-decker','fresh','tornado','unionaire','carrier','gree','other']::text[]),
      ('auto_part_brand', 'ماركة قطع السيارات', ARRAY['cars-parts']::text[], ARRAY['toyota','honda','nissan','hyundai','kia','mitsubishi','mazda','chevrolet','ford','bmw','mercedes','audi','volkswagen','renault','peugeot','fiat','skoda','chery','mg','byd','other']::text[]),
      ('food_brand', 'ماركة الأغذية', ARRAY['institution-offers','home-restaurants']::text[], ARRAY['nestle','lipton','almarai','juhayna','domty','lactel','coca-cola','pepsi','danone','other']::text[]),
      ('clothing_brand', 'ماركة الملابس', ARRAY['clothing']::text[], ARRAY['nike','adidas','puma','reebok','zara','levis','other']::text[]),
      ('lighting_brand', 'ماركة الإضاءة', ARRAY['lighting']::text[], ARRAY['philips','fresh','tornado','osram','other']::text[]),
      ('tool_brand', 'ماركة الأدوات', ARRAY['home-tools','agricultural-tools']::text[], ARRAY['bosch','black-decker','dewalt','makita','stanley','other']::text[]),
      ('medical_brand', 'ماركة الأجهزة الطبية', ARRAY['medical-devices','medical-supplies']::text[], ARRAY['philips','samsung','lg','other']::text[])
    ) AS x(slug, name_ar, parent_slugs, allowed_values)
  LOOP
    INSERT INTO public.marketplace_attributes (slug, name_ar, name_en, input_type, is_active)
    VALUES (v_category.slug, v_category.name_ar, v_category.slug, 'select', true)
    ON CONFLICT (slug) DO UPDATE SET name_ar = EXCLUDED.name_ar, is_active = true;

    SELECT id INTO v_scoped
    FROM public.marketplace_attributes
    WHERE slug = v_category.slug;

    INSERT INTO public.marketplace_attribute_options
      (attribute_id, value, label_ar, label_en, sort_order, is_active)
    SELECT
      v_scoped, old.value, old.label_ar, old.label_en, old.sort_order, true
    FROM public.marketplace_attribute_options old
    WHERE old.attribute_id = v_brand
      AND old.is_active = true
      AND old.value = ANY(v_category.allowed_values)
      AND NOT EXISTS (
        SELECT 1 FROM public.marketplace_attribute_options existing
        WHERE existing.attribute_id = v_scoped AND existing.value = old.value
      );

    INSERT INTO public.marketplace_category_attributes
      (category_id, attribute_id, sort_order, is_required, is_filterable,
       is_for_offer_creation, is_for_display)
    SELECT c.id, v_scoped, old_link.sort_order, old_link.is_required,
           old_link.is_filterable, old_link.is_for_offer_creation,
           old_link.is_for_display
    FROM public.marketplace_categories c
    JOIN public.marketplace_categories p ON p.id = c.parent_id
    JOIN public.marketplace_category_attributes old_link
      ON old_link.category_id = c.id AND old_link.attribute_id = v_brand
    WHERE p.slug = ANY(v_category.parent_slugs)
      AND NOT EXISTS (
        SELECT 1 FROM public.marketplace_category_attributes existing
        WHERE existing.category_id = c.id AND existing.attribute_id = v_scoped
      );

    DELETE FROM public.marketplace_category_attributes old_link
    USING public.marketplace_categories c
    JOIN public.marketplace_categories p ON p.id = c.parent_id
    WHERE old_link.category_id = c.id
      AND old_link.attribute_id = v_brand
      AND p.slug = ANY(v_category.parent_slugs);
  END LOOP;

  -- The user explicitly requested no brand field on the equipment domain.
  DELETE FROM public.marketplace_category_attributes old_link
  USING public.marketplace_categories c
  JOIN public.marketplace_categories p ON p.id = c.parent_id
  WHERE old_link.category_id = c.id
    AND old_link.attribute_id = v_brand
    AND p.slug = 'equipment';

  -- These institutional categories are personal/home-care products, not food.
  DELETE FROM public.marketplace_category_attributes old_link
  USING public.marketplace_categories c
  JOIN public.marketplace_attributes a ON a.id = old_link.attribute_id
  WHERE old_link.category_id = c.id
    AND a.slug = 'food_brand'
    AND c.slug IN ('supermarket-cleaning', 'supermarket-personal');
END $$;

-- Ensure no equipment child still exposes a brand field.
COMMENT ON TABLE public.marketplace_category_attributes IS
  'Category-scoped attributes; generic brand links are removed from equipment and migrated domains.';
