BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.partner_login_otp_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  partner_type text NOT NULL CHECK (partner_type IN ('institution', 'charity')),
  partner_id uuid NOT NULL,
  code_hash text NOT NULL CHECK (code_hash ~ '^[0-9a-f]{64}$'),
  salt text NOT NULL CHECK (salt ~ '^[0-9a-f]{32}$'),
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0 AND attempts <= 5),
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.partner_login_otp_challenges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.partner_login_otp_challenges FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS partner_login_otp_active_idx
  ON public.partner_login_otp_challenges
    (user_id, partner_type, partner_id, created_at DESC)
  WHERE consumed_at IS NULL;

CREATE OR REPLACE FUNCTION public.create_partner_login_otp_challenge(
  p_user_id uuid,
  p_partner_type text,
  p_partner_id uuid,
  p_code_hash text,
  p_salt text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_recent timestamptz;
  v_is_owner boolean := false;
BEGIN
  IF p_user_id IS NULL
     OR p_partner_id IS NULL
     OR coalesce(p_partner_type, '') NOT IN ('institution', 'charity')
     OR coalesce(p_code_hash, '') !~ '^[0-9a-f]{64}$'
     OR coalesce(p_salt, '') !~ '^[0-9a-f]{32}$' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_input');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  IF p_partner_type = 'institution' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.institutions
      WHERE id = p_partner_id
        AND user_id = p_user_id
        AND status IN ('approved', 'active')
    ) INTO v_is_owner;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.charities
      WHERE id = p_partner_id
        AND user_id = p_user_id
        AND status IN ('approved', 'active')
    ) INTO v_is_owner;
  END IF;

  IF NOT v_is_owner THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_allowed');
  END IF;

  SELECT created_at INTO v_recent
  FROM public.partner_login_otp_challenges
  WHERE user_id = p_user_id
    AND partner_type = p_partner_type
    AND partner_id = p_partner_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_recent IS NOT NULL AND v_recent > now() - interval '60 seconds' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'cooldown');
  END IF;

  UPDATE public.partner_login_otp_challenges
  SET consumed_at = now()
  WHERE user_id = p_user_id
    AND partner_type = p_partner_type
    AND partner_id = p_partner_id
    AND consumed_at IS NULL;

  INSERT INTO public.partner_login_otp_challenges (
    user_id, partner_type, partner_id, code_hash, salt, expires_at
  ) VALUES (
    p_user_id, p_partner_type, p_partner_id, p_code_hash, p_salt,
    now() + interval '5 minutes'
  );

  RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_partner_login_otp(
  p_partner_type text,
  p_partner_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_challenge public.partner_login_otp_challenges%ROWTYPE;
  v_is_owner boolean := false;
  v_now timestamptz := now();
BEGIN
  IF v_user_id IS NULL
     OR p_partner_id IS NULL
     OR coalesce(p_partner_type, '') NOT IN ('institution', 'charity')
     OR coalesce(p_otp, '') !~ '^\d{6}$' THEN
    RETURN jsonb_build_object('allowed', false);
  END IF;

  IF p_partner_type = 'institution' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.institutions
      WHERE id = p_partner_id
        AND user_id = v_user_id
        AND status IN ('approved', 'active')
    ) INTO v_is_owner;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.charities
      WHERE id = p_partner_id
        AND user_id = v_user_id
        AND status IN ('approved', 'active')
    ) INTO v_is_owner;
  END IF;

  IF NOT v_is_owner THEN
    RETURN jsonb_build_object('allowed', false);
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  SELECT * INTO v_challenge
  FROM public.partner_login_otp_challenges
  WHERE user_id = v_user_id
    AND partner_type = p_partner_type
    AND partner_id = p_partner_id
    AND consumed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND
     OR v_challenge.expires_at <= v_now
     OR v_challenge.attempts >= 5 THEN
    RETURN jsonb_build_object('allowed', false);
  END IF;

  IF encode(digest(p_otp || ':' || v_challenge.salt, 'sha256'), 'hex')
     <> v_challenge.code_hash THEN
    UPDATE public.partner_login_otp_challenges
    SET attempts = attempts + 1
    WHERE id = v_challenge.id
      AND consumed_at IS NULL
      AND attempts < 5;
    RETURN jsonb_build_object('allowed', false);
  END IF;

  UPDATE public.partner_login_otp_challenges
  SET consumed_at = v_now,
      attempts = attempts + 1
  WHERE id = v_challenge.id
    AND consumed_at IS NULL
    AND expires_at > v_now
    AND attempts < 5;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false);
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.create_partner_login_otp_challenge(uuid, text, uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_partner_login_otp_challenge(uuid, text, uuid, text, text)
  TO service_role;
REVOKE ALL ON FUNCTION public.verify_partner_login_otp(text, uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_partner_login_otp(text, uuid, text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;

COMMIT;
