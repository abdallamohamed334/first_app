-- Allow the requester to cancel an institution offer request before pickup.
-- The request and offer are locked in one transaction so reserved stock is
-- restored exactly once, even when cancellation races with another action.

CREATE OR REPLACE FUNCTION public.cancel_institution_offer_request(
  p_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid;
  v_request public.institution_offer_requests%rowtype;
  v_offer public.institution_offers%rowtype;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT *
  INTO v_request
  FROM public.institution_offer_requests
  WHERE id = p_request_id
    AND requester_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF v_request.status NOT IN ('pending', 'accepted', 'ready_for_pickup') THEN
    RAISE EXCEPTION 'Request cannot be cancelled';
  END IF;

  SELECT *
  INTO v_offer
  FROM public.institution_offers
  WHERE id = v_request.offer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer not found';
  END IF;

  IF v_offer.reserved_quantity < v_request.quantity THEN
    RAISE EXCEPTION 'Inventory inconsistency detected for request %', p_request_id;
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'cancelled',
      cancellation_reason = nullif(trim(p_reason), ''),
      pickup_code = NULL,
      pickup_token_hash = NULL,
      pickup_token_expires_at = NULL,
      pickup_token_used_at = NULL,
      updated_at = now()
  WHERE id = p_request_id;

  UPDATE public.institution_offers
  SET remaining_quantity = remaining_quantity + v_request.quantity,
      reserved_quantity = reserved_quantity - v_request.quantity,
      status = CASE WHEN status = 'sold_out' THEN 'active' ELSE status END,
      updated_at = now()
  WHERE id = v_offer.id;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_institution_offer_request(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_institution_offer_request(uuid, text) TO authenticated;
