# Production Audit النهائي — Flutter + Supabase

**التاريخ:** 2026-10-02  
**Repository:** `abdallamohamed334/first_app` — `main` / `d60de14`  
**الحالة:** **PRODUCTION CODE BASELINE READY — DEPLOYMENT GATED**

## نطاق المراجعة

تمت مراجعة بنية Flutter/Dart، `lib/`، الاختبارات، إعدادات Android/iOS، إدارة البيئة، migrations وEdge Functions المحلية، سجلات الأمان، وملفات التدقيق السابقة. لم يتم تنفيذ أي تغيير destructive أو تطبيق migration على Production.

## الإصلاحات المنفذة

| الملف | الإصلاح |
|---|---|
| `lib/main.dart` | منع تشغيل التطبيق عند فشل/نقص إعداد Supabase، إضافة شاشة خطأ مفهومة وزر إعادة محاولة، وتحديث رسالة إعداد البيئة. |
| `pubspec.yaml` | إزالة `.env` من Flutter assets؛ الإعدادات تأتي من `--dart-define` أو ملف محلي اختياري. |
| `lib/features/userhome/presentation/pages/user_home_page.dart` | إصلاح `const Border` غير الصحيح لأن اللون runtime-dependent. |
| `lib/core/pickup/presentation/pages/pickup_qr_page.dart` | حذف fallback token التجريبي؛ فشل إنشاء token يعرض خطأ بدل إنشاء كود غير صالح. إزالة logs تحتوي User/Business/Request IDs وtoken. |
| `lib/core/repositories/auth_repository.dart` | إزالة الهاتف من OTP logs. |
| `lib/core/services/loqma_image_storage_service.dart` | إزالة user IDs ومسارات الرفع التفصيلية من logs. |
| `supabase/migrations/20261002100000_harden_public_image_bucket_limits.sql` | إضافة migration محلية اختيارية لتقييد public image buckets إلى 5 MB وصيغ صور فقط؛ يلزم staging قبل تطبيقها. |
| `supabase/functions/verify-and-create/index.ts` | منع حذف orphan/conflicting user rows تلقائيًا؛ أصبحت reconciliation failures غير destructive وتعيد 409/503. |
| `supabase/functions/send-otp/index.ts` + `supabase/migrations/20261002110000_add_otp_rate_limit.sql` | إضافة rate limit ذري 5 طلبات/5 دقائق لكل phone+IP hash مع حماية من race conditions. |
| `supabase/config.toml` | تثبيت `verify_jwt` لكل Edge Function الحساسة في البيئة المحلية. |
| `lib/firebase_options.dart` + `.env.example` | إزالة Firebase web measurement placeholder واستبداله بإعداد اختياري من البيئة. |
| `.github/workflows/flutter-ci.yml` | إضافة CI لـ pub get/security checks/analyze/test. |
| `tool/production_gate.py` | بوابة ثابتة تمنع placeholders وfallbacks وlogs الحساسة وتتحقق من ملفات الإصدار. |
| `.github/workflows/release.yml` | workflow إصدار على tags/تشغيل يدوي لفحص الكود وبناء Android AAB وiOS IPA بعد توفير secrets والتوقيع. |

## Production deployment gates

1. لا يوجد في Flutter source أو الملفات المفحوصة service-role/private/payment key واضح. هذا لا يثبت سلامة أسرار Production أو Git history بالكامل.
2. لا يمكن تنفيذ E2E حقيقي لـ Auth/RLS/Storage دون حسابات staging وأدوار اختبار مصرح بها.
3. النشر الفعلي يتطلب تشغيل `.github/workflows/release.yml` على tag بعد إضافة Supabase/ Firebase/ Android signing secrets، وإضافة Apple signing إذا كان iOS مطلوبًا.

## High Issues — تحتاج نشرًا أو تحققًا خارجيًا

1. **Public provider data overexposure:** `published_service_providers` ما زالت تعرض phone/WhatsApp/email/website/address/company legal name/employees/branches ومؤشرات تشغيل. يلزم اعتماد public data contract ثم migration تفصل بيانات التواصل/KYC عن العرض العام.
2. **Public authentication surface:** `find_provider_by_phone` وعمليات pre-OTP تسمحان بالاستعلام anonymous؛ أضيف rate limiting محليًا، لكن يلزم نشره واختبار anti-enumeration/lockout على staging.
3. **Edge Function drift:** يوجد `verify-otp` محلي قديم بجانب `verify-and-create`، ولا يوجد proof محلي أن deployed versions مطابقة لـ Git. يلزم staging deployment مربوط بـ commit/hash ثم تعطيل المسار القديم بعد usage check.
4. **Storage rollout:** migration حدود `charity-images` و`home-banners` و`restaurant-offers` لم تُطبق على Production؛ يجب اختبار توافق العملاء قبل النشر.
5. **Release artifacts:** بوابة الإصدار أصبحت موجودة، لكن AAB/IPA لا يمكن إنتاجهما داخل Sandbox الحالي لغياب Flutter/Android SDK/Xcode وsigning credentials.

