-- Allow a logged-in user to add a contact email to an empty profile once.
-- Replacing an existing email remains blocked by the account-field guard.
CREATE OR REPLACE FUNCTION public.prevent_user_account_field_escalation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() = OLD.id THEN
    IF NEW.id IS DISTINCT FROM OLD.id
      OR (
        NULLIF(btrim(OLD.email), '') IS NOT NULL
        AND NEW.email IS DISTINCT FROM OLD.email
      )
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
