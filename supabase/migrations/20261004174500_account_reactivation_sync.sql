BEGIN;

CREATE OR REPLACE FUNCTION public.reactivate_user_account(
  p_target_user_id uuid,
  p_case_id uuid DEFAULT NULL,
  p_resolution text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_case_id uuid := p_case_id;
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF v_case_id IS NULL THEN
    SELECT suspension_case_id INTO v_case_id FROM public.users WHERE id = p_target_user_id;
  END IF;

  UPDATE public.users
  SET account_status = 'active', is_active = true, suspended_at = NULL,
      suspended_by = NULL, suspension_reason = NULL, suspension_case_id = NULL,
      suspension_until = NULL, last_security_action_at = now(), updated_at = now()
  WHERE id = p_target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'target_user_not_found'; END IF;

  UPDATE public.user_devices SET is_active = true, updated_at = now()
  WHERE user_id = p_target_user_id;

  -- Re-enable the account, but keep provider verification conservative: an
  -- approved provider must pass review again instead of being silently exposed.
  UPDATE public.service_providers
  SET is_active = true, is_available = false, verification_status = 'pending', updated_at = now()
  WHERE user_id = p_target_user_id;
  UPDATE public.institutions SET status = 'active', updated_at = now()
  WHERE user_id = p_target_user_id AND status = 'suspended';
  UPDATE public.businesses SET status = 'active', updated_at = now()
  WHERE user_id = p_target_user_id AND status = 'suspended';
  UPDATE public.restaurants SET status = 'active', updated_at = now()
  WHERE user_id = p_target_user_id AND status = 'suspended';
  UPDATE public.charities SET status = 'active', updated_at = now()
  WHERE user_id = p_target_user_id AND status = 'suspended';

  UPDATE public.account_cases
  SET status = 'resolved', resolution = p_resolution,
      resolved_at = now(), resolved_by = auth.uid()
  WHERE id = v_case_id;

  PERFORM public.write_account_audit_event(
    'account_reactivated', p_target_user_id, v_case_id, p_resolution, '{}'::jsonb
  );
  RETURN jsonb_build_object('success', true, 'target_user_id', p_target_user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.reactivate_user_account(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reactivate_user_account(uuid, uuid, text) TO authenticated;
COMMIT;
