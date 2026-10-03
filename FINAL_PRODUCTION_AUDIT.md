# تقرير مراجعة Production — Flutter + Supabase

**تاريخ المراجعة:** 2026-10-02  
**Repository:** `abdallamohamed334/first_app`  
**Branch/HEAD عند بدء المراجعة:** `main` / `d60de14`  
**Supabase project:** `gsrhoqdtcyfdmvgahqvl` — eu-west-1  
**نطاق المراجعة:** Flutter/Dart، Auth، Supabase schema/RLS/Storage/Functions، Android/iOS configuration، الاختبارات، وبناء التطبيق.

## Overall Status

# NOT READY

تم إصلاح عطلَي بناء آمنين محليًا، وأصبحت الاختبارات تمر. لكن لا يمكن اعتبار التطبيق جاهزًا للإطلاق بسبب مخاطر إنتاجية غير معالجة في Supabase/الخصوصية، وجود drift بين Edge Functions المنشورة ونسخة Git، وغياب Android SDK/Xcode في بيئة التحقق الحالية. لا توجد migrations أو تغييرات مباشرة على Production database ضمن هذه المراجعة.

## ملخص الأدلة التنفيذية

| الفحص | النتيجة |
|---|---|
| Flutter/Dart | Flutter 3.47.6 / Dart 3.13.5، مثبتان محليًا من stable |
| `flutter pub get` | نجح |
| `flutter analyze` قبل الإصلاح | فشل: compile error في `user_home_page.dart`، وasset `.env` مفقود |
| `flutter analyze` بعد الإصلاح | لا توجد أخطاء compile؛ بقيت 694 ملاحظة: 109 warnings و585 infos |
| `flutter test` قبل الإصلاح | فشل بسبب asset `.env`، ثم فشل اختبار fixture قديم |
| `flutter test` بعد الإصلاح | نجح: **All tests passed** |
| Android debug APK | لم يُبنَ: Android SDK غير موجود في sandbox |
| Android release AAB | لم يُتحقق منه للسبب نفسه، إضافة إلى أن signing credentials غير موجودة في البيئة |
| iOS release IPA | لم يُتحقق منه: لا Xcode/macOS toolchain في sandbox |
| Supabase project | active/healthy، PostgreSQL 17.6.1، eu-west-1 |
| Supabase migrations | 54 migration محلية؛ production migrations موجودة، لكن Edge Functions متقدمة/مختلفة عن Git |

## Critical Issues

لا يوجد تسريب واضح لـ Supabase service-role key أو private key داخل Flutter source بحسب فحص patterns والملفات التي تمت مراجعتها. مع ذلك، وجود خطر Critical متعلق ببيانات إنتاجية لا يمكن استبعاده دون اختبار مستخدمين بأدوار مختلفة؛ لذلك هذا الحكم لا يعني أن security مكتملة.

| Severity | File/Location | المشكلة | الأثر | الحالة |
|---|---|---|---|---|
| Critical | Production Supabase / deployed functions | لا يمكن إجراء اختبار end-to-end فعلي لحالات signup/login/disabled user/expired OTP بأحسابات اختبارية دون credentials/بيانات اختبار مصرح بها | قد تبقى أخطاء Auth أو authorization غير مكتشفة رغم نجاح static checks | لم يُصلح؛ يلزم staging/test accounts |

## High Issues

