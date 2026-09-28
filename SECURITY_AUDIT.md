# تقرير التدقيق الأمني — Wasla / Loqma

**النطاق:** تطبيق Flutter، Supabase Edge Functions، إعدادات Android/iOS، وسياسات المصادقة الظاهرة في الريبو.

**الحالة:** تحسّن أمني مهم تم تطبيقه، لكن التطبيق **ليس جاهزًا للإطلاق الإنتاجي بعد** بسبب متطلبات تشغيل وإطلاق خارج الكود.

## إصلاحات تم تطبيقها

- منع إنشاء حسابات مقدم الخدمة بحالة `approved` من بيانات العميل؛ التسجيل أصبح `pending` و`is_active=false`.
- منع العميل من اختيار أدوار privileged مثل `admin` أثناء التسجيل؛ الأدوار المسموحة للتسجيل هي `user`, `provider`, `institution` فقط.
- استبدال كلمة المرور الداخلية المتوقعة من رقم الهاتف بكلمة مرور عشوائية آمنة لكل عملية تحقق.
- منع تسجيل OTP وبيانات الملف الشخصي في السجلات.
- استبدال `Math.random()` في OTP بمصدر عشوائي تشفيري `crypto.getRandomValues`.
- إضافة منع إعادة إرسال OTP خلال 60 ثانية بالاعتماد على أحدث سجل في قاعدة البيانات.
- إضافة تحقق صارم من صيغة رقم الهاتف والكود.
- حماية `send-whatsapp` بحيث لا يعمل إلا مع جلسة مستخدم صحيحة، مع تقييد طول الرسالة ورقم الهاتف وعدم تسريب رد مزود WhatsApp.
- جعل `send-push-notification` داخليًا فقط عبر `NOTIFICATION_INTERNAL_SECRET` وعدم إعادة أخطاء FCM التفصيلية للعميل.
- جعل `notify-provider-approved`, `issue-signup-email-code`, و`verify-otp` داخلية فقط عبر `INTERNAL_FUNCTION_SECRET`.
- تعطيل cleartext HTTP صراحة في Android عبر `android:usesCleartextTraffic="false"`.
- رفع متطلبات كلمة المرور في إعداد Supabase المحلي إلى 8 أحرف مع حروف كبيرة/صغيرة وأرقام، وتفعيل إعادة التحقق عند تغيير كلمة المرور.

## ثغرات/مخاطر كانت موجودة

| الشدة | المشكلة | الأثر |
|---|---|---|
| حرجة | `verify-and-create` كان يعيّن مقدم الخدمة `approved` من طلب التسجيل | أي مهاجم يملك OTP كان يستطيع تجاوز مراجعة الإدارة والحصول على صلاحيات مقدم خدمة |
| حرجة | كلمة المرور الداخلية كانت مشتقة من رقم الهاتف بصيغة ثابتة | إمكانية تخمين بيانات اعتماد الحسابات بعد معرفة رقم الهاتف |
| عالية | `send-whatsapp` كان يسمح باستدعاء مزود الرسائل بدون مصادقة | إساءة استخدام الحساب لإرسال رسائل عشوائية وتكلفة مالية/حظر رقم WhatsApp |
| عالية | `send-push-notification` كان مكشوفًا بدون سر داخلي | إرسال إشعارات مزيفة لأي مستخدم عبر FCM |
| عالية | `notify-provider-approved` و`issue-signup-email-code` و`verify-otp` كانت بلا بوابة داخلية | إساءة استخدام webhooks وOTP وإرسال البريد |
| متوسطة | OTP كان يستخدم `Math.random()` ولا يوجد throttle دائم قبل الإنشاء | قابلية أعلى للتخمين وOTP spam |
| حرجة للإطلاق | Android Release يستخدم debug signing | لا يجوز نشر التطبيق بهذه الشهادة؛ خطر تحديثات/هوية التطبيق وفشل متطلبات المتاجر |

## متطلبات قبل الإطلاق

1. **إعداد توقيع Android إنتاجي**: إنشاء keystore حقيقي خارج Git، تخزينه في CI secrets، وتغيير `android/app/build.gradle.kts` ليستخدم release signing بدل:
   `signingConfigs.getByName("debug")`.
2. ضبط أسرار Supabase التالية في بيئة الإنتاج، وعدم وضعها في Git:
   - `INTERNAL_FUNCTION_SECRET`
   - `NOTIFICATION_INTERNAL_SECRET`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `WAPILOT_TOKEN` أو `WHATSAPP_TOKEN` حسب الوظيفة
   - `GOOGLE_SERVICE_ACCOUNT`
   - `RESEND_API_KEY` إذا كانت وظيفة البريد مستخدمة
3. تحديث استدعاءات webhooks الداخلية لإرسال headers المناسبة بعد تفعيل الأسرار:
   - `x-internal-function-secret`
   - `x-notification-secret`
