BEGIN;

-- Keep institution ownership checks working with column-level grants only.
-- The helper returns a boolean and never exposes the institution's user_id.
CREATE OR REPLACE FUNCTION public.user_owns_institution(p_institution_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.institutions AS i
    WHERE i.id = p_institution_id
      AND i.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.user_owns_institution(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_owns_institution(uuid) TO authenticated;

DROP POLICY IF EXISTS institution_offers_owner_select
  ON public.institution_offers;
CREATE POLICY institution_offers_owner_select
  ON public.institution_offers
  FOR SELECT TO authenticated
  USING (public.user_owns_institution(institution_id));

COMMIT;
