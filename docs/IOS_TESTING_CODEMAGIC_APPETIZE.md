# اختبار Khedma على iOS عبر Codemagic وAppetize

## نسخة Appetize

شغّل Workflow باسم `ios-simulator-appetize` في Codemagic. سيُنتج الملف:

```text
artifacts/khedma-ios-simulator.zip
```

ارفع هذا الملف إلى Appetize. الملف يحتوي على `Runner.app` مبنيًا لـ iOS Simulator، وليس IPA مخصصًا لجهاز حقيقي.

Appetize لا يقبل IPA الخاص بالتوزيع على أجهزة iPhone؛ المطلوب هو تطبيق iOS Simulator مضغوط بصيغة ZIP.

## نسخة iOS Release

شغّل Workflow باسم `ios-release` يدويًا بعد إعداد التوقيع في Codemagic:

1. أضف شهادة توزيع iOS وProvisioning Profile من إعدادات Codemagic.
2. اجعل اسم مجموعة البيئة `khedma-production` متاحًا للـ Workflow.
3. اربط الـ Provisioning Profile مع Bundle ID الحالي في مشروع Xcode.
4. شغّل البناء يدويًا.

سيُنتج البناء:

```text
build/ios/ipa/*.ipa
```

تم تفعيل `--obfuscate` و`--split-debug-info` في نسخة Release، بينما تبقى ملفات debug symbols داخل Artifacts ولا تُضمَّن في التطبيق الموزع.

## ملاحظات مهمة

- لا توجد شهادات Apple أو مفاتيح خاصة داخل المستودع.
- لا تضع مفاتيح Apple أو App Store Connect داخل `codemagic.yaml`.
- إعدادات التوقيع يجب أن تُحفظ داخل Codemagic Code signing أو Environment groups.
- ملف Appetize مخصص للمحاكي فقط، لذلك اختبار الكاميرا وGPS والإشعارات قد يختلف عن جهاز iPhone حقيقي.
- يجب رفع `codemagic.yaml` إلى جذر المستودع حتى يظهر كإعداد YAML في Codemagic.
- تم وضع معرف AdMob الرسمي التجريبي الخاص بـ iOS في `Info.plist` لمنع توقف المحاكي عند تهيئة SDK. إعلانات iOS متوقفة حاليًا في الكود. قبل تفعيل الإعلانات على App Store يجب استبداله بمعرف تطبيق iOS الحقيقي من AdMob، وليس معرف Android أو معرف وحدة الإعلان.