4. مراجعة كل سياسات RLS على المشروع البعيد، خصوصًا الجداول التي تحتوي على:
   - `otp_codes`
   - `user_devices`
   - `service_providers`
   - `users`
   - `storage.objects`
   لا يمكن تأكيد هذه المراجعة بالكامل من هذا الريبو لأن ملفات إنشاء المخطط الأساسية غير موجودة كلها محليًا.
5. تشغيل اختبار اختراق مصادق عليه على مشروع staging يشمل تجاوز الأدوار، IDOR، RLS، إعادة استخدام OTP، وسباق حجز العروض.
6. تفعيل مراقبة وتنبيهات لـ OTP abuse، رسائل WhatsApp، أخطاء FCM، ومحاولات الدخول الفاشلة.
7. التأكد من تعطيل وظائف Supabase القديمة غير المستخدمة بدل تركها منشورة.

## التحقق الذي تم في الساندبوكس

- `git diff --check`: ناجح.
- Prettier على وظائف TypeScript المعدلة: ناجح.
- فحص أنماط الأسرار/المفاتيح الخاصة: لم يظهر مفتاح service-role أو private key داخل الملفات.
- مراجعة Git history: مفاتيح Firebase الظاهرة هي مفاتيح client عامة وليست service credentials؛ مع ذلك يجب تقييدها من Firebase Console حسب package/bundle IDs وواجهات API المطلوبة.
- `flutter analyze` و`flutter build`: **لم يتمكنا من التشغيل لأن Flutter SDK غير مثبت في الساندبوكس**.

## الحكم النهائي

**لا أنصح بالإطلاق الآن.** الإصلاحات تمنع أخطر مسارات الاستغلال الموجودة في الكود، لكن يلزم أولًا إعداد release signing، ضبط أسرار Supabase والـ webhooks، مراجعة RLS على المشروع الفعلي، ثم تشغيل build واختبارات staging أمنية قبل نشر التطبيق.


## تحديث التدقيق الحي — 2026-09-28

تم تنفيذ الإصلاحات مباشرة على مشروع Supabase المتصل `gsrhoqdtcyfdmvgahqvl`:

- تفعيل RLS على `users`, `food_offers`, `offer_requests`, `notifications`.
- تقييد قراءة `users` للمستخدم نفسه بدل كشف كل بيانات المستخدمين، مع منع تعديل `id` وحقول الصلاحيات عبر سياسة التحديث.
- منع العميل من إنشاء الإشعارات؛ الإنشاء أصبح backend-only، مع السماح للمستخدم بقراءة وتحديث إشعاراته فقط.
- سحب تنفيذ دوال `public` من `anon`، وتثبيت `search_path = public, pg_temp` للدوال المملوكة للمشروع.
- تحويل الـviews التالية إلى `security_invoker`: `active_food_offers`, `active_institution_offers`, `home_offers`, `open_service_requests`, `published_service_reviews`.
- تفعيل RLS على `direct_charity_points_awards` و`business_capabilities`.
- نشر نسخ محصنة من: `send-otp` v6، `send-whatsapp` v3، `verify-and-create` v12، `send-push-notification` v27، `notify-provider-approved` v6، `notify-new-charity-donation` v19.
- الـwebhooks الداخلية أصبحت ترفض الطلبات بدون `x-internal-function-secret` أو `x-notification-secret` مطابق للـsecret المخزن.
- تم التحقق أن قيم `public.users.password` غير موجودة حاليًا (`0` صفوف غير فارغة)، لكن يظل العمود legacy ويجب حذفه بعد التأكد من عدم استخدامه في أي نسخة قديمة من التطبيق.

## المتبقي قبل الإطلاق

1. يجب التأكد من وجود الأسرار التالية في Supabase Secrets؛ لا يتم إرسالها عبر الدردشة: `INTERNAL_FUNCTION_SECRET`, `NOTIFICATION_INTERNAL_SECRET`, `WAPILOT_TOKEN`, `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_ID`, `GOOGLE_SERVICE_ACCOUNT`, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`.
2. Supabase لا يسمح لمالك المشروع بتعديل جدول PostGIS المملوك للإضافة `spatial_ref_sys` أو دوال `st_estimatedextent`؛ لذلك تظهر هذه العناصر فقط في Advisor، ولا تمس جداول التطبيق. معالجة ذلك تحتاج إعدادًا إداريًا من لوحة Supabase/الدعم أو نقل PostGIS إلى schema مخصص.
3. ما زالت هناك تحذيرات Advisor حول دوال `SECURITY DEFINER` التي يستدعيها المستخدم المسجل. لا يمكن سحب صلاحيتها عشوائيًا دون كسر RPCs التطبيق؛ يلزم اختبار كل RPC حسب الدور ثم تحويل غير الضروري إلى `SECURITY INVOKER` أو سحب `EXECUTE` منه.
4. يجب اختبار مسارات التسجيل، OTP، الطلبات، الإشعارات، والـwebhooks بحسابات test منفصلة قبل الإنتاج، خصوصًا بعد تضييق قراءة جدول `users`.
