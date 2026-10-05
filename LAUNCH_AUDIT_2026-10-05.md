# تقرير فحص إطلاق تطبيق وِصلة

**التاريخ:** 2026-10-05  
**المستودع:** `abdallamohamed334/first_app`  
**الفرع:** `main`  
**الـcommit المفحوص:** `11d821d`  
**مشروع Supabase:** `gsrhoqdtcyfdmvgahqvl`

## الحكم النهائي

> **الحالة الحالية: لا أنصح بالإطلاق العام بعد.**

التطبيق يمر في الاختبارات المحلية، ويمر في بوابة الأمان، وآخر GitHub CI على نفس الـcommit ناجح. لكن لم يتم إنتاج أو فحص Android AAB موقّع فعليًا، ولم يتم اختبار iOS على macOS/Xcode، ولم تُنفذ اختبارات staging حقيقية لكل الأدوار. كذلك توجد نتائج أمنية مباشرة من Supabase Advisor، أهمها views تعمل بصلاحيات مالكها وواجهات RPC عامة قبل تسجيل الدخول.

هذا ليس معناه أن التطبيق منهار؛ معناه أن **بوابة الإصدار الأخيرة لم تكتمل**.

## ما تم التحقق منه ونجح

| الفحص | النتيجة |
|---|---|
| `flutter test` | نجح: 15 اختبارًا ناجحًا و7 skipped كما هو متوقع |
| التحليل المستهدف للمسارات المعدلة سابقًا | بلا مشاكل |
| `python3 tool/security_regression_check.py` | `PASS` |
| `python3 tool/production_gate.py` | `PRODUCTION_GATE_PASS` |
| GitHub Flutter CI على commit `11d821d` | ناجح |
| Git status | الفرع نظيف ومتزامن مع `origin/main` |
| RLS للجداول الحساسة | مفعّل على `users`, `otp_codes`, `otp_rate_limits`, `user_devices`, `service_providers`, `account_cases`, `account_audit_log` |
| Supabase Realtime للحسابات | مفعّل على `users` و`account_cases` |
| وجود service-role/private key في Flutter/Git | لم يظهر في الفحص النصي |
| Android cleartext traffic | مغلق (`usesCleartextTraffic=false`) |

## الموانع الفعلية قبل النشر

### P0 — لا يوجد artifact إنتاجي مثبت

- بيئة الفحص الحالية لا تحتوي Android SDK.
- `flutter build apk --debug` فشل بسبب عدم وجود Android SDK.
- لم يتم تنفيذ `flutter build appbundle --release` محليًا.
- Workflow الإصدار في GitHub موجود، لكنه لم يُشغّل على tag/dispatch لإثبات إنتاج AAB موقّع.
- لا يوجد تحقق فعلي من keystore production أو من قبول Google Play للـAAB.
- iOS لم يُبنَ؛ يحتاج macOS وXcode وsigning/provisioning حقيقي.

**المطلوب:** تشغيل `.github/workflows/release.yml` على commit/tag مع secrets التوقيع، ثم تنزيل الـAAB وفحصه وتثبيته على جهاز Android حقيقي.

### P0 — لا يوجد E2E حقيقي بحسابات اختبار

لم يتم تنفيذ رحلة كاملة بحسابات منفصلة للأدوار التالية:

- مستخدم عادي.
- مزود خدمة.
- مؤسسة/جمعية/مطعم حسب المنتج.
- Admin.
- مستخدم موقوف.

يجب اختبار: التسجيل، OTP الصحيح والخاطئ والمنتهي، replay، rate limit، تسجيل الخروج، انتهاء الجلسة، RLS، رفع الصور، الإشعارات، إنشاء العرض، الحجز، التسليم، وإعادة تفعيل الحساب.

### P1 — Security Definer views في Supabase

Advisor الحي أظهر خطأين:

- `public.published_service_providers`
- `public.published_service_reviews`

الـviews تعمل بصلاحيات مالكها، وقد تتجاوز RLS للجداول الأساسية. `published_service_providers` يخفي بعض بيانات التواصل عن anonymous، لكنه يعيدها للمستخدم المسجل. يجب اعتماد عقد الخصوصية قبل الإطلاق والتأكد أن كل الأعمدة المعادة مقصودة فعلًا. `published_service_reviews` يحتاج التأكد من أن عرض المراجعات لا يكشف صفوفًا لا ينبغي للمستخدم رؤيتها.

**لا أنصح بإصلاحهما عشوائيًا** قبل اختبار كل الصفحات التي تعتمد عليهما؛ الإصلاح الصحيح هو view عامة minimal أو `security_invoker` مع سياسات قراءة واضحة.

### P1 — RPCs عامة قبل تسجيل الدخول

Advisor أظهر أن anonymous يستطيع تنفيذ SECURITY DEFINER على الأقل لهذه الدوال:

- `check_charity_fixed_code_by_email`
- `check_ordinary_user_by_phone`
- `find_provider_by_phone`
- `list_public_charity_donors` — قد تكون عامة مقصودة، لكن يجب مراجعة البيانات.
- دوال PostGIS `st_estimatedextent` — غالبًا من extension، وليست مسارًا أساسيًا للتطبيق.

الدوال الثلاث الأولى جزء من سطح Auth/lookup قبل تسجيل الدخول، ولذلك تحتاج rate limiting وanti-enumeration واختبارًا فعليًا. لا يتم سحب صلاحيتها قبل مراجعة مسارات الدخول حتى لا يتعطل OTP/login.

### P1 — Edge Functions المنشورة تحتاج مطابقة مع Git

