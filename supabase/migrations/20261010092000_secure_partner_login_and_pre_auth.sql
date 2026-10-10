BEGIN;

-- Keep partner login secrets out of API-exposed rows. The public columns are
-- retained as NULL-only compatibility columns; all hashes live in `private`.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS private.charity_login_secrets (
  charity_id uuid PRIMARY KEY REFERENCES public.charities(id) ON DELETE CASCADE,
  access_code_hash text,
  login_otp_hash text,
  access_code_attempts integer NOT NULL DEFAULT 0 CHECK (access_code_attempts >= 0),
  access_code_locked_until timestamptz,
  otp_failed_attempts integer NOT NULL DEFAULT 0 CHECK (otp_failed_attempts >= 0),
  otp_locked_until timestamptz
);

CREATE TABLE IF NOT EXISTS private.institution_login_secrets (
  institution_id uuid PRIMARY KEY REFERENCES public.institutions(id) ON DELETE CASCADE,
  login_otp_hash text,
  otp_failed_attempts integer NOT NULL DEFAULT 0 CHECK (otp_failed_attempts >= 0),
  otp_locked_until timestamptz
);

ALTER TABLE private.charity_login_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.charity_login_secrets FORCE ROW LEVEL SECURITY;
ALTER TABLE private.institution_login_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.institution_login_secrets FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.charity_login_secrets FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE private.institution_login_secrets FROM PUBLIC, anon, authenticated, service_role;

-- Preserve existing hashes and lockout state before clearing API-visible fields.
INSERT INTO private.charity_login_secrets (
  charity_id, access_code_hash, login_otp_hash,
  access_code_attempts, access_code_locked_until
)
SELECT id, access_code_hash, login_otp_hash,
       COALESCE(login_attempts, 0), locked_until
FROM public.charities
WHERE access_code_hash IS NOT NULL OR login_otp_hash IS NOT NULL
   OR COALESCE(login_attempts, 0) > 0 OR locked_until IS NOT NULL
ON CONFLICT (charity_id) DO UPDATE SET
  access_code_hash = COALESCE(private.charity_login_secrets.access_code_hash, EXCLUDED.access_code_hash),
  login_otp_hash = COALESCE(private.charity_login_secrets.login_otp_hash, EXCLUDED.login_otp_hash),
  access_code_attempts = GREATEST(private.charity_login_secrets.access_code_attempts, EXCLUDED.access_code_attempts),
  access_code_locked_until = GREATEST(private.charity_login_secrets.access_code_locked_until, EXCLUDED.access_code_locked_until);

INSERT INTO private.institution_login_secrets (institution_id, login_otp_hash)
SELECT id, login_otp_hash
FROM public.institutions
WHERE login_otp_hash IS NOT NULL
ON CONFLICT (institution_id) DO UPDATE SET
  login_otp_hash = COALESCE(private.institution_login_secrets.login_otp_hash, EXCLUDED.login_otp_hash);

UPDATE public.charities
SET access_code_hash = NULL,
    login_otp_hash = NULL,
    login_attempts = 0,
    locked_until = NULL
WHERE access_code_hash IS NOT NULL OR login_otp_hash IS NOT NULL
   OR COALESCE(login_attempts, 0) <> 0 OR locked_until IS NOT NULL;

UPDATE public.institutions
SET login_otp_hash = NULL
WHERE login_otp_hash IS NOT NULL;

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.charities'::regclass
      AND conname = 'charities_public_login_hashes_must_be_null'
  ) THEN
    ALTER TABLE public.charities
      ADD CONSTRAINT charities_public_login_hashes_must_be_null
      CHECK (access_code_hash IS NULL AND login_otp_hash IS NULL) NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.institutions'::regclass
      AND conname = 'institutions_public_login_hash_must_be_null'
  ) THEN
    ALTER TABLE public.institutions
      ADD CONSTRAINT institutions_public_login_hash_must_be_null
      CHECK (login_otp_hash IS NULL) NOT VALID;
  END IF;
END;
$block$;

