BEGIN;

-- The charity profile/context RPCs are the trusted path for an authenticated
-- charity account. Browser roles must not read legacy authentication secrets
-- or internal moderation/login columns from public.charities.
REVOKE ALL PRIVILEGES ON TABLE public.charities FROM anon, authenticated;

GRANT SELECT (
  id,
  user_id,
  name,
  description,
  address,
  phone,
  email,
  logo,
  logo_url,
  image_url,
  cover_image,
  cover_image_url,
  latitude,
  longitude,
  status,
  is_verified,
  rating,
  total_reviews,
  created_at,
  updated_at
) ON public.charities TO authenticated;

-- Charity account mutations must go through SECURITY DEFINER RPCs, such as
-- update_my_charity_logo, instead of direct browser-role table updates.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.charities FROM anon, authenticated;

COMMIT;
