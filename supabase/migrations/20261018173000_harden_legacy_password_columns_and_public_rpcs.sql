BEGIN;

-- Legacy password columns are not part of Supabase Auth and must never be
-- readable or writable by client roles. Keep the columns for compatibility
-- until a separately verified data migration removes them.
REVOKE SELECT (password), INSERT (password), UPDATE (password)
  ON TABLE public.users, public.restaurants, public.charities
  FROM anon, authenticated;

-- The donor leaderboard is rendered inside the authenticated application.
-- It must not be callable by unauthenticated clients even though the function
-- only returns an aggregate/public projection.
REVOKE EXECUTE ON FUNCTION public.list_public_charity_donors()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_public_charity_donors()
  TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
