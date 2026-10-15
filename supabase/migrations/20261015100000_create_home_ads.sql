-- Home advertisements are independent from marketplace offers.
-- The app calls get_active_home_ads(), which also deactivates expired rows.

CREATE TABLE IF NOT EXISTS public.home_ads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advertiser_name text NOT NULL,
  title text,
  subtitle text,
  image_url text NOT NULL,
  target_url text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT false,
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT home_ads_valid_period CHECK (ends_at > starts_at),
  CONSTRAINT home_ads_non_negative_sort_order CHECK (sort_order >= 0),
  CONSTRAINT home_ads_image_url_not_blank CHECK (length(trim(image_url)) > 0),
  CONSTRAINT home_ads_advertiser_not_blank CHECK (length(trim(advertiser_name)) > 0)
);

CREATE INDEX IF NOT EXISTS home_ads_active_schedule_idx
  ON public.home_ads (is_active, starts_at, ends_at, sort_order);

ALTER TABLE public.home_ads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS home_ads_public_active_read ON public.home_ads;
CREATE POLICY home_ads_public_active_read
  ON public.home_ads
  FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND starts_at <= now()
    AND ends_at > now()
  );

DROP POLICY IF EXISTS home_ads_admin_read ON public.home_ads;
CREATE POLICY home_ads_admin_read
  ON public.home_ads
  FOR SELECT
  TO authenticated
  USING (public.is_admin_actor());

DROP POLICY IF EXISTS home_ads_admin_insert ON public.home_ads;
CREATE POLICY home_ads_admin_insert
  ON public.home_ads
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_actor());

DROP POLICY IF EXISTS home_ads_admin_update ON public.home_ads;
CREATE POLICY home_ads_admin_update
  ON public.home_ads
  FOR UPDATE
  TO authenticated
  USING (public.is_admin_actor())
  WITH CHECK (public.is_admin_actor());

DROP POLICY IF EXISTS home_ads_admin_delete ON public.home_ads;
CREATE POLICY home_ads_admin_delete
  ON public.home_ads
  FOR DELETE
  TO authenticated
  USING (public.is_admin_actor());

CREATE OR REPLACE FUNCTION public.set_home_ads_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS home_ads_updated_at ON public.home_ads;
CREATE TRIGGER home_ads_updated_at
BEFORE UPDATE ON public.home_ads
FOR EACH ROW EXECUTE FUNCTION public.set_home_ads_updated_at();

CREATE OR REPLACE FUNCTION public.get_active_home_ads()
RETURNS TABLE (
  id uuid,
  advertiser_name text,
  title text,
  subtitle text,
  image_url text,
  target_url text,
  sort_order integer,
  is_active boolean,
  starts_at timestamptz,
  ends_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  UPDATE public.home_ads AS expired
  SET is_active = false,
      updated_at = now()
  WHERE expired.is_active = true
    AND expired.ends_at <= now();

  RETURN QUERY
  SELECT a.id, a.advertiser_name, a.title, a.subtitle, a.image_url,
         a.target_url, a.sort_order, a.is_active, a.starts_at, a.ends_at
  FROM public.home_ads AS a
  WHERE a.is_active = true
    AND a.starts_at <= now()
    AND a.ends_at > now()
  ORDER BY a.sort_order ASC, a.created_at DESC
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_home_ads() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_home_ads() TO anon, authenticated;
