// lib/features/services/presentation/pages/service_provider_details_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/services/data/repositories/service_providers_repository.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/domain/entities/service_review.dart';
import 'package:loqma/features/services/presentation/widgets/rating_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceProviderDetailsPage extends StatefulWidget {
  final ServiceProvider provider;

  const ServiceProviderDetailsPage({
    super.key,
    required this.provider,
  });

  @override
  State<ServiceProviderDetailsPage> createState() =>
      _ServiceProviderDetailsPageState();
}

class _ServiceProviderDetailsPageState
    extends State<ServiceProviderDetailsPage> {
  final _repository = ServiceProvidersRepository();

  List<ServiceReview> _reviews = [];
  bool _loadingReviews = true;

  // ✅ تقييم المستخدم الحالي
  ServiceReview? _myReview;
  bool _checkingMyReview = true;

  // ── ألوان
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF1C1C1E);
  static const _cardSoft = Color(0xFF2C2C2E);
  static const _primaryRed = Color(0xFFE31C25);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFFAAAAAA);
  static const _border = Color(0x14FFFFFF);
  static const _orange = Color(0xFFE28B00);
  static const _green = Color(0xFF2E9B5C);
  static const _blue = Color(0xFF3679C8);
  static const _gold = Color(0xFFFFD700);
  static const _purple = Color(0xFF6651B5);

  // ── أبعاد الهيدر
  static const double _coverHeight = 190;
  static const double _avatarSize = 108;
  static const double _headerOverlapReserve = 64;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkMyReview();
  }

  // ═══════════════════════════════════════════════════════════
  // Reviews
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadReviews() async {
    if (mounted) setState(() => _loadingReviews = true);
    try {
      final list = await _repository.listReviews(
        providerId: widget.provider.id,
      );
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _loadingReviews = false;
      });
      await _checkMyReview();
    } catch (e) {
      debugPrint('❌ loadReviews error: $e');
      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فحص تقييم المستخدم الحالي
  // ═══════════════════════════════════════════════════════════
  Future<void> _checkMyReview() async {
    final user = SupabaseService().client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checkingMyReview = false);
      return;
    }

    try {
      final review = await _repository.getUserReviewForProvider(
        providerId: widget.provider.id,
        userId: user.id,
      );
      if (!mounted) return;
      setState(() {
        _myReview = review;
        _checkingMyReview = false;
      });
    } catch (e) {
      debugPrint('❌ _checkMyReview error: $e');
      if (!mounted) return;
      setState(() => _checkingMyReview = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فتح شيت التقييم
  // ═══════════════════════════════════════════════════════════
  Future<void> _openRatingSheet() async {
    final user = SupabaseService().client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'سجّل دخولك الأول',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _card,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingSheet(
        providerId: widget.provider.id,
        providerName: widget.provider.displayName,
        userId: user.id,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم إرسال تقييمك، شكرًا لك',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );
      await _loadReviews();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = widget.provider;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(
            primary: _primaryRed,
            surface: _bg,
            onSurface: _textPrimary,
          ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          body: RefreshIndicator(
            color: _primaryRed,
            backgroundColor: _card,
            onRefresh: _loadReviews,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(p),
                SizedBox(height: _headerOverlapReserve),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildIdentityBlock(p),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsBar(p),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickInfoPills(p),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── نبذة
                      if (p.bio != null && p.bio!.isNotEmpty) ...[
                        _buildSection(
                          title: 'نبذة',
                          icon: Icons.info_outline_rounded,
                          child: _buildBio(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── بيانات الشركة
                      if (p.isCompany) ...[
                        _buildSection(
                          title: 'بيانات الشركة',
                          icon: Icons.business_center_rounded,
                          child: _buildCompanyInfo(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── المهارات
                      if (p.skills.isNotEmpty) ...[
                        _buildSection(
                          title: 'المهارات',
                          icon: Icons.psychology_rounded,
                          child: _buildSkills(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── مناطق الخدمة
                      if (p.serviceAreas.isNotEmpty) ...[
                        _buildSection(
                          title: 'مناطق الخدمة',
                          icon: Icons.map_rounded,
                          trailing: 'حتى ${p.maxDistanceKm} كم',
                          child: _buildServiceAreas(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── صور من الشغل
                      if (p.portfolioImages.isNotEmpty) ...[
                        _buildSection(
                          title: 'صور من الشغل',
                          icon: Icons.photo_library_rounded,
                          trailing: '${p.portfolioImages.length} صورة',
                          child: _buildPortfolio(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── الفروع
                      if (p.isCompany && p.branches.isNotEmpty) ...[
                        _buildSection(
                          title: 'الفروع',
                          icon: Icons.location_city_rounded,
                          trailing: '${p.branches.length} فرع',
                          child: _buildBranches(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── التواصل
                      if (_hasContactInfo(p)) ...[
                        _buildSection(
                          title: 'التواصل',
                          icon: Icons.contact_phone_rounded,
                          child: _buildContactInfo(p),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── الإحصائيات
                      _buildSection(
                        title: 'الإحصائيات',
                        icon: Icons.insights_rounded,
                        child: _buildDetailedStats(p),
                      ),
                      const SizedBox(height: 18),

                      // ── التقييمات
                      _buildSection(
                        title: 'التقييمات',
                        icon: Icons.star_rounded,
                        trailing: _reviews.isNotEmpty
                            ? '${_reviews.length} تقييم'
                            : null,
                        child: _buildReviews(),
                      ),
                      const SizedBox(height: 14),

                      // ✅ زر التقييم / عرض تقييمي
                      _buildRatingButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(p),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(ServiceProvider p) {
    return SizedBox(
      height: _coverHeight + (_avatarSize / 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _coverHeight,
            child: _buildCover(p),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: _circleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: _buildTypeBadgeOnCover(p),
          ),
          Positioned(
            top: _coverHeight - (_avatarSize / 2),
            left: 0,
            right: 0,
            child: Center(child: _buildAvatar(p)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadgeOnCover(ServiceProvider p) {
    final isCompany = p.isCompany;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: (isCompany ? _blue : _primaryRed).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompany ? Icons.business_rounded : Icons.person_rounded,
            size: 12,
            color: isCompany ? _blue : _primaryRed,
          ),
          const SizedBox(width: 5),
          Text(
            isCompany ? 'شركة' : 'فرد',
            style: TextStyle(
              color: isCompany ? _blue : _primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(ServiceProvider p) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: p.coverImageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _coverFallback(),
            )
          else
            _coverFallback(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  _bg.withValues(alpha: 0.9),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue, _purple],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
    );
  }

  Widget _buildAvatar(ServiceProvider p) {
    final isVerified = p.isVerified;

    return SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                if (isVerified)
                  BoxShadow(
                    color: _green.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isVerified
                      ? _green
                      : _textSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child:
                    p.profileImageUrl != null && p.profileImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: p.profileImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _initialAvatar(p.displayName),
                          )
                        : _initialAvatar(p.displayName),
              ),
            ),
          ),
          if (isVerified)
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 3),
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
    );
  }

  Widget _initialAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return Container(
      color: _blue.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Identity Block
  // ═══════════════════════════════════════════════════════════
  Widget _buildIdentityBlock(ServiceProvider p) {
    return Column(
      children: [
        Text(
          p.displayName,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            if (p.categoryName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _cardSoft,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.categoryIcon != null) ...[
                      Icon(
                        _iconFromName(p.categoryIcon!),
                        size: 11,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      p.categoryName!,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (p.foundedYear != null && p.isCompany)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history_rounded, size: 11, color: _purple),
                    const SizedBox(width: 4),
                    Text(
                      'منذ ${p.foundedYear}',
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Stats Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsBar(ServiceProvider p) {
    final isCompany = p.isCompany;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: Icons.star_rounded,
              iconColor: _gold,
              value: p.ratingAvg.toStringAsFixed(1),
              label: '${p.totalReviews} تقييم',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.check_circle_rounded,
              iconColor: _green,
              value: '${p.completedJobs}',
              label: 'شغل مكتمل',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.favorite_rounded,
              iconColor: _primaryRed,
              value: '${p.volunteerJobs}',
              label: 'تطوعي',
            ),
          ),
          _divider(),
          Expanded(
            child: isCompany && p.employeesCount != null
                ? _statItem(
                    icon: Icons.groups_rounded,
                    iconColor: _orange,
                    value: '${p.employeesCount}',
                    label: 'موظف',
                  )
                : _statItem(
                    icon: Icons.workspace_premium_rounded,
                    iconColor: _orange,
                    value: p.experienceYears != null && p.experienceYears! > 0
                        ? '${p.experienceYears}'
                        : '—',
                    label: 'سنة خبرة',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 34,
      color: _border,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Quick Info Pills
  // ═══════════════════════════════════════════════════════════
  Widget _buildQuickInfoPills(ServiceProvider p) {
    final isFree = p.isFree;
    final isSymbolic = p.isSymbolic;
    final priceColor = isFree
        ? _green
        : isSymbolic
            ? _orange
            : _primaryRed;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _infoPill(
          icon: isFree
              ? Icons.favorite_rounded
              : isSymbolic
                  ? Icons.volunteer_activism_rounded
                  : Icons.payments_rounded,
          label: p.pricingLabel,
          color: priceColor,
          highlight: true,
        ),
        if (p.city != null && p.city!.isNotEmpty)
          _infoPill(
            icon: Icons.location_on_rounded,
            label: p.city!,
            color: _blue,
          ),
        _infoPill(
          icon: p.isAvailable
              ? Icons.check_circle_rounded
              : Icons.access_time_rounded,
          label: p.isAvailable ? 'متاح الآن' : 'مشغول حاليًا',
          color: p.isAvailable ? _green : _orange,
        ),
        if (p.maxDistanceKm > 0)
          _infoPill(
            icon: Icons.explore_rounded,
            label: 'حتى ${p.maxDistanceKm} كم',
            color: _purple,
          ),
        if (p.isCompany && p.acceptsInstallments)
          _infoPill(
            icon: Icons.credit_card_rounded,
            label: 'يقبل التقسيط',
            color: _green,
          ),
      ],
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String label,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.15)
            : _cardSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: highlight ? color.withValues(alpha: 0.35) : _border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: highlight ? color : _textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Section Wrapper
  // ═══════════════════════════════════════════════════════════
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    String? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primaryRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primaryRed, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Bio
  // ═══════════════════════════════════════════════════════════
  Widget _buildBio(ServiceProvider p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Text(
        p.bio!,
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 13,
          height: 1.6,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Company Info
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompanyInfo(ServiceProvider p) {
    final items = <Widget>[];

    if (p.companyLegalName != null && p.companyLegalName!.isNotEmpty) {
      items.add(_companyRow(
        icon: Icons.business_rounded,
        label: 'الاسم القانوني',
        value: p.companyLegalName!,
        color: _blue,
      ));
    }
    if (p.foundedYear != null) {
      items.add(_companyRow(
        icon: Icons.calendar_today_rounded,
        label: 'سنة التأسيس',
        value: '${p.foundedYear}',
        color: _purple,
      ));
    }
    if (p.employeesCount != null && p.employeesCount! > 0) {
      items.add(_companyRow(
        icon: Icons.groups_rounded,
        label: 'عدد الموظفين',
        value: '${p.employeesCount} موظف',
        color: _orange,
      ));
    }
    if (p.branches.isNotEmpty) {
      items.add(_companyRow(
        icon: Icons.location_city_rounded,
        label: 'عدد الفروع',
        value: '${p.branches.length} فرع',
        color: _green,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: _border),
              const SizedBox(height: 10),
            ],
            items[i],
          ],
        ],
      ),
    );
  }

  Widget _companyRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.left,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Skills
  // ═══════════════════════════════════════════════════════════
  Widget _buildSkills(ServiceProvider p) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: p.skills.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: _green, size: 13),
              const SizedBox(width: 6),
              Text(
                s,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Service Areas
  // ═══════════════════════════════════════════════════════════
  Widget _buildServiceAreas(ServiceProvider p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.address != null && p.address!.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home_rounded,
                      color: _primaryRed, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العنوان الأساسي',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.address!,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: _border),
            const SizedBox(height: 12),
          ],
          const Text(
            'بنخدم في:',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.serviceAreas.map((area) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _blue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: _blue, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      area,
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Portfolio
  // ═══════════════════════════════════════════════════════════
  Widget _buildPortfolio(ServiceProvider p) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: p.portfolioImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final url = p.portfolioImages[index];
          return GestureDetector(
            onTap: () => _showImage(context, url),
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: _cardSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: _cardSoft,
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primaryRed,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: _cardSoft,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: _textSecondary.withValues(alpha: 0.5),
                        size: 30,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${index + 1}/${p.portfolioImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Branches
  // ═══════════════════════════════════════════════════════════
  Widget _buildBranches(ServiceProvider p) {
    return Column(
      children: p.branches.asMap().entries.map<Widget>((entry) {
        final branch = entry.value;
        final index = entry.key;
        if (branch is! Map) return const SizedBox.shrink();
        final city = branch['city']?.toString() ?? '';
        final address = branch['address']?.toString() ?? '';
        final phone = branch['phone']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_blue, _purple],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_rounded,
                        color: Colors.white, size: 16),
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (city.isNotEmpty)
                      Text(
                        city,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded,
                              color: _green, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Contact Info
  // ═══════════════════════════════════════════════════════════
  bool _hasContactInfo(ServiceProvider p) {
    return (p.phone != null && p.phone!.isNotEmpty) ||
        (p.whatsapp != null && p.whatsapp!.isNotEmpty) ||
        (p.email != null && p.email!.isNotEmpty) ||
        (p.website != null && p.website!.isNotEmpty);
  }

  Widget _buildContactInfo(ServiceProvider p) {
    final items = <Widget>[];

    if (p.phone != null && p.phone!.isNotEmpty) {
      items.add(_contactRow(
        icon: Icons.phone_rounded,
        label: 'الهاتف',
        value: p.phone!,
        color: _green,
        onTap: () => _makeCall(p.phone!),
      ));
    }
    if (p.whatsapp != null && p.whatsapp!.isNotEmpty) {
      items.add(_contactRow(
        icon: Icons.chat_rounded,
        label: 'واتساب',
        value: p.whatsapp!,
        color: const Color(0xFF25D366),
        onTap: () => _openWhatsapp(p.whatsapp!),
      ));
    }
    if (p.email != null && p.email!.isNotEmpty) {
      items.add(_contactRow(
        icon: Icons.email_rounded,
        label: 'الإيميل',
        value: p.email!,
        color: _blue,
        onTap: () => _openEmail(p.email!),
      ));
    }
    if (p.website != null && p.website!.isNotEmpty) {
      items.add(_contactRow(
        icon: Icons.language_rounded,
        label: 'الموقع',
        value: p.website!,
        color: _purple,
        onTap: () => _openWebsite(p.website!),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: _border),
              const SizedBox(height: 10),
            ],
            items[i],
          ],
        ],
      ),
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: _textSecondary.withValues(alpha: 0.5),
            size: 12,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Detailed Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildDetailedStats(ServiceProvider p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        children: [
          _detailedStatRow(
            icon: Icons.work_rounded,
            label: 'إجمالي الطلبات',
            value: '${p.totalJobs}',
            color: _blue,
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          _detailedStatRow(
            icon: Icons.check_circle_rounded,
            label: 'شغل مكتمل',
            value: '${p.completedJobs}',
            color: _green,
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          _detailedStatRow(
            icon: Icons.favorite_rounded,
            label: 'شغل تطوعي',
            value: '${p.volunteerJobs}',
            color: _primaryRed,
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          _detailedStatRow(
            icon: Icons.cancel_rounded,
            label: 'طلبات ملغية',
            value: '${p.totalJobs - p.completedJobs}',
            color: _orange,
          ),
        ],
      ),
    );
  }

  Widget _detailedStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ زر التقييم
  // ═══════════════════════════════════════════════════════════
  Widget _buildRatingButton() {
    // ⏳ جاري الفحص
    if (_checkingMyReview) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryRed,
            ),
          ),
        ),
      );
    }

    // ✅ المستخدم قيّم بالفعل
    if (_myReview != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _green, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أنت قيّمت الخدمة',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < (_myReview?.rating ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _gold,
                          size: 14,
                        );
                      }),
                      if (_myReview?.comment != null &&
                          _myReview!.comment!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _myReview!.comment!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🎯 زر التقييم
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _openRatingSheet,
        icon: const Icon(Icons.star_rounded, size: 20),
        label: const Text(
          'قيّم الخدمة',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Reviews
  // ═══════════════════════════════════════════════════════════
  Widget _buildReviews() {
    if (_loadingReviews) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _primaryRed,
            ),
          ),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              color: _textSecondary.withValues(alpha: 0.5),
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'لسه مفيش تقييمات',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildRatingSummary(widget.provider),
        const SizedBox(height: 12),
        ..._reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _buildRatingSummary(ServiceProvider p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: _gold.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.ratingAvg.toStringAsFixed(1),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < p.ratingAvg.round()
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _gold,
                      size: 10,
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.totalReviews} تقييم',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'على أساس تجارب حقيقية من المستخدمين',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ServiceReview r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withValues(alpha: 0.15),
                ),
                child: ClipOval(
                  child: r.userAvatar != null && r.userAvatar!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: r.userAvatar!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _reviewInitial(r.displayName),
                        )
                      : _reviewInitial(r.displayName),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (r.isAnonymous) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.visibility_off_rounded,
                            color: _textSecondary.withValues(alpha: 0.7),
                            size: 12,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < r.rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: _gold,
                            size: 12,
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          r.timeAgo,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.comment!,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: r.tags.map((t) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: _green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewInitial(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '?';
    return Container(
      color: _blue.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: _blue,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Bottom Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildBottomBar(ServiceProvider p) {
    final hasPhone = p.phone != null && p.phone!.isNotEmpty;
    final hasWhatsapp = p.whatsapp != null && p.whatsapp!.isNotEmpty;

    if (!hasPhone && !hasWhatsapp) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _card,
        border: const Border(
          top: BorderSide(color: _border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasPhone)
            Expanded(
              child: _bottomButton(
                icon: Icons.phone_rounded,
                label: 'اتصل',
                color: _green,
                onTap: () => _makeCall(p.phone!),
              ),
            ),
          if (hasPhone && hasWhatsapp) const SizedBox(width: 10),
          if (hasWhatsapp)
            Expanded(
              child: _bottomButton(
                icon: Icons.chat_rounded,
                label: 'واتساب',
                color: const Color(0xFF25D366),
                onTap: () => _openWhatsapp(p.whatsapp!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _showImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => Container(
                height: 300,
                color: _card,
                child: const Center(
                  child: CircularProgressIndicator(color: _primaryRed),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('❌ makeCall error: $e');
    }
  }

  Future<void> _openWhatsapp(String phone) async {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('20') && cleaned.length == 10) {
      cleaned = '20$cleaned';
    }
    final uri = Uri.parse('https://wa.me/$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ whatsapp error: $e');
    }
  }

  Future<void> _openEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('❌ email error: $e');
    }
  }

  Future<void> _openWebsite(String url) async {
    var fullUrl = url;
    if (!fullUrl.startsWith('http://') && !fullUrl.startsWith('https://')) {
      fullUrl = 'https://$fullUrl';
    }
    final uri = Uri.parse(fullUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ website error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Icon Mapper
  // ═══════════════════════════════════════════════════════════
  IconData _iconFromName(String name) {
    switch (name) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'tutoring':
        return Icons.menu_book_rounded;
      case 'barber':
        return Icons.content_cut_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'it':
        return Icons.computer_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'garden':
        return Icons.grass_rounded;
      case 'moving':
        return Icons.local_shipping_rounded;
      case 'construction':
        return Icons.construction_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }
}
