BEGIN;

-- Keep the security invariant enforced even if a legacy/admin write updates only
-- account_status. Reactivation remains explicit through reactivate_user_account.
CREATE OR REPLACE FUNCTION public.enforce_account_safety_invariant()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.account_status IN ('under_review', 'suspended', 'closed') THEN
    NEW.is_active = false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_account_safety_invariant ON public.users;
CREATE TRIGGER users_account_safety_invariant
BEFORE INSERT OR UPDATE OF account_status, is_active ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.enforce_account_safety_invariant();

-- Do not let a normal authenticated user rewrite the security state directly.
-- Admin moderation RPCs run as an active admin and remain allowed.
CREATE OR REPLACE FUNCTION public.prevent_direct_account_security_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND auth.uid() = OLD.id
     AND NOT public.is_admin_actor()
     AND (
       NEW.account_status IS DISTINCT FROM OLD.account_status OR
       NEW.is_active IS DISTINCT FROM OLD.is_active OR
       NEW.suspended_at IS DISTINCT FROM OLD.suspended_at OR
       NEW.suspended_by IS DISTINCT FROM OLD.suspended_by OR
       NEW.suspension_reason IS DISTINCT FROM OLD.suspension_reason OR
       NEW.suspension_case_id IS DISTINCT FROM OLD.suspension_case_id OR
       NEW.suspension_until IS DISTINCT FROM OLD.suspension_until OR
       NEW.last_security_action_at IS DISTINCT FROM OLD.last_security_action_at
     ) THEN
    RAISE EXCEPTION 'account_security_fields_are_admin_only';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_prevent_direct_account_security_update ON public.users;
CREATE TRIGGER users_prevent_direct_account_security_update
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_direct_account_security_update();

-- Repair only rows whose persisted status already says they are restricted.
UPDATE public.users
SET is_active = false,
    updated_at = now()
WHERE account_status IN ('under_review', 'suspended', 'closed')
  AND is_active IS DISTINCT FROM false;

COMMIT;
