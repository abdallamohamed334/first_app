-- Harden the public reviews view without changing its public read contract.
-- The underlying service_reviews table already has an intentional public SELECT policy.
-- Do not apply security_invoker to published_service_providers here: that view
-- intentionally masks contact columns and currently relies on definer execution.
BEGIN;

ALTER VIEW public.published_service_reviews SET (security_invoker = true);

REVOKE ALL ON public.published_service_reviews FROM PUBLIC;
GRANT SELECT ON public.published_service_reviews TO anon, authenticated;

COMMIT;
