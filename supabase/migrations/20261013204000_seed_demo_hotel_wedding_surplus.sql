-- Demo data only: one approved hotel and one approved wedding hall with active surplus offers.
-- Demo institutions are attached to existing users without an institution profile,
-- preserving the one-institution-per-user constraint.
DO $$
DECLARE
  v_hotel_owner_id uuid;
  v_hall_owner_id uuid;
  v_hotel_id uuid;
  v_hall_id uuid;
  v_root_id uuid;
  v_hotel_category_id uuid;
  v_hall_category_id uuid;
BEGIN
  SELECT u.id INTO v_hotel_owner_id
  FROM public.users u
  LEFT JOIN public.institutions i ON i.user_id = u.id
  WHERE i.id IS NULL AND lower(coalesce(u.role, '')) = 'user'
  ORDER BY u.created_at LIMIT 1;

  SELECT u.id INTO v_hall_owner_id
  FROM public.users u
  LEFT JOIN public.institutions i ON i.user_id = u.id
  WHERE i.id IS NULL AND lower(coalesce(u.role, '')) = 'user'
    AND u.id IS DISTINCT FROM v_hotel_owner_id
  ORDER BY u.created_at OFFSET 0 LIMIT 1;

  IF v_hotel_owner_id IS NULL OR v_hall_owner_id IS NULL THEN
    RAISE EXCEPTION 'Cannot seed demo institutions: two unassigned user profiles are required';
  END IF;

  SELECT id INTO v_root_id
  FROM public.marketplace_categories
  WHERE slug = 'institution-offers' AND parent_id IS NULL LIMIT 1;
  SELECT id INTO v_hotel_category_id
  FROM public.marketplace_categories
  WHERE slug = 'hotel' AND parent_id = v_root_id LIMIT 1;
  SELECT id INTO v_hall_category_id
  FROM public.marketplace_categories
  WHERE slug = 'wedding_hall' AND parent_id = v_root_id LIMIT 1;

  IF v_hotel_category_id IS NULL OR v_hall_category_id IS NULL THEN
    RAISE EXCEPTION 'Cannot seed demo offers: hotel/wedding_hall categories are missing';
  END IF;

  SELECT id INTO v_hotel_id FROM public.institutions
  WHERE name = '[تجريبي] فندق النيل' AND institution_type = 'hotel' LIMIT 1;
  IF v_hotel_id IS NULL THEN
    INSERT INTO public.institutions (
      user_id, name, institution_type, description, city, address,
      latitude, longitude, status, is_verified, metadata
    ) VALUES (
      v_hotel_owner_id, '[تجريبي] فندق النيل', 'hotel',
      'حساب تجريبي لعرض فائض الطعام من الفنادق.', 'القاهرة',
      'وسط القاهرة - نقطة استلام تجريبية', 30.0444, 31.2357,
      'approved', true,
      jsonb_build_object('demo_seed', true, 'demo_scope', 'institution_surplus')
    ) RETURNING id INTO v_hotel_id;
  END IF;

  SELECT id INTO v_hall_id FROM public.institutions
  WHERE name = '[تجريبي] قاعة ليالي القاهرة' AND institution_type = 'wedding_hall' LIMIT 1;
  IF v_hall_id IS NULL THEN
    INSERT INTO public.institutions (
      user_id, name, institution_type, description, city, address,
      latitude, longitude, status, is_verified, metadata
    ) VALUES (
      v_hall_owner_id, '[تجريبي] قاعة ليالي القاهرة', 'wedding_hall',
      'حساب تجريبي لعرض فائض الطعام من قاعات الأفراح.', 'القاهرة',
      'مدينة نصر - نقطة استلام تجريبية', 30.0616, 31.3456,
      'approved', true,
      jsonb_build_object('demo_seed', true, 'demo_scope', 'institution_surplus')
    ) RETURNING id INTO v_hall_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.institution_offers
    WHERE institution_id = v_hotel_id
      AND title = '[تجريبي] وجبات فندقية فائضة - فندق النيل'
      AND deleted_at IS NULL
  ) THEN
    INSERT INTO public.institution_offers (
      institution_id, title, description, category, quantity,
      remaining_quantity, original_price, symbolic_price, images,
      pickup_location, expires_at, pickup_before, status,
      food_type, food_condition, requires_refrigeration,
      pickup_notes, contact_phone, latitude, longitude,
      marketplace_category_id
    ) VALUES (
      v_hotel_id, '[تجريبي] وجبات فندقية فائضة - فندق النيل',
      'وجبات طازجة فائضة من خدمة البوفيه اليومية، متاحة بسعر رمزي للاستلام في الموعد المحدد.',
      'food', 35, 35, 180, 25, ARRAY[]::text[],
      'فندق النيل - بوابة الخدمة', now() + interval '14 days', now() + interval '13 days',
      'active', 'وجبات جاهزة', 'good', true,
      'يرجى إحضار عبوة مناسبة والاستلام خلال فترة الاستلام.',
      (SELECT phone FROM public.institutions WHERE id = v_hotel_id),
      30.0444, 31.2357, v_hotel_category_id
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.institution_offers
    WHERE institution_id = v_hall_id
      AND title = '[تجريبي] فائض بوفيه مناسبات - قاعة ليالي القاهرة'
      AND deleted_at IS NULL
  ) THEN
    INSERT INTO public.institution_offers (
      institution_id, title, description, category, quantity,
      remaining_quantity, original_price, symbolic_price, images,
      pickup_location, expires_at, pickup_before, status,
      food_type, food_condition, requires_refrigeration,
      pickup_notes, contact_phone, latitude, longitude,
      marketplace_category_id
    ) VALUES (
      v_hall_id, '[تجريبي] فائض بوفيه مناسبات - قاعة ليالي القاهرة',
      'أصناف فائضة من بوفيه مناسبة، محفوظة بعناية ومتاحة للاستلام بسعر رمزي.',
      'food', 24, 24, 150, 20, ARRAY[]::text[],
      'قاعة ليالي القاهرة - مدخل الخدمة', now() + interval '14 days', now() + interval '13 days',
      'active', 'بوفيه مناسبات', 'good', true,
      'التواصل قبل الوصول والتأكد من موعد الاستلام.',
      (SELECT phone FROM public.institutions WHERE id = v_hall_id),
      30.0616, 31.3456, v_hall_category_id
    );
  END IF;
END $$;
