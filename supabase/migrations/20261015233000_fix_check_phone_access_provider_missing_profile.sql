BEGIN;

-- Fix provider-login checks for ordinary users without a service_providers row.
-- Do not coalesce an enum value with the invalid literal 'unknown'.
CREATE OR REPLACE FUNCTION public.check_phone_access(
  p_phone text,
  p_login_mode text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions, pg_temp
AS $function$
DECLARE
  v_phone text;
  v_user public.users%ROWTYPE;
  v_provider public.service_providers%ROWTYPE;
  v_user_role text;
  v_provider_status text;
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

  IF v_user.is_active IS NOT TRUE OR v_user.account_status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'account_inactive');
  END IF;

  SELECT * INTO v_provider
  FROM public.service_providers
  WHERE user_id = v_user.id
  LIMIT 1;

  -- Cast only an existing enum value. A missing provider profile stays NULL.
  v_provider_status := CASE
    WHEN v_provider.id IS NULL THEN NULL
    ELSE lower(v_provider.verification_status::text)
  END;

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

  IF p_login_mode = 'provider' AND v_provider_status IN ('rejected', 'suspended', 'inactive', 'closed') THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'provider_disabled');
  END IF;

  IF p_login_mode = 'provider' AND v_provider.is_active IS NOT TRUE THEN
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

COMMIT;
