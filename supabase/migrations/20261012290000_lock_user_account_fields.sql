-- Prevent an authenticated user from mutating account/security fields on their own
-- public.users row through the broad legacy users_update_own policy.
-- Server-side/service-role operations (auth.uid() IS NULL) remain unaffected.

CREATE OR REPLACE FUNCTION public.prevent_user_account_field_escalation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() = OLD.id THEN
    IF NEW.id IS DISTINCT FROM OLD.id
      OR NEW.email IS DISTINCT FROM OLD.email
      OR NEW.phone IS DISTINCT FROM OLD.phone
      OR NEW.password IS DISTINCT FROM OLD.password
      OR NEW.points IS DISTINCT FROM OLD.points
      OR NEW.level IS DISTINCT FROM OLD.level
      OR NEW.is_verified IS DISTINCT FROM OLD.is_verified
      OR NEW.is_phone_verified IS DISTINCT FROM OLD.is_phone_verified
      OR NEW.is_active IS DISTINCT FROM OLD.is_active
      OR NEW.user_type IS DISTINCT FROM OLD.user_type
      OR NEW.role IS DISTINCT FROM OLD.role
      OR NEW.created_at IS DISTINCT FROM OLD.created_at
      OR NEW.last_login_at IS DISTINCT FROM OLD.last_login_at
      OR NEW.account_status IS DISTINCT FROM OLD.account_status
      OR NEW.suspended_at IS DISTINCT FROM OLD.suspended_at
      OR NEW.suspended_by IS DISTINCT FROM OLD.suspended_by
      OR NEW.suspension_reason IS DISTINCT FROM OLD.suspension_reason
      OR NEW.suspension_case_id IS DISTINCT FROM OLD.suspension_case_id
      OR NEW.suspension_until IS DISTINCT FROM OLD.suspension_until
      OR NEW.last_security_action_at IS DISTINCT FROM OLD.last_security_action_at
    THEN
      RAISE EXCEPTION 'لا يمكن تعديل بيانات أمان الحساب من التطبيق'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_user_account_field_escalation
  ON public.users;

CREATE TRIGGER trg_prevent_user_account_field_escalation
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_user_account_field_escalation();

REVOKE ALL ON FUNCTION public.prevent_user_account_field_escalation() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.prevent_user_account_field_escalation() FROM anon;
REVOKE ALL ON FUNCTION public.prevent_user_account_field_escalation() FROM authenticated;
