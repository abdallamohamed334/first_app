-- Normalize marketplace ownership of home-restaurant offers and keep the
-- institution catalog limited to institution categories.
BEGIN;

DO $$
DECLARE
  v_institution_root uuid;
  v_home_root uuid;
  v_home_food uuid;
  v_home_sweets uuid;
BEGIN
  SELECT id INTO v_institution_root
  FROM public.marketplace_categories
  WHERE slug = 'institution-offers' AND parent_id IS NULL
  LIMIT 1;

  SELECT id INTO v_home_root
  FROM public.marketplace_categories
  WHERE slug = 'home-restaurants'
  LIMIT 1;

  IF v_home_root IS NULL THEN
    INSERT INTO public.marketplace_categories
      (slug, name_ar, name_en, icon, is_active, sort_order, parent_id)
    VALUES
      ('home-restaurants', 'مطعم بيتي', 'Home Restaurant', 'restaurant', true, 11, NULL)
    RETURNING id INTO v_home_root;
  ELSE
    UPDATE public.marketplace_categories
    SET name_ar = 'مطعم بيتي', name_en = 'Home Restaurant', icon = 'restaurant',
        is_active = true, sort_order = 11, parent_id = NULL
    WHERE id = v_home_root;
  END IF;

  -- The home-restaurant subcategories belong to the top-level home category.
  UPDATE public.marketplace_categories
  SET parent_id = v_home_root, is_active = true
  WHERE slug IN ('home-sweets', 'home-food');

  -- Household items are not institution-offer categories.
  UPDATE public.marketplace_categories
  SET is_active = false
  WHERE parent_id = v_institution_root
    AND slug IN ('household-items', 'home-restaurants');

  SELECT id INTO v_home_sweets FROM public.marketplace_categories
  WHERE slug = 'home-sweets' AND parent_id = v_home_root LIMIT 1;
  SELECT id INTO v_home_food FROM public.marketplace_categories
  WHERE slug = 'home-food' AND parent_id = v_home_root LIMIT 1;

  -- Backfill existing rows into the same tree used by the app.
  UPDATE public.institution_offers io
  SET marketplace_category_id = CASE
    WHEN i.institution_type = 'home_restaurant'
      AND lower(btrim(coalesce(io.category, ''))) IN ('home_sweets', 'home-sweets', 'sweets', 'dessert')
      THEN v_home_sweets
    WHEN i.institution_type = 'home_restaurant' THEN v_home_food
    WHEN i.institution_type = 'household_goods' THEN NULL
    ELSE io.marketplace_category_id
  END
  FROM public.institutions i
  WHERE i.id = io.institution_id;
END $$;

CREATE OR REPLACE FUNCTION public.sync_institution_offer_catalog_category()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type text;
  v_category_id uuid;
  v_institution_root uuid;
  v_home_root uuid;
  v_target_slug text;
BEGIN
  SELECT lower(btrim(institution_type)) INTO v_type
  FROM public.institutions WHERE id = NEW.institution_id;

  SELECT id INTO v_institution_root FROM public.marketplace_categories
  WHERE slug = 'institution-offers' AND parent_id IS NULL LIMIT 1;
  SELECT id INTO v_home_root FROM public.marketplace_categories
  WHERE slug = 'home-restaurants' AND parent_id IS NULL LIMIT 1;

  IF v_type IN ('home_restaurant', 'home-restaurant', 'home_restaurants', 'home-restaurants') THEN
    v_target_slug := CASE lower(btrim(coalesce(NEW.category, '')))
      WHEN 'home_sweets' THEN 'home-sweets'
      WHEN 'home-sweets' THEN 'home-sweets'
      WHEN 'sweets' THEN 'home-sweets'
      WHEN 'dessert' THEN 'home-sweets'
      ELSE 'home-food'
    END;
    SELECT id INTO v_category_id FROM public.marketplace_categories
    WHERE slug = v_target_slug AND parent_id = v_home_root AND is_active = true LIMIT 1;
  ELSIF v_type = 'household_goods' THEN
    NEW.marketplace_category_id := NULL;
    RETURN NEW;
  ELSE
    SELECT id INTO v_category_id FROM public.marketplace_categories
    WHERE slug = CASE v_type
      WHEN 'supermarket' THEN 'grocery'
      WHEN 'grocery' THEN 'grocery'
      WHEN 'meat_shop' THEN 'meat_shop'
      WHEN 'butcher' THEN 'butcher'
      ELSE coalesce(nullif(v_type, ''), 'other')
    END
      AND parent_id = v_institution_root AND is_active = true LIMIT 1;
  END IF;

  NEW.marketplace_category_id := v_category_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_institution_offer_catalog_category ON public.institution_offers;
