-- Count unique authenticated viewers for community marketplace offers.
ALTER TABLE public.community_offers
  ADD COLUMN IF NOT EXISTS views_count bigint NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.community_offer_views (
  offer_id uuid NOT NULL REFERENCES public.community_offers(id) ON DELETE CASCADE,
  viewer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (offer_id, viewer_id)
);

ALTER TABLE public.community_offer_views ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.community_offer_views FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_community_offer_view(p_offer_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_owner_id uuid;
  v_views_count bigint;
  v_inserted integer;
BEGIN
  IF v_viewer_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to record an offer view'
      USING ERRCODE = '42501';
  END IF;

  SELECT o.owner_id, COALESCE(o.views_count, 0)
    INTO v_owner_id, v_views_count
  FROM public.community_offers AS o
  WHERE o.id = p_offer_id
    AND o.charity_id IS NULL
    AND o.listing_type = 'symbolic_sale';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Community offer not found'
      USING ERRCODE = 'P0002';
  END IF;

  -- The owner can see the current total, but viewing their own offer is not counted.
  IF v_owner_id = v_viewer_id THEN
    RETURN v_views_count;
  END IF;

  INSERT INTO public.community_offer_views (offer_id, viewer_id)
  VALUES (p_offer_id, v_viewer_id)
  ON CONFLICT (offer_id, viewer_id) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  IF v_inserted > 0 THEN
    UPDATE public.community_offers
    SET views_count = COALESCE(views_count, 0) + 1
    WHERE id = p_offer_id
    RETURNING views_count INTO v_views_count;
  END IF;

  RETURN COALESCE(v_views_count, 0);
END;
$$;

REVOKE ALL ON FUNCTION public.record_community_offer_view(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_community_offer_view(uuid) TO authenticated;
