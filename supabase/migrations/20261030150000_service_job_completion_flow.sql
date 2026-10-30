BEGIN;

CREATE TABLE IF NOT EXISTS public.service_job_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE REFERENCES public.service_requests(id) ON DELETE CASCADE,
  provider_id uuid NOT NULL REFERENCES public.service_providers(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  executed_on date NOT NULL DEFAULT CURRENT_DATE,
  description text NOT NULL CHECK (char_length(description) BETWEEN 1 AND 200),
  photo_urls text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending_client_confirmation'
    CHECK (status IN ('pending_client_confirmation', 'confirmed', 'disputed', 'unconfirmed')),
  photos_hidden boolean NOT NULL DEFAULT false,
  client_responded_at timestamptz,
  confirmation_deadline timestamptz NOT NULL DEFAULT (now() + interval '3 days'),
  confirmed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT service_job_completion_photo_limit CHECK (cardinality(photo_urls) <= 6)
);

CREATE TABLE IF NOT EXISTS public.service_job_completion_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  completion_id uuid NOT NULL REFERENCES public.service_job_completions(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('delete_photos', 'report')),
  reason text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS service_job_completions_provider_idx ON public.service_job_completions(provider_id, status, executed_on DESC);
CREATE INDEX IF NOT EXISTS service_job_completions_client_idx ON public.service_job_completions(client_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS service_job_actions_completion_idx ON public.service_job_completion_actions(completion_id, created_at DESC);

ALTER TABLE public.service_job_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_job_completion_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_job_completion_public_read ON public.service_job_completions;
CREATE POLICY service_job_completion_public_read ON public.service_job_completions
  FOR SELECT TO anon, authenticated USING (status IN ('confirmed', 'unconfirmed'));
DROP POLICY IF EXISTS service_job_completion_owner_read ON public.service_job_completions;
CREATE POLICY service_job_completion_owner_read ON public.service_job_completions
  FOR SELECT TO authenticated USING (
    client_id = auth.uid()
    OR provider_id IN (SELECT id FROM public.service_providers WHERE user_id = auth.uid())
    OR public.is_admin_actor()
  );
DROP POLICY IF EXISTS service_job_actions_owner_read ON public.service_job_completion_actions;
CREATE POLICY service_job_actions_owner_read ON public.service_job_completion_actions
  FOR SELECT TO authenticated USING (requester_id = auth.uid() OR public.is_admin_actor());

CREATE OR REPLACE FUNCTION public.submit_service_job_completion(p_request_id uuid, p_executed_on date, p_description text, p_photo_urls text[] DEFAULT '{}')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_request public.service_requests%ROWTYPE; v_completion_id uuid;
BEGIN
  SELECT * INTO v_request FROM public.service_requests
  WHERE id = p_request_id AND accepted_provider_id IN (SELECT id FROM public.service_providers WHERE user_id = auth.uid()) FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'هذا الطلب غير مرتبط بحساب مقدم الخدمة الحالي'; END IF;
  IF v_request.status NOT IN ('in_progress', 'completed') THEN RAISE EXCEPTION 'لا يمكن إنهاء الطلب في حالته الحالية'; END IF;
  IF char_length(btrim(coalesce(p_description, ''))) < 1 OR char_length(btrim(p_description)) > 200 THEN RAISE EXCEPTION 'وصف الشغلانة يجب أن يكون من 1 إلى 200 حرف'; END IF;
  IF cardinality(coalesce(p_photo_urls, '{}')) > 6 THEN RAISE EXCEPTION 'الحد الأقصى للصور هو 6'; END IF;
  IF EXISTS (SELECT 1 FROM public.service_job_completions WHERE request_id = p_request_id) THEN RAISE EXCEPTION 'تم إرسال إنهاء هذه الشغلانة من قبل'; END IF;
  INSERT INTO public.service_job_completions(request_id, provider_id, client_id, executed_on, description, photo_urls)
  VALUES (p_request_id, v_request.accepted_provider_id, v_request.user_id, coalesce(p_executed_on, current_date), btrim(p_description), coalesce(p_photo_urls, '{}'))
  RETURNING id INTO v_completion_id;
  UPDATE public.service_requests SET status = 'completed', completed_at = coalesce(completed_at, now()), updated_at = now() WHERE id = p_request_id;
  INSERT INTO public.notifications(user_id, title, body, type, reference_id, reference_type)
  VALUES (v_request.user_id, 'هل تمت هذه الشغلانة؟', 'مقدم الخدمة أعلن انتهاء الشغلانة. راجع التفاصيل واختر تأكيد أو اعتراض خلال 3 أيام.', 'service_job_confirmation', v_completion_id, 'service_job_completion');
  RETURN v_completion_id;
END; $$;

CREATE OR REPLACE FUNCTION public.respond_service_job_completion(p_completion_id uuid, p_response text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_completion public.service_job_completions%ROWTYPE; v_provider_user_id uuid;
BEGIN
  SELECT * INTO v_completion FROM public.service_job_completions WHERE id = p_completion_id AND client_id = auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'الشغلانة غير موجودة'; END IF;
  IF v_completion.status <> 'pending_client_confirmation' THEN RAISE EXCEPTION 'تم التعامل مع هذه الشغلانة من قبل'; END IF;
  IF now() > v_completion.confirmation_deadline THEN
    UPDATE public.service_job_completions SET status = 'unconfirmed', updated_at = now() WHERE id = p_completion_id;
    RETURN 'unconfirmed';
  END IF;
  IF p_response NOT IN ('confirmed', 'disputed') THEN RAISE EXCEPTION 'الاختيار غير صحيح'; END IF;
  UPDATE public.service_job_completions SET status = p_response, client_responded_at = now(), confirmed_at = CASE WHEN p_response = 'confirmed' THEN now() ELSE NULL END, updated_at = now() WHERE id = p_completion_id;
  SELECT user_id INTO v_provider_user_id FROM public.service_providers WHERE id = v_completion.provider_id;
  IF p_response = 'confirmed' THEN
    INSERT INTO public.notifications(user_id, title, body, type, reference_id, reference_type) VALUES (v_provider_user_id, 'تم تأكيد الشغلانة من العميل ✓', 'العميل أكد تنفيذ الشغلانة. ظهرت الآن ضمن أعمالك المؤكدة.', 'service_job_confirmed', p_completion.id, 'service_job_completion');
    INSERT INTO public.notifications(user_id, title, body, type, reference_id, reference_type) VALUES (auth.uid(), 'قيّم مقدم الخدمة', 'تم تأكيد الشغلانة. شارك رأيك في مقدم الخدمة.', 'service_job_rating', p_completion.id, 'service_job_completion');
  ELSE
    INSERT INTO public.service_job_completion_actions(completion_id, requester_id, action_type, reason) VALUES (p_completion.id, auth.uid(), 'report', 'اعتراض العميل على تنفيذ الشغلانة');
    INSERT INTO public.notifications(user_id, title, body, type, reference_id, reference_type)
    SELECT u.id, 'اعتراض على شغلانة منشورة', 'يوجد اعتراض من العميل ويحتاج إلى مراجعة.', 'service_job_dispute', p_completion.id, 'service_job_completion'
    FROM public.users u WHERE lower(coalesce(u.role, u.user_type, '')) = 'admin';
  END IF;
  RETURN p_response;
END; $$;

CREATE OR REPLACE FUNCTION public.expire_service_job_completions()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_count integer;
BEGIN
  UPDATE public.service_job_completions SET status = 'unconfirmed', updated_at = now() WHERE status = 'pending_client_confirmation' AND confirmation_deadline <= now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

CREATE OR REPLACE FUNCTION public.request_service_job_action(p_completion_id uuid, p_action_type text, p_reason text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_completion public.service_job_completions%ROWTYPE; v_action_id uuid;
BEGIN
  PERFORM public.expire_service_job_completions();
  SELECT * INTO v_completion FROM public.service_job_completions WHERE id = p_completion_id AND (client_id = auth.uid() OR status IN ('confirmed', 'unconfirmed'));
  IF NOT FOUND THEN RAISE EXCEPTION 'الشغلانة غير موجودة'; END IF;
  IF p_action_type NOT IN ('delete_photos', 'report') THEN RAISE EXCEPTION 'نوع الطلب غير صحيح'; END IF;
  INSERT INTO public.service_job_completion_actions(completion_id, requester_id, action_type, reason) VALUES (p_completion_id, auth.uid(), p_action_type, nullif(btrim(p_reason), '')) RETURNING id INTO v_action_id;
  IF p_action_type = 'delete_photos' AND v_completion.client_id = auth.uid() THEN UPDATE public.service_job_completions SET photos_hidden = true, updated_at = now() WHERE id = p_completion_id; END IF;
  RETURN v_action_id;
END; $$;

REVOKE ALL ON FUNCTION public.submit_service_job_completion(uuid, date, text, text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.respond_service_job_completion(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.expire_service_job_completions() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.request_service_job_action(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_service_job_completion(uuid, date, text, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_service_job_completion(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_service_job_completions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_service_job_action(uuid, text, text) TO authenticated;

INSERT INTO storage.buckets(id, name, public) VALUES ('service-job-completion-images', 'service-job-completion-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;
DROP POLICY IF EXISTS service_job_images_insert ON storage.objects;
CREATE POLICY service_job_images_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'service-job-completion-images' AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS service_job_images_read ON storage.objects;
CREATE POLICY service_job_images_read ON storage.objects FOR SELECT TO public USING (bucket_id = 'service-job-completion-images');

NOTIFY pgrst, 'reload schema';
COMMIT;
