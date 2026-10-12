-- Publish provider cards through an explicit, sanitized projection table.
-- This removes the need for a SECURITY DEFINER public view over KYC/profile tables.
BEGIN;

CREATE TABLE IF NOT EXISTS public.published_service_provider_cards (
  id uuid PRIMARY KEY,
  category_id uuid NOT NULL,
  provider_type text NOT NULL,
  display_name text NOT NULL,
  bio text,
  experience_years integer,
  skills text[] NOT NULL DEFAULT '{}'::text[],
  profile_image_url text,
  cover_image_url text,
  portfolio_images text[] NOT NULL DEFAULT '{}'::text[],
  governorate text,
  city text,
  address text,
  service_areas text[] NOT NULL DEFAULT '{}'::text[],
  available_days text[] NOT NULL DEFAULT '{}'::text[],
  latitude double precision,
  longitude double precision,
  max_distance_km integer NOT NULL DEFAULT 15,
  pricing_type text NOT NULL DEFAULT 'market',
  price_from numeric,
  price_currency text NOT NULL DEFAULT 'EGP',
  accepts_installments boolean NOT NULL DEFAULT false,
  phone text,
  whatsapp text,
  email text,
  website text,
  verification_status text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  is_available boolean NOT NULL DEFAULT true,
  availability_note text,
  total_jobs integer NOT NULL DEFAULT 0,
  completed_jobs integer NOT NULL DEFAULT 0,
  cancelled_jobs integer NOT NULL DEFAULT 0,
  volunteer_jobs integer NOT NULL DEFAULT 0,
  rating_avg numeric NOT NULL DEFAULT 0,
  total_reviews integer NOT NULL DEFAULT 0,
  response_time_minutes integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  category_name text,
  category_icon text,
  category_slug text
);

ALTER TABLE public.published_service_provider_cards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS published_provider_cards_read ON public.published_service_provider_cards;
CREATE POLICY published_provider_cards_read
  ON public.published_service_provider_cards
  FOR SELECT TO anon, authenticated
  USING (verification_status = 'approved' AND is_active AND is_available);

