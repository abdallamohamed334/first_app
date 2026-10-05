BEGIN;

CREATE TABLE IF NOT EXISTS public.swap_listing_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.swap_listings(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN ('fraud', 'inappropriate', 'wrong_contact', 'duplicate', 'other')),
  details text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  resolution text
);

CREATE UNIQUE INDEX IF NOT EXISTS swap_listing_reports_one_open_per_user
  ON public.swap_listing_reports (listing_id, reporter_id)
  WHERE status IN ('open', 'reviewing');

CREATE INDEX IF NOT EXISTS swap_listing_reports_status_created_idx
  ON public.swap_listing_reports (status, created_at DESC);

ALTER TABLE public.swap_listing_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS swap_listing_reports_insert_own ON public.swap_listing_reports;
CREATE POLICY swap_listing_reports_insert_own
  ON public.swap_listing_reports FOR INSERT TO authenticated
  WITH CHECK (
    reporter_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.swap_listings listing
      WHERE listing.id = listing_id
        AND listing.owner_id <> auth.uid()
    )
  );

DROP POLICY IF EXISTS swap_listing_reports_read_own_or_admin ON public.swap_listing_reports;
CREATE POLICY swap_listing_reports_read_own_or_admin
  ON public.swap_listing_reports FOR SELECT TO authenticated
  USING (
    reporter_id = auth.uid()
    OR public.is_admin_actor()
  );

DROP POLICY IF EXISTS swap_listing_reports_admin_update ON public.swap_listing_reports;
CREATE POLICY swap_listing_reports_admin_update
  ON public.swap_listing_reports FOR UPDATE TO authenticated
  USING (public.is_admin_actor())
  WITH CHECK (public.is_admin_actor());

GRANT SELECT, INSERT ON public.swap_listing_reports TO authenticated;
GRANT UPDATE ON public.swap_listing_reports TO authenticated;

COMMIT;
