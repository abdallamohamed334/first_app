-- Do not allow a provider account to be created or logged in with a phone
-- number that already belongs to an ordinary user account.
-- The function intentionally returns only a boolean and never exposes user
-- IDs, names, emails, or phone data.
BEGIN;

CREATE OR REPLACE FUNCTION public.check_ordinary_user_by_phone(p_phone text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS u
    WHERE lower(coalesce(u.user_type::text, '')) = 'user'
      AND right(regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g'), 10) =
          right(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'), 10)
  );
$$;

REVOKE ALL ON FUNCTION public.check_ordinary_user_by_phone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_ordinary_user_by_phone(text) TO anon, authenticated;

COMMIT;
