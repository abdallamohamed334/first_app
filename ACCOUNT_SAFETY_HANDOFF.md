# Loqma account safety handoff

## الهدف

تم تنفيذ طبقة سلامة للحسابات تمنع الحسابات الموقوفة من استخدام التطبيق، وتحتفظ بالقضايا والأدلة وسجل التدقيق بدل حذف البيانات.

هذه المذكرة موجهة للوكيل التالي الذي سيكمل العمل ويجري التحقق اليدوي.

## ما تم تنفيذه

### قاعدة البيانات وSupabase

تم تطبيق هذه migrations فعليًا على مشروع Supabase:

1. `20261004170000_account_suspension_and_audit.sql`
2. `20261004173000_account_case_management_rpc.sql`
3. `20261004174500_account_reactivation_sync.sql`
4. `20261004180000_enforce_account_safety_invariant.sql`

المشروع المستخدم:

- Project ref: `gsrhoqdtcyfdmvgahqvl`
- الحالة عند التطبيق: `ACTIVE_HEALTHY`

الجداول الجديدة:

- `public.account_cases`
- `public.account_audit_log`
- `public.account_evidence`

الأعمدة الجديدة في `public.users`:

- `account_status`: `active | under_review | suspended | closed`
- `suspended_at`
- `suspended_by`
- `suspension_reason`
- `suspension_case_id`
- `suspension_until`
- `last_security_action_at`

الدوال الأساسية:

- `get_my_account_restriction()`
- `is_admin_actor()`
- `suspend_user_account(target_user_id, reason, case_id, status, suspension_until)`
- `reactivate_user_account(target_user_id, case_id, resolution)`
- `list_account_cases(status, limit, offset)`
- `admin_update_account_case(case_id, status, priority, internal_notes, resolution)`
- `write_account_audit_event(event_type, target_user_id, case_id, reason, metadata)`

### سلوك الإيقاف

` suspend_user_account ` لا تعمل إلا لمسؤول نشط (`role = admin` أو `user_type = admin`). عند نجاحها:

- تجعل `users.account_status = suspended` أو `under_review` أو `closed`.
- تجعل `users.is_active = false`.
- تحفظ السبب والمسؤول والقضية.
- تعطل `user_devices` وتحذف `fcm_token`.
- تعطل مزود الخدمة المرتبط وتجعله غير متاح.
- توقف المؤسسة/المطعم/النشاط/الجمعية المرتبطة.
- تلغي عروض النشاط والمؤسسة وعروض المجتمع الخاصة بالحساب.
- تسجل `account_suspended` أو `account_under_review` أو `account_closed` في Audit.

لا يتم حذف المستخدم أو سجله التاريخي.

### إعادة التفعيل

`reactivate_user_account`:

- تعيد المستخدم إلى `active`.
- تعيد تشغيل الأجهزة.
- تعيد تفعيل الكيانات التجارية أو الجمعية.
- تغلق القضية وتسجل قرار إعادة التفعيل.
- تعيد مزود الخدمة إلى `pending` و`is_available = false` بدل إعادته تلقائيًا إلى `approved`.

## ملفات Flutter المعدلة

### حارس حالة الحساب

- `lib/core/services/auth_state_notifier.dart`
- `lib/routes/app_router.dart`

تمت إضافة route:

- `/account-restricted`

وتمت إضافة route الإدارة:

- `/admin/account-cases`

أي حساب حالته غير `active` يذهب إلى صفحة الحساب الموقوف ولا يستطيع فتح Home أو لوحة تشغيلية.

### صفحات جديدة

- `lib/features/auth/presentation/pages/account_restricted_page.dart`
- `lib/features/admin/presentation/pages/account_cases_page.dart`

### مزامنة الحالة

تم تمرير `account_status` و`suspension_until` في:

- `lib/main.dart`
- `lib/core/repositories/auth_repository.dart`
- `lib/features/splash/presentation/pages/splash_page.dart`

وتمت إضافة فحوصات مباشرة قبل الدخول في:

- `lib/features/provider/data/repositories/service_provider_repository.dart`
- `lib/features/auth/presentation/pages/institution_login_page.dart`

## GitHub

الفرع نظيف ومتزامن مع GitHub:

```text
b523321 feat: add enterprise account safety and moderation cases
main == origin/main
```

## ما تم اختباره

- `flutter test` مرّ: الاختبارات التنفيذية نجحت، مع وجود 7 اختبارات skipped في suite العامة.
- `flutter test test/core_contracts_test.dart` مرّ: `All tests passed!`
- التحليل المستهدف للملفات الأمنية مرّ: `No issues found!`
- `flutter analyze` الكامل يرجع exit غير صفري بسبب 680 warning/info قديمة في المشروع، بدون أخطاء compile في الملفات المعدلة.
- لم يتم بناء APK حسب طلب المستخدم.

### تحقق الإنتاج بعد الإصلاح