التقارير السابقة سجلت drift بين نسخ Edge Functions المنشورة ونسخة Git. لا يكفي أن الكود المحلي آمن؛ يجب التأكد أن نفس commit هو الذي يعمل على Supabase، خصوصًا:

- `send-otp`
- `verify-and-create`
- `verify-otp`
- `send-whatsapp`
- `send-push-notification`

يجب توحيد مسار OTP وعدم ترك مسار قديم منشورًا بدون usage check وتعطيل آمن.

## ملاحظات Supabase غير المانعة فورًا لكنها مهمة

### RLS مفعّل بلا policies

Advisor أظهر 16 جدولًا عليها RLS بدون policies، منها جداول حساسة مثل:

- `otp_codes`
- `otp_rate_limits`
- `admin_audit_logs`
- `delivery_tasks`
- `points_transactions`
- `swap_proposals`

هذا قد يكون مقصودًا للجداول التي لا يجب أن يقرأها العميل مباشرة، وتُستخدم عبر SECURITY DEFINER/RPC أو service role. لكنه يحتاج مصفوفة صلاحيات موثقة واختبارًا بحسابات حقيقية؛ لا تتم إضافة policies عامة لمجرد إسكات Advisor.

### Performance Advisor

Advisor أظهر:

- 47 foreign keys بلا indexes تغطّيها.
- 107 سياسات RLS تعيد تقييم `auth.uid()` لكل صف.

هذه ليست مانع إطلاق لتطبيق صغير، لكنها ستؤثر مع نمو البيانات. يبدأ الإصلاح بعد قياس query plans وإضافة indexes للصفحات الأكثر استخدامًا، وليس بإضافة 47 index عشوائيًا.

### PostGIS warnings

هناك تحذير حول `spatial_ref_sys` وامتداد PostGIS داخل `public`. هذا غالبًا متعلق بإدارة extension نفسها وليس جدولًا يملكه التطبيق. لا يتم تعديلها مباشرة بدون خطة Supabase/PostGIS واضحة.

## Flutter والتحليل

`dart analyze` الكامل ينتهي بـ **679 issue**، لكن الفحص لا يظهر compile errors؛ أغلبها `info` قديمة مثل:

- `prefer_const_constructors`
- `avoid_print`
- `use_build_context_synchronously`
- أسماء types غير مطابقة للنمط

المهم قبل الإطلاق هو فصل warnings lifecycle الحقيقية عن style-only findings. أي `use_build_context_synchronously` في flow يفتح Snackbar/navigation بعد await يجب مراجعته، لأنه قد يسبب سلوكًا على Widget تم التخلص منه. لا يُنصح بمحاولة إصلاح 679 ملاحظة دفعة واحدة قبل release.

## إعدادات الإصدار

- Android package/application ID: `com.jood.app`
- iOS bundle ID: `com.jood.app`
- Android target/compile SDK: 36
- Release signing مصمم ليكون fail-closed إذا لم توجد credentials؛ هذه نقطة جيدة.
- أسرار التوقيع لا توجد في Git، وworkflow يستعيد keystore من GitHub Secrets.
- runtime config يحتوي Supabase publishable/anon key وFirebase client key؛ وجود هذه المفاتيح في التطبيق متوقع، ولا يساوي service-role secret.
- `flutter_map_cancellable_tile_provider` معلّمة كـ discontinued؛ ليست blocker فورية، لكنها تحتاج خطة تحديث.

## وظائف التطبيق غير المكتملة أو التي تحتاج اختبارًا يدويًا

يوجد عدد من TODOs في التنقل وبعض الخصائص، مثل:

- geocoding search.
- فتح تفاصيل بعض العروض/الطلبات.
- بعض quick actions في dashboards.
- tracking والتقييم في بعض تدفقات المجتمع.

لا أستطيع اعتبارها كلها blocker بدون product checklist؛ لكن أي زر ظاهر للمستخدم ويؤدي إلى لا شيء يجب إخفاؤه أو إكماله قبل الإعلان العام.

## خطة الإطلاق الآمنة

1. إنشاء حسابات اختبار منفصلة لكل role وعدم استخدام حسابات حقيقية.
2. تشغيل آخر GitHub CI والتأكد أنه على نفس الـcommit المطلوب.
3. تشغيل release workflow بإدخال secrets الحقيقية من Secret Manager/GitHub Secrets.
4. إنتاج AAB موقّع، تثبيته على جهازين Android، وتجربة cold start وupgrade وnotifications وlocation/camera/photos.
5. اختبار staging لـAuth/OTP/RLS/Storage/Edge Functions.
6. مطابقة deployed Edge Functions مع commit الإصدار.
7. مراجعة `published_service_providers` و`published_service_reviews` وإقرار عقد الخصوصية.
8. اختبار الدوال anonymous الثلاث مع rate limit وanti-enumeration.
9. مراجعة Google Play Data Safety وPrivacy Policy، وApple Privacy Nutrition Labels إذا كان iOS مطلوبًا.
10. بعد نجاح كل ذلك فقط: tag للإصدار ثم نشر تدريجي/closed testing قبل public release.

## قرار عملي الآن

- **الكود المحلي:** جيد من ناحية الاختبارات والبوابات الثابتة.
- **قاعدة البيانات:** تعمل، لكن تحتاج مراجعة views وRPCs العامة واختبارات صلاحيات.
- **الإصدار:** غير مثبت بعد بسبب غياب artifact موقّع.
- **النشر العام:** مؤجل حتى إغلاق P0 وP1 أعلاه.

تمت هذه المراجعة قراءةً وفحصًا فقط؛ لم أعدّل ملفات التطبيق أو قاعدة البيانات أثناء التدقيق.


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
