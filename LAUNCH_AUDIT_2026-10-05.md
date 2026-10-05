

## تحديث الإصلاحات — 2026-10-05

تم تنفيذ ورفع الإصلاحات التالية في commit `82b4ee1`:

- حماية `HomeBannerCarousel` من استخدام `BuildContext` بعد انتهاء الصفحة.
- حماية `NotificationsPage` من lifecycle races بعد العمليات غير المتزامنة.
- استبدال رسائل أخطاء قاعدة البيانات المعروضة للمستخدم برسائل عامة، مع إبقاء التفاصيل في `debugPrint` المحلي فقط.
- إضافة migration `20261005150000_harden_published_reviews_view.sql`.

نتيجة التحقق بعد الإصلاحات:

- التحليل المستهدف للملفات المعدلة: **No issues found**.
- `flutter test`: **15 passed، 7 skipped**.
- `security_regression_check.py`: **PASS**.
- `production_gate.py`: **PASS**.
- GitHub branch: **نظيف ومتزامن**.

تم تطبيق migration `harden_published_reviews_view` على Supabase بعد موافقة صريحة. التحقق الحي أكد:

- `published_service_reviews` أصبحت `security_invoker=true`.
- `anon` و`authenticated` ما زالا يملكان `SELECT`.
- لم يتم تعديل بيانات المستخدمين أو view مزودي الخدمة.

لا تزال هناك حاجة لإنتاج AAB موقّع وتشغيل E2E بحسابات اختبار قبل الإعلان العام.
