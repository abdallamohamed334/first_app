BEGIN;

CREATE TABLE IF NOT EXISTS public.swap_listing_views (
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES public.swap_listings(id) ON DELETE CASCADE,
  last_viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, listing_id)
);

CREATE INDEX IF NOT EXISTS swap_listing_views_user_recent_idx
  ON public.swap_listing_views (user_id, last_viewed_at DESC);

ALTER TABLE public.swap_listing_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS swap_listing_views_select_own ON public.swap_listing_views;
CREATE POLICY swap_listing_views_select_own
  ON public.swap_listing_views FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS swap_listing_views_insert_own ON public.swap_listing_views;
CREATE POLICY swap_listing_views_insert_own
  ON public.swap_listing_views FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS swap_listing_views_update_own ON public.swap_listing_views;
CREATE POLICY swap_listing_views_update_own
  ON public.swap_listing_views FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

COMMIT;
