BEGIN;
CREATE INDEX IF NOT EXISTS idx_deliveries_volunteer_status
  ON public.deliveries (volunteer_id, status);
CREATE INDEX IF NOT EXISTS idx_donations_donor_status
  ON public.donations (donor_id, status);
COMMIT;
