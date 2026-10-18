BEGIN;

CREATE OR REPLACE FUNCTION public.admin_create_institution(
  p_user_id uuid,
  p_name text,
  p_email text,
  p_phone text DEFAULT NULL,
  p_institution_type text DEFAULT 'grocery',
  p_city text DEFAULT NULL,
  p_address text DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_status text DEFAULT 'pending',
  p_is_verified boolean DEFAULT false,
  p_login_otp text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, extensions, pg_temp
AS $$
DECLARE
  v_institution_id uuid;
  v_role text := current_setting('request.jwt.claim.role', true);
  v_type text := lower(trim(coalesce(p_institution_type, '')));
  v_status text := lower(trim(coalesce(p_status, 'pending')));
BEGIN
  IF v_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'admin_only';
  END IF;
  IF p_user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users au WHERE au.id = p_user_id LIMIT 1
  ) THEN
    RAISE EXCEPTION 'auth_user_not_found';
  END IF;
  IF nullif(btrim(coalesce(p_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'institution_name_required';
  END IF;
  IF lower(trim(coalesce(p_email, ''))) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' THEN
    RAISE EXCEPTION 'institution_email_invalid';
  END IF;
  IF v_type NOT IN ('grocery', 'supermarket', 'bakery', 'pastry_shop', 'restaurant', 'hotel', 'wedding_hall') THEN
    RAISE EXCEPTION 'institution_type_not_supported';
  END IF;
  IF v_status NOT IN ('pending', 'approved') THEN
    RAISE EXCEPTION 'institution_status_invalid';
  END IF;
  IF p_login_otp IS NULL OR p_login_otp !~ '^[0-9]{6}$' THEN
    RAISE EXCEPTION 'institution_otp_invalid';
  END IF;
  IF EXISTS (SELECT 1 FROM public.institutions WHERE user_id = p_user_id LIMIT 1) THEN
    RAISE EXCEPTION 'institution_already_exists';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.institutions
    WHERE lower(trim(email)) = lower(trim(p_email))
    LIMIT 1
  ) THEN
    RAISE EXCEPTION 'institution_email_already_exists';
  END IF;

  INSERT INTO public.users (
    id, name, email, phone, phone_normalized,
    user_type, role, is_verified, is_phone_verified,
    is_active, account_status, language
  ) VALUES (
    p_user_id,
    btrim(p_name),
    lower(trim(p_email)),
    nullif(btrim(p_phone), ''),
    CASE
      WHEN nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), '') IS NULL THEN NULL
      WHEN regexp_replace(p_phone, '[^0-9]', '', 'g') LIKE '0%' THEN
        '20' || right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 10)
      ELSE regexp_replace(p_phone, '[^0-9]', '', 'g')
    END,
    'institution', 'institution', false, false,
    true, 'active', 'ar'
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    phone_normalized = EXCLUDED.phone_normalized,
    user_type = 'institution',
    role = 'institution',
    is_active = true,
    account_status = 'active';

  INSERT INTO public.institutions (
    user_id, name, institution_type, phone, email,
    description, city, address, status, is_verified, metadata
  ) VALUES (
    p_user_id,
    btrim(p_name),
    v_type,
    nullif(btrim(p_phone), ''),
    lower(trim(p_email)),
    nullif(btrim(p_description), ''),
    nullif(btrim(p_city), ''),
    nullif(btrim(p_address), ''),
    v_status,
    coalesce(p_is_verified, false),
    jsonb_build_object('created_by', 'desktop_admin_app', 'admin_fixture', true)
  )
  RETURNING id INTO v_institution_id;

  INSERT INTO private.institution_login_secrets (institution_id, login_otp_hash)
  VALUES (v_institution_id, crypt(p_login_otp, gen_salt('bf')))
  ON CONFLICT (institution_id) DO UPDATE SET
    login_otp_hash = EXCLUDED.login_otp_hash,
    otp_failed_attempts = 0,
    otp_locked_until = NULL;

  RETURN jsonb_build_object(
    'institution_id', v_institution_id,
    'user_id', p_user_id,
    'status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_institution(uuid, text, text, text, text, text, text, text, text, boolean, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_institution(uuid, text, text, text, text, text, text, text, text, boolean, text)
  TO service_role;

COMMIT;
