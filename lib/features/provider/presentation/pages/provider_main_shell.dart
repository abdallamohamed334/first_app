// lib/features/provider/presentation/pages/provider_main_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/routes/app_router.dart';

import 'provider_dashboard_page.dart';
import 'provider_reviews_page.dart';
import 'provider_profile_page.dart';

class ProviderMainShell extends StatefulWidget {
  const ProviderMainShell({super.key});

  @override
  State<ProviderMainShell> createState() => _ProviderMainShellState();
}

class _ProviderMainShellState extends State<ProviderMainShell> {
  static const _bg = Color(0xFFF4F8F6);
  static const _blue = Color(0xFF3679C8);
  static const _inkSoft = Color(0xFF315A45);

  final _repo = ServiceProviderRepository();

  int _currentIndex = 0;
  bool _checking = true;

  late final List<Widget> _pages = const <Widget>[
    ProviderDashboardPage(),
    ProviderReviewsPage(),
    ProviderProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  /// ✅ نتأكد إن الحساب مسموح له يدخل
  Future<void> _checkAccess() async {
    final result = await _repo.getCurrentProvider();
    if (!mounted) return;

    result.fold(
      (err) {
        // لو فيه مشكلة، نسيبه يكمل عادي (canPop/refresh هيتعامل)
        if (mounted) setState(() => _checking = false);
      },
      (provider) {
        final status = provider['verification_status']?.toString() ?? 'pending';
        final isActive = provider['is_active'] as bool? ?? true;

        final isBlocked = !isActive ||
            status == 'suspended' ||
            status == 'rejected' ||
            status == 'pending';

        if (isBlocked) {
          // ✅ نحدّث الـ notifier
          AuthStateNotifier.instance.setLoggedIn(
            isLoggedIn: true,
            role: 'provider',
            providerStatus: status,
            isActive: isActive,
          );

          // ✅ نحوّله لصفحة Pending
          context.go(AppRouter.providerPending, extra: provider);
          return;
        }

        // ✅ الحساب تمام
        if (mounted) setState(() => _checking = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ لما نتأكد الأول
    if (_checking) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _bg,
          body: Center(
            child: CircularProgressIndicator(color: _blue),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  _navItem(0, Icons.home_rounded, 'الرئيسية'),
                  _navItem(1, Icons.star_rounded, 'التقييمات'),
                  _navItem(2, Icons.person_rounded, 'حسابي'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? _blue.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: selected ? _blue : _inkSoft.withValues(alpha: 0.6),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? _blue : _inkSoft.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