| # | المصدر | المشكلة ولماذا مهمة | التوصية | الحالة |
|---:|---|---|---|---|
| H1 | `public.published_service_providers` في Production؛ migration `20260929130000...` و`20261001100000...` | الـ public view تعرض phone وWhatsApp وemail وwebsite وcompany legal name وemployees وbranches والعنوان والإحداثيات ومؤشرات التشغيل. هذا يتعارض مع تعليق migrations الذي يقول إن public cards يجب ألا تعرض بيانات KYC/moderation، وقد يكون تسريبًا للبيانات الشخصية/التجارية | تحديد contract العام بدقة ثم إنشاء view عامة minimal؛ قصر وسائل التواصل على ما يوافق عليه المستخدم؛ مراجعة سياسة الخصوصية وإزالة الأعمدة الحساسة أو فصلها عن public API | لم يُصلح؛ يحتاج migration ومراجعة product/privacy قبل التنفيذ |
| H2 | `check_charity_fixed_code_by_email` و`find_provider_by_phone` في Production | الدالتان SECURITY DEFINER وممنوحتان لـ `anon`. الأولى تبحث بالبريد والكود الثابت وتعيد حالات قبول/رفض؛ الثانية تطابق رقم الهاتف وتعيد provider state. حتى لو كان ذلك مقصودًا لمسار pre-OTP، فهو public authentication surface يحتاج rate limiting وabuse controls دقيقة | تقليل grants قدر الإمكان، إضافة rate limiting/lockout server-side، منع account/status enumeration، ومراجعة التدفق قبل أي تغيير | لم يُصلح؛ تغيير grant/auth behavior يتطلب خطة واختبار |
| H3 | Deployed Edge Functions مقابل `supabase/functions/` | الوظائف المنشورة ليست نسخة مطابقة لـ Git: `send-otp` v7، `verify-and-create` v18، `send-whatsapp` v3، `send-push-notification` v27، `verify-otp` v2 وغيرها. deployed `verify-otp` يحتوي مسارًا قديمًا يستخدم `generateLink` مع domain مختلف عن `verify-and-create`، ما يخلق مسارين للمصادقة | اعتماد release process يربط كل deploy بـ commit/hash، تعطيل/تقاعد المسار القديم بعد usage check، ثم نشر نسخة موحدة فقط من staging | لم يُصلح؛ النشر الخارجي غير منفذ |
| H4 | Storage buckets: `charity-images`, `home-banners`, `restaurant-offers` | buckets public وبدون `file_size_limit` أو `allowed_mime_types` في Production | resource abuse، ملفات ضخمة/غير متوقعة، وتكلفة/أداء أسوأ. public access قد يكون مقصودًا للصور، لكن القيود ما زالت مطلوبة | ضبط limits/MIME policies بعد تأكيد الاستخدام؛ لا تُطبّق مباشرة على Production في هذه المراجعة |
| H5 | Android release configuration | لا توجد signing credentials في البيئة ولا Android SDK للتحقق من release؛ المشروع fail-closed عند release task وهذا جيد أمنيًا، لكن artifact الإنتاجي غير مثبت | تنفيذ build داخل CI/جهاز Android مهيأ، تثبيت keystore من secret manager، والتحقق من `flutter build appbundle --release` | لم يُتحقق |

## Medium Issues

