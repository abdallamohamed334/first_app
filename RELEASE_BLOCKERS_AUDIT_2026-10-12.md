
## تحديث التنفيذ — 2026-10-12 22:20

تم تنفيذ والتحقق من التالي:

- تطبيق `public_provider_projection_and_rpc_hardening` على Supabase بنجاح.
- نقل العرض العام إلى `published_service_provider_cards` مع RLS وحقول public صريحة فقط.
- تحويل `published_service_providers` إلى `security_invoker=true`.
- إزالة `company_legal_name`, `employees_count`, `founded_year`, `branches` وحقول KYC/owner من projection العامة.
- إغلاق تنفيذ `guard_community_offer_single_edit` و`sync_institution_offer_catalog_category` عن أدوار API.
- اختبار REST للـanon على الـView الجديدة نجح بـHTTP 200.
- تحديث Flutter repository لعدم طلب الحقول التي لم تعد public.
- تحديث static security regression checks لتمنع عودة الحقول الحساسة أو RPCs الداخلية.
- تطبيق migration إغلاق PostGIS RPCs؛ لكن Supabase يعيد منح هذه الصلاحيات على extension-managed functions، لذلك بقي Advisor يعرضها. التطبيق نفسه لا يستخدم هذه الدوال، ويجب التعامل معها كتحذير platform-managed لا كعطل في منطق التطبيق.
- تعديل release workflow بحيث لا يشغل iOS validation إلا عند تفعيل `ENABLE_IOS_VALIDATION=true`؛ سبب فشل التشغيل السابق كان غياب `FIREBASE_IOS_API_KEY`.

التحققات الأخيرة:

```text
security regression checks: PASS
PRODUCTION_GATE_PASS
REST published_service_providers (anon): HTTP 200
```

ما زال يتطلب إجراءً خارجيًا قبل إعلان الجاهزية النهائية: تشغيل Android Production Release مع secrets التوقيع الفعلية، وإنشاء staging accounts لاختبارات E2E، واسترجاع SQL الأصلي للـmigration الإنتاجية `20261011193316` حتى يصبح Git هو مصدر الحقيقة الوحيد.
