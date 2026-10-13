BEGIN;

-- Browser roles must never read legacy authentication material or account
-- ownership metadata from the institutions base table. Public offer reads use
-- the allowlisted columns below; the owner context is returned by an RPC.
REVOKE ALL PRIVILEGES ON TABLE public.institutions FROM anon, authenticated;

GRANT SELECT (
  id,
  name,
  institution_type,
  description,
  address,
  city,
  phone,
  logo_url,
  cover_image_url,
  latitude,
  longitude,
  status,
  is_verified,
  created_at,
  updated_at
) ON public.institutions TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.institutions FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_institution_context()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', i.id,
    'user_id', i.user_id,
    'name', i.name,
    'institution_type', i.institution_type,
    'phone', i.phone,
    'email', i.email,
    'logo_url', i.logo_url,
    'cover_image_url', i.cover_image_url,
    'description', i.description,
    'city', i.city,
    'address', i.address,
    'status', i.status,
    'is_verified', i.is_verified
  )
  FROM public.institutions AS i
  WHERE i.user_id = auth.uid()
  ORDER BY i.created_at ASC
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_my_institution_context() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_institution_context() TO authenticated;

COMMIT;
