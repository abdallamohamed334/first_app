import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/routes/app_router.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد حذف الحساب'),
        content: const Text('سيتم حذف حسابك وبيانات ملفك والعروض المرتبطة به. لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final response = await SupabaseService().client.functions.invoke('delete-account');
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        throw Exception(data is Map ? data['error'] ?? 'تعذر حذف الحساب' : 'تعذر حذف الحساب');
      }
      await SupabaseService().signOut();
      if (mounted) context.go(AppRouter.userTypeSelection);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حذف الحساب الآن. حاول مرة أخرى أو تواصل مع الدعم.')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('حذف الحساب'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.delete_forever_rounded, size: 72, color: Colors.red),
              const SizedBox(height: 18),
              Text('طلب حذف حساب Khedma', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              const Text('يمكنك حذف حسابك وبياناتك من هنا. سيتم تسجيل خروجك بعد اكتمال الطلب، ولا يمكن استعادة البيانات المحذوفة.', textAlign: TextAlign.center, style: TextStyle(height: 1.6)),
              const SizedBox(height: 26),
              FilledButton.icon(onPressed: _busy ? null : _delete, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_forever_rounded), label: Text(_busy ? 'جارٍ حذف الحساب...' : 'حذف حسابي نهائيًا')),
              const SizedBox(height: 14),
              const Text('تحتفظ Khedma فقط بالسجلات التي يلزم الاحتفاظ بها قانونيًا أو لأغراض السلامة، وفق سياسة الخصوصية.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      );
}
