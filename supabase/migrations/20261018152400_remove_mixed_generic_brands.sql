DELETE FROM public.marketplace_category_attributes AS link
USING public.marketplace_categories AS c, public.marketplace_categories AS p, public.marketplace_attributes AS a
WHERE link.category_id = c.id
  AND c.parent_id = p.id
  AND link.attribute_id = a.id
  AND a.slug = 'brand'
  AND (
    (p.slug = 'professional-equip')
    OR (p.slug = 'stationery-school')
    OR (p.slug = 'home-supplies' AND c.slug = 'cleaners')
  );
