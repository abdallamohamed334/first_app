// lib/features/services/presentation/pages/service_category_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqma/features/services/data/repositories/service_providers_repository.dart';
import 'package:loqma/features/services/domain/entities/service_category.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/presentation/pages/service_provider_details_page.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceCategoryPage extends StatefulWidget {
  final ServiceCategory category;

  const ServiceCategoryPage({
    super.key,
    required this.category,
  });

  @override
  State<ServiceCategoryPage> createState() => _ServiceCategoryPageState();
}

class _ServiceCategoryPageState extends State<ServiceCategoryPage> {
  final _repository = ServiceProvidersRepository();

  // ── Filters
  String? _providerType; // null = all | individual | company
  String? _pricingType; // null = all | free | symbolic | market

  List<ServiceProvider> _providers = [];
  bool _loading = true;
  String? _error;

  // ── ألوان
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF1C1C1E);
  static const _cardSoft = Color(0xFF2C2C2E);
  static const _primaryRed = Color(0xFFE31C25);
  static const _primaryRedDark = Color(0xFF8E0F14);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFFAAAAAA);
  static const _border = Color(0x14FFFFFF);
  static const _orange = Color(0xFFE28B00);
  static const _green = Color(0xFF2E9B5C);
  static const _blue = Color(0xFF3679C8);
  static const _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await _repository.listByCategory(
        categoryId: widget.category.id,
        providerType: _providerType,
        pricingType: _pricingType,
      );
      if (!mounted) return;
      setState(() {
        _providers = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ load providers error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل مقدمي الخدمة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildFilters(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // AppBar
  // ═══════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_blue, Color(0xFF6651B5)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _iconFromName(widget.category.icon ?? ''),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.category.nameAr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _loading ? 'بيتم التحميل...' : '${_providers.length} متاح',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
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
  // Filters
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── نوع مقدم الخدمة ──
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _filterChip(
                  label: 'الكل',
                  icon: Icons.apps_rounded,
                  selected: _providerType == null,
                  onTap: () {
                    setState(() => _providerType = null);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'أفراد',
                  icon: Icons.person_rounded,
                  selected: _providerType == 'individual',
                  onTap: () {
                    setState(() => _providerType = 'individual');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'شركات',
                  icon: Icons.business_rounded,
                  selected: _providerType == 'company',
                  onTap: () {
                    setState(() => _providerType = 'company');
                    _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── نوع التسعير ──
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _filterChip(
                  label: 'كل الأسعار',
                  icon: Icons.tune_rounded,
                  selected: _pricingType == null,
                  onTap: () {
                    setState(() => _pricingType = null);
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'تطوعي',
                  icon: Icons.favorite_rounded,
                  color: _green,
                  selected: _pricingType == 'free',
                  onTap: () {
                    setState(() => _pricingType = 'free');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'رمزي',
                  icon: Icons.volunteer_activism_rounded,
                  color: _orange,
                  selected: _pricingType == 'symbolic',
                  onTap: () {
                    setState(() => _pricingType = 'symbolic');
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'سعر السوق',
                  icon: Icons.payments_rounded,
                  selected: _pricingType == 'market',
                  onTap: () {
                    setState(() => _pricingType = 'market');
                    _load();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color color = _primaryRed,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : _card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? Colors.transparent : _border,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _textPrimary,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Body
  // ═══════════════════════════════════════════════════════════
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryRed),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_providers.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: _primaryRed,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          return _buildProviderCard(_providers[index]);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Provider Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildProviderCard(ServiceProvider p) {
    final isCompany = p.isCompany;
    final isFree = p.isFree;
    final isSymbolic = p.isSymbolic;
    final isVerified = p.isVerified;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServiceProviderDetailsPage(provider: p),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
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
                        child: p.profileImageUrl != null &&
                                p.profileImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: p.profileImageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _initialAvatar(p.displayName),
                              )
                            : _initialAvatar(p.displayName),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Name + Badge ──
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Badge فرد/شركة
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCompany
                                      ? _blue.withValues(alpha: 0.15)
                                      : _primaryRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCompany
                                          ? Icons.business_rounded
                                          : Icons.person_rounded,
                                      size: 10,
                                      color: isCompany ? _blue : _primaryRed,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isCompany ? 'شركة' : 'فرد',
                                      style: TextStyle(
                                        color: isCompany ? _blue : _primaryRed,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded,
                                    color: _green, size: 14),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          // ── Rating + Jobs ──
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: _gold, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                p.ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${p.totalReviews})',
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                              if (p.completedJobs > 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded,
                                    color: _green, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '${p.completedJobs} شغل',
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          // ── Experience / Employees ──
                          Row(
                            children: [
                              if (isCompany && p.employeesCount != null) ...[
                                const Icon(Icons.groups_rounded,
                                    color: _textSecondary, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '${p.employeesCount} موظف',
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ] else if (p.experienceYears != null &&
                                  p.experienceYears! > 0) ...[
                                const Icon(Icons.workspace_premium_rounded,
                                    color: _textSecondary, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '${p.experienceYears} سنة خبرة',
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 10.5,
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

                const SizedBox(height: 12),

                // ── Pricing + Location pills ──
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(
                      icon: isFree
                          ? Icons.favorite_rounded
                          : isSymbolic
                              ? Icons.volunteer_activism_rounded
                              : Icons.payments_rounded,
                      label: p.pricingLabel,
                      color: isFree
                          ? _green
                          : isSymbolic
                              ? _orange
                              : _primaryRed,
                    ),
                    if (p.city != null && p.city!.isNotEmpty)
                      _pill(
                        icon: Icons.location_on_rounded,
                        label: p.city!,
                        color: _blue,
                      ),
                    if (p.isAvailable)
                      _pill(
                        icon: Icons.check_circle_rounded,
                        label: 'متاح الآن',
                        color: _green,
                      ),
                  ],
                ),

                // ── Bio ──
                if (p.bio != null && p.bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    p.bio!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],

                // ── Skills ──
                if (p.skills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: p.skills.take(4).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cardSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Action Buttons ──
                Row(
                  children: [
                    // اتصل
                    if (p.phone != null && p.phone!.isNotEmpty)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.phone_rounded,
                          label: 'اتصل',
                          color: _green,
                          onTap: () => _makeCall(p.phone!),
                        ),
                      ),
                    if (p.phone != null &&
                        p.phone!.isNotEmpty &&
                        p.whatsapp != null &&
                        p.whatsapp!.isNotEmpty)
                      const SizedBox(width: 8),
                    // واتساب
                    if (p.whatsapp != null && p.whatsapp!.isNotEmpty)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.chat_rounded,
                          label: 'واتساب',
                          color: const Color(0xFF25D366),
                          onTap: () => _openWhatsapp(p.whatsapp!),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Call & WhatsApp Helpers
  // ═══════════════════════════════════════════════════════════
  Future<void> _makeCall(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('مش قادر أفتح الاتصال');
      }
    } catch (e) {
      debugPrint('❌ makeCall error: $e');
      _showSnack('تعذر فتح الاتصال');
    }
  }

  Future<void> _openWhatsapp(String phone) async {
    // نشيل كل حاجة غير الأرقام
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // لو الرقم مصري بيبدأ بـ 0 → نحوله لـ 20
    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('20') && cleaned.length == 10) {
      cleaned = '20$cleaned';
    }

    final uri = Uri.parse('https://wa.me/$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('مش قادر أفتح واتساب');
      }
    } catch (e) {
      debugPrint('❌ whatsapp error: $e');
      _showSnack('تعذر فتح واتساب');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: _cardSoft,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // Empty / Error
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFromName(widget.category.icon ?? ''),
                color: _blue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'مفيش ${widget.category.nameAr} متاحين دلوقتي',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'جرّب تغير الفلاتر أو ارجع بعدين',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            if (_providerType != null || _pricingType != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _providerType = null;
                    _pricingType = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('مسح الفلاتر'),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryRed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _primaryRed,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error ?? 'تعذر التحميل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
