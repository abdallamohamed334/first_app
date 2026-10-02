# تقرير جاهزية الإنتاج — وِصلة

**التاريخ:** 2026-10-02
**المستودع:** `abdallamohamed334/first_app`
**الفرع:** `main`

## الحالة

**Production-ready code baseline — deployment and staging gated.**

تم فحص المستودع وطبّقت الإصلاحات الآمنة القابلة للتحقق محليًا. لا يمكن اعتبار التطبيق منشورًا فعليًا قبل نجاح CI، تطبيق migrations على Supabase، واختبارات staging الحقيقية.

## الإصلاحات المنفذة

- إضافة migration جديدة `20261002120000_lock_public_provider_surface.sql`:
  - إخفاء phone/WhatsApp/email/website/address/branches والمؤشرات التشغيلية عن الزائر anonymous.
  - إتاحة بيانات التواصل فقط للجلسات authenticated عبر view مشروط بـ `auth.uid()`.
  - إزالة `user_id` من نتيجة البحث قبل OTP لمنع user enumeration.
  - إزالة company legal/KYC-like fields من عقد العرض العام.
- إزالة `ACCESS_BACKGROUND_LOCATION` من Android؛ التطبيق يستخدم الموقع أثناء الاستخدام فقط ولا يحتوي background location flow.
- إزالة طباعة FCM token وUser ID وبيانات الإشعار التفصيلية من سجلات التطبيق.
- تحديث بوابة الأمان لتتحقق من migration الجديدة وعقد البيانات الآمن.
- إعادة تسمية artifact iOS غير الموقّع إلى validation artifact صراحةً؛ لا يتم تقديمه كحزمة App Store إنتاجية.

## التحقق المنفذ

- `python3 tool/security_regression_check.py` — **PASS**
- `python3 tool/production_gate.py` — **PASS**
- `git diff --check` — **PASS**
- لا توجد مراجع `ACCESS_BACKGROUND_LOCATION` أو `enableBackgroundMode` في Android/lib.
- لا توجد طباعة مباشرة لـ FCM token أو User ID في `fcm_service.dart`.

## ما يحتاج بيئة خارجية قبل النشر

1. تشغيل GitHub CI بنجاح (`flutter analyze` و`flutter test`).
2. تطبيق migrations على Supabase staging أولًا ثم production بعد مراجعة أثر عقد البيانات.
3. اختبار Auth/OTP: expiry، wrong attempts، replay، rate-limit، duplicate phone، provider registration.
4. اختبار RLS/Storage بحسابات anonymous وauthenticated وأدوار user/provider/institution.
5. نشر Edge Functions من نفس commit والتحقق من عدم وجود drift، ثم إزالة/تعطيل `verify-otp` القديم بعد usage check.
6. توفير Android signing secrets لإنتاج AAB موقّع.
7. توفير Apple signing/App Store credentials إذا كان iOS مطلوبًا؛ artifact iOS الحالي للتحقق فقط وغير صالح للتوزيع.

## ملاحظة مهمة

مفاتيح Supabase/Firebase العامة ليست بديلًا عن أسرار Edge Functions. يجب ضبط `SUPABASE_SERVICE_ROLE_KEY` وWapilot/FCM/internal secrets في Supabase Secrets فقط، وعدم وضعها في Flutter أو GitHub artifacts.
