BEGIN;

-- Partner login codes are provisioned manually and verified against login_otp_hash.
-- Keep the existing SECURITY DEFINER ownership checks; allow only signed-in users
-- to invoke them from the temporary authenticated session.
REVOKE ALL ON FUNCTION public.verify_institution_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_institution_login_otp(uuid, text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.verify_charity_login_otp(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_charity_login_otp(uuid, text)
  TO authenticated;

COMMIT;
