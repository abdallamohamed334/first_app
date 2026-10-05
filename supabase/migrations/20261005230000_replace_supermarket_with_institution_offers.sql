-- Replace the generic supermarket category with a dedicated institution-offers tree.
-- Existing category and offer rows are retained; only the visible hierarchy changes.
BEGIN;

DO $$
DECLARE
  v_parent_id uuid;
  item record;
  v_existing_id uuid;
BEGIN
  SELECT id INTO v_parent_id
  FROM public.marketplace_categories
  WHERE parent_id IS NULL AND slug = 'supermarket'
  LIMIT 1;

  IF v_parent_id IS NULL THEN
    SELECT id INTO v_parent_id
    FROM public.marketplace_categories
    WHERE parent_id IS NULL AND slug = 'institution-offers'
    LIMIT 1;
  END IF;

  IF v_parent_id IS NULL THEN
    INSERT INTO public.marketplace_categories
      (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
    VALUES
      ('institution-offers', 'عروض المؤسسات', 'Institution Offers', 'business', true, 9, NULL)
    RETURNING id INTO v_parent_id;
  ELSE
    UPDATE public.marketplace_categories
    SET slug = 'institution-offers',
        name_ar = 'عروض المؤسسات',
        name_en = 'Institution Offers',
        icon = 'business',
        is_active = true,
        sort_order = 9
    WHERE id = v_parent_id;
  END IF;

  UPDATE public.marketplace_categories
  SET is_active = false
  WHERE parent_id = v_parent_id;

  FOR item IN
    SELECT * FROM (VALUES
      ('grocery', 'بقالة', 'Grocery', 'shopping_basket', 1),
      ('supermarket', 'سوبر ماركت', 'Supermarket', 'shopping_cart', 2),
      ('bakery', 'مخبز', 'Bakery', 'bakery_dining', 3),
      ('pastry_shop', 'حلويات ومخبوزات', 'Pastry Shop', 'cake', 4),
      ('restaurant', 'مطعم', 'Restaurant', 'restaurant', 5),
      ('cafe', 'كافيه', 'Cafe', 'local_cafe', 6),
      ('juice_shop', 'محل عصائر', 'Juice Shop', 'local_drink', 7),
      ('butcher', 'جزارة', 'Butcher', 'set_meal', 8),
      ('fish_market', 'سوق أسماك', 'Fish Market', 'set_meal', 9),
      ('poultry_shop', 'محل دواجن', 'Poultry Shop', 'egg_alt', 10),
      ('dairy_shop', 'ألبان ومنتجاتها', 'Dairy Shop', 'local_drink', 11),
      ('food_factory', 'مصنع أغذية', 'Food Factory', 'factory', 12),
      ('catering', 'تموين وحفلات', 'Catering', 'room_service', 13),
      ('food_truck', 'عربة طعام', 'Food Truck', 'local_shipping', 14),
      ('hotel', 'فندق', 'Hotel', 'hotel', 15),
      ('resort', 'منتجع', 'Resort', 'holiday_village', 16),
      ('wedding_hall', 'قاعة أفراح', 'Wedding Hall', 'celebration', 17),
      ('game_store', 'متجر ألعاب', 'Game Store', 'sports_esports', 18),
      ('pharmacy', 'صيدلية', 'Pharmacy', 'local_pharmacy', 19),
      ('clinic', 'عيادة', 'Clinic', 'medical_services', 20),
      ('school', 'مدرسة', 'School', 'school', 21),
      ('university', 'جامعة', 'University', 'account_balance', 22),
      ('bookstore', 'مكتبة', 'Bookstore', 'menu_book', 23),
      ('clothing_store', 'متجر ملابس', 'Clothing Store', 'checkroom', 24),
      ('electronics_store', 'متجر إلكترونيات', 'Electronics Store', 'devices', 25),
      ('furniture_store', 'متجر أثاث', 'Furniture Store', 'chair', 26),
      ('market', 'سوق', 'Market', 'storefront', 27),
      ('company', 'شركة', 'Company', 'business', 28),
      ('other', 'أخرى', 'Other', 'category', 99)
    ) AS requested(slug, name_ar, name_en, icon, sort_order)
  LOOP
    SELECT id INTO v_existing_id
    FROM public.marketplace_categories
    WHERE slug = item.slug
    LIMIT 1;

    IF v_existing_id IS NULL THEN
      INSERT INTO public.marketplace_categories
        (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
      VALUES
        (item.slug, item.name_ar, item.name_en, item.icon, true, item.sort_order, v_parent_id);
    ELSE
      UPDATE public.marketplace_categories
      SET parent_id = v_parent_id,
          name_ar = item.name_ar,
          name_en = item.name_en,
          icon = item.icon,
          is_active = true,
          sort_order = item.sort_order
      WHERE id = v_existing_id;
    END IF;
  END LOOP;
END $$;

COMMIT;
