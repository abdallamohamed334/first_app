# تقرير فحص جاهزية الإطلاق — Loqma / Khedma

**تاريخ الفحص:** 2026-10-18  
**المستودع:** `abdallamohamed334/first_app`  
**الفرع:** `main`  
**آخر commit مفحوص:** `4d413bf` (`feat: replace butcher institution with pastry shops`)  
**مشروع Supabase الحي:** `gsrhoqdtcyfdmvgahqvl` — `eu-west-1`  
**نطاق الفحص:** Flutter/Dart، CI/CD، الأسرار، Supabase schema/RLS/RPC، Edge Functions، migrations، ومؤشرات الأمان والأداء.

## القرار التنفيذي

## **غير جاهز للإطلاق العام حاليًا (NO-GO)**

التطبيق ليس في حالة تسمح بإطلاق عام آمن اليوم. السبب ليس عطلًا واحدًا فقط؛ توجد بوابة CI أمنية فاشلة، وتنبيهات أمنية حية في Supabase، واختبارات صلاحيات حقيقية بين مستخدمين وأدوار مختلفة لم تُنفذ، ولا يوجد تحقق حديث من Android release/iOS release داخل بيئة تشغيل مجهزة.

يمكن اعتباره **قابلًا للتحضير للإطلاق** بعد إغلاق الـ blockers أدناه وإعادة تشغيل بوابة كاملة ناجحة.

## الأدلة التي تم تنفيذها

| الفحص | النتيجة |
|---|---|
| `python3 tool/production_gate.py` | **PASS** |
| `python3 tool/performance_regression_check.py` | **PASS** |
| `python3 tool/security_regression_check.py` | **FAIL** — الاختبار يتوقع تمرير WhatsApp عبر service-role بصيغة لا تطابق المصدر الحالي |
| `flutter analyze` | **لم يُنفذ**: Flutter غير مثبت في الـSandbox الحالي |
| `flutter test` | **لم يُنفذ** للسبب نفسه |
| `git diff --check` | **PASS** |
| فحص تاريخ Git للأسرار | لم يظهر service-role/private key؛ مفاتيح Firebase العامة موجودة وهي ليست أسرارًا بحد ذاتها |
| Supabase project | **ACTIVE_HEALTHY**، PostgreSQL 17.6.1 |
| Supabase migrations | آخر migrations المحلية ممثلة في المشروع الحي، لكن أسماء/أرقام النسخ الحية مولدة/مختلفة عن filenames المحلية؛ يلزم ضبط release traceability |
| Edge Functions | كلها ACTIVE، لكن توجد فروقات versions كبيرة بين المنشور والمصدر المحلي |
| iOS/Android toolchain | لم يتم build إنتاجي فعلي في هذه البيئة |

## الـ Blockers التي تمنع الإطلاق

### B1 — بوابة الأمن المحلية تفشل

الأمر:

```text
python3 tool/security_regression_check.py
```

يفشل عند التحقق من أن وظيفة `notify-charity-donation-event` تستخدم استدعاء WhatsApp بصيغة service-role التي يتوقعها الاختبار. المصدر الحالي يرسل WhatsApp مباشرة من الوظيفة باستخدام `WAPILOT_TOKEN`، بينما وظيفة `send-whatsapp` المنشورة تقبل service-role فقط.

هذا يعني أن هناك **عدم اتساق بين contract الاختبار وتصميم التنفيذ الحالي**. لا يجوز تجاهله قبل الإطلاق:

1. إما توحيد التصميم ليكون `notify-charity-donation-event -> send-whatsapp` مع اعتماد داخلي مضبوط.
2. أو تحديث الاختبار ليعكس التصميم المباشر، مع إضافة تحقق مكافئ يمنع أي endpoint عام من إرسال WhatsApp.
3. ثم تشغيل البوابة في CI والتأكد أنها PASS، وليس تجاوزها.

### B2 — Supabase Advisor يسجل خطأ أمنيًا حيًا

الفحص الحي بتاريخ 2026-10-18 أظهر:

- `public.spatial_ref_sys` في schema العامة بدون RLS — مستوى **ERROR**.
- PostGIS مثبت داخل `public` — مستوى **WARN**.
- سبع دوال `SECURITY DEFINER` قابلة للتنفيذ من `anon`، منها `check_charity_fixed_code_by_email` و`get_active_home_ads` و`get_community_stats`.
- عدد كبير من دوال `SECURITY DEFINER` متاح لـ `authenticated`؛ بعضها مقصود كـ RPC محمية داخليًا، لكن يلزم اختبار صلاحياتها فعليًا لا الاكتفاء بوجودها.
- حماية Supabase Auth من كلمات المرور المسرّبة معطلة — مستوى **WARN**.

تنبيه PostGIS قد يكون platform-owned ولا يمكن إصلاحه من دور المشروع، لكن يجب توثيق ذلك رسميًا مع Supabase أو عبر مسار إدارة الإضافة المدعوم. أما الدوال العامة وحماية Auth فهي مسؤولية مباشرة قبل الإطلاق.