| # | المصدر | المشكلة | التوصية | الحالة |
|---:|---|---|---|---|
| M1 | Supabase Security Advisor | 14 جدولًا عليها RLS بدون policies؛ هذا يمنع الوصول غالبًا، لكنه قد يكسر backend paths أو features إن كان مقصودًا أن تصل إليها authenticated clients | إنشاء مصفوفة access لكل جدول، ثم إضافة policies minimal فقط حيث يلزم واختبارها بأدوار anon/authenticated/owner/admin | لم يُصلح |
| M2 | Supabase Performance Advisor | 42 foreign keys بلا indexes | قد تتدهور joins وcascade checks والاستعلامات مع النمو | إضافة indexes بعد مراجعة query plans وحجم البيانات؛ migration منفصلة | لم يُصلح |
| M3 | Supabase Performance Advisor | 109 RLS policies تستخدم `auth.uid()`/current_setting مباشرة لكل row بدل `(select auth.uid())` | تكلفة متكررة على الاستعلامات الكبيرة | تحسين policies تدريجيًا مع EXPLAIN/اختبارات regression | لم يُصلح |
| M4 | Edge Functions | wildcard CORS في عدة functions، مع `verify_jwt=false` في functions تعتمد على internal secret أو public flows | يزيد surface للاتصالات غير المتوقعة؛ لا يعد وحده bypass إذا كانت secrets/auth صحيحة | تقييد origins حيثما كان browser client لا يحتاج wildcard، والإبقاء على secret validation server-side | لم يُصلح |
| M5 | `lib/` | `flutter analyze` سجل 109 warnings و585 infos، منها `avoid_print` على نطاق واسع، `use_build_context_synchronously`، dead null-aware expressions، unused members/imports، و`invalid_use_of_visible_for_testing_member` | يصعّب اكتشاف defects الحقيقية، وبعض lifecycle warnings قد تتحول إلى crashes أو snackbars على widget disposed | تنظيف تدريجي حسب feature/risk، والبدء بـ async context/lifecycle وerror handling قبل style-only cleanup | لم يُصلح بالكامل |
| M6 | `lib/main.dart` | startup يتابع العمل حتى عند فشل Supabase initialization، مع logging فقط | قد تظهر واجهة مكسورة أو Auth/router state غير واضح بدل configuration/error state صريح | إضافة حالة startup failure قابلة لإعادة المحاولة ورسالة مفهومة، مع إبقاء startup bounded | لم يُصلح |
| M7 | Permissions | Android/iOS يطلبان location وbackground location/camera/photos/notifications. الحاجة التجارية لبعضها واضحة، لكن background location يحتاج justification قويًا وإفصاح متجر | تقليل الصلاحيات إلى وقت الاستخدام، ومراجعة Data Safety/Privacy Nutrition Labels وstore declarations | لم يُصلح |
| M8 | Dependencies | `flutter pub get` نجح، لكن 77 package لها updates غير متوافقة وpackage واحدة discontinued (`flutter_map_cancellable_tile_provider`) | التحديث العشوائي قد يغيّر السلوك؛ لكن ترك dependency discontinued مخاطرة صيانة | خطة تحديث منفصلة مع changelog/tests، وعدم ترقيات عمياء ضمن هذا audit | لم يُصلح |

## Low Issues

| المصدر | الملاحظة |
|---|---|
| `pubspec.yaml` وcode style | 694 analyzer issues أغلبها style/dead-code/unused symbols؛ ليست كلها release blockers لكنها تزيد ضوضاء المراجعة |
| `README`/release process | يلزم توثيق واضح لـ production `--dart-define`، keystore variables، Supabase deploy hash، وCI commands |
| iOS | تم فحص `Info.plist` وظهر ATS مضبوطًا على عدم السماح بالـ insecure loads، لكن لم يمكن اختبار signing/capabilities/IPA |

## Security

### Authentication

مسار OTP الحالي يستخدم Edge Functions منشورة مع service-role داخل الخادم فقط، و`verify-and-create` ينشئ Auth users ثم يعيد session tokens للعميل عبر HTTPS. توجد safeguards مثل expiry ومحاولات OTP وnormalization، لكن يوجد مساران منشوران (`verify-otp` القديم و`verify-and-create` الحالي) مع اختلاف domains/behavior. يجب توحيد المسار قبل الإطلاق.

الـ deployed `send-otp` لا يطلب JWT، وهو متوقع لمسار pre-auth، لكنه public endpoint يرسل WhatsApp ويحتاج rate limiting ومقاومة enumeration. `find_provider_by_phone` و`check_charity_fixed_code_by_email` public SECURITY DEFINER يجب اعتبارهما authentication endpoints وليس RPC عادية.

### Authorization / RLS

تم فحص سياسات public وstorage عبر `pg_policies`. توجد owner checks كثيرة ومفيدة، كما أن أحدث migrations تحاول منع تعديل role/status/KYC fields. لكن production view لا يعكس نية تقليل public provider data، وبعض public-role policies واسعة اسميًا حتى لو كان `auth.uid()` يمنع anon فعليًا في الكتابة. كما أن 14 جدولًا RLS-enabled بلا policies تحتاج مصفوفة صلاحيات مقصودة بدل افتراض أنها سليمة.

