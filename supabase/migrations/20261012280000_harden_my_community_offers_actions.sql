BEGIN;

-- Do not trust a user id supplied by the client. Bind both actions to auth.uid().
CREATE OR REPLACE FUNCTION public.mark_community_offer_completed(
  p_offer_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_owner uuid;
  v_status text;
BEGIN
  IF v_user_id IS NULL OR p_user_id IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'يجب استخدام حساب المستخدم الحالي' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id, status
  INTO v_owner, v_status
  FROM public.community_offers
  WHERE id = p_offer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'العرض غير موجود' USING ERRCODE = 'P0010';
  END IF;
  IF v_owner IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'لا تملك صلاحية تعديل هذا العرض' USING ERRCODE = 'P0011';
  END IF;
  IF v_status <> 'available' THEN
    RAISE EXCEPTION 'لا يمكن إكمال عرض بحالة: %', v_status USING ERRCODE = 'P0012';
  END IF;

  UPDATE public.community_offers
  SET status = 'completed', updated_at = now()
  WHERE id = p_offer_id AND owner_id = v_user_id AND status = 'available';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'تم تحديث العرض من جهاز آخر';
  END IF;
  RETURN true;
END;
$function$;

DROP FUNCTION IF EXISTS public.renew_community_offer(uuid, uuid, integer);

CREATE OR REPLACE FUNCTION public.renew_community_offer(
  p_offer_id uuid,
  p_user_id uuid,
  p_days integer
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_owner uuid;
  v_status text;
  v_old_expires timestamptz;
  v_new_expiry timestamptz;
BEGIN
  IF v_user_id IS NULL OR p_user_id IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'يجب استخدام حساب المستخدم الحالي' USING ERRCODE = '42501';
  END IF;
  IF p_days <> 7 THEN
    RAISE EXCEPTION 'يمكن تجديد العرض لمدة أسبوع واحد فقط';
  END IF;
  IF NOT public.can_renew_offer(v_user_id) THEN
    RAISE EXCEPTION 'لقد وصلت للحد الأقصى من التجديدات اليومية (5 تجديدات). حاول مرة أخرى غدًا.'
      USING ERRCODE = 'P0101';
  END IF;

  SELECT owner_id, status, expires_at
  INTO v_owner, v_status, v_old_expires
  FROM public.community_offers
  WHERE id = p_offer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'العرض غير موجود' USING ERRCODE = 'P0010';
  END IF;
  IF v_owner IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'لا تملك صلاحية تعديل هذا العرض' USING ERRCODE = 'P0011';
  END IF;
  IF v_status <> 'expired' THEN
    RAISE EXCEPTION 'لا يمكن تجديد عرض بحالة: %', v_status USING ERRCODE = 'P0013';
  END IF;

  v_new_expiry := now() + interval '7 days';
  UPDATE public.community_offers
  SET status = 'available', expires_at = v_new_expiry, updated_at = now()
  WHERE id = p_offer_id AND owner_id = v_user_id AND status = 'expired';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'تم تحديث العرض من جهاز آخر';
  END IF;

  INSERT INTO public.offer_renewals_log (offer_id, user_id, old_expires_at, new_expires_at)
  VALUES (p_offer_id, v_user_id, v_old_expires, v_new_expiry);
  RETURN v_new_expiry;
END;
$function$;

REVOKE ALL ON FUNCTION public.mark_community_offer_completed(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.mark_community_offer_completed(uuid, uuid)
  TO authenticated;

REVOKE ALL ON FUNCTION public.renew_community_offer(uuid, uuid, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.renew_community_offer(uuid, uuid, integer)
  TO authenticated;

COMMIT;
