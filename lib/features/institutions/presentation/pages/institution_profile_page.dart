// lib/features/institutions/presentation/pages/institution_profile_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/institutions/data/repositories/institutions_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution.dart';

class InstitutionProfilePage extends StatefulWidget {
  final Institution institution;

  const InstitutionProfilePage({
    super.key,
    required this.institution,
  });

  @override
  State<InstitutionProfilePage> createState() => _InstitutionProfilePageState();
}

class _InstitutionProfilePageState extends State<InstitutionProfilePage> {
  final _repository = InstitutionsRepository();
  bool _isLoading = false;
  int _offersCount = 0;
  int _followersCount = 0;
  double _rating = 0.0;

  // ─── ألوان هوية وِصلة ───
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _primaryDark = Color(0xFF054D34);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF7B5EC7);
  static const Color _red = Color(0xFFDC4C4C);
  static const Color _whatsapp = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final institutionId = widget.institution.id;

      final offersResponse = await SupabaseService()
          .client
          .from('food_offers')
          .select('id')
          .eq('business_id', institutionId)
          .eq('status', 'available');
      _offersCount = offersResponse.length;

      try {
        final followersResponse = await SupabaseService()
            .client
            .from('institution_followers')
            .select('id')
            .eq('institution_id', institutionId);
        _followersCount = followersResponse.length;
      } catch (_) {
        _followersCount = 0;
      }

      try {
        final ratingsResponse = await SupabaseService()
            .client
            .from('institution_ratings')
            .select('rating')
            .eq('institution_id', institutionId);

        if (ratingsResponse.isNotEmpty) {
          double total = 0;
          for (var item in ratingsResponse) {
            total += (item['rating'] as num?)?.toDouble() ?? 0;
          }
          _rating = total / ratingsResponse.length;
        } else {
          _rating = 0;
        }
      } catch (_) {
        _rating = 0;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // WhatsApp Support
  // ═══════════════════════════════════════════════════════════
  Future<void> _openWhatsAppSupport() async {
    const phoneNumber = '201040652783';
    const url = 'https://wa.me/$phoneNumber';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        const fallbackUrl = 'https://api.whatsapp.com/send?phone=$phoneNumber';
        if (await canLaunchUrl(Uri.parse(fallbackUrl))) {
          await launchUrl(Uri.parse(fallbackUrl),
              mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('تعذر فتح واتساب، يرجى الاتصال على 01040652783',
              error: true);
        }
      }
    } catch (e) {
      _showSnackBar('تعذر فتح واتساب، يرجى الاتصال على 01040652783',
          error: true);
    }
  }

  void _showSnackBar(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: error ? _red : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════════
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: _inkSoft),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      _showSnackBar('تعذر تسجيل الخروج. حاول مرة أخرى', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final institution = widget.institution;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════════
            // Sliver App Bar
            // ═══════════════════════════════════════════════
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'المزيد',
                  onSelected: (value) {
                    if (value == 'logout') _logout();
                  },
                  icon: const Icon(Icons.more_vert_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: _red, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: _red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildHeroHeader(institution),
              ),
            ),

            // ═══════════════════════════════════════════════
            // Content
            // ═══════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, -8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: CircularProgressIndicator(color: _primary),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Handle
                            Center(
                              child: Container(
                                width: 44,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 22),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),

                            // ── Stats Grid
                            _buildStatsGrid(),

                            const SizedBox(height: 20),

                            // ── Info Card
                            _buildInfoCard(institution),

                            const SizedBox(height: 16),

                            // ── Status Card
                            _buildStatusCard(institution),

                            const SizedBox(height: 16),

                            // ── Actions Card
                            _buildActionsCard(),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader(Institution institution) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primary, _primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // ── Decorative circles
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          // ── Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: institution.logoUrl != null &&
                              institution.logoUrl!.isNotEmpty
                          ? Image.network(
                              institution.logoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: const Color(0xFFE8F5EE),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: _primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  _buildLogoPlaceholder(),
                            )
                          : _buildLogoPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Name
                  Text(
                    institution.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Type Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getTypeLabel(institution.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.business_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS GRID
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.star_rounded,
            label: 'التقييم',
            value: _rating > 0 ? _rating.toStringAsFixed(1) : '—',
            color: _gold,
            sublabel: _rating > 0 ? 'من 5' : 'لا يوجد',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_rounded,
            label: 'المتابعون',
            value: '$_followersCount',
            color: _blue,
            sublabel: 'متابع',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_offer_rounded,
            label: 'العروض',
            value: '$_offersCount',
            color: _primary,
            sublabel: 'عرض',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              color: _inkSoft.withValues(alpha: 0.7),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INFO CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard(Institution institution) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryLight],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'معلومات المؤسسة',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Info rows
          _infoRow(
            icon: Icons.phone_rounded,
            label: 'الهاتف',
            value: institution.phone ?? 'غير محدد',
            color: _primary,
          ),
          _infoRow(
            icon: Icons.location_city_rounded,
            label: 'المدينة',
            value: institution.city ?? 'غير محدد',
            color: _blue,
          ),
          _infoRow(
            icon: Icons.location_on_rounded,
            label: 'العنوان',
            value: institution.address ?? 'غير محدد',
            color: _purple,
          ),
          _infoRow(
            icon: Icons.description_rounded,
            label: 'نبذة',
            value: institution.description ?? 'لا يوجد وصف',
            color: _orange,
          ),
          _infoRow(
            icon: Icons.email_rounded,
            label: 'الإيميل',
            value: institution.email ?? 'غير محدد',
            color: _primary,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _inkSoft.withValues(alpha: 0.7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusCard(Institution institution) {
    final isVerified = institution.isVerified ?? false;
    final isActive = institution.isActive ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _blue,
                      _blue.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'حالة المؤسسة',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Status chips
          Row(
            children: [
              Expanded(
                child: _buildStatusChip(
                  icon:
                      isVerified ? Icons.verified_rounded : Icons.info_rounded,
                  label: isVerified ? 'موثقة' : 'غير موثقة',
                  color: isVerified ? _primary : _inkSoft,
                  active: isVerified,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatusChip(
                  icon: isActive
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  label: isActive ? 'نشطة' : 'غير نشطة',
                  color: isActive ? _blue : _red,
                  active: isActive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBF0), Color(0xFFFFF7E0)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _orange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: _orange,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'البيانات معروضة للقراءة فقط. للطلب تغيير أي بيانات يرجى التواصل مع الدعم الفني.',
                    style: TextStyle(
                      color: Color(0xFF704C00),
                      fontSize: 11.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _purple,
                      _purple.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'إجراءات سريعة',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── QR + Share
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'رمز QR',
                  color: _blue,
                  onTap: () {
                    _showSnackBar('جاري تجهيز رمز QR للمؤسسة');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  color: _orange,
                  onTap: () {
                    _showSnackBar('جاري تجهيز رابط المشاركة');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── WhatsApp Support
          _actionButton(
            icon: Icons.support_agent_rounded,
            label: 'تواصل مع الدعم الفني',
            color: _whatsapp,
            onTap: _openWhatsAppSupport,
            fullWidth: true,
            elevated: true,
          ),

          const SizedBox(height: 12),

          // ── Support number
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone_rounded,
                    size: 12,
                    color: _inkSoft.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'رقم الدعم: 01040652783',
                    style: TextStyle(
                      color: _inkSoft.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
    bool elevated = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: elevated ? 16 : 14,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            gradient: elevated
                ? LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.08),
                      color.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  elevated ? Colors.transparent : color.withValues(alpha: 0.2),
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: elevated ? Colors.white : color,
                size: elevated ? 22 : 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: elevated ? Colors.white : color,
                    fontSize: elevated ? 14.5 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  String _getTypeLabel(String type) {
    const types = <String, String>{
      'bakery': 'مخبز وحلويات',
      'grocery': 'بقالة',
      'game_store': 'محل ألعاب',
      'supermarket': 'سوبر ماركت',
      'cafe': 'كافيه',
      'hotel': 'فندق',
      'home_restaurant': 'مطاعم منزلية',
      'household_goods': 'أغراض منزلية',
      'other': 'مؤسسة أخرى',
    };
    return types[type] ?? type;
  }
}
