BEGIN;

CREATE TABLE IF NOT EXISTS public.account_deletion_otp_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text NOT NULL CHECK (phone ~ '^20[0-9]{10}$'),
  code_hash text NOT NULL,
  expires_at timestamptz NOT NULL,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz
);

CREATE INDEX IF NOT EXISTS account_deletion_otp_user_created_idx
  ON public.account_deletion_otp_challenges (user_id, created_at DESC);

ALTER TABLE public.account_deletion_otp_challenges ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.account_deletion_otp_challenges
  FROM PUBLIC, anon, authenticated, service_role;
GRANT DELETE ON TABLE public.account_deletion_otp_challenges TO service_role;

CREATE OR REPLACE FUNCTION public.create_account_deletion_otp_challenge(
  p_user_id uuid,
  p_phone text,
  p_code text,
  p_expires_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_last_created_at timestamptz;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     OR p_user_id IS NULL
     OR coalesce(p_phone, '') !~ '^20[0-9]{10}$'
     OR coalesce(p_code, '') !~ '^[0-9]{6}$'
     OR p_expires_at IS NULL
     OR p_expires_at <= now()
     OR p_expires_at > now() + interval '5 minutes' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid_input');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  SELECT created_at INTO v_last_created_at
  FROM public.account_deletion_otp_challenges
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_created_at IS NOT NULL
     AND v_last_created_at > now() - interval '60 seconds' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'cooldown');
  END IF;

  DELETE FROM public.account_deletion_otp_challenges
  WHERE user_id = p_user_id AND consumed_at IS NULL;

  INSERT INTO public.account_deletion_otp_challenges
    (user_id, phone, code_hash, expires_at)
  VALUES (
    p_user_id,
    p_phone,
    extensions.crypt(p_code, extensions.gen_salt('bf', 8)),
    p_expires_at
  );

  RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.consume_account_deletion_otp_challenge(
  p_user_id uuid,
  p_phone text,
  p_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_challenge public.account_deletion_otp_challenges%ROWTYPE;
  v_now timestamptz := now();
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role'
     OR p_user_id IS NULL
     OR coalesce(p_phone, '') !~ '^20[0-9]{10}$'
     OR coalesce(p_code, '') !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('success', false, 'reason', 'invalid');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  SELECT * INTO v_challenge
  FROM public.account_deletion_otp_challenges
  WHERE user_id = p_user_id
    AND phone = p_phone
    AND consumed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'not_found');
  END IF;
  IF v_challenge.expires_at <= v_now THEN
    RETURN jsonb_build_object('success', false, 'reason', 'expired');
  END IF;
  IF v_challenge.attempts >= 5 THEN
    RETURN jsonb_build_object('success', false, 'reason', 'attempts_exceeded');
  END IF;

  IF extensions.crypt(p_code, v_challenge.code_hash) IS DISTINCT FROM v_challenge.code_hash THEN
    UPDATE public.account_deletion_otp_challenges
      SET attempts = attempts + 1
      WHERE id = v_challenge.id AND consumed_at IS NULL;
    RETURN jsonb_build_object('success', false, 'reason', 'invalid');
  END IF;

  UPDATE public.account_deletion_otp_challenges
  SET consumed_at = v_now, attempts = attempts + 1
  WHERE id = v_challenge.id
    AND consumed_at IS NULL
    AND expires_at > v_now
    AND attempts < 5;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_consumed');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.create_account_deletion_otp_challenge(uuid, text, text, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_account_deletion_otp_challenge(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_account_deletion_otp_challenge(uuid, text, text, timestamptz)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_account_deletion_otp_challenge(uuid, text, text)
  TO service_role;

COMMIT;
