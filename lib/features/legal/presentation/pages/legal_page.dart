import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

class LegalPage extends StatelessWidget {
  final LegalDocument document;

  const LegalPage({super.key, required this.document});

  bool get isPrivacy => document == LegalDocument.privacy;

  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? 'سياسة الخصوصية' : 'شروط الاستخدام';
    final sections = isPrivacy ? _privacySections : _termsSections;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Text('Khedma', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('آخر تحديث: 16 أكتوبر 2026', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 22),
            ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.$1, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Text(section.$2, style: const TextStyle(height: 1.65)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  static const _privacySections = <(String, String)>[
    ('ما الذي نجمعه؟', 'نجمع رقم الهاتف أو البريد المستخدم لتسجيل الدخول، بيانات الملف الشخصي التي تدخلها، الصور التي ترفعها، بيانات موقعك عند طلب استخدام الخريطة، وبيانات البلاغات وتقارير الأعطال. مزودو الخدمة قد يرسلون صور بطاقات الهوية وبيانات التحقق اللازمة للمراجعة.'),
    ('كيف نستخدم البيانات؟', 'نستخدم البيانات لتسجيل الدخول، تشغيل الحجوزات والعروض، عرض النتائج القريبة، حماية المجتمع من إساءة الاستخدام، مراجعة حسابات مزودي الخدمة، وإرسال الإشعارات التي تختار تفعيلها.'),
    ('المشاركة والحماية', 'لا نبيع بياناتك. نشارك الحد الأدنى اللازم لتشغيل الخدمة مع مزودي الاستضافة والإشعارات، ونحمي البيانات الحساسة بسياسات وصول وRLS. صور بطاقات الهوية في bucket خاص ولا تظهر في صفحات العرض العامة.'),
    ('الاحتفاظ والحذف', 'يمكنك حذف حسابك من داخل التطبيق. يؤدي الطلب إلى حذف حساب المصادقة والبيانات المرتبطة به وفق القيود القانونية وسجلات السلامة اللازمة. لطلب الحذف من الويب استخدم رابط طلب حذف الحساب في صفحة الدعم.'),
    ('التواصل', 'للاستفسارات أو طلبات الخصوصية: support@khedma.app. يمكنك أيضًا التواصل معنا عبر واتساب من صفحة الدعم داخل التطبيق.'),
  ];

  static const _termsSections = <(String, String)>[
    ('الاستخدام المقبول', 'استخدم Khedma للتواصل وتبادل الخدمات والعروض الحقيقية. لا تنشر محتوى مضللًا أو مسيئًا أو مخالفًا للقانون، ولا تنتحل شخصية شخص آخر.'),
    ('المحتوى الذي ينشئه المستخدمون', 'أنت مسؤول عن المحتوى الذي تنشره. يمكنك الإبلاغ عن المحتوى أو حظر المستخدمين، ويجوز لنا إخفاء المحتوى المخالف أو تقييد الحساب بعد المراجعة.'),
    ('العروض والحجوزات', 'العروض تخضع للتوفر والوقت والشروط الموضحة في التطبيق. لا تضمن Khedma جودة أو تنفيذ معاملة خارج ما هو موضح داخل المنصة.'),
    ('الحساب والأمان', 'حافظ على سرية كود التحقق ولا تشاركه. يجوز تعليق الحساب عند وجود إساءة استخدام أو نشاط احتيالي أو مخالفة لهذه الشروط.'),
    ('الدعم والتغييرات', 'للدعم استخدم صفحة التواصل داخل التطبيق. قد نحدّث هذه الشروط عند إضافة وظائف جديدة، وسنعرض تاريخ آخر تحديث بوضوح.'),
  ];
}
