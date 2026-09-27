-- Institution charity donations are insertable only by the owning approved institution.
-- No new permission is added; only the impossible active status is corrected.

ALTER POLICY institution_donations_owner_insert
ON public.institution_charity_donations
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.institutions AS i
    WHERE i.id = institution_charity_donations.institution_id
      AND i.user_id = auth.uid()
      AND i.status = 'approved'
  )
);
