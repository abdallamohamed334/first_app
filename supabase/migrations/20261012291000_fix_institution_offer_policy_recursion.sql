-- The requester policy previously queried institution_offer_requests directly.
-- institution_offer_requests has an institution-side policy that joins back to
-- institution_offers, so PostgreSQL recursively evaluated the two policies.
-- Keep requester visibility, but move the ownership check into a tightly scoped
-- SECURITY DEFINER helper that runs with the policy owner privileges.

CREATE OR REPLACE FUNCTION public.is_requester_for_institution_offer(p_offer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.institution_offer_requests r
    WHERE r.offer_id = p_offer_id
      AND r.requester_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_requester_for_institution_offer(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_requester_for_institution_offer(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_requester_for_institution_offer(uuid) TO authenticated;

DROP POLICY IF EXISTS institution_offers_requester_select
  ON public.institution_offers;

CREATE POLICY institution_offers_requester_select
  ON public.institution_offers
  FOR SELECT TO authenticated
  USING (public.is_requester_for_institution_offer(id));
