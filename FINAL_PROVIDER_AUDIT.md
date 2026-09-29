# الفحص النهائي: مزود الخدمة وصفحات مزود الخدمة

**التاريخ:** 2026-09-29  
**النطاق:** Flutter provider flow، صفحات عرض مزودي الخدمة، مستودعات Supabase، والـ live Supabase project `gsrhoqdtcyfdmvgahqvl`.  
**حالة الفحص:** اكتمل — لم يتم تنفيذ أي تعديل على بيانات الإنتاج أو صلاحيات قاعدة البيانات.

## الخلاصة التنفيذية

تدفق مزود الخدمة الأساسي موجود ويغطي التسجيل، OTP، حالة الانتظار، لوحة التحكم، تعديل الملف، التقييمات، ومعاينة الملف. لكن لا أنصح باعتبار الجزء جاهزًا للإطلاق قبل معالجة **مشكلتين أمنيتين مرتفعتي الخطورة**:

1. **تسريب بيانات التوثيق في الـ public provider view**: الـ view المستخدمة من صفحات المستخدم ترجع أرقام/روابط بطاقة الهوية، السجل التجاري، البطاقة الضريبية، الترخيص، وملاحظات الإدارة.
2. **Bucket صور مزودي الخدمة غير محمي بقيود نوع/حجم الملف**: bucket `provider-images` عام، و`file_size_limit` و`allowed_mime_types` كلاهما `null`، بينما كود الرفع يقبل الامتداد القادم من اسم الملف.

كما توجد مشاكل وظيفية/تشغيلية متوسطة: تحقق الخبرة يسمح بالقيمة `0` عند بعض أنواع البيانات، وصفحتا `خدماتي` و`الطلبات` مجرد placeholders وغير مربوطتين بالـ router أو shell، ولا يوجد اختبار provider فعلي في مجلد الاختبارات.

## المشاكل المؤكدة

### P0 — تسريب بيانات التوثيق عبر `published_service_providers`

**الدليل من قاعدة الإنتاج:** تعريف الـ view العامة يضم الحقول التالية ضمن `SELECT`:

- `id_card_url`
- `id_card_number`
- `certificate_url`
- `commercial_register`
- `commercial_register_url`
- `tax_id`
- `tax_card_url`
- `license_url`
- `verification_notes`
- `verified_by`
- `verified_at`

والـ view مفلترة فقط على `verification_status = approved`, `is_active = true`, `is_available = true`، وليست مفلترة على الحقول الحساسة.

**الأثر:** أي عميل يقرأ `published_service_providers` يستطيع استقبال بيانات KYC/إدارية لا يحتاجها المستخدم النهائي. المشكلة مضاعفة لأن التطبيق نفسه يستخدم `select()` بلا قائمة أعمدة في:

- `lib/features/services/data/repositories/service_providers_repository.dart:22-25`
- `lib/features/services/data/repositories/service_providers_repository.dart:93-97`

**الإصلاح المطلوب:**

- إنشاء view عامة جديدة أو تعديل view الحالية لتُرجع فقط بيانات العرض العام: الاسم، التصنيف، النبذة، الصور العامة، المدينة، مناطق الخدمة، الأسعار، وسائل التواصل التي قرر المنتج نشرها، الإحصائيات، وحالة التوفر.
- حذف كل حقول KYC والإدارة من الـ public view.
- تغيير استعلامات التطبيق من `select()` إلى قائمة أعمدة صريحة حتى لا يعود تسريب جديد عند إضافة عمود للـ view.
- إبقاء الوصول إلى بيانات التوثيق مقتصرًا على صاحب الحساب/الإدارة عبر table أو RPC محمي.

### P0 — تخزين صور غير مقيد في `provider-images`

**الدليل من الإنتاج:** bucket `provider-images` حالته:

- `public = true`
- `file_size_limit = null`
- `allowed_mime_types = null`

سياسات التخزين الحالية تتحقق من أن أول مجلد يساوي `auth.uid()` فقط، لكنها لا تتحقق من الامتداد أو الحجم أو نوع الصورة. كما أن كود العميل يبني اسم الملف من امتداد المسار مباشرة:

- `lib/features/provider/data/repositories/service_provider_repository.dart:558-560`
- الرفع في السطور `566-573`

**الأثر:** إمكانية رفع ملفات كبيرة أو أنواع ملفات غير صور إلى bucket عام، مع استهلاك/إساءة استخدام التخزين، وربما نشر محتوى غير متوقع عبر روابط عامة.

**الإصلاح المطلوب:**

- وضع حد حجم مناسب، مثل 5–10 MB.
- تحديد MIME types إلى `image/jpeg`, `image/png`, `image/webp` فقط.
- تقييد سياسات INSERT/UPDATE إلى مسارات provider محددة (`profile_`, `cover_`, `portfolio_`) وامتدادات مسموحة.
- التحقق في التطبيق من الامتداد/النوع قبل الرفع، وعدم الاعتماد على اسم الملف فقط.
- إضافة تنظيف للصور القديمة بعد نجاح استبدال الصورة، لأن الحفظ الحالي يرفع نسخة جديدة ولا يحذف السابقة.

### P1 — فحص سنوات الخبرة يسمح بقيمة غير صحيحة

في `checkProfileCompletion`:

```dart
final exp = provider['experience_years'];
if (exp == null || (exp is int && exp < 1)) {
  missing.add('سنوات الخبرة');
}
```

المكان: `lib/features/provider/data/repositories/service_provider_repository.dart:139-143`.

لو وصلت القيمة كنص `'0'` أو كـ `double 0.0` فلن تُعتبر ناقصة. واجهة التعديل تحفظ `0` أيضًا عند فشل التحويل:

- `lib/features/provider/presentation/pages/provider_edit_profile_page.dart:279`

