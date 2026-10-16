import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/routes/app_router.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح وسيلة التواصل')));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('الدعم والتواصل'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(Icons.support_agent_rounded, size: 68),
              const SizedBox(height: 12),
              const Text('نحن هنا لمساعدتك', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('لو واجهت مشكلة في الدخول أو الحجز أو أي محتوى مخالف، تواصل معنا مباشرة.', textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: () => _open(context, Uri(scheme: 'mailto', path: 'support@khedma.app', queryParameters: {'subject': 'دعم Khedma'})), icon: const Icon(Icons.email_outlined), label: const Text('راسل الدعم عبر البريد')),
              const SizedBox(height: 24),
              ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('سياسة الخصوصية'), trailing: const Icon(Icons.chevron_left), onTap: () => context.push(AppRouter.privacy)),
              ListTile(leading: const Icon(Icons.description_outlined), title: const Text('شروط الاستخدام'), trailing: const Icon(Icons.chevron_left), onTap: () => context.push(AppRouter.terms)),
              ListTile(leading: const Icon(Icons.delete_forever_outlined, color: Colors.red), title: const Text('طلب حذف الحساب'), trailing: const Icon(Icons.chevron_left), onTap: () => context.push(AppRouter.accountDeletion)),
            ],
          ),
        ),
      );
}
