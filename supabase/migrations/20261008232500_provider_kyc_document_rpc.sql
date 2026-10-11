BEGIN;

CREATE OR REPLACE FUNCTION public.link_my_provider_identity_documents(
  p_provider_id uuid,
  p_front_path text DEFAULT NULL,
  p_back_path text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage, pg_temp
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_provider public.service_providers%ROWTYPE;
  v_front text;
  v_back text;
  v_front_prefix text;
  v_back_prefix text;
BEGIN
  IF v_user_id IS NULL OR p_provider_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول');
  END IF;

  SELECT * INTO v_provider
  FROM public.service_providers
  WHERE id = p_provider_id
    AND user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملف غير موجود');
  END IF;

  IF v_provider.profile_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'تم قفل الملف للمراجعة');
  END IF;

  v_front := NULLIF(trim(p_front_path), '');
  v_back := NULLIF(trim(p_back_path), '');
  v_front_prefix := v_user_id::text || '/id_card_front_';
  v_back_prefix := v_user_id::text || '/id_card_back_';

  IF v_front IS NOT NULL AND (
    left(v_front, length(v_front_prefix)) <> v_front_prefix
    OR v_front !~ '^[0-9a-f-]+/id_card_front_[0-9]+[.]webp$'
    OR NOT EXISTS (
      SELECT 1 FROM storage.objects o
      WHERE o.bucket_id = 'provider-documents' AND o.name = v_front
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'مسار صورة الوجه الأمامي غير صالح');
  END IF;

  IF v_back IS NOT NULL AND (
    left(v_back, length(v_back_prefix)) <> v_back_prefix
    OR v_back !~ '^[0-9a-f-]+/id_card_back_[0-9]+[.]webp$'
    OR NOT EXISTS (
      SELECT 1 FROM storage.objects o
      WHERE o.bucket_id = 'provider-documents' AND o.name = v_back
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'مسار صورة الوجه الخلفي غير صالح');
  END IF;

  v_front := coalesce(v_front, v_provider.id_card_front_url);
  v_back := coalesce(v_back, v_provider.id_card_back_url);

  UPDATE public.service_providers
  SET id_card_front_url = v_front,
      id_card_back_url = v_back,
      profile_locked_at = CASE
        WHEN v_front IS NOT NULL AND v_back IS NOT NULL
          THEN coalesce(profile_locked_at, now())
        ELSE profile_locked_at
      END,
      updated_at = now()
  WHERE id = p_provider_id
    AND user_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'profile_locked', v_front IS NOT NULL AND v_back IS NOT NULL
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.link_my_provider_identity_documents(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.link_my_provider_identity_documents(uuid, text, text)
  TO authenticated;

COMMIT;
