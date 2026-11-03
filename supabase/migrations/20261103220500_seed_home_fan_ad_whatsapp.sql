BEGIN;

INSERT INTO public.home_ads (
  advertiser_name,
  title,
  subtitle,
  image_url,
  target_url,
  sort_order,
  is_active,
  starts_at,
  ends_at
)
SELECT
  'تجربة خدمة',
  'صيانة مراوح البيت',
  'تركيب وتنظيف وإصلاح مراوح المنزل — إعلان تجريبي',
  'https://raw.githubusercontent.com/abdallamohamed334/first_app/main/assets/images/khedma_icon.png',
  'https://wa.me/201286162776',
  1,
  true,
  now(),
  now() + interval '30 days'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.home_ads
  WHERE advertiser_name = 'تجربة خدمة'
    AND title = 'صيانة مراوح البيت'
);

UPDATE public.home_ads
SET target_url = 'https://wa.me/201286162776',
    is_active = true,
    updated_at = now()
WHERE advertiser_name = 'تجربة خدمة'
  AND title = 'صيانة مراوح البيت';

COMMIT;
