BEGIN;

CREATE OR REPLACE FUNCTION public.list_account_cases(
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  id uuid,
  target_user_id uuid,
  target_name text,
  target_phone text,
  target_role text,
  account_status text,
  status text,
  priority text,
  reason text,
  internal_notes text,
  resolution text,
  legal_hold boolean,
  created_at timestamptz,
  updated_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
  IF p_offset IS NULL OR p_offset < 0 THEN RAISE EXCEPTION 'invalid_offset'; END IF;

  RETURN QUERY
  SELECT c.id, c.target_user_id, u.name, u.phone,
         coalesce(u.role, u.user_type), u.account_status,
         c.status, c.priority, c.reason, c.internal_notes, c.resolution,
         c.legal_hold, c.created_at, c.updated_at, c.resolved_at
  FROM public.account_cases c
  JOIN public.users u ON u.id = c.target_user_id
  WHERE p_status IS NULL OR c.status = p_status
  ORDER BY CASE c.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END,
           c.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_account_case(
  p_case_id uuid,
  p_status text DEFAULT NULL,
  p_priority text DEFAULT NULL,
  p_internal_notes text DEFAULT NULL,
  p_resolution text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_target uuid;
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('open','investigating','resolved','appealed','closed') THEN RAISE EXCEPTION 'invalid_case_status'; END IF;
  IF p_priority IS NOT NULL AND p_priority NOT IN ('low','normal','high','critical') THEN RAISE EXCEPTION 'invalid_case_priority'; END IF;

  SELECT target_user_id INTO v_target FROM public.account_cases WHERE id = p_case_id;
  IF v_target IS NULL THEN RAISE EXCEPTION 'case_not_found'; END IF;

  UPDATE public.account_cases
  SET status = coalesce(p_status, status),
      priority = coalesce(p_priority, priority),
      internal_notes = coalesce(p_internal_notes, internal_notes),
      resolution = coalesce(p_resolution, resolution),
      resolved_at = CASE WHEN p_status IN ('resolved','closed') THEN now() ELSE resolved_at END,
      resolved_by = CASE WHEN p_status IN ('resolved','closed') THEN auth.uid() ELSE resolved_by END
  WHERE id = p_case_id;

  PERFORM public.write_account_audit_event(
    'case_updated', v_target, p_case_id,
    coalesce(p_resolution, p_internal_notes),
    jsonb_build_object('status', p_status, 'priority', p_priority)
  );
  RETURN jsonb_build_object('success', true, 'case_id', p_case_id);
END;
$$;

REVOKE ALL ON FUNCTION public.list_account_cases(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_account_cases(text, integer, integer) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_update_account_case(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_update_account_case(uuid, text, text, text, text) TO authenticated;

COMMIT;