**الأثر:** المزود قد يفعّل الظهور رغم أن شرط الخبرة غير مكتمل، حسب شكل القيمة الراجع من Supabase/الـ mapping.

**الإصلاح المطلوب:** تحويل القيمة إلى رقم موحد ثم التحقق من `>= 1`، مع منع الحفظ بقيمة سالبة أو صفر إن كان الشرط المنتجّي هو وجود خبرة.

### P1 — صفحات مزود غير مكتملة وغير مستخدمة

الملفان:

- `lib/features/provider/presentation/pages/provider_services_page.dart:15-17`
- `lib/features/provider/presentation/pages/provider_requests_page.dart:15-17`

يعرضان فقط:

- `خدماتي — قيد التطوير`
- `الطلبات — قيد التطوير`

ولا توجد لهما routes في `lib/routes/app_router.dart`، كما أن `ProviderMainShell` يحتوي على تبويبات: الرئيسية، التقييمات، حسابي فقط.

**الأثر:** لو كان نطاق المنتج يتطلب أن يدير المزود خدماته أو طلباته، فالوظيفة غير متاحة فعليًا رغم وجود ملفات تحمل أسماء الصفحات. هذا ليس ثغرة أمنية، لكنه gap وظيفي واضح.

**الإصلاح المطلوب:** إما ربط الصفحات بتدفق فعلي يعتمد على `service_offers` و`service_requests` مع سياسات/RPC مناسبة، أو إزالة/تعليم الملفات كـ planned feature حتى لا تبدو الوظيفة جاهزة.

### P1 — `select()` واسع في صفحات ومخازن مزودي الخدمة

الاستعلامات التالية تستخدم `select()` أو `*` بدل projection صريح:

- `listByCategory` و`getById` على `published_service_providers`.
- `checkProviderByPhone` على `service_providers`.
- `getCurrentProvider` على `service_providers`.
- `toggleAvailability` على `service_providers`.
- `ProviderPublicProfilePage` يعتمد على بيانات الصف كما هي.

حتى بعد إصلاح الـ view، هذا النمط يجعل أي تغيير schema مستقبلي قابلًا لتوسيع البيانات المكشوفة بلا مراجعة UI/أمنية.

**الإصلاح المطلوب:** تعريف projections منفصلة:

- `publicProviderColumns`
- `ownerProviderColumns`
- `providerAuthLookupColumns`
- `providerStatsColumns`

والامتناع عن `select('*')` في كل كود التطبيق.

### P2 — كشف وجود حساب مزود من شاشة الدخول

الـ live database تحتوي على `find_provider_by_phone(p_phone text)` كـ `SECURITY DEFINER`، ومتاح للـ `anon` حسب Advisor. كما أن التطبيق ينفذ فحصًا مباشرًا بالهاتف قبل OTP في `checkProviderByPhone`.

هذا قد يكون مقصودًا لتوجيه المستخدم إلى تبويب الدخول الصحيح، لكنه يسمح بتأكيد أن رقمًا معينًا مسجل كمزود خدمة، ويجب اعتباره قرار خصوصية/anti-enumeration.

**الإصلاح المقترح:** توحيد الرسالة والسلوك بحيث لا تكشف حالة الحساب قبل نجاح OTP، أو الاحتفاظ بالـ lookup ولكن إرجاع أقل قدر ممكن من البيانات، مع rate limiting ومراقبة المحاولات.

## فجوات الاختبار والتحقق

- لم توجد اختبارات provider مخصصة؛ الاختبار الموجود حاليًا هو `test/validators_test.dart` فقط.
- لم يمكن تشغيل `flutter test` أو `flutter analyze` في بيئة الفحص لأن Flutter SDK غير مثبت في الـ sandbox الحالي (`flutter: command not found`).
- تم تنفيذ مراجعة static للكود مع فحص live Supabase schema/policies/views/advisors.
- حالة المستودع نظيفة: لا توجد تغييرات غير محفوظة قبل إنشاء هذا التقرير.

## ملاحظات قاعدة البيانات والـ deployment drift

يوجد في Supabase live migration باسم `20260929084618_harden_service_provider_access`، لكنه غير موجود ضمن `supabase/migrations` في هذا الريبو. هذا يعني أن حالة قاعدة البيانات الحالية غير قابلة لإعادة البناء بالكامل من نسخة Git الحالية.

**الإصلاح المطلوب:** سحب/تسجيل migration الخاصة بمزود الخدمة داخل الريبو، ثم إضافة migration تصحيحية موثقة للـ public view وbucket policies. لا يُنصح بتعديل live schema يدويًا فقط دون migration مقابلة.

## ترتيب التنفيذ المقترح

1. **فورًا:** إزالة KYC والحقول الإدارية من `published_service_providers`.
2. **فورًا:** فرض MIME/size/path restrictions على `provider-images`.
3. **بعدها:** استبدال كل `select('*')` بقوائم أعمدة صريحة.
4. **بعدها:** إصلاح تحقق سنوات الخبرة وإضافة unit tests له.
5. **قبل الإطلاق:** تحديد قرار المنتج بخصوص `خدماتي` و`الطلبات` وتنفيذها أو إخفاؤها.
6. **قبل كل deploy:** مزامنة migrations بين الإنتاج والريبو وتشغيل Flutter analyzer/tests على CI.

## الحكم النهائي

**الجزء الأساسي يعمل من ناحية التدفق، لكنه غير جاهز للإطلاق العام أمنيًا** بسبب تسريب بيانات التوثيق وقيود التخزين المفقودة. بعد معالجة مشكلتي P0، ثم إغلاق فجوة الاختبارات والـ deployment drift، يمكن إعادة الفحص النهائي على build فعلي مع حساب مزود معتمد وحساب مستخدم عادي.