// lib/features/provider/presentation/pages/provider_profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/features/provider/presentation/utils/service_category_icons.dart';
import 'package:loqma/routes/app_router.dart';

class ProviderProfilePage extends StatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  // ── ألوان
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _orange = Color(0xFFE28B00);
  static const _red = Color(0xFFD64545);

  final _repo = ServiceProviderRepository();

  Map<String, dynamic>? _provider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _repo.getCurrentProvider();
    if (!mounted) return;

    result.fold(
      (err) => setState(() => _loading = false),
      (provider) => setState(() {
        _provider = provider;
        _loading = false;
      }),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Logout
  // ══════════════════════════════════════════════════════════
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: _red,
              size: 30,
            ),
          ),
          title: const Text(
            'تسجيل الخروج',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          content: Text(
            'متأكد إنك عايز تسجل خروج؟\nهتحتاج تدخل تاني بكود التحقق.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: _inkSoft.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: _inkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'تسجيل خروج',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // ✅ signOut
    await _repo.logout();

    // ✅ نصفّر الـ AuthStateNotifier
    AuthStateNotifier.instance.clear();

    if (!mounted) return;

    context.go(AppRouter.providerAuth);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, _bgDark],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _blue),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _blue,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildMenuSection(),
                          const SizedBox(height: 16),
                          _buildDangerSection(),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Header Card
  // ══════════════════════════════════════════════════════════
  Widget _buildHeaderCard() {
    final name = _provider?['display_name']?.toString() ?? 'مزود خدمة';
    final phone = _provider?['phone']?.toString() ?? '';
    final email = _provider?['email']?.toString() ?? '';
    final avatar = _provider?['profile_image_url']?.toString();
    final isVerified =
        _provider?['verification_status']?.toString() == 'approved';

    final cat = _provider?['categories'];
    final catName = cat is Map ? cat['name_ar']?.toString() ?? '' : '';
    final catIcon = cat is Map ? cat['icon']?.toString() ?? '' : '';
    final iconData = ServiceCategoryIcons.getIcon(catIcon);
    final iconColor = ServiceCategoryIcons.getColor(catIcon);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BA3E8), _blue],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border.all(
                    color: _blue.withValues(alpha: 0.2),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (avatar != null && avatar.isNotEmpty)
                      ? Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          errorBuilder: (_, __, ___) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              if (isVerified)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          // Category chip
          if (catName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: iconColor, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    catName,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Phone + Email
          if (phone.isNotEmpty) ...[
            _contactRow(Icons.phone_rounded, phone),
            const SizedBox(height: 6),
          ],
          if (email.isNotEmpty)
            _contactRow(Icons.alternate_email_rounded, email),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 46,
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _inkSoft.withValues(alpha: 0.6), size: 15),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: _inkSoft.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // Menu Section
  // ══════════════════════════════════════════════════════════
  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _menuItem(
            icon: Icons.edit_rounded,
            title: 'تعديل بروفايلي',
            subtitle: 'عدّل بياناتك وصورك',
            color: _blue,
            onTap: () async {
              await context.push(AppRouter.providerEditProfile);
              // ✅ نحدّث البيانات بعد الرجوع
              if (mounted) _load();
            },
          ),
          _divider(),
          _menuItem(
            icon: Icons.visibility_rounded,
            title: 'شكل بروفايلي',
            subtitle: 'شوف بروفايلك زي ما المستخدم بيشوفه',
            color: _primary,
            onTap: () => context.push(AppRouter.providerPublicProfile),
          ),
          _divider(),
          _menuItem(
            icon: Icons.star_rounded,
            title: 'تقييماتي',
            subtitle: 'شوف آراء العملاء فيك',
            color: _orange,
            onTap: () => context.push(AppRouter.providerReviews),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: _inkSoft.withValues(alpha: 0.06),
      indent: 60,
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _inkSoft.withValues(alpha: 0.6),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: _inkSoft.withValues(alpha: 0.4),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Danger Section (Logout)
  // ══════════════════════════════════════════════════════════
  Widget _buildDangerSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: _red,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: _red.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
