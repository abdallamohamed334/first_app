BEGIN;

-- Add high-demand service categories while preserving existing providers and
-- historical service-request references.
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
    'car_mechanic',
    'ميكانيكي سيارات',
    'Car Mechanic',
    '🚗🔧',
    'فحص وصيانة وإصلاح أعطال السيارات والميكانيكا العامة',
    true,
    true,
    'market',
    true,
    8,
    now()
  ),
  (
    'carpentry',
    'نجار',
    'Carpenter',
    '🪚',
    'أعمال النجارة وإصلاح وتركيب الأثاث والأبواب',
    true,
    true,
    'market',
    true,
    9,
    now()
  ),
  (
    'water_heaters',
    'صيانة سخانات',
    'Water Heater Maintenance',
    '🔥',
    'تركيب وصيانة وإصلاح السخانات ومشاكل المياه الساخنة',
    true,
    true,
    'market',
    true,
    10,
    now()
  ),
  (
    'waterproofing',
    'عزل وتسريب مياه',
    'Waterproofing & Leak Repair',
    '💧',
    'كشف وإصلاح تسربات المياه وعزل الأسطح والحوائط قبل أمطار الشتاء',
    true,
    true,
    'market',
    true,
    11,
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
