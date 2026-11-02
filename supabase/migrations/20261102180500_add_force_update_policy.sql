CREATE TABLE IF NOT EXISTS public.app_update_policy (
  id text PRIMARY KEY DEFAULT 'global',
  minimum_version text NOT NULL DEFAULT '1.0.0',
  minimum_build integer NOT NULL DEFAULT 1,
  android_store_url text NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=com.jood.com',
  ios_store_url text NOT NULL DEFAULT 'https://apps.apple.com/eg/search?term=Khedma',
  web_update_url text NOT NULL DEFAULT 'https://play.google.com/store/apps/details?id=com.jood.com',
  message text NOT NULL DEFAULT 'يوجد إصدار جديد إلزامي من التطبيق. حدّث التطبيق للمتابعة.',
  is_enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_update_policy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read app update policy" ON public.app_update_policy;
CREATE POLICY "Public can read app update policy"
  ON public.app_update_policy
  FOR SELECT
  TO anon, authenticated
  USING (is_enabled = true);

INSERT INTO public.app_update_policy (id)
VALUES ('global')
ON CONFLICT (id) DO NOTHING;

GRANT SELECT ON public.app_update_policy TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
