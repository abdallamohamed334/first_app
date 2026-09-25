// lib/features/auth/presentation/pages/user_type_selection_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/routes/app_router.dart';

class UserTypeSelectionPage extends StatelessWidget {
  const UserTypeSelectionPage({super.key});

  // ── ألوان جُود
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _primaryLight = Color(0xFF25B77C);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bg, _bgDark],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 30),

                    // ── Logo
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.18),
                              blurRadius: 26,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/loqma_launcher_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primary, _primaryLight],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.volunteer_activism_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Title
                    const Text(
                      'أهلًا بيك في جُود 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اختار نوع حسابك عشان نجهزلك التجربة الصح',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.75),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ═══════════════════════════════════════════
                    // 👤 مستخدم عادي → LOGIN
                    // ═══════════════════════════════════════════
                    _TypeCard(
                      icon: Icons.person_rounded,
                      title: 'مستخدم عادي',
                      subtitle: 'اكتشف عروض قريبة منك، واطلب خدمات',
                      color: _primary,
                      onTap: () => context.push(AppRouter.login),
                    ),
                    const SizedBox(height: 14),

                    // ═══════════════════════════════════════════
                    // 🔧 مقدم خدمة → ProviderAuthPage ✅ جديد
                    // ═══════════════════════════════════════════
                    _TypeCard(
                      icon: Icons.handyman_rounded,
                      title: 'مقدم خدمة',
                      subtitle: 'سباك، كهربائي، نجار، أو أي حرفة تانية',
                      color: const Color(0xFF3679C8),
                      onTap: () => context.push(AppRouter.providerAuth),
                    ),
                    const SizedBox(height: 14),

                    // ═══════════════════════════════════════════
                    // 🏢 مؤسسة / جمعية → LOGIN PAGE
                    // ═══════════════════════════════════════════
                    _TypeCard(
                      icon: Icons.business_rounded,
                      title: 'مؤسسة / جمعية',
                      subtitle: 'مطعم، جمعية، أو مؤسسة شريكة مع جُود',
                      color: const Color(0xFFE28B00),
                      onTap: () => context.push(AppRouter.institutionLogin),
                    ),
                    const SizedBox(height: 36),

                    // ── Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'عندك حساب بالفعل؟',
                          style: TextStyle(
                            color: _inkSoft.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRouter.login),
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TYPE CARD
// ============================================================
class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: _inkSoft.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: color.withValues(alpha: 0.6),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
