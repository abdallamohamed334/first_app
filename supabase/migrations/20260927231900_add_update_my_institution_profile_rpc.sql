-- Allow an authenticated institution owner to edit profile fields only.
-- user_id, status, is_verified, and ownership are intentionally immutable here.

CREATE OR REPLACE FUNCTION public.update_my_institution_profile(
  p_name text DEFAULT NULL,
  p_institution_type text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_logo_url text DEFAULT NULL,
  p_cover_image_url text DEFAULT NULL
)
RETURNS public.institutions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution public.institutions;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.institutions
  SET
    name = COALESCE(NULLIF(trim(p_name), ''), name),
    institution_type = COALESCE(NULLIF(trim(p_institution_type), ''), institution_type),
    phone = COALESCE(NULLIF(trim(p_phone), ''), phone),
    city = COALESCE(NULLIF(trim(p_city), ''), city),
    address = COALESCE(NULLIF(trim(p_address), ''), address),
    description = COALESCE(NULLIF(trim(p_description), ''), description),
    logo_url = COALESCE(NULLIF(trim(p_logo_url), ''), logo_url),
    cover_image_url = COALESCE(NULLIF(trim(p_cover_image_url), ''), cover_image_url),
    updated_at = now()
  WHERE user_id = auth.uid()
  RETURNING * INTO v_institution;

  IF v_institution.id IS NULL THEN
    RAISE EXCEPTION 'No institution is linked to the current account';
  END IF;

  RETURN v_institution;
END;
$function$;
