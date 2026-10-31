BEGIN;

CREATE TABLE IF NOT EXISTS public.provider_completed_works (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES public.service_providers(id) ON DELETE CASCADE,
  executed_on date NOT NULL DEFAULT CURRENT_DATE,
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 1 AND 1000),
  amount numeric(12,2),
  photo_paths text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT provider_completed_works_amount_nonnegative
    CHECK (amount IS NULL OR (amount >= 0 AND amount <> 'NaN'::numeric)),
  CONSTRAINT provider_completed_works_photo_limit
    CHECK (cardinality(photo_paths) BETWEEN 1 AND 6)
);

CREATE INDEX IF NOT EXISTS provider_completed_works_provider_date_idx
  ON public.provider_completed_works(provider_id, executed_on DESC, created_at DESC);

ALTER TABLE public.provider_completed_works ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.provider_completed_works FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS provider_completed_works_public_read
  ON public.provider_completed_works;
CREATE POLICY provider_completed_works_public_read
  ON public.provider_completed_works
  FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS provider_completed_works_owner_insert
  ON public.provider_completed_works;
CREATE POLICY provider_completed_works_owner_insert
  ON public.provider_completed_works
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.service_providers sp
      WHERE sp.id = provider_completed_works.provider_id
        AND sp.user_id = (SELECT auth.uid())
        AND sp.verification_status = 'approved'
        AND sp.is_active = true
    )
    AND NOT EXISTS (
      SELECT 1
      FROM unnest(provider_completed_works.photo_paths) AS paths(path)
      WHERE path !~ ('^' || (SELECT auth.uid())::text || '/completed_work/[^/]+[.]webp$')
    )
  );

REVOKE ALL ON TABLE public.provider_completed_works FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.provider_completed_works TO anon, authenticated;
GRANT INSERT ON TABLE public.provider_completed_works TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
