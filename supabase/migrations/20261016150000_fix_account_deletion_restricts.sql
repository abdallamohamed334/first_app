BEGIN;

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  -- Remove rows with RESTRICT foreign keys first.
  DELETE FROM public.account_cases WHERE target_user_id = v_user_id;
  DELETE FROM public.institution_offer_requests WHERE requester_id = v_user_id;
  DELETE FROM public.delivery_tasks WHERE volunteer_id = v_user_id;
  DELETE FROM public.volunteer_points_awards WHERE volunteer_id = v_user_id;
  DELETE FROM public.restaurant_charity_pickup_codes
    WHERE issued_by_restaurant_user_id = v_user_id;

  -- Preserve shared records while removing personal ownership references.
  UPDATE public.service_providers SET verified_by = NULL WHERE verified_by = v_user_id;
  UPDATE public.food_offers SET reserved_by = NULL WHERE reserved_by = v_user_id;

  -- Owned institution rows can cascade their owned offers and requests.
  DELETE FROM public.institutions WHERE user_id = v_user_id;

  -- The public profile deletion cascades the remaining user-owned rows.
  DELETE FROM public.users WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

COMMIT;
