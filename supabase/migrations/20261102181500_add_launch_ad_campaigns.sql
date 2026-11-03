CREATE TABLE IF NOT EXISTS public.advertising_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  image_url text NOT NULL,
  target_url text,
  whatsapp text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'active', 'paused', 'rejected', 'expired')),
  is_enabled boolean NOT NULL DEFAULT false,
  priority integer NOT NULL DEFAULT 0,
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.advertising_campaigns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read active advertising campaigns" ON public.advertising_campaigns;
CREATE POLICY "Public can read active advertising campaigns"
  ON public.advertising_campaigns
  FOR SELECT
  TO anon, authenticated
  USING (
    status = 'active'
    AND is_enabled = true
    AND starts_at <= now()
    AND ends_at >= now()
  );

GRANT SELECT ON public.advertising_campaigns TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
