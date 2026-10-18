BEGIN;

-- Small restaurants publish through the institution-offers track.
INSERT INTO public.marketplace_categories (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
SELECT 'restaurant', 'مطاعم صغيرة', 'Small Restaurants', 'restaurant', true, 5, root.id
FROM public.marketplace_categories root
WHERE root.slug = 'institution-offers' AND root.parent_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.marketplace_categories c
    WHERE c.slug = 'restaurant' AND c.parent_id = root.id
  );

CREATE OR REPLACE FUNCTION public.enforce_institution_offer_type()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_type text;
BEGIN
  SELECT lower(trim(institution_type)) INTO v_type
  FROM public.institutions WHERE id = NEW.institution_id;
  IF v_type IS NULL OR v_type NOT IN
    ('grocery','supermarket','bakery','pastry_shop','restaurant','hotel','wedding_hall') THEN
    RAISE EXCEPTION 'institution type cannot publish offers';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_institution_offer_catalog_category()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_type text; v_category_id uuid; v_institution_root uuid;
  v_home_root uuid; v_target_slug text;
BEGIN
  SELECT lower(btrim(institution_type)) INTO v_type
  FROM public.institutions WHERE id = NEW.institution_id;
  SELECT id INTO v_institution_root FROM public.marketplace_categories
    WHERE slug = 'institution-offers' AND parent_id IS NULL LIMIT 1;
  SELECT id INTO v_home_root FROM public.marketplace_categories
    WHERE slug = 'home-restaurants' AND parent_id IS NULL LIMIT 1;
  IF v_type IN ('home_restaurant','home-restaurant','home_restaurants','home-restaurants') THEN
    v_target_slug := CASE lower(btrim(coalesce(NEW.category,'')))
      WHEN 'home_sweets' THEN 'home-sweets' WHEN 'home-sweets' THEN 'home-sweets'
      WHEN 'sweets' THEN 'home-sweets' WHEN 'dessert' THEN 'home-sweets'
      ELSE 'home-food' END;
    SELECT id INTO v_category_id FROM public.marketplace_categories
      WHERE slug=v_target_slug AND parent_id=v_home_root AND is_active=true LIMIT 1;
  ELSIF v_type='household_goods' THEN
    NEW.marketplace_category_id := NULL; RETURN NEW;
  ELSE
    SELECT id INTO v_category_id FROM public.marketplace_categories
      WHERE slug=CASE v_type
        WHEN 'supermarket' THEN 'grocery' WHEN 'grocery' THEN 'grocery'
        WHEN 'bakery' THEN 'bakery' WHEN 'pastry_shop' THEN 'pastry_shop'
        WHEN 'restaurant' THEN 'restaurant'
        ELSE coalesce(nullif(v_type,''),'other') END
        AND parent_id=v_institution_root AND is_active=true LIMIT 1;
  END IF;
  NEW.marketplace_category_id := v_category_id;
  RETURN NEW;
END;
$$;

DROP POLICY IF EXISTS institution_offers_public_select ON public.institution_offers;
CREATE POLICY institution_offers_public_select ON public.institution_offers
FOR SELECT TO authenticated USING (
  status='active' AND expires_at > now() AND EXISTS (
    SELECT 1 FROM public.institutions i WHERE i.id=institution_offers.institution_id
      AND i.status='approved'
      AND lower(trim(i.institution_type)) IN
        ('grocery','supermarket','bakery','pastry_shop','restaurant','hotel','wedding_hall')
  )
);

COMMIT;
