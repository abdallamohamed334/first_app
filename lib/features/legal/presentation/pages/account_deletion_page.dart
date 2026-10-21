import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/routes/app_router.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _codeController = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  String _phoneHint = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    if (!_codeSent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد طلب حذف الحساب'),
          content: const Text(
            'سنرسل كود تحقق إلى رقم الهاتف المرتبط بحسابك. '
            'لن يُحذف الحساب إلا بعد إدخال الكود الصحيح. '
            'الحذف نهائي ولا يمكن التراجع عنه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال كود التحقق'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final response = await SupabaseService().client.functions.invoke(
        'delete-account',
        body: {'action': 'request_code'},
      );
      final data = _asMap(response.data);
      if (data?['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'تعذر إرسال كود التحقق');
      }
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _phoneHint = data?['phone_hint']?.toString() ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _phoneHint.isEmpty
                ? 'تم إرسال كود التحقق إلى رقم حسابك على واتساب'
                : 'تم إرسال كود التحقق إلى رقم ينتهي بـ $_phoneHint',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_messageFromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyAndDelete() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('اكتب كود التحقق المكوّن من 6 أرقام');
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await SupabaseService().client.functions.invoke(
        'delete-account',
        body: {'action': 'confirm', 'code': code},
      );
      final data = _asMap(response.data);
      if (data?['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'تعذر حذف الحساب');
      }

      await SupabaseService()
          .client
          .auth
          .signOut(scope: SignOutScope.local);
      if (mounted) context.go(AppRouter.userTypeSelection);
    } catch (error) {
      if (mounted) _showMessage(_messageFromError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _messageFromError(Object error) {
    final text = error.toString();
    final match = RegExp(r'Exception: (.*)').firstMatch(text);
    return match?.group(1) ?? 'تعذر إكمال العملية الآن. حاول مرة أخرى.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              Text(
                'طلب حذف حساب Khedma',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              const Text(
                'للتأكد من ملكية الحساب، سنرسل كود تحقق إلى رقم الهاتف المسجل. '
                'بعد إدخال الكود الصحيح فقط سيتم حذف الحساب وبياناته المرتبطة.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 26),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'كود التحقق',
                    hintText: '••••••',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'الكود صالح لمدة 5 دقائق${_phoneHint.isEmpty ? '' : ' • الرقم $_phoneHint'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : _codeSent
                        ? _verifyAndDelete
                        : _requestCode,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _codeSent
                            ? Icons.delete_forever_rounded
                            : Icons.sms_outlined,
                      ),
                label: Text(
                  _busy
                      ? (_codeSent ? 'جارٍ التحقق والحذف...' : 'جارٍ إرسال الكود...')
                      : (_codeSent ? 'تحقق واحذف الحساب نهائيًا' : 'إرسال كود التحقق'),
                ),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _requestCode,
                  child: const Text('إعادة إرسال الكود'),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'تحتفظ Khedma فقط بالسجلات التي يلزم الاحتفاظ بها قانونيًا أو لأغراض السلامة، وفق سياسة الخصوصية.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      );
}
