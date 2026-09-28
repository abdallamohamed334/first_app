-- Independent taxonomy for community needs.
-- Needs must not depend on marketplace/community offer categories.

CREATE TABLE IF NOT EXISTS public.community_need_categories (
  slug text PRIMARY KEY,
  name_ar text NOT NULL,
  name_en text,
  icon text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.community_need_categories (slug, name_ar, name_en, icon, sort_order)
VALUES
  ('food', 'طعام ومواد غذائية', 'Food and groceries', 'restaurant', 10),
  ('clothing', 'ملابس وأحذية', 'Clothing and shoes', 'checkroom', 20),
  ('medicine', 'أدوية ومستلزمات طبية', 'Medicine and medical supplies', 'medical_services', 30),
  ('school', 'مستلزمات تعليمية', 'School supplies', 'school', 40),
  ('baby', 'مستلزمات أطفال', 'Baby supplies', 'child_friendly', 50),
  ('furniture', 'أثاث ومفروشات', 'Furniture and home items', 'chair', 60),
  ('appliances', 'أجهزة وأدوات منزلية', 'Appliances and home tools', 'kitchen', 70),
  ('housing', 'سكن وتجهيز منزل', 'Housing and home setup', 'home', 80),
  ('transport', 'مواصلات وانتقال', 'Transport and mobility', 'directions_car', 90),
  ('work', 'عمل ومستلزمات مهنة', 'Work and tools', 'work', 100),
  ('other', 'احتياج آخر', 'Other need', 'category', 110)
ON CONFLICT (slug) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  icon = EXCLUDED.icon,
  sort_order = EXCLUDED.sort_order,
  is_active = true;

ALTER TABLE public.community_needs
  ADD COLUMN IF NOT EXISTS need_category text;

-- Existing databases may have required legacy category columns. New needs use
-- need_category and remain independent from marketplace/community categories.
ALTER TABLE public.community_needs
  ALTER COLUMN category_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS community_needs_need_category_idx
  ON public.community_needs (need_category);

ALTER TABLE public.community_need_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS community_need_categories_read ON public.community_need_categories;
CREATE POLICY community_need_categories_read
  ON public.community_need_categories FOR SELECT
  TO anon, authenticated
  USING (is_active = true);

DROP FUNCTION IF EXISTS public.list_community_needs_v2(text, text, text, integer, integer);
CREATE FUNCTION public.list_community_needs_v2(
  p_need_category text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid, requester_id uuid, requester_name text, requester_avatar text,
  category_id uuid, category_slug text, category_name_ar text, title text,
  description text, quantity integer, urgency text, city text, address text,
  contact_phone text, contact_whatsapp text, contact_count integer,
  phone_count integer, whatsapp_count integer, status text,
  expires_at timestamptz, created_at timestamptz, image_url text
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT n.id, n.requester_id, u.name, u.avatar_url,
    n.category_id,
    COALESCE(n.need_category, n.category_slug),
    COALESCE(c.name_ar, n.category_name_ar, 'احتياج آخر'),
    n.title, n.description, n.quantity, n.urgency, n.city, n.address,
    n.contact_phone, n.contact_whatsapp, n.contact_count,
    n.phone_count, n.whatsapp_count, n.status, n.expires_at,
    n.created_at, n.image_url
  FROM public.community_needs n
  LEFT JOIN public.users u ON u.id = n.requester_id
  LEFT JOIN public.community_need_categories c
    ON c.slug = n.need_category AND c.is_active = true
  WHERE n.status = 'active'
    AND n.expires_at > now()
    AND (p_need_category IS NULL OR n.need_category = p_need_category)
    AND (p_city IS NULL OR n.city = p_city)
    AND (
      p_search IS NULL OR p_search = ''
      OR n.title ILIKE '%' || p_search || '%'
      OR n.description ILIKE '%' || p_search || '%'
    )
    AND n.requester_id != auth.uid()
  ORDER BY
    CASE n.urgency
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    n.created_at DESC
  LIMIT LEAST(GREATEST(p_limit, 1), 50)
  OFFSET GREATEST(p_offset, 0);
$$;

REVOKE ALL ON FUNCTION public.list_community_needs_v2(text, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_community_needs_v2(text, text, text, integer, integer) TO authenticated;
