-- Enterprise account safety foundation:
-- suspension / review / closure, investigation cases, private evidence metadata,
-- and append-only audit events. No user data is deleted by this migration.
BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS account_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz,
  ADD COLUMN IF NOT EXISTS suspended_by uuid,
  ADD COLUMN IF NOT EXISTS suspension_reason text,
  ADD COLUMN IF NOT EXISTS suspension_case_id uuid,
  ADD COLUMN IF NOT EXISTS suspension_until timestamptz,
  ADD COLUMN IF NOT EXISTS last_security_action_at timestamptz;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_account_status_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_account_status_check
  CHECK (account_status IN ('active', 'under_review', 'suspended', 'closed'));

CREATE INDEX IF NOT EXISTS users_account_status_idx
  ON public.users (account_status);
CREATE INDEX IF NOT EXISTS users_suspension_until_idx
  ON public.users (suspension_until)
  WHERE suspension_until IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.account_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'investigating', 'resolved', 'appealed', 'closed')),
  priority text NOT NULL DEFAULT 'normal'
    CHECK (priority IN ('low', 'normal', 'high', 'critical')),
  reason text NOT NULL,
  internal_notes text,
  resolution text,
  assigned_to uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  legal_hold boolean NOT NULL DEFAULT false,
  retention_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS account_cases_target_idx
  ON public.account_cases (target_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS account_cases_queue_idx
  ON public.account_cases (status, priority, created_at DESC);

CREATE TABLE IF NOT EXISTS public.account_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  target_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  case_id uuid REFERENCES public.account_cases(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  request_id text,
  ip_hash text,
  previous_event_hash text,
  event_hash text
);

CREATE INDEX IF NOT EXISTS account_audit_target_idx
  ON public.account_audit_log (target_user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS account_audit_case_idx
  ON public.account_audit_log (case_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS account_audit_type_idx
  ON public.account_audit_log (event_type, occurred_at DESC);

CREATE TABLE IF NOT EXISTS public.account_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id uuid NOT NULL REFERENCES public.account_cases(id) ON DELETE RESTRICT,
  uploaded_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  storage_bucket text NOT NULL,
  storage_path text NOT NULL,
  content_type text,
  file_size_bytes bigint,
  sha256 text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS account_evidence_case_idx
  ON public.account_evidence (case_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.touch_account_case_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS account_cases_touch_updated_at ON public.account_cases;
CREATE TRIGGER account_cases_touch_updated_at
BEFORE UPDATE ON public.account_cases
FOR EACH ROW EXECUTE FUNCTION public.touch_account_case_updated_at();

CREATE OR REPLACE FUNCTION public.prevent_account_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION 'account_audit_log_is_append_only';
END;
$$;

DROP TRIGGER IF EXISTS account_audit_no_update ON public.account_audit_log;
CREATE TRIGGER account_audit_no_update
BEFORE UPDATE OR DELETE ON public.account_audit_log
FOR EACH ROW EXECUTE FUNCTION public.prevent_account_audit_mutation();

CREATE OR REPLACE FUNCTION public.is_admin_actor()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND (role = 'admin' OR user_type = 'admin')
      AND account_status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION public.get_my_account_restriction()
RETURNS TABLE(account_status text, suspension_until timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT u.account_status, u.suspension_until
  FROM public.users u
  WHERE u.id = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.write_account_audit_event(
  p_event_type text,
  p_target_user_id uuid,
  p_case_id uuid DEFAULT NULL,
  p_reason text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'admin_required';
  END IF;

  INSERT INTO public.account_audit_log(
    actor_id, target_user_id, case_id, event_type, reason, metadata
  ) VALUES (
    auth.uid(), p_target_user_id, p_case_id, trim(p_event_type),
    NULLIF(trim(coalesce(p_reason, '')), ''), coalesce(p_metadata, '{}'::jsonb)
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.suspend_user_account(
  p_target_user_id uuid,
  p_reason text,
  p_case_id uuid DEFAULT NULL,
  p_status text DEFAULT 'suspended',
  p_suspension_until timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_case_id uuid := p_case_id;
  v_status text := lower(trim(p_status));
  v_target_exists boolean;
BEGIN
  IF NOT public.is_admin_actor() THEN
    RAISE EXCEPTION 'admin_required';
  END IF;
  IF v_status NOT IN ('under_review', 'suspended', 'closed') THEN
    RAISE EXCEPTION 'invalid_account_status';
  END IF;
  IF nullif(trim(coalesce(p_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'suspension_reason_required';
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.users WHERE id = p_target_user_id)
    INTO v_target_exists;
  IF NOT v_target_exists THEN
    RAISE EXCEPTION 'target_user_not_found';
  END IF;

  IF v_case_id IS NULL THEN
    INSERT INTO public.account_cases(
      target_user_id, status, priority, reason, created_by
    ) VALUES (
      p_target_user_id,
      CASE WHEN v_status = 'under_review' THEN 'investigating' ELSE 'open' END,
      CASE WHEN v_status = 'closed' THEN 'critical' ELSE 'high' END,
      trim(p_reason), auth.uid()
    ) RETURNING id INTO v_case_id;
  ELSE
    UPDATE public.account_cases
    SET target_user_id = p_target_user_id,
        reason = trim(p_reason),
        status = CASE WHEN v_status = 'under_review' THEN 'investigating' ELSE status END
    WHERE id = v_case_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'case_not_found'; END IF;
  END IF;

  UPDATE public.users
  SET account_status = v_status,
      is_active = false,
      suspended_at = now(),
      suspended_by = auth.uid(),
      suspension_reason = trim(p_reason),
      suspension_case_id = v_case_id,
      suspension_until = p_suspension_until,
      last_security_action_at = now(),
      fcm_token = NULL,
      updated_at = now()
  WHERE id = p_target_user_id;

  UPDATE public.user_devices
  SET is_active = false, updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.service_providers
  SET is_active = false,
      is_available = false,
      verification_status = 'suspended',
      updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.institutions
  SET status = 'suspended', updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.businesses
  SET status = 'suspended', updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.restaurants
  SET status = 'suspended', updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.charities
  SET status = 'suspended', updated_at = now()
  WHERE user_id = p_target_user_id;

  UPDATE public.food_offers fo
  SET status = 'cancelled', deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  FROM public.businesses b
  WHERE fo.business_id = b.id AND b.user_id = p_target_user_id;

  UPDATE public.institution_offers io
  SET status = 'cancelled', deleted_at = coalesce(deleted_at, now()),
      updated_at = now()
  FROM public.institutions i
  WHERE io.institution_id = i.id AND i.user_id = p_target_user_id;

  UPDATE public.community_offers
  SET status = 'cancelled', updated_at = now()
  WHERE owner_id = p_target_user_id;

  UPDATE public.swap_listings
  SET status = 'cancelled', updated_at = now()
  WHERE owner_id = p_target_user_id
    AND status NOT IN ('completed', 'cancelled', 'expired');

  PERFORM public.write_account_audit_event(
    CASE WHEN v_status = 'closed' THEN 'account_closed'
         WHEN v_status = 'under_review' THEN 'account_under_review'
         ELSE 'account_suspended' END,
    p_target_user_id, v_case_id, p_reason,
    jsonb_build_object('status', v_status, 'suspension_until', p_suspension_until)
  );

  RETURN jsonb_build_object(
    'success', true,
    'target_user_id', p_target_user_id,
    'account_status', v_status,
    'case_id', v_case_id
  );
END;
$$;

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
DECLARE
  v_case_id uuid := p_case_id;
BEGIN
  IF NOT public.is_admin_actor() THEN RAISE EXCEPTION 'admin_required'; END IF;
  IF v_case_id IS NULL THEN
    SELECT suspension_case_id INTO v_case_id
    FROM public.users WHERE id = p_target_user_id;
  END IF;

  UPDATE public.users
  SET account_status = 'active',
      is_active = true,
      suspended_at = NULL,
      suspended_by = NULL,
      suspension_reason = NULL,
      suspension_case_id = NULL,
      suspension_until = NULL,
      last_security_action_at = now(),
      updated_at = now()
  WHERE id = p_target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'target_user_not_found'; END IF;

  UPDATE public.user_devices SET is_active = true, updated_at = now()
  WHERE user_id = p_target_user_id;

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

-- Only the functions mediate moderation. Clients cannot write audit/case tables.
ALTER TABLE public.account_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.account_evidence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS account_cases_admin_select ON public.account_cases;
CREATE POLICY account_cases_admin_select ON public.account_cases
FOR SELECT TO authenticated USING (public.is_admin_actor());
DROP POLICY IF EXISTS account_cases_admin_update ON public.account_cases;
CREATE POLICY account_cases_admin_update ON public.account_cases
FOR UPDATE TO authenticated USING (public.is_admin_actor()) WITH CHECK (public.is_admin_actor());

DROP POLICY IF EXISTS account_audit_admin_select ON public.account_audit_log;
CREATE POLICY account_audit_admin_select ON public.account_audit_log
FOR SELECT TO authenticated USING (public.is_admin_actor());

DROP POLICY IF EXISTS account_evidence_admin_select ON public.account_evidence;
CREATE POLICY account_evidence_admin_select ON public.account_evidence
FOR SELECT TO authenticated USING (public.is_admin_actor());

REVOKE ALL ON TABLE public.account_cases, public.account_audit_log, public.account_evidence FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON public.account_cases TO authenticated;
GRANT SELECT ON public.account_audit_log, public.account_evidence TO authenticated;
REVOKE ALL ON FUNCTION public.is_admin_actor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin_actor() TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_account_restriction() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_account_restriction() TO authenticated;
REVOKE ALL ON FUNCTION public.write_account_audit_event(text, uuid, uuid, text, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.write_account_audit_event(text, uuid, uuid, text, jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.suspend_user_account(uuid, text, uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.suspend_user_account(uuid, text, uuid, text, timestamptz) TO authenticated;
REVOKE ALL ON FUNCTION public.reactivate_user_account(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reactivate_user_account(uuid, uuid, text) TO authenticated;

COMMIT;
