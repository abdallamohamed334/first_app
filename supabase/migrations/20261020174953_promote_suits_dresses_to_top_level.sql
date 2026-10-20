BEGIN;

-- The user-facing purchase categories strip reads active root categories and
-- sorts by sort_order. Promote this section to the first standalone category;
-- its four sale/rental leaves remain attached to the same parent ID.
UPDATE public.marketplace_categories
SET parent_id = NULL,
    sort_order = 0,
    is_active = true
WHERE slug = 'suits-dresses';

UPDATE public.community_categories AS community
SET parent_id = NULL,
    sort_order = 0,
    is_active = true
FROM public.marketplace_categories AS marketplace
WHERE marketplace.slug = 'suits-dresses'
  AND community.id = marketplace.id;

COMMIT;
