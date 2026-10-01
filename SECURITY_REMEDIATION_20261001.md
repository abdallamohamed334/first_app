# تقرير تنفيذ الإصلاحات الأمنية — 2026-10-01

## النطاق

تم تنفيذ الإصلاحات المستخلصة من تقارير التدقيق الموجودة في المستودع (`SECURITY_AUDIT.md` و`FINAL_PROVIDER_AUDIT.md`) على الكود وSupabase project المرتبط:

- Project ref: `gsrhoqdtcyfdmvgahqvl`
- آخر migrations المطبقة في الإنتاج: `close_provider_privilege_escalation` و`revoke_anon_public_rpc_access`

> لم يوجد ملف باسم `SECURITY_AUDIT_FULL_20261001.md` في النسخة المستنسخة؛ تم الاعتماد على تقارير التدقيق الموجودة فعليًا وعلى فحص المخطط الحي.

## الإصلاحات المنفذة

### تصعيد الصلاحيات وتحديث مزود الخدمة

- سحب `UPDATE` العام من `users` و`service_providers` للمستخدم المسجل.
- إعادة منح `UPDATE` على قوائم أعمدة مسموحة فقط.
- منع تعديل أدوار المستخدمين، حالة التفعيل، حالة اعتماد مزود الخدمة، المالك، ملاحظات الإدارة، أرقام الهاتف الثابتة، والإحصائيات عبر PostgREST.
- الإبقاء على مسارات backend/admin الحالية لتعديل الحقول المحمية.

### RPC وIDOR

- استبدال `get_provider_auth_state(uuid)` بـ `get_provider_auth_state()` يعتمد على `auth.uid()` داخل قاعدة البيانات.
- سحب تنفيذ RPC الحالة من `anon`؛ أصبح `authenticated` فقط.
- إزالة `user_id` الداخلي من ناتج `find_provider_by_phone` مع إبقاء أقل قدر مطلوب لتوجيه تسجيل الدخول قبل OTP.
- سحب التنفيذ المجهول من `list_community_needs_v2` و`list_public_volunteers`.
- تحديث Flutter callers لعدم تمرير UUID يختاره العميل إلى RPC الحالة.

### RLS وبيانات العرض العام

- إعادة إنشاء `published_service_providers` بدون `user_id` أو حقول KYC/المراجعة الداخلية.
- التحقق من الإنتاج أن public view لا تحتوي الأعمدة الحساسة المفحوصة.
- bucket `provider-images` في الإنتاج مضبوط على 10 MB وصيغ JPEG/JPG/PNG/WebP، مع سياسات مسار مقيّدة.

### رفع الصور والتحقق المحلي

- تمرير MIME type الحقيقي في رفع صور الملف والوثائق.
- الإبقاء على قيود الامتداد والحجم والمسار في العميل والسياسات.
- التحقق من سنوات الخبرة بعد توحيد النص/الرقم ورفض الصفر والقيم السالبة.

## الاختبارات والتحقق

- `python3 tool/security_regression_check.py` — ناجح.
- `git diff --check` — ناجح.
- تحقق Supabase migration history — المهاجرتان مسجلتان في المشروع الحي.
- تحقق bucket production — القيود موجودة.
- تم تحديث production advisors بعد التطبيق.

لا يمكن تشغيل `flutter test` أو `flutter analyze` في هذه البيئة لأن Flutter/Dart SDK غير مثبتين في Sandbox الحالي. يجب تشغيلهما في CI أو جهاز Flutter قبل دمج نسخة التطبيق النهائية.

## Advisor findings المتبقية

- تحذير `find_provider_by_phone` كـ `SECURITY DEFINER` متاح لـ `anon` مقصود حاليًا لأنه مطلوب لتوجيه تدفق OTP قبل تسجيل الدخول، وأصبح يعيد أقل projection ممكن بدون `user_id`.
- `check_charity_fixed_code_by_email` و`st_estimatedextent` مرتبطة بمسارات pre-auth/PostGIS وتحتاج قرارًا معماريًا مستقلًا.
- تحذير views ذات `security_invoker=false` لا يمثل تسريبًا بعد تقليص projection، لكنه يحتاج نقل public directory/reviews إلى جداول أو API آمنة إذا كان الهدف إزالة تحذيرات Advisor بالكامل.
- `spatial_ref_sys` مملوكة لإضافة PostGIS ولا ينبغي تعديلها من migration التطبيق؛ نقل PostGIS إلى schema منفصل إجراء إداري مستقل.

## الملفات الجديدة/المعدلة

- `supabase/migrations/20261001100000_close_provider_privilege_escalation.sql`
- `supabase/migrations/20261001101500_revoke_anon_public_rpc_access.sql`
- `lib/main.dart`
- `lib/features/provider/data/repositories/service_provider_repository.dart`
- `tool/security_regression_check.py`
