-- Expose only the public identity fields needed by offer publisher profiles.
-- Phone numbers, email addresses, and other private fields remain protected by users RLS.
CREATE OR REPLACE FUNCTION public.get_public_user_profiles(p_user_ids uuid[])
RETURNS TABLE (
  id uuid,
  name text,
  avatar_url text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'extensions', 'pg_temp'
AS $function$
  SELECT
    u.id,
    COALESCE(NULLIF(btrim(u.name), ''), 'مستخدم خدمة')::text AS name,
    NULLIF(btrim(u.avatar_url), '')::text AS avatar_url,
    u.created_at
  FROM public.users AS u
  WHERE p_user_ids IS NOT NULL
    AND cardinality(p_user_ids) BETWEEN 1 AND 100
    AND u.id = ANY (p_user_ids)
  ORDER BY array_position(p_user_ids, u.id);
$function$;

REVOKE ALL ON FUNCTION public.get_public_user_profiles(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_user_profiles(uuid[]) TO authenticated;

COMMENT ON FUNCTION public.get_public_user_profiles(uuid[]) IS
  'Returns only public profile fields (id, name, avatar_url, created_at) for publisher and reviewer display.';
