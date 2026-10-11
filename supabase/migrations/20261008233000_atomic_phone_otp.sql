BEGIN;

ALTER TABLE public.otp_codes
  ADD COLUMN IF NOT EXISTS login_mode text NOT NULL DEFAULT 'user';

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'otp_codes_login_mode_check'
      AND conrelid = 'public.otp_codes'::regclass
  ) THEN
    ALTER TABLE public.otp_codes
      ADD CONSTRAINT otp_codes_login_mode_check
      CHECK (login_mode IN ('user', 'provider'));
  END IF;
END;
$block$;

CREATE OR REPLACE FUNCTION public.create_otp_challenge(
  p_phone text,
  p_code text,
  p_login_mode text,
  p_expires_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_last_created_at timestamptz;
BEGIN
  IF coalesce(p_phone, '') !~ '^20[0-9]{10}$'
     OR coalesce(p_code, '') !~ '^[0-9]{6}$'
     OR coalesce(p_login_mode, '') NOT IN ('user', 'provider')
     OR p_expires_at IS NULL
     OR p_expires_at <= now()
     OR p_expires_at > now() + interval '10 minutes' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_input');
  END IF;

  -- Serialize all OTP issuance and consumption for this phone.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_phone, 0));

  SELECT created_at INTO v_last_created_at
  FROM public.otp_codes
  WHERE phone = p_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_created_at IS NOT NULL
     AND v_last_created_at > now() - interval '60 seconds' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'cooldown');
  END IF;

  DELETE FROM public.otp_codes
  WHERE phone = p_phone AND verified IS NOT TRUE;

  INSERT INTO public.otp_codes(phone, code, expires_at, verified, attempts, login_mode)
  VALUES (p_phone, p_code, p_expires_at, false, 0, p_login_mode);

  RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.consume_otp_challenge(
  p_phone text,
  p_code text,
  p_login_mode text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_otp public.otp_codes%ROWTYPE;
  v_now timestamptz := now();
BEGIN
  IF coalesce(p_phone, '') !~ '^20[0-9]{10}$'
     OR coalesce(p_code, '') !~ '^[0-9]{6}$'
     OR coalesce(p_login_mode, '') NOT IN ('user', 'provider') THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_phone, 0));

  SELECT * INTO v_otp
  FROM public.otp_codes
  WHERE phone = p_phone
    AND verified IS NOT TRUE
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;

  IF v_otp.expires_at <= v_now THEN
    RETURN jsonb_build_object('success', false, 'reason', 'expired');
  END IF;

  IF coalesce(v_otp.attempts, 0) >= 5 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'attempts_exceeded');
  END IF;

  IF v_otp.code <> p_code OR v_otp.login_mode <> p_login_mode THEN
    UPDATE public.otp_codes
    SET attempts = coalesce(attempts, 0) + 1
    WHERE id = v_otp.id AND verified IS NOT TRUE;
    RETURN jsonb_build_object('success', false, 'reason', 'invalid');
  END IF;

  UPDATE public.otp_codes
  SET verified = true,
      attempts = coalesce(attempts, 0) + 1
  WHERE id = v_otp.id
    AND verified IS NOT TRUE
    AND expires_at > v_now
    AND coalesce(attempts, 0) < 5
  RETURNING * INTO v_otp;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_consumed');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.create_otp_challenge(text, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_otp_challenge(text, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_otp_challenge(text, text, text, timestamptz)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_otp_challenge(text, text, text)
  TO service_role;

COMMIT;
