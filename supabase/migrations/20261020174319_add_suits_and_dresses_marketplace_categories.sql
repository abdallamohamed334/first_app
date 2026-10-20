BEGIN;

-- Keep the shared community/marketplace category IDs aligned so users can
-- browse these sections and select the same leaves when publishing offers.
INSERT INTO public.marketplace_categories
  (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
SELECT
  'suits-dresses', 'بدل وفساتين', 'Suits & Dresses', 'business_center', true, 11, clothing.id
FROM public.marketplace_categories AS clothing
WHERE clothing.slug = 'clothing' AND clothing.parent_id IS NULL
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon = EXCLUDED.icon,
  is_active = true,
  sort_order = EXCLUDED.sort_order,
  parent_id = EXCLUDED.parent_id;

INSERT INTO public.marketplace_categories
  (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
SELECT v.slug, v.name_ar, v.name_en, v.icon, true, v.sort_order, parent.id
FROM (VALUES
  ('suit-rental', 'تأجير بدل', 'Suit Rental', 'man', 1),
  ('suit-sale', 'بيع بدل', 'Suit Sales', 'man', 2),
  ('dress-rental', 'تأجير فساتين', 'Dress Rental', 'woman', 3),
  ('dress-sale', 'بيع فساتين', 'Dress Sales', 'woman', 4)
) AS v(slug, name_ar, name_en, icon, sort_order)
JOIN public.marketplace_categories AS parent ON parent.slug = 'suits-dresses'
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon = EXCLUDED.icon,
  is_active = true,
  sort_order = EXCLUDED.sort_order,
  parent_id = EXCLUDED.parent_id;

-- community_categories is the publishing picker source; reuse the marketplace
-- IDs instead of creating a second, disconnected category tree.
INSERT INTO public.community_categories
  (id, slug, name_ar, name_en, description, parent_id, icon, is_active, sort_order)
SELECT
  category.id,
  category.slug,
  category.name_ar,
  category.name_en,
  category.description,
  category.parent_id,
  category.icon,
  true,
  category.sort_order
FROM public.marketplace_categories AS category
WHERE category.slug IN (
  'suits-dresses', 'suit-rental', 'suit-sale', 'dress-rental', 'dress-sale'
)
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  description = EXCLUDED.description,
  parent_id = EXCLUDED.parent_id,
  icon = EXCLUDED.icon,
  is_active = true,
  sort_order = EXCLUDED.sort_order;

-- Reuse clothing size/color/condition fields in both discovery filters and
-- the offer form; suits inherit the men's options and dresses the women's.
INSERT INTO public.marketplace_category_attributes
  (category_id, attribute_id, sort_order, is_required, is_filterable,
   is_for_offer_creation, is_for_display)
SELECT
  target.id,
  mapping.attribute_id,
  mapping.sort_order,
  mapping.is_required,
  mapping.is_filterable,
  mapping.is_for_offer_creation,
  mapping.is_for_display
FROM public.marketplace_categories AS target
JOIN public.marketplace_categories AS source
  ON source.slug = CASE
    WHEN target.slug IN ('suit-rental', 'suit-sale') THEN 'men-clothing'
    ELSE 'women-clothing'
  END
JOIN public.marketplace_category_attributes AS mapping
  ON mapping.category_id = source.id
JOIN public.marketplace_attributes AS attribute
  ON attribute.id = mapping.attribute_id
WHERE target.slug IN ('suit-rental', 'suit-sale', 'dress-rental', 'dress-sale')
  AND attribute.slug IN ('size', 'color', 'condition')
ON CONFLICT (category_id, attribute_id) DO UPDATE SET
  sort_order = EXCLUDED.sort_order,
  is_required = EXCLUDED.is_required,
  is_filterable = EXCLUDED.is_filterable,
  is_for_offer_creation = EXCLUDED.is_for_offer_creation,
  is_for_display = EXCLUDED.is_for_display;

COMMIT;