- تم تطبيق migration `enforce_account_safety_invariant` على المشروع `gsrhoqdtcyfdmvgahqvl`.
- تم تصحيح الحساب المقيد الموجود بحيث أصبح `account_status = suspended` و`is_active = false`.
- تم إنشاء trigger يمنع المستخدم العادي من تعديل أعمدة الحماية مباشرة، ويجبر الحالات غير النشطة على `is_active = false`.
- نتيجة فحص الاتساق بعد التطبيق: `active/true = 7` و`suspended/false = 1`، ولا توجد حالة `suspended/true`.
- تم إضافة اختبارات صريحة لـ`under_review` و`suspended` و`closed` ولمنع الحساب الإداري المقيد من فتح لوحة الإدارة.

## نقطة مهمة قبل اختبار الإيقاف

لا يوجد في بيانات المشروع الحالية حساب admin معروف. لذلك لا يتم تشغيل سيناريو الإيقاف من حساب مستخدم عادي.

يجب تجهيز حساب إداري تجريبي موثوق من Supabase Dashboard أو من قناة إدارة آمنة، ثم اختبار الدوال من داخل التطبيق. لا يجب منح `admin` لأي حساب حقيقي عشوائي.

## سيناريو تحقق يدوي كامل

استخدم حسابين تجريبيين فقط:

- `ADMIN_TEST`: حساب الإدارة.
- `USER_TEST`: مستخدم عادي يملك عرضًا أو احتياجًا تجريبيًا غير حساس.

### A. الحساب الطبيعي

1. سجّل دخول `USER_TEST`.
2. تأكد أن `account_status = active`.
3. افتح Home.
4. انشر عرضًا/احتياجًا تجريبيًا.
5. تأكد أن العرض يظهر في المكان المتوقع.

### B. فتح قضية

1. سجّل دخول `ADMIN_TEST`.
2. افتح `/admin/account-cases`.
3. تأكد أن قائمة القضايا تعمل.
4. افتح قضية أو استخدم قضية اختبارية بسبب واضح.

### C. إيقاف الحساب

1. من لوحة الإدارة اضغط إيقاف.
2. أدخل سببًا واضحًا.
3. تحقق في Supabase أن المستخدم أصبح:
   - `account_status = suspended`
   - `is_active = false`
4. تحقق أن الأجهزة أصبحت `is_active = false`.
5. تحقق أن العرض التجريبي أصبح `cancelled` أو لم يعد ظاهرًا.
6. تحقق من إنشاء سجل في `account_audit_log`.
7. افتح التطبيق بحساب `USER_TEST` من جلسة قائمة.
8. تحقق أنه ينتقل إلى `/account-restricted` ولا يدخل Home.
9. سجّل خروجًا ثم حاول الدخول مرة أخرى.
10. تحقق أن الحساب لا يدخل اللوحات التشغيلية.

### D. منع المسارات المباشرة

أثناء الإيقاف جرّب يدويًا:

- `/home`
- `/provider-home`
- `/institutions-home`
- `/charity-home`
- `/admin/account-cases` بحساب غير admin

النتيجة المتوقعة:

- الحساب الموقوف: `/account-restricted`
- الحساب غير الإداري: لا يفتح مسار admin

### E. إعادة التفعيل

1. من `ADMIN_TEST` اضغط إعادة تفعيل.
2. تحقق أن المستخدم أصبح `active` و`is_active = true`.
3. تحقق أن القضية أصبحت `resolved`.
4. تحقق من سجل `account_reactivated`.
5. أدخل بالمستخدم مرة أخرى.
6. لو كان مزود خدمة، تأكد أنه عاد إلى `pending` وليس `approved` تلقائيًا.

## قيود معروفة يجب على مَانوس التحقق منها

1. إيقاف جلسة Supabase Auth نفسها على الخادم ليس منفذًا عبر حذف `auth.sessions`; الحماية الفعلية تعتمد على مزامنة `account_status` في التطبيق وتعطيل الأجهزة. يجب اختبار فتح التطبيق من جلسة كانت موجودة قبل الإيقاف.
2. البلاغات التلقائية واكتشاف المخدرات بالذكاء الاصطناعي غير منفذة هنا. النظام الحالي يبدأ من قرار الإدارة: قضية ثم إيقاف ثم تدقيق.
3. حساب admin يحتاج bootstrap آمن قبل اختبار لوحة الإدارة.
4. يجب اختبار كل أنواع المحتوى الموجودة في المشروع، لأن دالة الإيقاف تغطي الجداول الحالية المعروفة: المستخدم، مزود الخدمة، المؤسسة، النشاط، المطعم، الجمعية، عروض الطعام، عروض المؤسسة، عروض المجتمع، وswap listings.
5. يجب عدم اعتبار التطبيق جاهزًا للإطلاق النهائي قبل اختبار Android حقيقي لكل مسارات الحسابات، لأن المستخدم طلب عدم بناء APK في هذه المرحلة.

## أمر التحقق السريع

```bash
cd /home/ubuntu/first_app
export PATH=/home/ubuntu/flutter/bin:$PATH
flutter test test/core_contracts_test.dart
git status --short --branch
```

النتيجة المطلوبة:

- `All tests passed!`
- `main...origin/main`
- لا توجد ملفات غير محفوظة.
