import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/services/auth_state_notifier.dart';
import 'package:wasla/routes/app_router.dart';

class AccountRestrictedPage extends StatefulWidget {
  const AccountRestrictedPage({super.key});

  @override
  State<AccountRestrictedPage> createState() => _AccountRestrictedPageState();
}

class _AccountRestrictedPageState extends State<AccountRestrictedPage> {
  bool _signingOut = false;

  String get _title {
    switch (AuthStateNotifier.instance.accountStatus) {
      case 'under_review':
        return 'حسابك قيد المراجعة';
      case 'closed':
        return 'الحساب مغلق';
      default:
        return 'الحساب موقوف مؤقتًا';
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } finally {
      if (mounted) context.go(AppRouter.userTypeSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = AuthStateNotifier.instance.suspensionUntil;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gpp_bad_rounded,
                            size: 72, color: Colors.orange),
                        const SizedBox(height: 18),
                        Text(_title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 14),
                        const Text(
                          'لا يمكن استخدام الحساب أو نشر محتوى جديد حاليًا. بياناتك محفوظة ويمكنك التواصل مع الدعم لمراجعة الحالة.',
                          textAlign: TextAlign.center,
                        ),
                        if (until != null) ...[
                          const SizedBox(height: 12),
                          Text('حتى: ${until.toLocal()}'),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _signingOut ? null : _signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(_signingOut
                              ? 'جارٍ تسجيل الخروج...'
                              : 'تسجيل الخروج'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                            onPressed: () {},
                            child: const Text('التواصل مع الدعم')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
