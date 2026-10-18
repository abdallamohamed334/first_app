# أداة Desktop لإضافة المؤسسات

التطبيق موجود في [`institution_admin_app.py`](./institution_admin_app.py)، ويستخدم Tkinter ولا يحتاج إطار Desktop خارجي.

## 1. تطبيق Migration قاعدة البيانات

طبّق الملف التالي على مشروع Supabase:

```text
supabase/migrations/20261018210000_add_admin_create_institution_rpc.sql
```

الـRPC لا يسمح بالتنفيذ إلا لدور `service_role`، ويحفظ OTP كـbcrypt hash داخل `private.institution_login_secrets`.

## 2. إعداد المتغيرات

لا تضع `service_role` داخل الكود أو Git. على جهاز الإدارة:

```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
```

## 3. التشغيل

```bash
python3 -m pip install requests
python3 tools/institution_admin_app.py
```

على Windows PowerShell:

```powershell
$env:SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY"
python tools\institution_admin_app.py
```

## ما الذي يفعله التطبيق؟

- ينشئ مستخدمًا مؤكدًا في Supabase Auth.
- ينشئ سجل المؤسسة ويربطه بحساب Auth.
- يحفظ OTP الثاني كـhash فقط.
- إذا فشلت خطوة قاعدة البيانات، يحذف مستخدم Auth الذي أنشأه لتجنب الحسابات اليتيمة.
- يدعم: بقالة، سوبر ماركت، مخبز، حلويات، فندق، وقاعة أفراح.
- الحالة الافتراضية `قيد المراجعة`، ويمكن اختيار `معتمد` من داخل الواجهة.

## ملاحظة أمنية

هذه أداة إدارية موثوقة؛ لا توزعها على المستخدمين العاديين، ولا تستخدم مفتاح `service_role` في تطبيق عام أو داخل ملف تنفيذي موزع. الأفضل تشغيلها على جهاز الإدارة فقط، ثم تدوير المفتاح عند الحاجة.
