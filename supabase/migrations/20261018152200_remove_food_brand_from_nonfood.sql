DELETE FROM public.marketplace_category_attributes AS old_link
USING public.marketplace_categories AS c, public.marketplace_attributes AS a
WHERE old_link.category_id = c.id
  AND old_link.attribute_id = a.id
  AND a.slug = 'food_brand'
  AND c.slug IN ('supermarket-cleaning', 'supermarket-personal');
