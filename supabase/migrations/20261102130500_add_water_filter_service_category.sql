BEGIN;

INSERT INTO public.service_categories (
  slug,
  name_ar,
  name_en,
  icon,
  description,
  supports_individual,
  supports_company,
  default_pricing,
  is_active,
  sort_order,
  updated_at
)
VALUES (
  'water_filters',
  'تركيب وتصليح فلاتر',
  'Water Filter Installation & Repair',
  '💧',
  'تركيب وصيانة وتصليح فلاتر المياه وتغيير الشمعات',
  true,
  true,
  'market',
  true,
  6,
  now()
)
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon = EXCLUDED.icon,
  description = EXCLUDED.description,
  supports_individual = EXCLUDED.supports_individual,
  supports_company = EXCLUDED.supports_company,
  default_pricing = EXCLUDED.default_pricing,
  is_active = true,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

NOTIFY pgrst, 'reload schema';
COMMIT;