### Storage

`provider-documents` private مع owner-scoped policies وimage limits، وهذه نقطة جيدة. لكن public buckets الثلاثة غير محدودة الحجم/النوع. يجب إضافة limits والتحقق من path/ownership لكل bucket قبل استقبال ملفات من مستخدمين حقيقيين.

### Secrets

لم يظهر service-role key أو private key داخل Flutter source أو Git في الفحص. publishable/anon key وجوده في client متوقع، ولا يجب اعتباره secret. لا تُشارك مفاتيح التشغيل في Git؛ استخدم dart-defines وsecret manager/CI.

### Edge Functions

الوظائف تستخدم secrets الخادم بشكل صحيح في بعض المسارات (`WAPILOT_TOKEN`, `GOOGLE_SERVICE_ACCOUNT`, `INTERNAL_FUNCTION_SECRET`). لكن drift بين deployed وGit هو أكبر خطر تشغيلي: لا يمكن ضمان أن إصلاحًا في repository هو ما يعمل فعليًا.

## Reliability / Network / Crash Risks

الكود يحتوي timeouts في startup وبعض calls، لكن analyzer كشف `use_build_context_synchronously` في map flows، وعددًا كبيرًا من `print/debugPrint` بما في ذلك user IDs/phone/path/error context. يجب استخدام structured redacted logging، وحراسة `mounted` بعد awaits قبل `setState`/SnackBar/navigation. لا يمكن اختبار offline/slow network/401/403/429/500 end-to-end في sandbox.

## Performance

Advisor أكد 42 foreign keys بلا indexes و109 RLS per-row optimization findings. توجد indexes جيدة على كثير من listing/status/date paths، لكن يلزم EXPLAIN على الاستعلامات الأكثر استخدامًا قبل إضافة indexes. توجد صور وuploads متعددة؛ limits موجودة في معظم buckets، لكنها مفقودة في ثلاثة public buckets. لم يُنفذ profiling فعلي للـ startup/render/memory بسبب غياب جهاز تشغيل.

## Android

تمت مراجعة `AndroidManifest.xml` و`android/app/build.gradle.kts`. application id هو `com.jood.app`، target/compile SDK 36، release signing يعتمد على environment variables ولا يضع keystore في Git، وهذا fail-closed behavior جيد. لكن sandbox لا يحتوي Android SDK، لذلك:

- `flutter build apk --debug`: لم يُبنَ — `No Android SDK found`.
- `flutter build appbundle --release`: لم يُنفذ/يتحقق.
- لا توجد شهادة أو keystore production في البيئة الحالية.

## iOS

تمت مراجعة `ios/Runner/Info.plist`. توجد location/camera/photo/notification declarations وATS غير متساهل. لم يمكن تنفيذ `flutter build ipa --release` لأن بيئة sandbox Linux ولا تحتوي Xcode/macOS signing toolchain. يجب إجراء فحص مستقل على macOS مع provisioning profiles وpush entitlements وrelease Firebase configuration.

## Tests

الاختبارات الموجودة ركزت على validators وprovider profile completion. قبل الإصلاح فشل `provider_profile_completion_test.dart` لأن fixture لم يعد يطابق قواعد الإنتاج التي تطلب governorate وavailable days وصورتي الهوية. تم تحديث fixture، وأصبح:

```text
TEST_EXIT=0
All tests passed!
```

هذا لا يغطي Auth/RLS/Storage/Edge Functions end-to-end؛ يلزم staging test suite بأدوار ومستخدمين اصطناعيين.

## Safe Fixes Applied

