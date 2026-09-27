-- An institution may complete an offer request only after pickup verification.

CREATE OR REPLACE FUNCTION public.institution_complete_offer_request(p_request_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_institution_id uuid;
  v_current_status text;
BEGIN
  SELECT o.institution_id, r.status
  INTO v_institution_id, v_current_status
  FROM public.institution_offer_requests r
  JOIN public.institution_offers o ON o.id = r.offer_id
  WHERE r.id = p_request_id;

  IF v_institution_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'الطلب غير موجود');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.institutions
    WHERE id = v_institution_id AND user_id = auth.uid() AND status = 'approved'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'غير مصرح لك بتحديث هذا الطلب');
  END IF;

  IF v_current_status <> 'picked_up' THEN
    RETURN json_build_object('success', false, 'message', 'لا يمكن إكمال الطلب قبل تأكيد الاستلام');
  END IF;

  UPDATE public.institution_offer_requests
  SET status = 'completed', updated_at = now()
  WHERE id = p_request_id;

  RETURN json_build_object('success', true, 'message', 'تم إكمال الطلب بنجاح', 'status', 'completed');
END;
$function$;
