-- Provider OTP verification can complete before the client session is observable.
-- Return only login-routing state through a narrowly scoped definer RPC.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_provider_auth_state(p_user_id uuid)
RETURNS TABLE(
  id uuid,
  verification_status text,
  is_active boolean,
  verification_notes text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    sp.id,
    sp.verification_status::text,
    sp.is_active,
    sp.verification_notes
  FROM public.service_providers AS sp
  WHERE sp.user_id = p_user_id
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_provider_auth_state(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_provider_auth_state(uuid) TO anon, authenticated;
COMMIT;
