-- Reproducible security hardening applied to the linked Supabase project.

BEGIN;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offer_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_charity_points_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_capabilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_read_authenticated ON public.users;
DROP POLICY IF EXISTS "Users can update own data" ON public.users;
DROP POLICY IF EXISTS users_select_own ON public.users;
DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_select_own ON public.users
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY users_update_own ON public.users
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

ALTER VIEW public.active_food_offers SET (security_invoker = true);
ALTER VIEW public.active_institution_offers SET (security_invoker = true);
ALTER VIEW public.home_offers SET (security_invoker = true);
ALTER VIEW public.open_service_requests SET (security_invoker = true);
ALTER VIEW public.published_service_reviews SET (security_invoker = true);

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

DO $$
DECLARE f record;
BEGIN
  FOR f IN
    SELECT n.nspname AS schema_name, p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS identity_args
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
      AND p.proowner = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND NOT EXISTS (
        SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg
        WHERE cfg LIKE 'search_path=%'
      )
  LOOP
    EXECUTE format(
      'ALTER FUNCTION %I.%I(%s) SET search_path = public, pg_temp',
      f.schema_name, f.function_name, f.identity_args
    );
  END LOOP;
END $$;

DO $$
DECLARE f record;
BEGIN
  FOR f IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef = true
      AND p.proowner = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND (
        p.proname ~ '^(admin_|auto_|award_|can_|check_|cleanup_|expire_|generate_|guard_|handle_|increment_|notify_|test_|touch_|sync_)'
        OR p.proname IN (
          'institution_can_publish', 'issue_signup_email_code',
          'list_open_donations_for_volunteers', 'mark_community_offer_completed',
          'migrate_restaurant_to_business', 'get_random_bytes',
          'add_image_to_offer', 'assign_donation_volunteer',
          'complete_pickup_by_qr'
        )
      )
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      f.signature
    );
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.reserve_food_offer(
  p_offer_id uuid, p_user_id uuid, p_quantity integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE v_remaining integer; v_request_id uuid;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'UNAUTHORIZED');
  END IF;
  IF p_quantity IS NULL OR p_quantity < 1 OR p_quantity > 100 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'INVALID_QUANTITY');
  END IF;
  SELECT quantity - reserved_quantity INTO v_remaining
  FROM public.food_offers
  WHERE id = p_offer_id AND deleted_at IS NULL AND status = 'available'
    AND is_paused = false AND expiry_time > now() FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OFFER_UNAVAILABLE');
  END IF;
  IF v_remaining < p_quantity THEN
    RETURN jsonb_build_object('ok', false, 'error', 'INSUFFICIENT_QUANTITY', 'remaining', v_remaining);
  END IF;
  INSERT INTO public.offer_requests (offer_id, user_id, status, quantity)
  VALUES (p_offer_id, p_user_id, 'pending', p_quantity) RETURNING id INTO v_request_id;
  UPDATE public.food_offers
  SET reserved_quantity = reserved_quantity + p_quantity,
      status = CASE WHEN reserved_quantity + p_quantity >= quantity THEN 'reserved' ELSE status END,
      updated_at = now()
  WHERE id = p_offer_id;
  RETURN jsonb_build_object('ok', true, 'request_id', v_request_id);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.reserve_food_offer(uuid, uuid, integer) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.reserve_food_offer(uuid, uuid, integer) FROM anon, PUBLIC;

CREATE OR REPLACE FUNCTION public.claim_delivery_task(
  p_task_id uuid, p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE v_updated integer;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RETURN false;
  END IF;
  UPDATE public.delivery_tasks
     SET volunteer_id = p_user_id, status = 'assigned', updated_at = now()
   WHERE id = p_task_id AND status = 'pending' AND volunteer_id IS NULL;
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END;
$function$;
GRANT EXECUTE ON FUNCTION public.claim_delivery_task(uuid, uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_delivery_task(uuid, uuid) FROM anon, PUBLIC;

COMMIT;
