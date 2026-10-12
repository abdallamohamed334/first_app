-- Aggregate the current user's counters server-side and avoid loading every row.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_user_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT points, level INTO v_user FROM public.users WHERE id = p_user_id;
  RETURN jsonb_build_object(
    'points', COALESCE(v_user.points, 0),
    'level', COALESCE(v_user.level, 1),
    'deliveriesCount', COALESCE((SELECT COUNT(*) FROM public.deliveries WHERE volunteer_id = p_user_id AND status = 'completed'), 0),
    'mealsSaved', COALESCE((SELECT COUNT(*) FROM public.donations WHERE donor_id = p_user_id AND status = 'completed'), 0),
    'tasksCompleted', COALESCE((SELECT COUNT(*) FROM public.deliveries WHERE volunteer_id = p_user_id AND status = 'completed'), 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_stats(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_stats(uuid) TO authenticated;

COMMIT;
