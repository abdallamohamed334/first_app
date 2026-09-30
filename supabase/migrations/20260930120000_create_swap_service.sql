-- Swap service: users publish what they want and other users propose an item in exchange.
BEGIN;

CREATE TABLE IF NOT EXISTS public.swap_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  wanted_title text NOT NULL CHECK (char_length(btrim(wanted_title)) BETWEEN 3 AND 120),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 10 AND 3000),
  category text NOT NULL DEFAULT 'other' CHECK (char_length(btrim(category)) BETWEEN 2 AND 80),
  wanted_condition text NOT NULL DEFAULT 'any' CHECK (wanted_condition IN ('new','like_new','good','used','any')),
  city text,
  governorate text,
  latitude double precision CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  longitude double precision CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  images text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','paused','closed','expired')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS public.swap_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.swap_listings(id) ON DELETE CASCADE,
  proposer_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  offered_title text NOT NULL CHECK (char_length(btrim(offered_title)) BETWEEN 3 AND 120),
  offered_description text NOT NULL CHECK (char_length(btrim(offered_description)) BETWEEN 10 AND 3000),
  offered_condition text NOT NULL DEFAULT 'good' CHECK (offered_condition IN ('new','like_new','good','used','needs_repair')),
  images text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','withdrawn')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  UNIQUE (listing_id, proposer_id)
);

CREATE INDEX IF NOT EXISTS swap_listings_open_idx
  ON public.swap_listings (status, expires_at, created_at DESC);
CREATE INDEX IF NOT EXISTS swap_listings_owner_idx
  ON public.swap_listings (owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS swap_proposals_listing_idx
  ON public.swap_proposals (listing_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS swap_proposals_proposer_idx
  ON public.swap_proposals (proposer_id, created_at DESC);

ALTER TABLE public.swap_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swap_proposals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS swap_listings_public_read ON public.swap_listings;
CREATE POLICY swap_listings_public_read ON public.swap_listings
  FOR SELECT TO authenticated
  USING (status = 'open' AND expires_at > now() OR owner_id = auth.uid());
DROP POLICY IF EXISTS swap_listings_owner_insert ON public.swap_listings;
CREATE POLICY swap_listings_owner_insert ON public.swap_listings
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());
DROP POLICY IF EXISTS swap_listings_owner_update ON public.swap_listings;
CREATE POLICY swap_listings_owner_update ON public.swap_listings
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());
DROP POLICY IF EXISTS swap_listings_owner_delete ON public.swap_listings;
CREATE POLICY swap_listings_owner_delete ON public.swap_listings
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

DROP POLICY IF EXISTS swap_proposals_involved_read ON public.swap_proposals;
CREATE POLICY swap_proposals_involved_read ON public.swap_proposals
  FOR SELECT TO authenticated
  USING (
    proposer_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.swap_listings l
      WHERE l.id = listing_id AND l.owner_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS swap_proposals_proposer_insert ON public.swap_proposals;
CREATE POLICY swap_proposals_proposer_insert ON public.swap_proposals
  FOR INSERT TO authenticated
  WITH CHECK (
    proposer_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.swap_listings l
      WHERE l.id = listing_id AND l.owner_id <> auth.uid()
        AND l.status = 'open' AND l.expires_at > now()
    )
  );
CREATE OR REPLACE FUNCTION public.create_swap_proposal(
  p_listing_id uuid,
  p_offered_title text,
  p_offered_description text,
  p_offered_condition text,
  p_images text[] DEFAULT '{}'
) RETURNS public.swap_proposals
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_row public.swap_proposals;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.swap_listings
    WHERE id = p_listing_id AND owner_id <> auth.uid()
      AND status = 'open' AND expires_at > now()
  ) THEN RAISE EXCEPTION 'Swap listing is not available'; END IF;
  INSERT INTO public.swap_proposals
    (listing_id, proposer_id, offered_title, offered_description, offered_condition, images)
  VALUES
    (p_listing_id, auth.uid(), btrim(p_offered_title), btrim(p_offered_description),
     p_offered_condition, COALESCE(p_images, '{}'))
  RETURNING * INTO v_row;
  RETURN v_row;
EXCEPTION WHEN unique_violation THEN
  RAISE EXCEPTION 'You already proposed a swap for this listing';
END;
$$;

CREATE OR REPLACE FUNCTION public.update_swap_proposal_status(
  p_proposal_id uuid,
  p_status text
) RETURNS public.swap_proposals
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_row public.swap_proposals; v_listing public.swap_listings;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT p.* INTO v_row FROM public.swap_proposals p WHERE p.id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Proposal not found'; END IF;
  SELECT l.* INTO v_listing FROM public.swap_listings l WHERE l.id = v_row.listing_id FOR UPDATE;
  IF v_listing.owner_id <> auth.uid() AND v_row.proposer_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_status NOT IN ('accepted','rejected','withdrawn') THEN RAISE EXCEPTION 'Invalid status'; END IF;
  IF p_status = 'withdrawn' AND v_row.proposer_id <> auth.uid() THEN RAISE EXCEPTION 'Only proposer can withdraw'; END IF;
  IF p_status IN ('accepted','rejected') AND v_listing.owner_id <> auth.uid() THEN RAISE EXCEPTION 'Only listing owner can decide'; END IF;
  IF v_row.status <> 'pending' THEN RAISE EXCEPTION 'Proposal is no longer pending'; END IF;
  IF p_status = 'accepted' THEN
    IF v_listing.status <> 'open' OR v_listing.expires_at <= now() THEN RAISE EXCEPTION 'Listing is no longer open'; END IF;
    UPDATE public.swap_proposals SET status = 'rejected', updated_at = now()
      WHERE listing_id = v_row.listing_id AND id <> v_row.id AND status = 'pending';
    UPDATE public.swap_listings SET status = 'closed', updated_at = now() WHERE id = v_row.listing_id;
  END IF;
  UPDATE public.swap_proposals SET status = p_status,
    accepted_at = CASE WHEN p_status = 'accepted' THEN now() ELSE accepted_at END,
    updated_at = now() WHERE id = v_row.id RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.create_swap_proposal(uuid,text,text,text,text[]) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_swap_proposal(uuid,text,text,text,text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_swap_proposal(uuid,text,text,text,text[]) TO authenticated;
REVOKE ALL ON FUNCTION public.update_swap_proposal_status(uuid,text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_swap_proposal_status(uuid,text) FROM anon;
GRANT EXECUTE ON FUNCTION public.update_swap_proposal_status(uuid,text) TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.swap_listings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.swap_proposals TO authenticated;

COMMIT;
