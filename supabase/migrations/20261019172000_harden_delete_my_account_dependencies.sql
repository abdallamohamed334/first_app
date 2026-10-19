-- Remove user-owned dependent rows before deleting institutions/users.
-- This closes RESTRICT foreign-key paths for institution offers and donations.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_institution_ids uuid[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  SELECT COALESCE(array_agg(id), ARRAY[]::uuid[])
  INTO v_institution_ids
  FROM public.institutions
  WHERE user_id = v_user_id;

  -- Existing RESTRICT relations pointing directly to the user.
  DELETE FROM public.account_cases WHERE target_user_id = v_user_id;
  DELETE FROM public.institution_offer_requests WHERE requester_id = v_user_id;
  DELETE FROM public.delivery_tasks WHERE volunteer_id = v_user_id;
  DELETE FROM public.volunteer_points_awards WHERE volunteer_id = v_user_id;
  DELETE FROM public.restaurant_charity_pickup_codes
    WHERE issued_by_restaurant_user_id = v_user_id;

  UPDATE public.service_providers SET verified_by = NULL WHERE verified_by = v_user_id;
  UPDATE public.food_offers SET reserved_by = NULL WHERE reserved_by = v_user_id;

  IF cardinality(v_institution_ids) > 0 THEN
    -- Requests, banners, and dependent rows tied to institution offers.
    DELETE FROM public.institution_offer_requests
    WHERE offer_id IN (
      SELECT id FROM public.institution_offers
      WHERE institution_id = ANY(v_institution_ids)
    );
    DELETE FROM public.home_banners
    WHERE offer_id IN (
      SELECT id FROM public.institution_offers
      WHERE institution_id = ANY(v_institution_ids)
    );

    -- Legacy/core institution offers have their own RESTRICT relation.
    DELETE FROM public.institution_offers_core
    WHERE institution_id = ANY(v_institution_ids);
    DELETE FROM public.institution_offers
    WHERE institution_id = ANY(v_institution_ids);

    -- Remove delivery and rescue records before their parent donations.
    DELETE FROM public.deliveries
    WHERE donation_id IN (
      SELECT id FROM public.donations
      WHERE institution_id = ANY(v_institution_ids)
    );
    DELETE FROM public.rescued_meals
    WHERE donation_id IN (
      SELECT id FROM public.donations
      WHERE institution_id = ANY(v_institution_ids)
    );
    DELETE FROM public.delivery_tasks
    WHERE donation_id IN (
      SELECT id FROM public.donations
      WHERE institution_id = ANY(v_institution_ids)
    );
    DELETE FROM public.donations
    WHERE institution_id = ANY(v_institution_ids);

    DELETE FROM public.institution_charity_donations
    WHERE institution_id = ANY(v_institution_ids);
  END IF;

  DELETE FROM public.institutions WHERE user_id = v_user_id;
  DELETE FROM public.users WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