### B3 — لم يُنفذ اختبار Authorization حقيقي بحسابين وأدوار

لا يوجد دليل حديث على اختبار مستخدم A ضد مستخدم B باستخدام JWTs حقيقية/مؤقتة. يجب اختبار الأقل التالي على بيئة staging أو حسابات اختبار مصرح بها:

- قراءة وتعديل profile الخاص مقابل profile مستخدم آخر.
- العروض والطلبات والحجوزات بين المالك والطالب.
- وثائق مزود الخدمة الخاصة.
- البلاغات و`blocked_users`.
- صلاحيات user/provider/institution/charity/admin.
- استدعاءات RPC الحساسة، خصوصًا `SECURITY DEFINER`.
- انتهاء الجلسة، الحساب الموقوف، OTP منتهي، OTP خاطئ ومتكرر.

بدون هذا الاختبار لا يمكن إثبات أن RLS وRPC authorization تمنع التصعيد بين الحسابات.

### B4 — لا يوجد Release artifact تم التحقق منه في الفحص الحالي

Flutter غير مثبت في الـSandbox، لذلك لم يمكن إعادة تشغيل:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build appbundle --release`
- `flutter build apk --release`

كما لم يتم بناء iOS لأن ذلك يحتاج macOS/Xcode. ملف CI موجود ويحتوي على signing flow جيد مبدئيًا، لكن لم يتم إثبات نجاحه ببيئة أسرار/keystore فعلية.

## ملاحظات عالية الأولوية

### H1 — Drift بين Git وEdge Functions المنشورة

الوظائف الحية ACTIVE لكن versions مختلفة بشكل واضح عن المستودع/التقارير السابقة، مثل:

- `send-otp`: version 16
- `verify-and-create`: version 28
- `send-whatsapp`: version 6
- `notify-charity-donation-event`: version 7
- `send-push-notification`: version 31
- `verify-otp`: version 4

وجود source محلي لا يثبت أن نفس المصدر يعمل في الإنتاج. يجب ربط كل deploy بـ commit SHA، حفظ manifest للـversions/hashes، ومنع إطلاق migration أو app release إذا كان backend drift غير معروف.

### H2 — endpoints pre-auth حساسة ومكلفة

`send-otp` و`verify-and-create` public endpoints (`verify_jwt=false`) وهذا متوقع لمسار ما قبل تسجيل الدخول، لكنهما يرسلان WhatsApp وينشئان جلسات. توجد rate limiting على OTP حسب الهاتف وIP في المصدر المنشور، وهي نقطة جيدة، لكن يجب اختبار:

- enumeration بين رقم مسجل وغير مسجل.
- تجاوز rate limit بتغيير IP/صياغة الرقم.
- محاولات verify المتكررة.
- استهلاك WhatsApp quota.
- رسائل الخطأ التي تكشف حالة الحساب.

### H3 — وجود أعمدة `password` في جداول أعمال legacy

المخطط الحي يعرض أعمدة `password` في جداول مثل `users` و`restaurants` و`charities`. حتى إن كانت غير مستخدمة حاليًا، وجودها يزيد خطر تخزين/قراءة بيانات اعتماد خارج Supabase Auth. يجب تحديد الاستخدام، إزالة الأعمدة أو جعلها غير قابلة للوصول نهائيًا، والتأكد من عدم وجود كلمات مرور plaintext في البيانات الحالية.

### H4 — بيانات عامة وخصوصية

يلزم إعادة اعتماد contract البيانات العامة، خصوصًا views الخاصة بمزودي الخدمة ووسائل الاتصال. يجب التأكد أن الهاتف والبريد والعنوان والإحداثيات وبيانات KYC لا تظهر إلا عند الحاجة وبموافقة واضحة.

### H5 — مؤشرات الأداء ليست blockers مباشرة لكنها تحتاج خطة

Supabase Advisor أظهر:

- **48** foreign keys بدون covering indexes.
- **111** ملاحظة RLS init-plan بسبب إعادة تقييم `auth.uid()`/`current_setting()` لكل صف.

هذه ليست ثغرة سرية مباشرة، لكنها قد تسبب بطئًا عند نمو البيانات. يجب معالجة الاستعلامات الساخنة بقياسات `EXPLAIN` واختبار تحميل، لا بإضافة indexes عشوائيًا.

## نقاط جيدة

- المشروع لا يضع service-role key أو private key في Flutter/Git بحسب الفحص الحالي.
- مفاتيح Supabase publishable/anon ومفاتيح Firebase client العامة في التطبيق متوقعة وليست بديلًا عن أسرار الخادم.
- `production_gate.py` و`performance_regression_check.py` يمران.
- release workflow يفشل بأمان عند غياب signing material بدل إنتاج artifact غير موقع.
- وظيفة `send-whatsapp` المنشورة تتحقق من service-role قبل إرسال رسالة، وهذا أفضل من endpoint يقبل أي session.
- معظم جداول التطبيق عليها RLS مفعّل.
- توجد rate limiting لمسار OTP في الوظيفة المنشورة.
- Android يمنع cleartext traffic، وCI يستخدم obfuscation وsplit debug info.

## خطة الإغلاق قبل الإطلاق

### P0 — قبل أي نشر

1. إصلاح أو إعادة تصميم contract إشعارات WhatsApp حتى يمر `security_regression_check.py`.
2. تفعيل Leaked Password Protection من Supabase Auth.
3. مراجعة الدوال السبع المتاحة لـ`anon` وإلغاء أي grant غير مطلوب، مع إبقاء public RPC فقط إذا كان contract مقصودًا ومختبرًا.
4. توثيق/معالجة `spatial_ref_sys` وPostGIS عبر المسار المدعوم.
5. إنشاء حسابي اختبار على الأقل لكل الأدوار المطلوبة، وتشغيل مصفوفة authorization حقيقية.
6. مطابقة deployed Edge Functions مع Git commit واحد معروف، ثم نشرها من CI فقط.

### P1 — قبل Production rollout

1. تشغيل Flutter analyze/test/build على CI ناجح مع نفس commit.
2. إنتاج Android AAB موقع واختباره على Google Play Internal testing.
3. إنتاج iOS archive/IPA على macOS مع اختبار push/deep links/camera/location/photo upload.
4. وضع limits وMIME allowlist لكل public storage bucket.
5. إزالة/عزل أعمدة passwords legacy والتحقق من عدم وجود plaintext credentials.
6. اختبار OTP وWhatsApp/FCM في staging مع logging منقح وعدم إرسال بيانات حساسة إلى logs.
7. مراجعة Privacy Policy وData Safety وApp Privacy وstore permissions.

### P2 — بعد الإطلاق التجريبي وقبل التوسع

1. معالجة foreign-key indexes حسب query plans.
2. تحسين RLS init plans إلى `(select auth.uid())` حيث ينطبق.
3. إضافة load test على المسارات: home feed، nearby offers، reservations، OTP، uploads، notifications.
4. تفعيل dashboards وalerts للـ5xx، OTP abuse، WhatsApp failures، FCM failures، وRLS denials.

## الخلاصة

**الحكم النهائي: لا تطلق الآن.**

أقرب توصيف للحالة: **Backend متقدم وبه hardening واضح، لكن release governance والاختبارات الحية والـsecurity gates لم تصل إلى مستوى Go/No-Go النهائي.** بعد إغلاق B1–B4 وإعادة الفحص كاملًا يمكن الانتقال إلى إطلاق داخلي/Closed beta، وليس مباشرة إلى إطلاق عام.

> لم يتم حذف أي بيانات أو نشر Edge Function أثناء الفحص الأول. لاحقًا، أثناء مرحلة الإصلاح، تم تطبيق migration صلاحيات غير حاذفة موضحة في سجل الإصلاح أدناه.


## سجل الإصلاحات — 2026-10-18

تم تنفيذ التالي بعد التقرير الأول:

- تحديث `tool/security_regression_check.py` ليتحقق من استخدام `WAPILOT_TOKEN` الخادمي الفعلي في إرسال WhatsApp بدل contract قديم كان يبحث عن `SUPABASE_SERVICE_ROLE_KEY`.
- إضافة migration باسم `20261018173000_harden_legacy_password_columns_and_public_rpcs.sql` لعزل أعمدة `password` القديمة عن أدوار `anon` و`authenticated`، وتقييد `list_public_charity_donors()` إلى `authenticated`.
- تطبيق migration بنجاح على Supabase الحي: `gsrhoqdtcyfdmvgahqvl`.
- إعادة فحص Advisor أكد اختفاء تنبيه `list_public_charity_donors()` من قائمة الدوال المتاحة لـ`anon`.
- بعد الإصلاحات أصبحت البوابات المحلية:
  - `security_regression_check.py`: **PASS**
  - `production_gate.py`: **PASS**
  - `performance_regression_check.py`: **PASS**
  - `git diff --check`: **PASS**

### المتبقي الذي لا يمكن اعتباره مغلقًا من داخل هذا الـSandbox

- تفعيل Leaked Password Protection من إعدادات Supabase Auth.
- مراجعة/اختبار دوال `SECURITY DEFINER` الحية بحسابات أدوار فعلية.
- اختبار Authorization بين مستخدمين فعليين بحسابات staging.
- بناء Android/iOS إنتاجي؛ Flutter وXcode غير متاحين في البيئة الحالية.
- مطابقة نسخ Edge Functions المنشورة مع commit واحد وإعادة نشرها من CI.
- التحقق من PostGIS/`spatial_ref_sys`، وهو غالبًا مورد مملوك للمنصة.

لذلك تحسن الوضع وأُغلق blocker بوابة الأمان المحلية، لكن الحكم العام يظل **NO-GO للإطلاق العام** حتى إغلاق البنود المتبقية أعلاه.