ALTER TABLE public.charities VALIDATE CONSTRAINT charities_public_login_hashes_must_be_null;
ALTER TABLE public.institutions VALIDATE CONSTRAINT institutions_public_login_hash_must_be_null;

CREATE OR REPLACE FUNCTION public.check_charity_fixed_code_by_email(
  p_email text,
  p_access_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_charity public.charities%ROWTYPE;
  v_secret private.charity_login_secrets%ROWTYPE;
  v_attempts integer;
BEGIN
  IF p_email IS NULL OR btrim(p_email) = ''
     OR p_access_code IS NULL OR btrim(p_access_code) = '' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_credentials', 'message', 'بيانات الدخول غير صحيحة');
  END IF;

  SELECT * INTO v_charity
  FROM public.charities
  WHERE lower(trim(email)) = lower(trim(p_email))
  ORDER BY id
  LIMIT 1
  FOR UPDATE;

  -- Keep all pre-auth failures indistinguishable; do not disclose email or status.
  IF NOT FOUND
     OR lower(COALESCE(v_charity.status, 'pending')) IN ('rejected', 'inactive', 'suspended', 'pending')
     OR COALESCE(v_charity.code_enabled, false) IS NOT TRUE THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_credentials', 'message', 'بيانات الدخول غير صحيحة');
  END IF;

  SELECT * INTO v_secret
  FROM private.charity_login_secrets
  WHERE charity_id = v_charity.id
  FOR UPDATE;

  IF NOT FOUND
     OR v_secret.access_code_hash IS NULL
     OR (v_secret.access_code_locked_until IS NOT NULL AND v_secret.access_code_locked_until > now()) THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_credentials', 'message', 'بيانات الدخول غير صحيحة');
  END IF;

  IF extensions.crypt(p_access_code, v_secret.access_code_hash)
     IS DISTINCT FROM v_secret.access_code_hash THEN
    v_attempts := COALESCE(v_secret.access_code_attempts, 0) + 1;
    UPDATE private.charity_login_secrets
    SET access_code_attempts = v_attempts,
        access_code_locked_until = CASE
          WHEN v_attempts >= 5 THEN now() + interval '15 minutes'
          ELSE access_code_locked_until
        END
    WHERE charity_id = v_charity.id;
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_credentials', 'message', 'بيانات الدخول غير صحيحة');
  END IF;

  UPDATE private.charity_login_secrets
  SET access_code_attempts = 0, access_code_locked_until = NULL
  WHERE charity_id = v_charity.id;
  UPDATE public.charities
  SET login_attempts = 0, locked_until = NULL, last_login_at = now()
  WHERE id = v_charity.id;

  RETURN jsonb_build_object(
    'allowed', true,
    'charity_id', v_charity.id,
    'user_id', v_charity.user_id,
    'name', v_charity.name,
    'email', v_charity.email,
    'status', v_charity.status
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_charity_login_otp(
  p_charity_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_secret private.charity_login_secrets%ROWTYPE;
  v_attempts integer;
BEGIN
  IF auth.uid() IS NULL OR p_otp IS NULL OR p_otp !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  SELECT s.* INTO v_secret
  FROM private.charity_login_secrets AS s
  JOIN public.charities AS c ON c.id = s.charity_id
  WHERE c.id = p_charity_id
    AND c.user_id = auth.uid()
    AND c.status IN ('approved', 'active')
  FOR UPDATE OF s;

  IF NOT FOUND OR v_secret.login_otp_hash IS NULL
     OR (v_secret.otp_locked_until IS NOT NULL AND v_secret.otp_locked_until > now()) THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  IF extensions.crypt(p_otp, v_secret.login_otp_hash)
     IS DISTINCT FROM v_secret.login_otp_hash THEN
    v_attempts := COALESCE(v_secret.otp_failed_attempts, 0) + 1;
    UPDATE private.charity_login_secrets
    SET otp_failed_attempts = v_attempts,
        otp_locked_until = CASE
          WHEN v_attempts >= 5 THEN now() + interval '15 minutes'
          ELSE otp_locked_until
        END
    WHERE charity_id = p_charity_id;
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  UPDATE private.charity_login_secrets
  SET otp_failed_attempts = 0, otp_locked_until = NULL
  WHERE charity_id = p_charity_id;
  RETURN jsonb_build_object('allowed', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_institution_login_otp(
  p_institution_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_secret private.institution_login_secrets%ROWTYPE;
  v_attempts integer;
BEGIN
  IF auth.uid() IS NULL OR p_otp IS NULL OR p_otp !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  SELECT s.* INTO v_secret
  FROM private.institution_login_secrets AS s
  JOIN public.institutions AS i ON i.id = s.institution_id
  WHERE i.id = p_institution_id
    AND i.user_id = auth.uid()
    AND i.status IN ('approved', 'active')
  FOR UPDATE OF s;

  IF NOT FOUND OR v_secret.login_otp_hash IS NULL
     OR (v_secret.otp_locked_until IS NOT NULL AND v_secret.otp_locked_until > now()) THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  IF extensions.crypt(p_otp, v_secret.login_otp_hash)
     IS DISTINCT FROM v_secret.login_otp_hash THEN
    v_attempts := COALESCE(v_secret.otp_failed_attempts, 0) + 1;
    UPDATE private.institution_login_secrets
    SET otp_failed_attempts = v_attempts,
        otp_locked_until = CASE
          WHEN v_attempts >= 5 THEN now() + interval '15 minutes'
          ELSE otp_locked_until
        END
    WHERE institution_id = p_institution_id;
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  UPDATE private.institution_login_secrets
  SET otp_failed_attempts = 0, otp_locked_until = NULL
  WHERE institution_id = p_institution_id;
  RETURN jsonb_build_object('allowed', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_phone_access(
  p_phone text,
  p_login_mode text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $function$
DECLARE
  v_phone text;
  v_user public.users%ROWTYPE;
  v_provider public.service_providers%ROWTYPE;
  v_user_role text;
BEGIN
  v_phone := public.normalize_phone(p_phone);
  IF v_phone IS NULL OR p_login_mode IS NULL OR p_login_mode NOT IN ('user', 'provider') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'invalid_request');
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE phone_normalized = v_phone
  LIMIT 1;

  IF v_user.id IS NULL THEN
    RETURN jsonb_build_object('allowed', true, 'is_new_user', true, 'login_mode', p_login_mode);
  END IF;

  SELECT * INTO v_provider
  FROM public.service_providers
  WHERE user_id = v_user.id
  LIMIT 1;

  IF p_login_mode = 'user' THEN
    v_user_role := lower(COALESCE(
      NULLIF(btrim(v_user.user_type::text), ''),
      NULLIF(btrim(v_user.role::text), ''),
      'unknown'
    ));
    IF v_user_role <> 'user'
       OR lower(COALESCE(NULLIF(btrim(v_user.user_type::text), ''), 'user')) <> 'user'
       OR lower(COALESCE(NULLIF(btrim(v_user.role::text), ''), 'user')) <> 'user'
       OR v_provider.id IS NOT NULL THEN
      RETURN jsonb_build_object('allowed', false, 'reason', 'account_type_mismatch');
    END IF;
  END IF;

  IF p_login_mode = 'provider' AND v_provider.id IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'provider_profile_not_found');
  END IF;

  IF p_login_mode = 'provider' AND v_provider.verification_status = 'rejected' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'provider_rejected');
  END IF;

  IF p_login_mode = 'provider' AND COALESCE(v_provider.is_active, false) = false THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'provider_disabled');
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'is_new_user', false,
    'login_mode', p_login_mode,
    'user_id', v_user.id,
    'provider_id', v_provider.id,
    'verification_status', v_provider.verification_status,
    'provider_active', v_provider.is_active
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.check_phone_access(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_phone_access(text, text) TO service_role;
REVOKE ALL ON FUNCTION public.check_charity_fixed_code_by_email(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_charity_fixed_code_by_email(text, text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_charity_login_otp(uuid, text) TO authenticated;
REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_institution_login_otp(uuid, text) TO authenticated;
REVOKE ALL ON FUNCTION public.find_provider_by_phone(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_ordinary_user_by_phone(text) FROM PUBLIC, anon, authenticated;

COMMIT;
