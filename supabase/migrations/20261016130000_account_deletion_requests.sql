BEGIN;

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL CHECK (char_length(identifier) BETWEEN 5 AND 160),
  source text NOT NULL DEFAULT 'web' CHECK (source IN ('web', 'support')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'completed', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.account_deletion_requests FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS account_deletion_requests_admin_read ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_admin_read
  ON public.account_deletion_requests FOR SELECT TO authenticated
  USING (public.is_admin_actor());
DROP POLICY IF EXISTS account_deletion_requests_admin_update ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_admin_update
  ON public.account_deletion_requests FOR UPDATE TO authenticated
  USING (public.is_admin_actor()) WITH CHECK (public.is_admin_actor());

COMMIT;
