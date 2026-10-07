-- Keep only the institution catalog categories requested by the product owner.
-- Grocery and supermarket are represented by the single grocery category.
BEGIN;

UPDATE public.marketplace_categories AS child
SET is_active = child.slug IN (
  'grocery',
  'bakery',
  'butcher',
  'meat_shop',
  'poultry_shop',
  'wedding_hall',
  'game_store',
  'hotel'
)
FROM public.marketplace_categories AS parent
WHERE child.parent_id = parent.id
  AND parent.parent_id IS NULL
  AND parent.slug = 'institution-offers';

UPDATE public.marketplace_categories
SET is_active = false
WHERE slug = 'supermarket';

UPDATE public.marketplace_categories
SET name_ar = 'بقالة وسوبر ماركت',
    name_en = 'Grocery & Supermarket',
    is_active = true
WHERE slug = 'grocery'
  AND parent_id = (
    SELECT id
    FROM public.marketplace_categories
    WHERE slug = 'institution-offers'
      AND parent_id IS NULL
    LIMIT 1
  );

COMMIT;
