-- RLS remains the row-level security boundary; authenticated needs table SELECT
-- so policies that verify institution ownership can be evaluated by PostgREST.
GRANT SELECT ON TABLE public.institutions TO authenticated;
