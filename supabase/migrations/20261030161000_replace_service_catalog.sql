BEGIN;

-- Replace the service catalog while preserving existing provider accounts and
-- historical service request references.
DELETE FROM public.services;

-- Keep legacy category rows for referential integrity, but hide them from the
-- active catalog. Existing providers remain intact and are not deleted.
UPDATE public.service_categories
SET is_active = false,
    updated_at = now();

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
VALUES
  (
    'plumbing',
    'سباكة',
    'Plumbing',
    '🔧',
    'إصلاح وتركيب أعمال السباكة والمياه',
    true,
    true,
    'market',
    true,
    1,
    now()
  ),
  (
    'electricity',
    'كهرباء',
    'Electricity',
    '⚡',
    'أعمال الكهرباء والإصلاحات الكهربائية',
    true,
    true,
    'market',
    true,
    2,
    now()
  ),
  (
    'screen_maintenance',
    'صيانة الشاشات',
    'Screen Maintenance',
    '📺',
    'فحص وإصلاح وصيانة الشاشات والتلفزيونات',
    true,
    true,
    'market',
    true,
    3,
    now()
  ),
  (
    'transportation',
    'عربيات للنقل',
    'Transportation',
    '🚚',
    'نقل الأغراض والأثاث والبضائع بالعربيات',
    true,
    true,
    'market',
    true,
    4,
    now()
  ),
  (
    'daily_wage',
    'شغل باليومية',
    'Daily Wage Work',
    '🧰',
    'أعمال ومهام يتم تنفيذها بنظام اليومية',
    true,
    true,
    'market',
    true,
    5,
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
  is_active = EXCLUDED.is_active,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

NOTIFY pgrst, 'reload schema';
COMMIT;
