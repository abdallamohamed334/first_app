# روابط بروفايل مقدم الخدمة

يشارك التطبيق الرابط العام التالي:

```text
https://khedma.app/service-provider/<provider_id>
```

عند تثبيت التطبيق، يفتح الرابط صفحة مقدم الخدمة داخل التطبيق عبر Android App
Links أو iOS Universal Links. وعند عدم تثبيت التطبيق، يجب أن يعرض النطاق صفحة
الويب المقابلة أو صفحة تنزيل التطبيق. صفحة Flutter Web في هذا المشروع تحتوي
على نفس مسار `service-provider/:id`، لكن يجب نشرها على `khedma.app` مع تفعيل
إعادة توجيه المسارات إلى `index.html`.

## إعداد Android

يجب نشر الملف التالي على:

```text
https://khedma.app/.well-known/assetlinks.json
```

مع استبدال قيمة SHA-256 ببصمة شهادة إصدار Android الفعلية:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.jood.com",
      "sha256_cert_fingerprints": ["<RELEASE_CERT_SHA256>"]
    }
  }
]
```

## إعداد iOS

يجب نشر الملف التالي على:

```text
https://khedma.app/.well-known/apple-app-site-association
```

بدون امتداد، مع استبدال `<TEAM_ID>` بفريق Apple Developer المستخدم للتوقيع:

```json
{
  "applinks": {
    "details": [
      {
        "appID": "<TEAM_ID>.com.jood.com",
        "paths": ["/service-provider/*"]
      }
    ]
  }
}
```

إعدادات Android وiOS المحلية مضافة بالفعل إلى المشروع. بدون نشر ملفي التحقق
أعلاه، سيظل الرابط يفتح في المتصفح كبديل، لكنه لن يتحول تلقائيًا إلى التطبيق
في جميع الأجهزة.
