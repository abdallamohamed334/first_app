BEGIN;

UPDATE public.home_ads
SET advertiser_name = 'مؤسسة الطناحي للسباكة الحديثة',
    title = 'أفضل معرض أدوات صحية في طنطا',
    subtitle = 'كشف تسريبات بدون تكسير • تجهيز حمامات • خامات بضمان',
    target_url = 'https://wa.me/201288133345',
    is_active = true,
    updated_at = now()
WHERE advertiser_name = 'تجربة خدمة'
  AND title = 'صيانة مراوح البيت';

COMMIT;
