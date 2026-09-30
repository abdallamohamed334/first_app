BEGIN;

INSERT INTO public.swap_listings (
  owner_id, wanted_title, description, category, wanted_condition,
  city, governorate, latitude, longitude, images, status, expires_at,
  contact_phone, contact_whatsapp
)
SELECT
  '6934ac6c-b24c-4ad7-a015-2686e49b1041'::uuid,
  demo.wanted_title,
  demo.description,
  demo.category,
  demo.wanted_condition,
  'طنطا', 'الغربية', 30.7700380249497, 30.9651902590882,
  ARRAY[demo.image_url], 'open', now() + interval '7 days',
  '01000000001', '01000000001'
FROM (VALUES
  ('[تجريبي] iPhone 11', 'أرغب في استبدال لابتوب قديم أو جهاز إلكتروني بحالة جيدة بآيفون 11.', 'إلكترونيات', 'new', 'https://files.manuscdn.com/user_upload_by_module/session_file/310519663991340129/nWAyKIVMfscKQnIl.jpg'),
  ('[تجريبي] لابتوب فضي', 'لابتوب قديم ونظيف مناسب للدراسة، أبحث عن هاتف أو جهاز لوحي في المقابل.', 'إلكترونيات', 'good', 'https://files.manuscdn.com/user_upload_by_module/session_file/310519663991340129/UHfDuckhKtYpvScy.jpg'),
  ('[تجريبي] كاميرا رقمية', 'كاميرا صغيرة تعمل بشكل جيد، أقبل استبدالها بسماعة أو هاتف اقتصادي.', 'إلكترونيات', 'good', 'https://files.manuscdn.com/user_upload_by_module/session_file/310519663991340129/VsSogYrkxlTxZzkp.jpg'),
  ('[تجريبي] عجلة مدينة', 'عجلة مدينة زرقاء بحالة جيدة، أريد استبدالها بأداة رياضية أو جهاز مناسب.', 'رياضة', 'like_new', 'https://files.manuscdn.com/user_upload_by_module/session_file/310519663991340129/NQdYKLhFbLHBIEvr.jpg'),
  ('[تجريبي] جهاز ألعاب', 'جهاز ألعاب مع يد تحكم، أبحث عن هاتف أندرويد أو جهاز إلكتروني مفيد.', 'ألعاب', 'good', 'https://files.manuscdn.com/user_upload_by_module/session_file/310519663991340129/JiXyZYXibQGODOHP.jpg')
) AS demo(wanted_title, description, category, wanted_condition, image_url)
WHERE NOT EXISTS (
  SELECT 1 FROM public.swap_listings existing
  WHERE existing.owner_id = '6934ac6c-b24c-4ad7-a015-2686e49b1041'::uuid
    AND existing.wanted_title = demo.wanted_title
);

COMMIT;
