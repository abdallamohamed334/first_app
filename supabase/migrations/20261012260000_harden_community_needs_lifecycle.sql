-- Harden community-needs writes and bound the owner listing.
BEGIN;

CREATE OR REPLACE FUNCTION public.update_community_need(
  p_need_id uuid,
  p_patch jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_need public.community_needs%rowtype;
  v_title text;
  v_quantity integer;
  v_urgency text;
BEGIN
  IF auth.uid() IS NULL OR p_need_id IS NULL OR p_patch IS NULL THEN
    RAISE EXCEPTION 'يجب تسجيل الدخول وبيانات الاحتياج مطلوبة';
  END IF;

  SELECT * INTO v_need
  FROM public.community_needs
  WHERE id = p_need_id AND requester_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الاحتياج غير موجود أو ليس ملكك'; END IF;
  IF v_need.status NOT IN ('active', 'matched') THEN
    RAISE EXCEPTION 'لا يمكن تعديل احتياج في حالته الحالية';
  END IF;

  v_title := CASE WHEN p_patch ? 'title' THEN NULLIF(btrim(p_patch->>'title'), '') ELSE v_need.title END;
  v_quantity := CASE WHEN p_patch ? 'quantity' AND p_patch->>'quantity' IS NOT NULL
                     THEN (p_patch->>'quantity')::integer ELSE v_need.quantity END;
  v_urgency := CASE WHEN p_patch ? 'urgency' THEN p_patch->>'urgency' ELSE v_need.urgency END;

  IF v_title IS NULL OR length(v_title) < 3 THEN RAISE EXCEPTION 'عنوان الاحتياج قصير جدًا'; END IF;
  IF v_quantity IS NULL OR v_quantity <= 0 THEN RAISE EXCEPTION 'الكمية يجب أن تكون أكبر من صفر'; END IF;
  IF v_urgency NOT IN ('low', 'normal', 'high', 'urgent') THEN RAISE EXCEPTION 'الأولوية غير صحيحة'; END IF;
  IF p_patch ? 'contact_phone' AND NULLIF(btrim(p_patch->>'contact_phone'), '') IS NULL THEN RAISE EXCEPTION 'رقم الهاتف مطلوب'; END IF;
  IF p_patch ? 'contact_whatsapp' AND NULLIF(btrim(p_patch->>'contact_whatsapp'), '') IS NULL THEN RAISE EXCEPTION 'رقم الواتساب مطلوب'; END IF;

  UPDATE public.community_needs
  SET title = v_title,
      description = CASE WHEN p_patch ? 'description' THEN NULLIF(btrim(p_patch->>'description'), '') ELSE description END,
      quantity = v_quantity,
      urgency = v_urgency,
      city = CASE WHEN p_patch ? 'city' THEN NULLIF(btrim(p_patch->>'city'), '') ELSE city END,
      address = CASE WHEN p_patch ? 'address' THEN NULLIF(btrim(p_patch->>'address'), '') ELSE address END,
      contact_phone = CASE WHEN p_patch ? 'contact_phone' THEN NULLIF(btrim(p_patch->>'contact_phone'), '') ELSE contact_phone END,
      contact_whatsapp = CASE WHEN p_patch ? 'contact_whatsapp' THEN NULLIF(btrim(p_patch->>'contact_whatsapp'), '') ELSE contact_whatsapp END,
      need_category = CASE WHEN p_patch ? 'need_category' THEN NULLIF(btrim(p_patch->>'need_category'), '') ELSE need_category END,
      category_slug = CASE WHEN p_patch ? 'category_slug' THEN NULLIF(btrim(p_patch->>'category_slug'), '') ELSE category_slug END,
      category_name_ar = CASE WHEN p_patch ? 'category_name_ar' THEN NULLIF(btrim(p_patch->>'category_name_ar'), '') ELSE category_name_ar END,
      image_url = CASE WHEN p_patch ? 'image_url' THEN NULLIF(btrim(p_patch->>'image_url'), '') ELSE image_url END,
      updated_at = now()
  WHERE id = p_need_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_community_need(p_need_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  UPDATE public.community_needs
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_need_id
    AND requester_id = auth.uid()
    AND status IN ('active', 'matched');
  IF NOT FOUND THEN RAISE EXCEPTION 'الاحتياج غير موجود أو لا يمكن إلغاؤه الآن'; END IF;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.fulfill_community_need(p_need_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  UPDATE public.community_needs
  SET status = 'fulfilled', fulfilled_by = auth.uid(), fulfilled_at = now(), updated_at = now()
  WHERE id = p_need_id
    AND requester_id = auth.uid()
    AND status IN ('active', 'matched');
  IF NOT FOUND THEN RAISE EXCEPTION 'الاحتياج غير موجود أو لا يمكن إكماله الآن'; END IF;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_community_needs()
RETURNS SETOF public.community_needs
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT cn.*
  FROM public.community_needs cn
  WHERE cn.requester_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM public.dismissed_community_needs d
      WHERE d.user_id = auth.uid() AND d.need_id = cn.id
    )
  ORDER BY cn.created_at DESC
  LIMIT 200;
$$;

-- Keep direct client updates closed; the RPCs above are the write boundary.
REVOKE UPDATE ON TABLE public.community_needs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_community_need(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_community_need(uuid, jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.cancel_community_need(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_community_need(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.fulfill_community_need(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fulfill_community_need(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.list_my_community_needs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_my_community_needs() TO authenticated;

CREATE INDEX IF NOT EXISTS community_needs_active_feed_idx
  ON public.community_needs (status, expires_at, urgency, created_at DESC)
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS community_needs_owner_created_idx
  ON public.community_needs (requester_id, created_at DESC);

COMMIT;
