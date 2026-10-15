-- Public provider projections and review projections are read-only contracts.
-- Explicitly revoke every mutation privilege because earlier view grants may
-- have persisted across view recreation.
BEGIN;

REVOKE ALL PRIVILEGES ON TABLE public.published_service_providers
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.published_service_providers
  TO anon, authenticated;

REVOKE ALL PRIVILEGES ON TABLE public.published_service_reviews
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.published_service_reviews
  TO anon, authenticated;

COMMIT;
