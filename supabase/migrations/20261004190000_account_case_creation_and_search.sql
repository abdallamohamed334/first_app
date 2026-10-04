BEGIN;

CREATE OR REPLACE FUNCTION public.search_account_targets(
  p_query text DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS TABLE(
  id uuid,
  name text,
  phone text,
  email text,
  target_role text,
  account_status text,
  is_active boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_query text := lower(trim(coalesce(p_query, '')));
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 50 THEN
    RAISE EXCEPTION 'invalid_limit';
  END IF;

  RETURN QUERY
  SELECT u.id, u.name, u.phone, u.email,
         coalesce(u.role, u.user_type), u.account_status, u.is_active
  FROM public.users u
  WHERE v_query = ''
     OR lower(coalesce(u.name, '')) LIKE '%' || v_query || '%'
     OR lower(coalesce(u.phone, '')) LIKE '%' || v_query || '%'
     OR lower(coalesce(u.email, '')) LIKE '%' || v_query || '%'
  ORDER BY CASE WHEN u.account_status <> 'active' THEN 0 ELSE 1 END,
           u.updated_at DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_account_case(
  p_target_user_id uuid,
  p_reason text,
  p_priority text DEFAULT 'normal',
  p_internal_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_case_id uuid;
  v_priority text := lower(trim(coalesce(p_priority, 'normal')));
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF p_target_user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users WHERE id = p_target_user_id
  ) THEN
    RAISE EXCEPTION 'target_user_not_found';
  END IF;
  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'case_reason_required';
  END IF;
  IF v_priority NOT IN ('low', 'normal', 'high', 'critical') THEN
    RAISE EXCEPTION 'invalid_case_priority';
  END IF;

  INSERT INTO public.account_cases(
    target_user_id, status, priority, reason, internal_notes, created_by
  ) VALUES (
    p_target_user_id, 'open', v_priority, trim(p_reason),
    NULLIF(trim(coalesce(p_internal_notes, '')), ''), auth.uid()
  ) RETURNING id INTO v_case_id;

  PERFORM public.write_account_audit_event(
    'case_created', p_target_user_id, v_case_id, p_reason,
    jsonb_build_object('priority', v_priority)
  );

  RETURN jsonb_build_object(
    'success', true,
    'case_id', v_case_id,
    'target_user_id', p_target_user_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.search_account_targets(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_account_targets(text, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.create_account_case(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_account_case(uuid, text, text, text) TO authenticated;

COMMIT;
