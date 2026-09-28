-- Public volunteer leaderboard and reliable profile-avatar storage policies.
-- Expose only the fields needed by the leaderboard; keep the users table private.
CREATE OR REPLACE FUNCTION public.list_public_volunteers()
RETURNS TABLE(
  id uuid,
  name text,
  avatar_url text,
  points integer,
  level integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.id, COALESCE(NULLIF(btrim(u.name), ''), 'متطوع'),
         u.avatar_url, COALESCE(u.points, 0), COALESCE(u.level, 1)
  FROM public.users u
  WHERE lower(COALESCE(u.user_type, '')) = 'user'
    AND COALESCE(u.is_active, true) = true
  ORDER BY COALESCE(u.points, 0) DESC, u.created_at ASC
  LIMIT 500;
$$;

REVOKE ALL ON FUNCTION public.list_public_volunteers() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_public_volunteers() TO authenticated;

-- Normal user avatars use: <auth.uid>/avatar_<timestamp>.<extension>
DROP POLICY IF EXISTS profile_avatar_public_read ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_insert ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_update ON storage.objects;
DROP POLICY IF EXISTS profile_avatar_owner_delete ON storage.objects;

CREATE POLICY profile_avatar_public_read
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');

CREATE POLICY profile_avatar_owner_insert
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND name ~ '^[0-9a-fA-F-]{36}/avatar_[0-9]+[.](jpg|jpeg|png|webp)$'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY profile_avatar_owner_update
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars'
  AND split_part(name, '/', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars'
  AND split_part(name, '/', 1) = auth.uid()::text
);

CREATE POLICY profile_avatar_owner_delete
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars'
  AND split_part(name, '/', 1) = auth.uid()::text
);

UPDATE storage.buckets
SET public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
WHERE id = 'avatars';