REVOKE ALL ON public.published_service_provider_cards FROM PUBLIC;
GRANT SELECT ON public.published_service_provider_cards TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.sync_published_service_provider_card()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE'
     OR NEW.verification_status IS DISTINCT FROM 'approved'
     OR NEW.is_active IS NOT TRUE
     OR NEW.is_available IS NOT TRUE THEN
    DELETE FROM public.published_service_provider_cards
    WHERE id = COALESCE(OLD.id, NEW.id);
    RETURN COALESCE(NEW, OLD);
  END IF;

  INSERT INTO public.published_service_provider_cards (
    id, category_id, provider_type, display_name, bio, experience_years,
    skills, profile_image_url, cover_image_url, portfolio_images,
    governorate, city, address, service_areas, available_days,
    latitude, longitude, max_distance_km, pricing_type, price_from,
    price_currency, accepts_installments, phone, whatsapp, email, website,
    verification_status, is_active, is_available, availability_note,
    total_jobs, completed_jobs, cancelled_jobs, volunteer_jobs, rating_avg,
    total_reviews, response_time_minutes, created_at, updated_at,
    category_name, category_icon, category_slug
  )
  SELECT
    sp.id, sp.category_id, sp.provider_type, sp.display_name, sp.bio,
    sp.experience_years, COALESCE(sp.skills, '{}'::text[]),
    sp.profile_image_url, sp.cover_image_url,
    COALESCE(sp.portfolio_images, '{}'::text[]), sp.governorate, sp.city,
    sp.address, COALESCE(sp.service_areas, '{}'::text[]),
    COALESCE(sp.available_days, '{}'::text[]), sp.latitude, sp.longitude,
    COALESCE(sp.max_distance_km, 15), COALESCE(sp.pricing_type, 'market'),
    sp.price_from, COALESCE(sp.price_currency, 'EGP'),
    COALESCE(sp.accepts_installments, false), sp.phone, sp.whatsapp,
    sp.email, sp.website, sp.verification_status, sp.is_active,
    sp.is_available, sp.availability_note, COALESCE(sp.total_jobs, 0),
    COALESCE(sp.completed_jobs, 0), COALESCE(sp.cancelled_jobs, 0),
    COALESCE(sp.volunteer_jobs, 0), COALESCE(sp.rating_avg, 0),
    COALESCE(sp.total_reviews, 0), sp.response_time_minutes, sp.created_at,
    sp.updated_at, sc.name_ar, sc.icon, sc.slug
  FROM public.service_providers sp
  LEFT JOIN public.service_categories sc ON sc.id = sp.category_id
  WHERE sp.id = NEW.id
  ON CONFLICT (id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    provider_type = EXCLUDED.provider_type,
    display_name = EXCLUDED.display_name,
    bio = EXCLUDED.bio,
    experience_years = EXCLUDED.experience_years,
    skills = EXCLUDED.skills,
    profile_image_url = EXCLUDED.profile_image_url,
    cover_image_url = EXCLUDED.cover_image_url,
    portfolio_images = EXCLUDED.portfolio_images,
    governorate = EXCLUDED.governorate,
    city = EXCLUDED.city,
    address = EXCLUDED.address,
    service_areas = EXCLUDED.service_areas,
    available_days = EXCLUDED.available_days,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    max_distance_km = EXCLUDED.max_distance_km,
    pricing_type = EXCLUDED.pricing_type,
    price_from = EXCLUDED.price_from,
    price_currency = EXCLUDED.price_currency,
    accepts_installments = EXCLUDED.accepts_installments,
    phone = EXCLUDED.phone,
    whatsapp = EXCLUDED.whatsapp,
    email = EXCLUDED.email,
    website = EXCLUDED.website,
    verification_status = EXCLUDED.verification_status,
    is_active = EXCLUDED.is_active,
    is_available = EXCLUDED.is_available,
    availability_note = EXCLUDED.availability_note,
    total_jobs = EXCLUDED.total_jobs,
    completed_jobs = EXCLUDED.completed_jobs,
    cancelled_jobs = EXCLUDED.cancelled_jobs,
    volunteer_jobs = EXCLUDED.volunteer_jobs,
    rating_avg = EXCLUDED.rating_avg,
    total_reviews = EXCLUDED.total_reviews,
    response_time_minutes = EXCLUDED.response_time_minutes,
    updated_at = EXCLUDED.updated_at,
    category_name = EXCLUDED.category_name,
    category_icon = EXCLUDED.category_icon,
    category_slug = EXCLUDED.category_slug;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_published_service_provider_card() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_published_service_provider_card ON public.service_providers;
CREATE TRIGGER trg_sync_published_service_provider_card
AFTER INSERT OR UPDATE OR DELETE ON public.service_providers
FOR EACH ROW EXECUTE FUNCTION public.sync_published_service_provider_card();

TRUNCATE public.published_service_provider_cards;
INSERT INTO public.published_service_provider_cards
SELECT
  sp.id, sp.category_id, sp.provider_type, sp.display_name, sp.bio,
  sp.experience_years, COALESCE(sp.skills, '{}'::text[]), sp.profile_image_url,
  sp.cover_image_url, COALESCE(sp.portfolio_images, '{}'::text[]),
  sp.governorate, sp.city, sp.address, COALESCE(sp.service_areas, '{}'::text[]),
  COALESCE(sp.available_days, '{}'::text[]), sp.latitude, sp.longitude,
  COALESCE(sp.max_distance_km, 15), COALESCE(sp.pricing_type, 'market'),
  sp.price_from, COALESCE(sp.price_currency, 'EGP'),
  COALESCE(sp.accepts_installments, false), sp.phone, sp.whatsapp, sp.email,
  sp.website, sp.verification_status, sp.is_active, sp.is_available,
  sp.availability_note, COALESCE(sp.total_jobs, 0), COALESCE(sp.completed_jobs, 0),
  COALESCE(sp.cancelled_jobs, 0), COALESCE(sp.volunteer_jobs, 0),
  COALESCE(sp.rating_avg, 0), COALESCE(sp.total_reviews, 0),
  sp.response_time_minutes, sp.created_at, sp.updated_at, sc.name_ar, sc.icon, sc.slug
FROM public.service_providers sp
LEFT JOIN public.service_categories sc ON sc.id = sp.category_id
WHERE sp.verification_status = 'approved'
  AND sp.is_active IS TRUE
  AND sp.is_available IS TRUE;

DROP VIEW IF EXISTS public.published_service_providers;
CREATE VIEW public.published_service_providers
WITH (security_invoker = true)
AS SELECT * FROM public.published_service_provider_cards;
REVOKE ALL ON public.published_service_providers FROM PUBLIC;
GRANT SELECT ON public.published_service_providers TO anon, authenticated;

-- Trigger helpers must never be callable through the public PostgREST API.
REVOKE ALL ON FUNCTION public.guard_community_offer_single_edit() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_institution_offer_catalog_category() FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
