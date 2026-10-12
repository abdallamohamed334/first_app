-- Let a requester keep seeing the offer details attached to their own request,
-- even after the offer is sold out, expired, paused, or deleted.
-- This does not expose unrelated offers: the row must be linked to the current user.
BEGIN;

CREATE POLICY institution_offers_requester_select
  ON public.institution_offers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.institution_offer_requests r
      WHERE r.offer_id = institution_offers.id
        AND r.requester_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS institution_offer_requests_requester_offer_idx
  ON public.institution_offer_requests (requester_id, offer_id, created_at DESC);

COMMIT;
