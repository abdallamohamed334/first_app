-- Add household goods and a nested home-restaurant catalog. Home restaurant
-- offers are classified by the selected category (home sweets / home food).
BEGIN;

DO $$
DECLARE
  v_root uuid;
  v_home_restaurants uuid;
  v_category_id uuid;
  item record;
BEGIN
  SELECT id INTO v_root
  FROM public.marketplace_categories
  WHERE parent_id IS NULL AND slug = 'institution-offers'
  LIMIT 1;
  IF v_root IS NULL THEN
    RAISE EXCEPTION 'institution-offers root category is missing';
  END IF;

  FOR item IN
    SELECT * FROM (VALUES
      ('household-items', 'أغراض منزلية', 'Household Items', 'chair', 10),
      ('home-restaurants', 'مطاعم منزلية', 'Home Restaurants', 'restaurant', 11)
    ) AS requested(slug, name_ar, name_en, icon, sort_order)
  LOOP
    SELECT id INTO v_category_id
    FROM public.marketplace_categories
    WHERE slug = item.slug
    LIMIT 1;
    IF v_category_id IS NULL THEN
      INSERT INTO public.marketplace_categories
        (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
      VALUES
        (item.slug, item.name_ar, item.name_en, item.icon, true,
         item.sort_order, v_root)
      RETURNING id INTO v_category_id;
    ELSE
      UPDATE public.marketplace_categories
      SET name_ar = item.name_ar,
          name_en = item.name_en,
          icon = item.icon,
          is_active = true,
          sort_order = item.sort_order,
          parent_id = v_root
      WHERE id = v_category_id;
    END IF;
    IF item.slug = 'home-restaurants' THEN
      v_home_restaurants := v_category_id;
    END IF;
    v_category_id := NULL;
  END LOOP;

  FOR item IN
    SELECT * FROM (VALUES
      ('home-sweets', 'حلويات', 'Sweets', 'cake', 1),
      ('home-food', 'أكل بيتي', 'Home-cooked Food', 'restaurant', 2)
    ) AS requested(slug, name_ar, name_en, icon, sort_order)
  LOOP
    SELECT id INTO v_category_id
    FROM public.marketplace_categories
    WHERE slug = item.slug
    LIMIT 1;
    IF v_category_id IS NULL THEN
      INSERT INTO public.marketplace_categories
        (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
      VALUES
        (item.slug, item.name_ar, item.name_en, item.icon, true,
         item.sort_order, v_home_restaurants)
      RETURNING id INTO v_category_id;
    ELSE
      UPDATE public.marketplace_categories
      SET name_ar = item.name_ar,
          name_en = item.name_en,
          icon = item.icon,
          is_active = true,
          sort_order = item.sort_order,
          parent_id = v_home_restaurants
      WHERE id = v_category_id;
    END IF;
    v_category_id := NULL;
  END LOOP;
END $$;

UPDATE public.marketplace_categories AS child
SET is_active = child.slug IN (
  'grocery', 'bakery', 'butcher', 'meat_shop', 'poultry_shop',
  'wedding_hall', 'game_store', 'hotel', 'household-items', 'home-restaurants'
)
FROM public.marketplace_categories AS parent
WHERE child.parent_id = parent.id
  AND parent.parent_id IS NULL
  AND parent.slug = 'institution-offers';

CREATE OR REPLACE FUNCTION public.sync_institution_offer_catalog_category()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type text;
  v_category_id uuid;
  v_parent_id uuid;
  v_target_slug text;
BEGIN
  SELECT CASE lower(btrim(institution_type))
    WHEN 'supermarket' THEN 'grocery'
    WHEN 'grocery' THEN 'grocery'
    WHEN 'meat_shop' THEN 'meat_shop'
    WHEN 'butcher' THEN 'butcher'
    WHEN 'home_restaurant' THEN 'home-restaurants'
    WHEN 'household_goods' THEN 'household-items'
    ELSE COALESCE(NULLIF(lower(btrim(institution_type)), ''), 'other')
  END
  INTO v_type
  FROM public.institutions
  WHERE id = NEW.institution_id;

  SELECT id INTO v_parent_id
  FROM public.marketplace_categories
  WHERE slug = 'institution-offers' AND parent_id IS NULL
  LIMIT 1;

  IF v_type = 'home-restaurants' THEN
    v_target_slug := CASE lower(btrim(COALESCE(NEW.category, '')))
      WHEN 'home_sweets' THEN 'home-sweets'
      WHEN 'home-sweets' THEN 'home-sweets'
      WHEN 'sweets' THEN 'home-sweets'
      WHEN 'dessert' THEN 'home-sweets'
      WHEN 'home_food' THEN 'home-food'
      WHEN 'home-food' THEN 'home-food'
      WHEN 'food' THEN 'home-food'
      ELSE 'home-food'
    END;
    SELECT id INTO v_category_id
    FROM public.marketplace_categories
    WHERE slug = v_target_slug
      AND parent_id = (
        SELECT id FROM public.marketplace_categories
        WHERE slug = 'home-restaurants' AND parent_id = v_parent_id LIMIT 1
      )
    LIMIT 1;
  ELSE
    SELECT id INTO v_category_id
    FROM public.marketplace_categories
    WHERE slug = v_type AND parent_id = v_parent_id
    LIMIT 1;
  END IF;

  IF v_category_id IS NOT NULL THEN
    NEW.marketplace_category_id := v_category_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_institution_offer_catalog_category
  ON public.institution_offers;
CREATE TRIGGER trg_sync_institution_offer_catalog_category
BEFORE INSERT OR UPDATE OF institution_id, marketplace_category_id, category
ON public.institution_offers
FOR EACH ROW
EXECUTE FUNCTION public.sync_institution_offer_catalog_category();

-- Backfill existing offers belonging to the newly introduced institution types.
UPDATE public.institution_offers io
SET marketplace_category_id = CASE
  WHEN i.institution_type = 'home_restaurant' AND lower(btrim(COALESCE(io.category, ''))) IN ('home_sweets', 'home-sweets', 'sweets', 'dessert')
    THEN (SELECT c.id FROM public.marketplace_categories c JOIN public.marketplace_categories p ON p.id = c.parent_id WHERE c.slug = 'home-sweets' AND p.slug = 'home-restaurants' LIMIT 1)
  WHEN i.institution_type = 'home_restaurant'
    THEN (SELECT c.id FROM public.marketplace_categories c JOIN public.marketplace_categories p ON p.id = c.parent_id WHERE c.slug = 'home-food' AND p.slug = 'home-restaurants' LIMIT 1)
  WHEN i.institution_type = 'household_goods'
    THEN (SELECT c.id FROM public.marketplace_categories c WHERE c.slug = 'household-items' AND c.parent_id = (SELECT id FROM public.marketplace_categories WHERE slug = 'institution-offers' AND parent_id IS NULL LIMIT 1) LIMIT 1)
  ELSE io.marketplace_category_id
END
FROM public.institutions i
WHERE i.id = io.institution_id
  AND i.institution_type IN ('home_restaurant', 'household_goods');

COMMIT;
