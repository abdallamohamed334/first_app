import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/routes/app_router.dart';

class UserTypeSelectionPage extends StatelessWidget {
  const UserTypeSelectionPage({super.key});

  static const _background = Color(0xFFF7F8FA);
  static const _primary = Color(0xFFFF2E3B);
  static const _ink = Color(0xFF1B1D22);
  static const _muted = Color(0xFF68707C);
  static const _border = Color(0xFFE2E6EC);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: _background,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFFFFAFA), _background],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 30),
                    const Text(
                      'أهلًا بيك في Khedma',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 27,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'اختار حسابك عشان تلاقي الخدمة المناسبة أو تعرض خدمتك.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'هتستخدم التطبيق بصفتك إيه؟',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    _AccountTypeCard(
                      icon: Icons.person_outline_rounded,
                      title: 'مستخدم عادي',
                      description:
                      'ابحث عن مقدمي الخدمات القريبين وانشر احتياجك للخدمة.',
                      onTap: () => context.go(AppRouter.login),
                    ),
                    const SizedBox(height: 11),
                    _AccountTypeCard(
                      icon: Icons.handyman_outlined,
                      title: 'مقدّم خدمة',
                      description:
                      'اعرض خدماتك واستقبل طلبات العملاء من مكان واحد.',
                      onTap: () => context.push(AppRouter.providerAuth),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 19,
                            color: _primary,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'لو عندك حساب بالفعل، اختار نفس نوعه عشان تدخل من الصفحة المناسبة.',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/khedma_icon.png',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Khedma',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _border),
          ),
          child: const Text(
            'اختيار الحساب',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  static const _primary = Color(0xFFFF2E3B);
  static const _ink = Color(0xFF1B1D22);
  static const _muted = Color(0xFF68707C);
  static const _border = Color(0xFFE2E6EC);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEC),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _primary, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_left_rounded,
                color: _muted,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
