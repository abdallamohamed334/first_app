BEGIN;

CREATE OR REPLACE FUNCTION public.prevent_locked_provider_profile_changes()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.profile_locked_at IS NOT NULL THEN
    IF NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.category_id IS DISTINCT FROM OLD.category_id
      OR NEW.provider_type IS DISTINCT FROM OLD.provider_type
      OR NEW.phone IS DISTINCT FROM OLD.phone
      OR NEW.email IS DISTINCT FROM OLD.email
      OR NEW.verification_status IS DISTINCT FROM OLD.verification_status
      OR NEW.verification_notes IS DISTINCT FROM OLD.verification_notes
      OR NEW.verified_by IS DISTINCT FROM OLD.verified_by
      OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
      OR NEW.is_active IS DISTINCT FROM OLD.is_active
      OR NEW.id_card_front_url IS DISTINCT FROM OLD.id_card_front_url
      OR NEW.id_card_back_url IS DISTINCT FROM OLD.id_card_back_url
      OR NEW.profile_locked_at IS DISTINCT FROM OLD.profile_locked_at
    THEN
      RAISE EXCEPTION 'provider_identity_fields_locked';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
COMMIT;
