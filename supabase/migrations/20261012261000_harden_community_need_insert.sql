-- Normalize client-created community needs at the database boundary.
BEGIN;

CREATE OR REPLACE FUNCTION public.protect_community_need_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.requester_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'لا يمكنك إنشاء احتياج باسم مستخدم آخر';
  END IF;
  IF auth.uid() IS NOT NULL THEN
    NEW.requester_id := auth.uid();
    NEW.status := 'active';
    NEW.fulfilled_by := NULL;
    NEW.fulfilled_at := NULL;
    NEW.contact_count := 0;
    NEW.phone_count := 0;
    NEW.whatsapp_count := 0;
    NEW.created_at := now();
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS community_needs_protect_insert ON public.community_needs;
CREATE TRIGGER community_needs_protect_insert
BEFORE INSERT ON public.community_needs
FOR EACH ROW EXECUTE FUNCTION public.protect_community_need_insert();

COMMIT;
