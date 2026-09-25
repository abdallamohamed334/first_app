// lib/features/provider/presentation/pages/provider_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/features/provider/presentation/utils/service_category_icons.dart';
import 'package:loqma/routes/app_router.dart';

class ProviderDashboardPage extends StatefulWidget {
  const ProviderDashboardPage({super.key});

  @override
  State<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage> {
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
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final providerResult = await _repo.getCurrentProvider();
    if (!mounted) return;

    await providerResult.fold(
      (err) async {
        setState(() => _loading = false);
        _snack(err, error: true);
      },
      (provider) async {
        setState(() => _provider = provider);

        final statsResult =
            await _repo.getProviderStats(provider['id'].toString());

        if (!mounted) return;

        statsResult.fold(
          (err) => setState(() => _loading = false),
          (stats) => setState(() {
            _stats = stats;
            _loading = false;
          }),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // ✅ Toggle Visibility (مع فحص البروفايل)
  // ══════════════════════════════════════════════════════════
  Future<void> _toggleVisibility(bool value) async {
    if (_provider == null) return;

    // ══════════════════════════════════════════════════════════
    // ✅ لو بيفتح الظهور → افحص البروفايل الأول
    // ══════════════════════════════════════════════════════════
    if (value) {
      final missing = _repo.checkProfileCompletion(_provider!);

      if (missing.isNotEmpty) {
        if (!mounted) return;
        await _showIncompleteProfileDialog(missing);
        return;
      }
    }

    // ══════════════════════════════════════════════════════════
    // ✅ البروفايل كامل → نشغّل/نوقف الظهور
    // ══════════════════════════════════════════════════════════
    setState(() => _toggling = true);

    final result = await _repo.toggleAvailability(
      providerId: _provider!['id'].toString(),
      isAvailable: value,
    );

    if (!mounted) return;

    result.fold(
      (err) {
        setState(() => _toggling = false);
        _snack(err, error: true);
      },
      (isVisible) {
        setState(() {
          _provider = {..._provider!, 'is_available': isVisible};
          _toggling = false;
        });
        _snack(
          isVisible ? 'أنت ظاهر للمستخدمين دلوقتي ✅' : 'مخفي عن المستخدمين 🚫',
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // ✅ Dialog البروفايل الناقص
  // ══════════════════════════════════════════════════════════
  Future<void> _showIncompleteProfileDialog(List<String> missing) async {
    await showDialog<void>(
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
              color: _orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: _orange,
              size: 32,
            ),
          ),
          title: const Text(
            'كمّل بروفايلك الأول',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عشان يظهر بروفايلك للمستخدمين، لازم تكمّل:',
                style: TextStyle(
                  color: _inkSoft.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              ...missing.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: _orange,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'لاحقاً',
                style: TextStyle(
                  color: _inkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push(AppRouter.providerEditProfile).then((_) {
                  if (mounted) _load();
                });
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'كمّل البروفايل',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: error ? _red : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
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
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildVisibilityCard(),
                          const SizedBox(height: 18),
                          _buildStatsGrid(),
                          const SizedBox(height: 18),
                          _buildQuickActions(),
                          const SizedBox(height: 18),
                          _buildRatingCard(),
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
  // Header
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final name = _provider?['display_name']?.toString() ?? 'مزود خدمة';
    final cat = _provider?['categories'];
    final catName = cat is Map ? cat['name_ar']?.toString() ?? '' : '';
    final catIcon = cat is Map ? cat['icon']?.toString() ?? '' : '';
    final iconData = ServiceCategoryIcons.getIcon(catIcon);
    final avatar = _provider?['profile_image_url']?.toString();
    final isVerified =
        _provider?['verification_status']?.toString() == 'approved';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5BA3E8), _blue],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: (avatar != null && avatar.isNotEmpty)
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                if (catName.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          catName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 22,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.3),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Visibility Card (أظهرني للناس)
  // ══════════════════════════════════════════════════════════
  Widget _buildVisibilityCard() {
    final isVisible = _provider?['is_available'] as bool? ?? false;
    final isComplete = _repo.checkProfileCompletion(_provider ?? {}).isEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isVisible ? _primary : _cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (isVisible ? _primary : _inkSoft).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isVisible
                      ? Colors.white.withValues(alpha: 0.2)
                      : _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: isVisible ? Colors.white : _primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVisible ? 'ظاهر للمستخدمين ✅' : 'مخفي عن المستخدمين',
                      style: TextStyle(
                        color: isVisible ? Colors.white : _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isVisible
                          ? 'المستخدمين هيشوفوك ويقدروا يتواصلوا معاك'
                          : isComplete
                              ? 'شغّل الزر عشان يظهر بروفايلك للناس'
                              : 'كمّل بروفايلك الأول عشان تقدر تظهر',
                      style: TextStyle(
                        color: isVisible
                            ? Colors.white.withValues(alpha: 0.85)
                            : _inkSoft.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _toggling
                  ? SizedBox(
                      width: 50,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: isVisible ? Colors.white : _primary,
                          ),
                        ),
                      ),
                    )
                  : Transform.scale(
                      scale: 1.15,
                      child: Switch(
                        value: isVisible,
                        onChanged: _toggleVisibility,
                        activeThumbColor: _primary,
                        activeTrackColor: Colors.white,
                        inactiveThumbColor: _inkSoft.withValues(alpha: 0.5),
                        inactiveTrackColor: Colors.white,
                      ),
                    ),
            ],
          ),

          // ✅ تنبيه: البروفايل ناقص
          if (!isComplete) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _orange,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'في بيانات ناقصة في بروفايلك. كمّلها عشان تقدر تظهر للمستخدمين.',
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.push(AppRouter.providerEditProfile).then((_) {
                        if (mounted) _load();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'كمّل الآن',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
          // ✅ تنبيه: أنت مخفي (لما البروفايل كامل)
          else if (!isVisible) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'أنت مش ظاهر في البحث دلوقتي. المستخدمين مش هيشوفوا بروفايلك.',
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.85),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Stats
  // ══════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    final total = _stats?['total_jobs'] ?? 0;
    final completed = _stats?['completed_jobs'] ?? 0;
    final reviews = _stats?['total_reviews'] ?? 0;
    final rating = (_stats?['rating_avg'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 10),
          child: Text(
            'إحصائياتك',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _statCard(
              icon: Icons.assignment_rounded,
              label: 'إجمالي الخدمات',
              value: '$total',
              color: _blue,
            ),
            _statCard(
              icon: Icons.check_circle_rounded,
              label: 'منجزة',
              value: '$completed',
              color: _primary,
            ),
            _statCard(
              icon: Icons.rate_review_rounded,
              label: 'عدد التقييمات',
              value: '$reviews',
              color: _orange,
            ),
            _statCard(
              icon: Icons.star_rounded,
              label: 'متوسط التقييم',
              value: rating.toStringAsFixed(1),
              color: _orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: _inkSoft.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Quick Actions
  // ══════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 10),
          child: Text(
            'إجراءات سريعة',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.edit_rounded,
                label: 'تعديل بروفايلي',
                color: _blue,
                onTap: () async {
                  await context.push(AppRouter.providerEditProfile);
                  if (mounted) _load();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                icon: Icons.star_rounded,
                label: 'تقييماتي',
                color: _orange,
                onTap: () => context.push(AppRouter.providerReviews),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _actionCard(
                icon: Icons.visibility_rounded,
                label: 'شكل بروفايلي',
                color: _primary,
                onTap: () => context.push(AppRouter.providerPublicProfile),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Rating Card
  // ══════════════════════════════════════════════════════════
  Widget _buildRatingCard() {
    final rating = (_stats?['rating_avg'] as num?)?.toDouble() ?? 0;
    final reviews = (_stats?['total_reviews'] as num?)?.toInt() ?? 0;

    return InkWell(
      onTap: () => context.push(AppRouter.providerReviews),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _orange.withValues(alpha: 0.85),
                    _orange,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.star_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقييمك العام',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ...List.generate(5, (i) {
                        return Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _orange,
                          size: 16,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        '($reviews)',
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Color(0xFF9AA1A8)),
          ],
        ),
      ),
    );
  }
}
