-- Storage may evaluate policies for multiple object-path shapes while planning
-- an INSERT. Never cast an arbitrary first path segment to uuid: validate the
-- shape first and return false for unrelated paths such as direct/....
CREATE OR REPLACE FUNCTION public.can_manage_charity_avatar_uuid_path(p_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_charity_id uuid;
BEGIN
  IF auth.uid() IS NULL
     OR p_name IS NULL
     OR p_name !~ '^[0-9a-fA-F-]{36}/[^/]+$' THEN
    RETURN false;
  END IF;

  v_charity_id := split_part(p_name, '/', 1)::uuid;

  RETURN EXISTS (
    SELECT 1
    FROM public.charities c
    WHERE c.id = v_charity_id
      AND c.user_id = auth.uid()
      AND lower(coalesce(c.status, '')) IN ('approved', 'active')
  );
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_manage_charity_avatar_path(p_name text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_charity_id uuid;
  v_uuid_text text;
BEGIN
  IF auth.uid() IS NULL
     OR p_name IS NULL
     OR p_name !~ '^charity-volunteers/[^/]+/[0-9a-fA-F-]{36}/[^/]+$' THEN
    RETURN false;
  END IF;

  v_uuid_text := split_part(p_name, '/', 3);
  v_charity_id := v_uuid_text::uuid;

  RETURN EXISTS (
    SELECT 1
    FROM public.charities c
    WHERE c.id = v_charity_id
      AND c.user_id = auth.uid()
      AND lower(coalesce(c.status, '')) IN ('approved', 'active')
  );
EXCEPTION
  WHEN invalid_text_representation THEN
    RETURN false;
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_charity_avatar_uuid_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_charity_avatar_uuid_path(text)
  TO authenticated, supabase_storage_admin;
REVOKE ALL ON FUNCTION public.can_manage_charity_avatar_path(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_charity_avatar_path(text)
  TO authenticated, supabase_storage_admin;
