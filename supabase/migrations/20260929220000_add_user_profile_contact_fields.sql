-- Add the profile fields collected by the user profile setup flow.
-- All columns are nullable so existing users can migrate gradually.
BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS governorate text,
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS whatsapp text;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_gender_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_gender_check
  CHECK (gender IS NULL OR gender IN ('male', 'female'));

CREATE INDEX IF NOT EXISTS users_governorate_city_idx
  ON public.users (governorate, city);

COMMIT;
