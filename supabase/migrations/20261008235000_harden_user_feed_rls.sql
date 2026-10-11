BEGIN;

-- Favorites are private user-owned rows. Keep the table-level operations needed
-- by the Flutter upsert/delete flow, but bind every operation to auth.uid().
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.favorites FROM anon, authenticated;
REVOKE SELECT (user_id, target_type, target_id, created_at),
       INSERT (user_id, target_type, target_id, created_at),
       UPDATE (user_id, target_type, target_id, created_at)
  ON public.favorites FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.favorites TO authenticated;
DROP POLICY IF EXISTS favorites_owner_select ON public.favorites;
DROP POLICY IF EXISTS favorites_owner_insert ON public.favorites;
DROP POLICY IF EXISTS favorites_owner_update ON public.favorites;
DROP POLICY IF EXISTS favorites_owner_delete ON public.favorites;
CREATE POLICY favorites_owner_select
  ON public.favorites FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY favorites_owner_insert
  ON public.favorites FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY favorites_owner_update
  ON public.favorites FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
CREATE POLICY favorites_owner_delete
  ON public.favorites FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- These are public-to-signed-in configuration/catalog rows, not per-user data.
ALTER TABLE public.business_capabilities ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.business_capabilities FROM anon, authenticated;
REVOKE SELECT (id, business_type, capability, is_enabled, created_at)
  ON public.business_capabilities FROM anon, authenticated;
GRANT SELECT (business_type, capability, is_enabled)
  ON public.business_capabilities TO authenticated;
DROP POLICY IF EXISTS business_capabilities_enabled_read ON public.business_capabilities;
CREATE POLICY business_capabilities_enabled_read
  ON public.business_capabilities FOR SELECT TO authenticated
  USING (is_enabled IS TRUE);

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.rewards FROM anon, authenticated;
REVOKE SELECT (id, title, description, points_required, image, is_active,
               created_at, stock, category)
  ON public.rewards FROM anon, authenticated;
GRANT SELECT (id, title, description, points_required, image, is_active, category)
  ON public.rewards TO authenticated;
DROP POLICY IF EXISTS rewards_active_read ON public.rewards;
CREATE POLICY rewards_active_read
  ON public.rewards FOR SELECT TO authenticated
  USING (is_active IS TRUE);

-- Volunteers may read only their own assigned tasks. Pending tasks are available
-- through the sanitized nearby_rescue_tasks RPC below, not through table SELECT.
ALTER TABLE public.delivery_tasks ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.delivery_tasks FROM anon, authenticated;
REVOKE SELECT (id, donation_id, charity_id, pickup_address, delivery_address,
               pickup_before, estimated_weight, estimated_distance, status,
               volunteer_id, created_at)
  ON public.delivery_tasks FROM anon, authenticated;
GRANT SELECT ON TABLE public.delivery_tasks TO authenticated;
DROP POLICY IF EXISTS delivery_tasks_assigned_volunteer_read ON public.delivery_tasks;
CREATE POLICY delivery_tasks_assigned_volunteer_read
  ON public.delivery_tasks FOR SELECT TO authenticated
  USING (volunteer_id = auth.uid());

CREATE OR REPLACE FUNCTION public.nearby_rescue_tasks(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 15,
  p_limit integer DEFAULT 5
)
RETURNS TABLE(
  id uuid,
  title text,
  quantity integer,
  pickup_address text,
  pickup_before timestamp with time zone,
  distance_km double precision,
  donor_name text,
  charity_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_radius double precision;
  v_limit integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول';
  END IF;
  IF p_lat IS NULL OR p_lat < -90 OR p_lat > 90
     OR p_lng IS NULL OR p_lng < -180 OR p_lng > 180
     OR p_radius_km IS NULL OR p_radius_km <= 0 THEN
    RETURN;
  END IF;

  v_radius := LEAST(p_radius_km, 100.0);
  v_limit := LEAST(GREATEST(COALESCE(p_limit, 5), 1), 50);

  RETURN QUERY
  WITH candidates AS (
    SELECT dt.id,
           COALESCE(d.description, 'تبرع طعام') AS title,
           COALESCE(d.quantity, 1)::integer AS quantity,
           dt.pickup_before,
           (6371.0 * acos(LEAST(1.0, GREATEST(-1.0,
             cos(radians(p_lat)) * cos(radians(ch.latitude)) *
             cos(radians(ch.longitude) - radians(p_lng)) +
             sin(radians(p_lat)) * sin(radians(ch.latitude))
           ))))::double precision AS distance_km,
           ch.name AS charity_name
    FROM public.delivery_tasks dt
    JOIN public.donations d ON d.id = dt.donation_id
    JOIN public.charities ch ON ch.id = dt.charity_id
    WHERE dt.status = 'pending'
      AND dt.volunteer_id IS NULL
      AND dt.pickup_before > now()
      AND ch.latitude BETWEEN -90 AND 90
      AND ch.longitude BETWEEN -180 AND 180
  )
  SELECT c.id,
         c.title,
         c.quantity,
         'موقع الاستلام الدقيق متاح بعد قبول المهمة'::text,
         c.pickup_before,
         c.distance_km,
         'متبرع'::text,
         c.charity_name
  FROM candidates c
  WHERE c.distance_km <= v_radius
  ORDER BY c.pickup_before ASC, c.distance_km ASC
  LIMIT v_limit;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.nearby_rescue_tasks(double precision, double precision, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_rescue_tasks(double precision, double precision, double precision, integer) TO authenticated;

-- The live function referenced a non-existent delivery_tasks.updated_at column,
-- causing every otherwise-valid claim to fail. Keep the atomic claim without it.
CREATE OR REPLACE FUNCTION public.claim_delivery_task(p_task_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_updated integer;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RETURN false;
  END IF;

  UPDATE public.delivery_tasks
     SET volunteer_id = p_user_id,
         status = 'assigned'
   WHERE id = p_task_id
     AND status = 'pending'
     AND volunteer_id IS NULL
     AND pickup_before > now();

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END;
$function$;
REVOKE EXECUTE ON FUNCTION public.claim_delivery_task(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_delivery_task(uuid, uuid) TO authenticated;

COMMIT;
