BEGIN;

CREATE TABLE IF NOT EXISTS public.swap_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name_ar text NOT NULL UNIQUE,
  icon text NOT NULL DEFAULT 'category',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.swap_categories (slug, name_ar, icon, sort_order)
VALUES
  ('electronics', 'إلكترونيات', 'devices', 10),
  ('mobile_phones', 'موبايلات', 'phone_android', 20),
  ('computers', 'كمبيوتر ولابتوب', 'computer', 30),
  ('cameras', 'كاميرات', 'camera_alt', 40),
  ('furniture', 'أثاث', 'chair', 50),
  ('clothing', 'ملابس', 'checkroom', 60),
  ('home_appliances', 'أجهزة منزلية', 'kitchen', 70),
  ('vehicles', 'سيارات ومواصلات', 'directions_car', 80),
  ('books', 'كتب وألعاب', 'menu_book', 90),
  ('sports', 'رياضة', 'sports_soccer', 100),
  ('other', 'أخرى', 'category', 110)
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  icon = EXCLUDED.icon,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

ALTER TABLE public.swap_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS swap_categories_select_active ON public.swap_categories;
CREATE POLICY swap_categories_select_active
  ON public.swap_categories FOR SELECT TO authenticated
  USING (is_active = true);

GRANT SELECT ON public.swap_categories TO authenticated;

COMMIT;
