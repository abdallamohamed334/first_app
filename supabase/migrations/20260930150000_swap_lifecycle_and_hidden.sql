BEGIN;

DO $$
BEGIN
  ALTER TABLE public.swap_listings DROP CONSTRAINT IF EXISTS swap_listings_status_check;
  ALTER TABLE public.swap_listings ADD CONSTRAINT swap_listings_status_check
    CHECK (status IN ('open','paused','closed','cancelled','expired'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.swap_listings
  ALTER COLUMN expires_at SET DEFAULT (now() + interval '7 days');

UPDATE public.swap_listings
SET expires_at = created_at + interval '7 days'
WHERE status IN ('open', 'paused')
  AND expires_at > created_at + interval '7 days';

CREATE TABLE IF NOT EXISTS public.swap_listing_hidden (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES public.swap_listings(id) ON DELETE CASCADE,
  hidden_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

ALTER TABLE public.swap_listing_hidden ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS swap_listing_hidden_select ON public.swap_listing_hidden;
CREATE POLICY swap_listing_hidden_select ON public.swap_listing_hidden FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS swap_listing_hidden_insert ON public.swap_listing_hidden;
CREATE POLICY swap_listing_hidden_insert ON public.swap_listing_hidden FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS swap_listing_hidden_delete ON public.swap_listing_hidden;
CREATE POLICY swap_listing_hidden_delete ON public.swap_listing_hidden FOR DELETE TO authenticated USING (user_id = auth.uid());
GRANT SELECT, INSERT, DELETE ON public.swap_listing_hidden TO authenticated;

COMMIT;
