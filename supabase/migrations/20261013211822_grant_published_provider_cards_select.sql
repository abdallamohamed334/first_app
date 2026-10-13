-- The public provider view uses security_invoker=true, so the browser roles
-- need base-table SELECT. RLS remains the row-level visibility boundary.
GRANT SELECT ON TABLE public.published_service_provider_cards TO anon, authenticated;