| الملف | التغيير |
|---|---|
| `lib/features/userhome/presentation/pages/user_home_page.dart` | إزالة `const` من `Border` لأن `_border` يعتمد على runtime theme state؛ أصلح compile error `Invalid constant value` |
| `pubspec.yaml` | إزالة `.env` من bundled assets؛ التحميل في `main.dart` optional ويعتمد على dart-defines/بيئة التشغيل، ووجوده كasset كان يكسر clean test/build عندما لا يكون الملف موجودًا |
| `test/provider_profile_completion_test.dart` | إضافة الحقول الإلزامية الحالية للـ fixture حتى يعكس contract الإنتاج، مع إبقاء اختبار numeric-string/zero-experience |
| `PRODUCTION_AUDIT_WORKING_NOTES.md` | ملاحظات evidence مرحلية للمراجعة |

لم يتم تعديل Supabase Production، ولم يتم حذف بيانات، ولم يتم تغيير RLS/Auth behavior أو نشر Edge Functions.

## Commands Executed

| Command | Result |
|---|---|
| `git status`, `git log`, repository scans | نجحت؛ لا تغييرات أصلية قبل الإصلاحات |
| `flutter --version` | Flutter 3.47.6 / Dart 3.13.5 |
| `flutter pub get` | نجح |
| `flutter analyze` | قبل الإصلاح failed بسبب compile error و`.env`; بعد الإصلاح لا compile errors، لكن exit 1 بسبب 694 analyzer issues |
| `flutter test` | قبل الإصلاح failed بسبب `.env` ثم stale fixture؛ بعد الإصلاح passed بالكامل |
| `flutter clean` | نجح |
| `flutter build apk --debug` | تعذر: Android SDK غير موجود |
| `flutter doctor --verbose` | Flutter ✓؛ Android toolchain ✗؛ لا Android SDK |
| Supabase `list_projects`, `get_project`, `list_tables`, `list_migrations`, `get_advisors`, `list_extensions`, `list_edge_functions` | نجحت؛ read-only inspection |
| Supabase `execute_sql` | read-only queries على policies/functions/views/storage/indexes/columns |
| Supabase `get_edge_function` | نجح لعدة deployed functions، وأثبت drift/version differences |
| Supabase `get_publishable_keys` | نجح؛ تم عدم إعادة نشر قيم المفاتيح في هذا التقرير |

## Remaining Risks / Unverified Areas

1. لم يتم إنشاء staging أو test accounts، لذلك لم يتم تنفيذ login/signup/logout/session-expiry/password-reset فعليًا.
2. لم يتم اختبار authorization بين user/provider/institution/charity/admin باستخدام JWTs حقيقية.
3. لم يتم نشر migrations أو تعديل Production لأن ذلك قد يغيّر RLS/Auth behavior، وهو خارج الإصلاح الآمن المباشر.
4. لم تتم مطابقة كل deployed Edge Function source مع commit Git أو معرفة triggers/webhooks الفعلية.
5. لم يُنفذ Android APK/AAB بسبب غياب SDK، ولم يُنفذ iOS IPA بسبب غياب Xcode/macOS.
6. لم يُراجع قانونيًا Privacy Policy أو store metadata؛ التقرير يحدد نقاط المراجعة فقط ولا يدعي compliance قانوني.
7. لم يُجرَ load test أو profiling على أجهزة حقيقية، ولا يمكن استنتاج memory/render performance من analyzer وحده.
8. لم يتم اعتبار وجود publishable/anon key في Flutter secret leak؛ يجب تدوير أي service-role/private/payment key فقط إذا ظهر في CI/logs أو history بعد secret-scanning كامل على كل Git history.

## Recommended Release Gate

لا تنتقل إلى Release Candidate قبل تنفيذ هذه الخطوات بالترتيب: (1) توحيد deployed functions مع Git عبر staging، (2) اعتماد public provider data contract وإصلاح view، (3) تأمين public RPCs وrate limits، (4) تحديد limits لكل storage bucket، (5) إنشاء role-based integration tests لـ Auth/RLS/Storage، (6) تنظيف lifecycle-sensitive analyzer findings، (7) تشغيل CI على Android SDK وmacOS/Xcode، ثم (8) مراجعة privacy/store declarations واختبار production-like build.