CREATE TRIGGER trg_sync_institution_offer_catalog_category
BEFORE INSERT OR UPDATE OF institution_id, marketplace_category_id, category
ON public.institution_offers FOR EACH ROW
EXECUTE FUNCTION public.sync_institution_offer_catalog_category();

CREATE OR REPLACE FUNCTION public.get_nearby_marketplace_category_offers(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision DEFAULT 70,
  p_limit_per_category integer DEFAULT 8
)
RETURNS TABLE(
  root_category_id uuid,
  root_category_slug text,
  root_category_name_ar text,
  offer_category_id uuid,
  offer_category_name_ar text,
  offer_id uuid,
  title text,
  description text,
  price numeric,
  original_price numeric,
  images text[],
  owner_type text,
  owner_name text,
  owner_logo text,
  latitude double precision,
  longitude double precision,
  status text,
  created_at timestamptz,
  distance_meters double precision,
  raw jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH RECURSIVE roots AS (
    SELECT c.id, c.id AS root_id, c.slug, c.name_ar, c.sort_order, c.is_active
    FROM public.marketplace_categories c
    WHERE c.parent_id IS NULL
      AND c.is_active = true
      AND c.slug NOT IN ('food', 'foods', 'restaurant', 'restaurants')
  ),
  category_tree AS (
    SELECT r.id, r.root_id, r.slug, r.name_ar, r.is_active
    FROM roots r
    UNION ALL
    SELECT child.id, tree.root_id, child.slug, child.name_ar, child.is_active
    FROM public.marketplace_categories child
    JOIN category_tree tree ON tree.id = child.parent_id
    WHERE child.is_active = true
  ),
  community_candidates AS (
    SELECT
      tree.root_id,
      tree.slug AS offer_slug,
      tree.name_ar AS offer_name,
      co.marketplace_category_id AS offer_category_id,
      co.id AS offer_id,
      co.title,
      co.description,
      co.price,
      NULL::numeric AS original_price,
      CASE
        WHEN co.image IS NOT NULL AND btrim(co.image) <> '' THEN
          ARRAY[co.image]::text[] || COALESCE(co.images, ARRAY[]::text[])
        ELSE COALESCE(co.images, ARRAY[]::text[])
      END AS images,
      'community'::text AS owner_type,
      u.name AS owner_name,
      u.avatar_url AS owner_logo,
      co.latitude::double precision,
      co.longitude::double precision,
      co.status,
      co.created_at,
      CASE
        WHEN co.latitude IS NULL OR co.longitude IS NULL THEN NULL::double precision
        ELSE 6371000 * 2 * asin(sqrt(
          power(sin(radians(co.latitude - p_latitude) / 2), 2) +
          cos(radians(p_latitude)) * cos(radians(co.latitude)) *
          power(sin(radians(co.longitude - p_longitude) / 2), 2)
        ))
      END AS distance_meters,
      jsonb_build_object(
        'id', co.id,
        'title', co.title,
        'description', co.description,
        'price', co.price,
        'image', co.image,
        'images', co.images,
        'marketplace_category_id', co.marketplace_category_id,
        'status', co.status,
        'created_at', co.created_at,
        'updated_at', co.updated_at,
        'latitude', co.latitude,
        'longitude', co.longitude
      ) AS raw
    FROM public.community_offers co
    JOIN category_tree tree ON tree.id = co.marketplace_category_id
    LEFT JOIN public.users u ON u.id = co.owner_id
    WHERE co.status = 'available'
      AND (co.expires_at IS NULL OR co.expires_at > now())
      AND co.latitude IS NOT NULL
      AND co.longitude IS NOT NULL
      AND (auth.uid() IS NULL OR NOT EXISTS (
        SELECT 1
        FROM public.blocked_users blocked
        WHERE blocked.blocker_id = auth.uid()
          AND blocked.blocked_id = co.owner_id
      ))
  ),
  institution_candidates AS (
    SELECT
      tree.root_id,
      tree.slug AS offer_slug,
      tree.name_ar AS offer_name,
      tree.id AS offer_category_id,
      io.id AS offer_id,
      io.title,
      io.description,
      io.symbolic_price AS price,
      io.original_price,
      COALESCE(io.images, ARRAY[]::text[]) AS images,
      'institution'::text AS owner_type,
      i.name AS owner_name,
      i.logo_url AS owner_logo,
      i.latitude::double precision,
      i.longitude::double precision,
      io.status,
      io.created_at,
      CASE
        WHEN i.latitude IS NULL OR i.longitude IS NULL THEN NULL::double precision
        ELSE 6371000 * 2 * asin(sqrt(
          power(sin(radians(i.latitude - p_latitude) / 2), 2) +
          cos(radians(p_latitude)) * cos(radians(i.latitude)) *
          power(sin(radians(i.longitude - p_longitude) / 2), 2)
        ))
      END AS distance_meters,
      jsonb_build_object(
        'id', io.id,
        'title', io.title,
        'description', io.description,
        'symbolic_price', io.symbolic_price,
        'original_price', io.original_price,
        'images', io.images,
        'marketplace_category_id', io.marketplace_category_id,
        'status', io.status,
        'quantity', io.quantity,
        'remaining_quantity', io.remaining_quantity,
        'pickup_location', io.pickup_location,
        'expires_at', io.expires_at,
        'pickup_before', io.pickup_before,
        'created_at', io.created_at,
        'updated_at', io.updated_at,
        'institution_id', io.institution_id,
        'institutions', jsonb_build_object(
          'id', i.id,
          'name', i.name,
          'logo_url', i.logo_url,
          'institution_type', i.institution_type,
          'address', i.address,
          'latitude', i.latitude,
          'longitude', i.longitude
        )
      ) AS raw
    FROM public.institution_offers io
    JOIN public.institutions i ON i.id = io.institution_id
    JOIN category_tree tree
      ON tree.id = io.marketplace_category_id
     AND tree.is_active = true
    WHERE io.status = 'active'
      AND io.expires_at > now()
      AND COALESCE(io.remaining_quantity, io.quantity, 0) > 0
      AND io.deleted_at IS NULL
      AND i.status IN ('active', 'approved')
      AND i.latitude IS NOT NULL
      AND i.longitude IS NOT NULL
  ),
  candidates AS (
    SELECT * FROM community_candidates
    UNION ALL
    SELECT * FROM institution_candidates
  ),
  nearby AS (
    SELECT
      candidates.*,
      row_number() OVER (
        PARTITION BY candidates.root_id
        ORDER BY candidates.distance_meters NULLS LAST, candidates.created_at DESC
      ) AS category_rank
    FROM candidates
    WHERE candidates.distance_meters IS NOT NULL
      AND candidates.distance_meters <= LEAST(GREATEST(COALESCE(p_radius_km, 70), 1), 200) * 1000
  )
  SELECT
    nearby.root_id,
    root.slug,
    root.name_ar,
    nearby.offer_category_id,
    nearby.offer_name,
    nearby.offer_id,
    nearby.title,
    nearby.description,
    nearby.price,
    nearby.original_price,
    nearby.images,
    nearby.owner_type,
    nearby.owner_name,
    nearby.owner_logo,
    nearby.latitude,
    nearby.longitude,
    nearby.status,
    nearby.created_at,
    nearby.distance_meters,
    nearby.raw
  FROM nearby
  JOIN roots root ON root.id = nearby.root_id
  WHERE nearby.category_rank <= LEAST(GREATEST(COALESCE(p_limit_per_category, 8), 1), 24)
  ORDER BY root.sort_order NULLS LAST, nearby.distance_meters ASC, nearby.created_at DESC;
$$;



CREATE INDEX IF NOT EXISTS idx_marketplace_categories_active_parent_sort
  ON public.marketplace_categories (parent_id, is_active, sort_order);
COMMIT;
