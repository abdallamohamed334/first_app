-- Fixed second-factor login for charities.
-- Store only a bcrypt hash; the fixed code is configured by the Wasla team.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.charities
  ADD COLUMN IF NOT EXISTS login_otp_hash text;

CREATE OR REPLACE FUNCTION public.verify_charity_login_otp(
  p_charity_id uuid,
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

  SELECT login_otp_hash INTO v_hash
  FROM public.charities
  WHERE id = p_charity_id
    AND user_id = auth.uid()
    AND status IN ('approved', 'active');

  IF v_hash IS NULL OR crypt(p_otp, v_hash) <> v_hash THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$$;

REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_charity_login_otp(uuid, text) TO authenticated;

COMMIT;

-- To set or rotate a code, run as a trusted database administrator:
-- UPDATE public.charities
-- SET login_otp_hash = crypt('123456', gen_salt('bf'))
-- WHERE id = '<charity-id>';
