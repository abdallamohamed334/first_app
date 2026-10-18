DELETE FROM public.notifications n
WHERE n.reference_id IN (
  SELECT d.id FROM public.charity_donation_requests d LIMIT 10000
)
AND n.title IN (
  'تم قبول تبرعك',
  'تم تعيين مندوب الجمعية',
  'تبرعك جاهز للاستلام',
  'تم استلام التبرع منك',
  'تبرعك في الطريق للجمعية',
  'وصل تبرعك للجمعية',
  'لم تقبل الجمعية التبرع',
  'تحديث على تبرعك'
);

UPDATE public.notifications n
SET reference_type = 'charity_donation'
WHERE n.reference_type IS NULL
  AND n.reference_id IN (
    SELECT d.id FROM public.charity_donation_requests d LIMIT 10000
  );
