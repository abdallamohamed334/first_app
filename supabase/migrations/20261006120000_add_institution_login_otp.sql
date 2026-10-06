-- Two-step login for institutions.
-- The fixed code is configured by the Wasla team as a bcrypt hash, never stored
-- in the Flutter application or returned to the client.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.institutions
  ADD COLUMN IF NOT EXISTS login_otp_hash text;

CREATE OR REPLACE FUNCTION public.verify_institution_login_otp(
  p_institution_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_hash text;
BEGIN
  IF auth.uid() IS NULL OR p_otp IS NULL OR p_otp !~ '^\\d{6}$' THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  SELECT login_otp_hash
    INTO v_hash
  FROM public.institutions
  WHERE id = p_institution_id
    AND user_id = auth.uid()
    AND status IN ('approved', 'active');

  IF v_hash IS NULL OR crypt(p_otp, v_hash) <> v_hash THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_institution_login_otp(uuid, text) TO authenticated;

COMMIT;

-- To set or rotate a code, run as a trusted database administrator:
-- UPDATE public.institutions
-- SET login_otp_hash = crypt('123456', gen_salt('bf'))
-- WHERE id = '<institution-id>';
