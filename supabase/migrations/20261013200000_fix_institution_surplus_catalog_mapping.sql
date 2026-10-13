BEGIN;

-- The surplus track is intentionally limited to hotels and wedding halls.
-- Keep both catalog entries active under the institution-offers root so the
-- Home page and the institution publisher use the same category tree.
DO $$
DECLARE
  v_root_id uuid;
  v_type text;
BEGIN
  SELECT id
    INTO v_root_id
  FROM public.marketplace_categories
  WHERE parent_id IS NULL
    AND slug = 'institution-offers'
  LIMIT 1;

  IF v_root_id IS NULL THEN
    RAISE EXCEPTION 'institution-offers root category is missing';
  END IF;

  FOREACH v_type IN ARRAY ARRAY['hotel', 'wedding_hall']
  LOOP
    INSERT INTO public.marketplace_categories
      (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
    SELECT
      v_type,
      CASE v_type
        WHEN 'hotel' THEN 'فندق'
        ELSE 'قاعة أفراح'
      END,
      CASE v_type
        WHEN 'hotel' THEN 'Hotel'
        ELSE 'Wedding Hall'
      END,
      CASE v_type
        WHEN 'hotel' THEN 'hotel'
        ELSE 'celebration'
      END,
      true,
      CASE v_type WHEN 'hotel' THEN 30 ELSE 31 END,
      v_root_id
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.marketplace_categories c
      WHERE c.parent_id = v_root_id
        AND c.slug = v_type
    );

    UPDATE public.marketplace_categories
    SET is_active = true
    WHERE parent_id = v_root_id
      AND slug = v_type;
  END LOOP;
END $$;

-- Repair existing rows that were created before the institution type mapping
-- was enabled, or that still point at an old/incorrect category.
UPDATE public.institution_offers AS io
SET marketplace_category_id = c.id
FROM public.institutions AS i
JOIN public.marketplace_categories AS root
  ON root.parent_id IS NULL
 AND root.slug = 'institution-offers'
JOIN public.marketplace_categories AS c
  ON c.parent_id = root.id
 AND c.slug = lower(btrim(i.institution_type))
WHERE io.institution_id = i.id
  AND lower(btrim(i.institution_type)) IN ('hotel', 'wedding_hall')
  AND io.marketplace_category_id IS DISTINCT FROM c.id;

COMMIT;
