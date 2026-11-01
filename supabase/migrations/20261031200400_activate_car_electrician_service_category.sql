BEGIN;

UPDATE public.service_categories
SET is_active = true,
    sort_order = 6
WHERE slug = 'car_electrician';

UPDATE public.service_providers
SET category_id = (
  SELECT id
  FROM public.service_categories
  WHERE slug = 'car_electrician'
  LIMIT 1
)
WHERE display_name = 'سعيد';

NOTIFY pgrst, 'reload schema';
COMMIT;
