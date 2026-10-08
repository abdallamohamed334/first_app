-- Expose the home-restaurant catalog consistently in the marketplace,
-- institution home section, and the symbolic-price offer category picker.
BEGIN;

DO $$
DECLARE
  v_marketplace_root uuid;
  v_marketplace_home_restaurants uuid;
  v_marketplace_home_sweets uuid;
  v_marketplace_home_food uuid;
  v_community_home_restaurants uuid;
  v_category_id uuid;
  item record;
BEGIN
  SELECT id
  INTO v_marketplace_root
  FROM public.marketplace_categories
  WHERE parent_id IS NULL
    AND slug = 'institution-offers'
  LIMIT 1;

  IF v_marketplace_root IS NULL THEN
    RAISE EXCEPTION 'institution-offers root category is missing';
  END IF;

  SELECT id
  INTO v_marketplace_home_restaurants
  FROM public.marketplace_categories
  WHERE slug = 'home-restaurants'
  LIMIT 1;

  IF v_marketplace_home_restaurants IS NULL THEN
    INSERT INTO public.marketplace_categories
      (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
    VALUES
      ('home-restaurants', 'مطعم بيتي', 'Home Restaurant', 'restaurant', true, 11,
       v_marketplace_root)
    RETURNING id INTO v_marketplace_home_restaurants;
  ELSE
    UPDATE public.marketplace_categories
    SET name_ar = 'مطعم بيتي',
        name_en = 'Home Restaurant',
        icon = 'restaurant',
        is_active = true,
        sort_order = 11,
        parent_id = v_marketplace_root
    WHERE id = v_marketplace_home_restaurants;
  END IF;

  FOR item IN
    SELECT * FROM (VALUES
      ('home-sweets', 'حلويات بيتي', 'Home Sweets', 'cake', 1),
      ('home-food', 'أكل بيتي', 'Home-cooked Food', 'restaurant', 2)
    ) AS requested(slug, name_ar, name_en, icon, sort_order)
  LOOP
    SELECT id
    INTO v_category_id
    FROM public.marketplace_categories
    WHERE slug = item.slug
    LIMIT 1;

    IF v_category_id IS NULL THEN
      INSERT INTO public.marketplace_categories
        (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
      VALUES
        (item.slug, item.name_ar, item.name_en, item.icon, true,
         item.sort_order, v_marketplace_home_restaurants)
      RETURNING id INTO v_category_id;
    ELSE
      UPDATE public.marketplace_categories
      SET name_ar = item.name_ar,
          name_en = item.name_en,
          icon = item.icon,
          is_active = true,
          sort_order = item.sort_order,
          parent_id = v_marketplace_home_restaurants
      WHERE id = v_category_id;
    END IF;

    IF item.slug = 'home-sweets' THEN
      v_marketplace_home_sweets := v_category_id;
    ELSE
      v_marketplace_home_food := v_category_id;
    END IF;

    v_category_id := NULL;
  END LOOP;

  -- The symbolic-price picker reads community_categories. Mirror the same
  -- slugs and IDs whenever possible so both category trees stay in sync.
  FOR item IN
    SELECT * FROM (VALUES
      ('home-restaurants', 'مطعم بيتي', 'Home Restaurant', 'restaurant', 11,
       v_marketplace_home_restaurants, NULL::uuid),
      ('home-sweets', 'حلويات بيتي', 'Home Sweets', 'cake', 1,
       v_marketplace_home_sweets, v_marketplace_home_restaurants),
      ('home-food', 'أكل بيتي', 'Home-cooked Food', 'restaurant', 2,
       v_marketplace_home_food, v_marketplace_home_restaurants)
    ) AS requested(
      slug, name_ar, name_en, icon, sort_order,
      marketplace_id, marketplace_parent_id
    )
  LOOP
    SELECT id
    INTO v_category_id
    FROM public.community_categories
    WHERE slug = item.slug
    LIMIT 1;

    IF item.slug = 'home-restaurants' THEN
      IF v_category_id IS NULL THEN
        INSERT INTO public.community_categories
          (id, slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
        VALUES
          (item.marketplace_id, item.slug, item.name_ar, item.name_en,
           item.icon, true, item.sort_order, NULL);
        v_community_home_restaurants := item.marketplace_id;
      ELSE
        UPDATE public.community_categories
        SET name_ar = item.name_ar,
            name_en = item.name_en,
            icon = item.icon,
            is_active = true,
            sort_order = item.sort_order,
            parent_id = NULL
        WHERE id = v_category_id;
        v_community_home_restaurants := v_category_id;
      END IF;
    ELSE
      IF v_category_id IS NULL THEN
        INSERT INTO public.community_categories
          (id, slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
        VALUES
          (item.marketplace_id, item.slug, item.name_ar, item.name_en,
           item.icon, true, item.sort_order, v_community_home_restaurants);
      ELSE
        UPDATE public.community_categories
        SET name_ar = item.name_ar,
            name_en = item.name_en,
            icon = item.icon,
            is_active = true,
            sort_order = item.sort_order,
            parent_id = v_community_home_restaurants
        WHERE id = v_category_id;
      END IF;
    END IF;
  END LOOP;
END $$;

COMMIT;
