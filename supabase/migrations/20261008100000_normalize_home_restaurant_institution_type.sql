-- Normalize legacy/alias values so the app and offer-category trigger use
-- the canonical institutions.institution_type value consistently.
BEGIN;

UPDATE public.institutions
SET institution_type = 'home_restaurant'
WHERE lower(btrim(institution_type)) IN (
  'home-restaurant',
  'home_restaurants',
  'home-restaurants',
  'home restaurant',
  'home restaurants',
  'مطاعم منزلية',
  'مطاعم_منزلية',
  'مطاعم منزليه',
  'مطاعم_منزليه'
);

COMMIT;
