# تقرير الفحص النهائي وتجهيز الإطلاق — وِصلة

**التاريخ:** 2026-09-29  
**المنصة:** Flutter 3.47.5 / Dart 3.13.4  
**المستودع:** `abdallamohamed334/first_app`

## الحكم التنفيذي

التطبيق **ليس جاهزًا للرفع النهائي على المتاجر بعد**؛ لكنه أصبح قابلًا للبناء والاختبار من ناحية الكود، وباقي العائق المباشر هو إعداد توقيع Android الإنتاجي وتجهيز بيئة Apple للتوقيع والمراجعة.

## ما تم فحصه وإصلاحه

- تشغيل `flutter pub get` بنجاح.
- تشغيل `flutter analyze`: لا توجد أخطاء compile؛ توجد 505 ملاحظات وتحذيرات جودة غير مانعة للبناء.
- تشغيل `flutter test`: **كل الاختبارات نجحت**.
- إصلاح استيراد `go_router` المفقود في صفحة المستخدم.
- إصلاح استيراد `debugPrint` المفقود في كيان مزود الخدمة.
- جعل خدمة FCM تُنشأ عند الحاجة بدل استدعاء Firebase أثناء تحميل اختبارات الوحدة.
- بناء `flutter build apk --debug` بنجاح، والملف الناتج:
  `build/app/outputs/flutter-apk/app-debug.apk`.
- محاولة بناء `flutter build appbundle --release`: فشلت برسالة مقصودة وواضحة لأن متغيرات توقيع الإنتاج غير مضبوطة.
- مراجعة إعدادات Android/iOS، الصلاحيات، Firebase، Supabase، وملفات الأمان الموجودة في المستودع.

## الملاحظات غير المانعة للبناء

التحليل الساكن يعرض تحذيرات كثيرة، أهمها imports غير مستخدمة، `print` في بعض المواضع، `BuildContext` بعد async gap، وdeprecated APIs. لا تمنع هذه الملاحظات إنشاء الحزمة حاليًا، لكنها تستحق backlog تحسين قبل الإطلاق الواسع.

كما توجد تحذيرات من بعض الإضافات التي ما زالت تستخدم Kotlin Gradle Plugin بالطريقة القديمة:

- `firebase_analytics`
- `firebase_remote_config`
- `flutter_image_compress_common`

ينبغي تحديثها عندما تتوفر إصدارات متوافقة مع Built-in Kotlin.

## المطلوب قبل Google Play

1. إنشاء أو استخدام **keystore إنتاجي دائم** والاحتفاظ بنسخة احتياطية آمنة خارج Git.
2. تمرير المتغيرات التالية إلى بيئة البناء/CI:
   - `ANDROID_KEYSTORE_PATH`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
3. بناء AAB:
   `flutter build appbundle --release`
4. اختبار AAB على Internal testing في Google Play قبل Production.
5. استكمال بيانات المتجر: اسم التطبيق، الوصف، الأيقونة، screenshots، رابط سياسة الخصوصية، Data safety، وتصنيف المحتوى.
6. تقييد مفاتيح Firebase العامة حسب package ID وواجهات API المطلوبة من Firebase Console.

## المطلوب قبل App Store

- لا يمكن تنفيذ توقيع أو Archive لـ iOS من بيئة Linux الحالية؛ يلزم macOS مع Xcode.
- ضبط Apple Team، Bundle ID `com.jood.app`، شهادات التوقيع، Provisioning Profile، وApp Store Connect.
- مراجعة أذونات الموقع والكاميرا والصور والإشعارات على جهاز iPhone حقيقي.
- اختبار تسجيل الدخول OTP، الإشعارات، رفع الصور، الموقع، والروابط العميقة على Release build.
- استكمال Privacy Nutrition Labels وApp Privacy وبيانات المتجر.

## مخاطر إنتاجية يجب إغلاقها قبل النشر العام

التقارير الأمنية الموجودة في المستودع ما زالت تشير إلى عناصر خارج الكود يجب تأكيدها على البيئة الحية:

- الأسرار الداخلية لـ Supabase وEdge Functions مضبوطة ومختلفة عن staging.
- مراجعة RLS وRPCs على مشروع Supabase الفعلي.
- إزالة أي بيانات KYC من الـ public provider view.
- تقييد bucket صور مزودي الخدمة من حيث MIME type والحجم والمسار.
- مزامنة أي migrations موجودة على Supabase وغير مسجلة في Git.
- اختبار staging بحسابات منفصلة لمسارات OTP، الأدوار، الطلبات، الحجز، رفع الصور، والإشعارات.

## الملفات المعدلة في هذه الجولة

- `lib/core/services/supabase_service.dart`
- `lib/features/services/domain/entities/service_provider.dart`
- `lib/features/userhome/presentation/pages/user_home_page.dart`
- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `FINAL_RELEASE_AUDIT.md`

> لا يحتوي التغيير على keystore أو مفاتيح توقيع أو أسرار إنتاجية.
