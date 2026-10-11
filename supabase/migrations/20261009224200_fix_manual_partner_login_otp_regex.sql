BEGIN;

-- The previous verifier used an over-escaped \\d pattern, which PostgreSQL
-- interpreted as a literal backslash and therefore rejected every valid code.
-- Keep the manual-code flow and all ownership/status/hash checks intact.
CREATE OR REPLACE FUNCTION public.verify_institution_login_otp(
  p_institution_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_hash text;
BEGIN
  IF auth.uid() IS NULL OR p_otp IS NULL OR p_otp !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  SELECT login_otp_hash INTO v_hash
  FROM public.institutions
  WHERE id = p_institution_id
    AND user_id = auth.uid()
    AND status IN ('approved', 'active');

  IF v_hash IS NULL OR crypt(p_otp, v_hash) IS DISTINCT FROM v_hash THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.verify_charity_login_otp(
  p_charity_id uuid,
  p_otp text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $function$
DECLARE
  v_hash text;
BEGIN
  IF auth.uid() IS NULL OR p_otp IS NULL OR p_otp !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  SELECT login_otp_hash INTO v_hash
  FROM public.charities
  WHERE id = p_charity_id
    AND user_id = auth.uid()
    AND status IN ('approved', 'active');

  IF v_hash IS NULL OR crypt(p_otp, v_hash) IS DISTINCT FROM v_hash THEN
    RETURN jsonb_build_object('allowed', false, 'message', 'كود التحقق غير صحيح');
  END IF;

  RETURN jsonb_build_object('allowed', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_institution_login_otp(uuid, text)
  TO authenticated;
REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_charity_login_otp(uuid, text)
  TO authenticated;

COMMIT;