## Medium / Low Issues

- المشروع يحتوي **362 ملف Dart** لكن الاختبارات المحلية الظاهرة تغطي validators وprovider profile فقط (**اختباران**؛ لا تغطية Auth/RLS/Storage أو user flows الأساسية).
- توجد عشرات `FutureBuilder`/`StreamBuilder` وعمليات select بلا pagination واضحة؛ يلزم profiling وEXPLAIN على البيانات الحقيقية.
- ما زالت توجد debug logs كثيرة، وبعضها يطبع أخطاء تقنية؛ تم تنقية المسارات الحساسة ذات الأولوية، ويلزم structured redacted logger موحّد لبقية المشروع.
- Android يطلب `ACCESS_BACKGROUND_LOCATION`؛ يجب إثبات الحاجة الفعلية ومراجعة إفصاحات Google Play.
- iOS يعلن location/camera/photos/notifications؛ يلزم مراجعة Privacy Nutrition Labels وusage disclosures.
- dependency `flutter_map_cancellable_tile_provider` معلّمة سابقًا كـ discontinued؛ التحديث يحتاج خطة منفصلة واختبارات.
- توجد TODOs وظيفية في flows مثل geocoding وبعض أزرار التنقل؛ ليست كلها release blockers لكنها تحتاج triage.

## Security / Reliability / Performance

- **Auth:** يوجد OTP/session sync وحراسة lifecycle جزئية، لكن لا يوجد اختبار staging للحالات المنتهية/المعطلة/المكررة.
- **Authorization/RLS:** توجد migrations hardening جيدة محليًا، لكن لا يمكن إثبات صلاحيات الأدوار دون JWTs حقيقية؛ لا تعتمد على static SQL وحده.
- **Storage:** `provider-documents` وprovider images لديهما قيود محلية، بينما public buckets المذكورة تحتاج rollout.
- **Network:** startup لديه timeouts، وأضيفت الآن حالة فشل صريحة بدل استمرار router في حالة Supabase غير مهيأة. يلزم اختبار 401/403/409/429/500/offline.
- **Performance:** لا توجد نتائج profiling أو query plans في هذه البيئة؛ لا يجوز اعتبارها سليمة بالاستنتاج.
- **Privacy:** تم تقليل logs الحساسة في الملفات المعدلة، لكن يلزم مراجعة بقية `print/debugPrint` في CI/release logging policy.

## Android / iOS / Tests

- **Android:** `applicationId=com.jood.app`، `compileSdk/targetSdk=36`، release signing fail-closed عبر environment variables. Build غير متحقق لغياب Android SDK.
- **iOS:** ATS غير متساهل، وInfo.plist يحتوي declarations للصلاحيات والإشعارات. IPA/signing/capabilities غير متحققة لأن البيئة Linux بلا Xcode.
- **Tests:** لم يمكن تشغيل `flutter analyze` أو `flutter test` في البيئة الحالية لأن `flutter` و`dart` غير مثبتين. فحص الأمان المخصص مرّ بنجاح، و`git diff --check` مرّ بنجاح. تقرير التدقيق السابق ذكر أن الاختبارات كانت تمر في بيئة Flutter أخرى، لكن ذلك غير قابل لإعادة التحقق هنا.

## Commands / Evidence

- `git log`, `git status`, repository scans — نجحت.
- `python3 tool/security_regression_check.py` — **PASS**.
- static checks لعدم وجود حذف تلقائي في `verify-and-create` ولوجود rate limit migration — **PASS**.
- static checks للـ assets/migration/sensitive logs — **PASS**.
- `git diff --check` — **PASS**.
- `tool/production_gate.py` — **PASS**.
- `flutter analyze`, `flutter test`, `flutter build appbundle --release`, `flutter build ipa --release` — **غير منفذة داخل Sandbox: الأدوات/toolchains غير متاحة؛ workflow الإصدار يشغلها على CI**.
- Supabase Production queries/deploy — **غير منفذة**؛ لا توجد صلاحية/موافقة لتغيير Production ضمن هذه المراجعة.

## Release Gate

الكود وملفات CI جاهزة لبوابة Production. لا تعتبر النسخة منشورة فعليًا حتى ينجح workflow الإصدار على tag، وتُطبّق migrations/Edge Functions على Supabase، وتنجح اختبارات staging وعمليات توقيع المتاجر. عقد provider data العام بقي كما طلب المنتج ولم تُحذف منه حقول التواصل.
