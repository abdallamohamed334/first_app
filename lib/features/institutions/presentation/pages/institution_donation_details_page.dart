// lib/features/institutions/presentation/pages/institution_donation_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/institutions_repository.dart';

class InstitutionDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;
  const InstitutionDonationDetailsPage({super.key, required this.donation});

  @override
  State<InstitutionDonationDetailsPage> createState() =>
      _InstitutionDonationDetailsPageState();
}

class _InstitutionDonationDetailsPageState
    extends State<InstitutionDonationDetailsPage> {
  final _repository = InstitutionsRepository();
  late Map<String, dynamic> _donation;
  bool _busy = false;
  int _currentImageIndex = 0;
  List<String> _images = [];

  // ── ألوان الهوية ──
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryDark = Color(0xFF064E3B);
  static const Color _primaryLight = Color(0xFFE8F5EE);
  static const Color _surface = Color(0xFFF6F9F7);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF7A8E87);
  static const Color _textDark = Color(0xFF123F31);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _error = Color(0xFFD64545);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF8A5BB7);

  @override
  void initState() {
    super.initState();
    _donation = Map<String, dynamic>.from(widget.donation);
    _loadImages();
  }

  // ═══════════════════════════════════════════════════════════
  // تحميل الصور
  // ═══════════════════════════════════════════════════════════
  void _loadImages() {
    final images = _donation['images'];
    List<String> allImages = [];

    if (images is List) {
      for (var img in images) {
        if (img != null) {
          final url = img.toString().trim();
          if (url.isNotEmpty && !allImages.contains(url)) {
            allImages.add(url);
          }
        }
      }
    }

    final singleImage = _donation['image']?.toString().trim() ?? '';
    if (singleImage.isNotEmpty && !allImages.contains(singleImage)) {
      allImages.add(singleImage);
    }

    final publicUrl = _donation['public_url']?.toString().trim() ?? '';
    if (publicUrl.isNotEmpty && !allImages.contains(publicUrl)) {
      allImages.add(publicUrl);
    }

    final media = _donation['media'] as List? ?? [];
    for (var item in media) {
      if (item is Map) {
        final url = item['url']?.toString().trim() ??
            item['public_url']?.toString().trim() ??
            '';
        if (url.isNotEmpty && !allImages.contains(url)) {
          allImages.add(url);
        }
      }
    }

    if (mounted) {
      setState(() => _images = allImages);
    }
  }

  String get _status => (_donation['status'] ?? 'pending').toString();

  // ═══════════════════════════════════════════════════════════
  // استخراج رسالة الخطأ الحقيقية
  // ═══════════════════════════════════════════════════════════
  String _errorText(Object error, {String? fallback}) {
    String raw = error.toString();

    if (error is PostgrestException) {
      final msg = error.message.trim();
      if (msg.isNotEmpty) {
        if (RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) return msg;
        return _translatePgError(msg, fallback);
      }
    }

    final pgMatch = RegExp(
      r'PostgrestException\(message:\s*(.+?),\s*code:',
      dotAll: true,
    ).firstMatch(raw);
    if (pgMatch != null) {
      final msg = (pgMatch.group(1) ?? '').trim();
      if (msg.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) {
        return msg;
      }
    }

    raw = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();

    if (RegExp(r'[\u0600-\u06FF]').hasMatch(raw) && raw.length < 200) {
      return raw;
    }

    return fallback ?? 'تعذر إتمام العملية، حاول مرة أخرى';
  }

  String _translatePgError(String msg, String? fallback) {
    final m = msg.toLowerCase();
    if (m.contains('not authorized') || m.contains('permission')) {
      return 'غير مصرح لك بتنفيذ هذه العملية';
    }
    if (m.contains('not found')) return 'التبرع غير موجود';
    if (m.contains('expired')) return 'انتهت صلاحية هذا التبرع';
    return fallback ?? 'تعذر إتمام العملية، حاول مرة أخرى';
  }

  // ═══════════════════════════════════════════════════════════
  // تشغيل عملية
  // ═══════════════════════════════════════════════════════════
  Future<void> _run(Future<Map<String, dynamic>> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (!mounted) return;

      setState(() {
        _donation = {..._donation, ...result};
        _busy = false;
      });

      _loadImages();

      _showToast(
        result['message']?.toString() ?? 'تم تنفيذ العملية بنجاح',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast(_errorText(e), success: false);
    }
  }

  void _showToast(String text, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textAlign: TextAlign.right),
          backgroundColor: success ? _primary : _error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: Duration(seconds: success ? 3 : 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // إدخال كود الاستلام
  // ═══════════════════════════════════════════════════════════
  Future<void> _enterPickupCode(String donationId) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _PickupCodeEntrySheet(),
    );

    if (code == null || !mounted) return;

    await _run(() => _repository.verifyPickupCode(
          donationId: donationId,
          code: code,
        ));
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final title = (_donation['item_title'] ?? 'تبرع بدون اسم').toString();
    final charity = _donation['charities'];
    final charityName = _nestedName(charity) ??
        (_donation['charity_name']?.toString() ?? 'جمعية');
    final institutionName = _nestedName(_donation['institutions']) ??
        (_donation['institution_name']?.toString() ?? 'مؤسسة');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════════════
            // SLIVER APP BAR with Hero Image
            // ═══════════════════════════════════════════════
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              stretch: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: _textDark,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.fadeTitle,
                ],
                background: _buildHeroSection(
                  title,
                  institutionName,
                  charityName,
                ),
              ),
            ),

            // ═══════════════════════════════════════════════
            // CONTENT
            // ═══════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusBanner(),
                        const SizedBox(height: 16),
                        _buildInfoCard(charityName, institutionName),
                        _buildVolunteerSection(),
                        _buildDescriptionSection(),
                        _buildTimeline(),
                        _buildActionsSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
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
  // HERO SECTION — الصورة + العنوان
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroSection(
    String title,
    String institutionName,
    String charityName,
  ) {
    final images = _images;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── الخلفية (صورة أو gradient)
        if (images.isNotEmpty)
          CarouselSlider(
            options: CarouselOptions(
              height: 320,
              viewportFraction: 1.0,
              enableInfiniteScroll: images.length > 1,
              autoPlay: images.length > 1,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 900),
              onPageChanged: (index, reason) {
                setState(() => _currentImageIndex = index);
              },
            ),
            items: images.map((image) {
              return Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryDark, _primary],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 80,
              ),
            ),
          ),

        // ── Overlay gradient للقراءة
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),

        // ── شارة الحالة
        Positioned(
          top: 60,
          right: 16,
          child: _buildStatusBadge(_status),
        ),

        // ── Dots للصور
        if (images.length > 1)
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentImageIndex + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── العنوان + المؤسسة
        Positioned(
          bottom: 60,
          right: 20,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _heroChip(
                    Icons.storefront_rounded,
                    institutionName,
                  ),
                  const SizedBox(width: 8),
                  _heroChip(
                    Icons.volunteer_activism_rounded,
                    charityName,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS BANNER
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusBanner() {
    final data = _statusBannerData(_status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            data.color.withValues(alpha: 0.12),
            data.color.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: data.color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة التبرع',
                  style: TextStyle(
                    color: data.color.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _statusLabel(_status),
                  style: TextStyle(
                    color: data.color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color color, IconData icon}) _statusBannerData(String status) {
    switch (status) {
      case 'pending':
        return (
          color: const Color(0xFFB36B12),
          icon: Icons.pending_actions_rounded,
        );
      case 'accepted':
        return (
          color: _blue,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'volunteer_assigned':
        return (
          color: _purple,
          icon: Icons.person_add_alt_1_rounded,
        );
      case 'institution_ready':
        return (
          color: _primary,
          icon: Icons.inventory_2_rounded,
        );
      case 'volunteer_departed':
        return (
          color: _purple,
          icon: Icons.delivery_dining_rounded,
        );
      case 'picked_up':
        return (
          color: const Color(0xFF2F6DA5),
          icon: Icons.handshake_rounded,
        );
      case 'completed':
        return (
          color: _primary,
          icon: Icons.emoji_events_rounded,
        );
      case 'rejected':
      case 'cancelled':
        return (
          color: _error,
          icon: Icons.cancel_rounded,
        );
      case 'expired':
        return (
          color: _textMuted,
          icon: Icons.timer_off_rounded,
        );
      default:
        return (
          color: _textMuted,
          icon: Icons.info_outline_rounded,
        );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INFO CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard(String charityName, String institutionName) {
    final quantity = (_donation['quantity'] ?? '—').toString();
    final condition = _donation['item_condition']?.toString().trim() ?? '';

    return _stunningCard(
      icon: Icons.info_outline_rounded,
      title: 'معلومات التبرع',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.volunteer_activism_rounded,
                  'الجمعية',
                  charityName,
                  color: _purple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoItem(
                  Icons.inventory_2_rounded,
                  'الكمية',
                  '$quantity وحدة',
                  color: _primary,
                ),
              ),
            ],
          ),
          if (condition.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoItem(
                    Icons.verified_outlined,
                    'حالة المنتج',
                    condition,
                    color: _blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _infoItem(
                    Icons.storefront_rounded,
                    'المؤسسة',
                    institutionName,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            _infoItem(
              Icons.storefront_rounded,
              'المؤسسة',
              institutionName,
              color: _primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    final c = color ?? _primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: c, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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
  // VOLUNTEER SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildVolunteerSection() {
    final volunteerName = _donation['volunteer_name']?.toString().trim() ?? '';
    final volunteerPhone =
        _donation['volunteer_phone']?.toString().trim() ?? '';
    final hasVolunteer = volunteerName.isNotEmpty || volunteerPhone.isNotEmpty;

    if (!hasVolunteer) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _VolunteerInfoCard(
        name: volunteerName,
        phone: volunteerPhone,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DESCRIPTION SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildDescriptionSection() {
    final description = (_donation['description']?.toString() ?? '').trim();
    if (description.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _stunningCard(
        icon: Icons.description_outlined,
        title: 'وصف التبرع',
        child: Text(
          description,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 14,
            height: 1.8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TIMELINE
  // ═══════════════════════════════════════════════════════════
  Widget _buildTimeline() {
    const steps = [
      ('pending', 'مراجعة الطلب', Icons.pending_actions_rounded),
      ('accepted', 'تم القبول', Icons.check_circle_outline_rounded),
      ('volunteer_assigned', 'تعيين متطوع', Icons.person_add_rounded),
      ('institution_ready', 'جاهز للتسليم', Icons.inventory_2_rounded),
      ('volunteer_departed', 'في الطريق', Icons.delivery_dining_rounded),
      ('picked_up', 'تم الاستلام', Icons.handshake_rounded),
      ('completed', 'تم التسليم', Icons.emoji_events_rounded),
    ];

    final currentIndex = steps.indexWhere((s) => s.$1 == _status);
    final isRejected =
        _status == 'rejected' || _status == 'cancelled' || _status == 'expired';

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _stunningCard(
        icon: Icons.timeline_outlined,
        title: 'خط سير التبرع',
        child: Column(
          children: steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isDone = !isRejected && currentIndex >= index;
            final isCurrent = index == currentIndex && !isRejected;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── الدائرة + الخط
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _primary
                            : isRejected && isCurrent
                                ? _error
                                : const Color(0xFFE4EAE5),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: _primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : isRejected && isCurrent
                                ? Icons.close_rounded
                                : step.$3,
                        color: isDone || (isRejected && isCurrent)
                            ? Colors.white
                            : const Color(0xFFA8B4AC),
                        size: 18,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2.5,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone ? _primary : const Color(0xFFE4EAE5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // ── النص
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                step.$2,
                                style: TextStyle(
                                  color: isDone || (isRejected && isCurrent)
                                      ? _textDark
                                      : _textMuted,
                                  fontWeight:
                                      isDone || (isRejected && isCurrent)
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isCurrent && !isRejected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'الحالية',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionsSection() {
    final id = _donation['id']?.toString();
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final actions = _buildActions(id);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions,
      ),
    );
  }

  List<Widget> _buildActions(String id) {
    // ═══════════════════════════════════════════════════════
    // volunteer_assigned → "أنا جاهز للتسليم"
    // ═══════════════════════════════════════════════════════
    if (_status == 'volunteer_assigned') {
      return [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed:
                _busy ? null : () => _run(() => _repository.markReady(id)),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 22),
            label: Text(_busy ? 'جاري التنفيذ...' : 'أنا جاهز للتسليم'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ];
    }

    // ═══════════════════════════════════════════════════════
    // institution_ready → في انتظار تحرك المندوب
    // ═══════════════════════════════════════════════════════
    if (_status == 'institution_ready') {
      return const [
        _DonationNoticeCard(
          icon: Icons.hourglass_top_rounded,
          title: 'في انتظار تحرك المندوب',
          text:
              'أكدت جاهزيتك للتسليم. الجمعية لسه ما أكدتش إن المندوب خرج. الكود هيظهر للمندوب بعد ما الجمعية تأكد التحرك.',
          color: _blue,
        ),
      ];
    }

    // ═══════════════════════════════════════════════════════
    // volunteer_departed → "إدخال كود الاستلام"
    // ═══════════════════════════════════════════════════════
    if (_status == 'volunteer_departed') {
      return [
        const _DonationNoticeCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'المندوب في الطريق',
          text:
              'عند وصول المندوب، هيوريك كود مكوّن من 6 أرقام. دخل الكود هنا للتحقق من الاستلام.',
          color: _purple,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _enterPickupCode(id),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.password_rounded, size: 22),
            label: Text(_busy ? 'جاري التحقق...' : '🔑 إدخال كود الاستلام'),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ];
    }

    // ═══════════════════════════════════════════════════════
    // picked_up
    // ═══════════════════════════════════════════════════════
    if (_status == 'picked_up') {
      return const [
        _DonationNoticeCard(
          icon: Icons.check_circle_rounded,
          title: 'تم التحقق من الكود ✅',
          text:
              'تم تسليم التبرع للمندوب بنجاح. في انتظار تأكيد الجمعية لوصول التبرع لإكمال العملية.',
          color: _primary,
        ),
      ];
    }

    // ═══════════════════════════════════════════════════════
    // completed
    // ═══════════════════════════════════════════════════════
    if (_status == 'completed') {
      return const [
        _DonationNoticeCard(
          icon: Icons.emoji_events_rounded,
          title: 'تم تسليم التبرع بنجاح! 🏆',
          text: 'وصل التبرع للجمعية وتم تأكيد الاستلام. شكرًا لك!',
          color: _gold,
        ),
      ];
    }

    // ═══════════════════════════════════════════════════════
    // rejected / cancelled / expired
    // ═══════════════════════════════════════════════════════
    if (_status == 'rejected' ||
        _status == 'cancelled' ||
        _status == 'expired') {
      return const [
        _DonationNoticeCard(
          icon: Icons.cancel_rounded,
          title: 'تم إلغاء التبرع',
          text: 'هذا التبرع تم إلغاؤه ولا يمكن متابعته.',
          color: _error,
        ),
      ];
    }

    return [];
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS BADGE
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatusBadge(String status) {
    final colors = {
      'pending': (const Color(0xFFB36B12), const Color(0xFFFFF0DA)),
      'accepted': (_blue, const Color(0xFFEAF2FF)),
      'volunteer_assigned': (_purple, const Color(0xFFF0EBF8)),
      'institution_ready': (_primary, _primaryLight),
      'volunteer_departed': (_purple, const Color(0xFFF0EBF8)),
      'picked_up': (const Color(0xFF2F6DA5), const Color(0xFFE8F0FB)),
      'completed': (_primary, _primaryLight),
      'rejected': (_error, const Color(0xFFFFEEEE)),
      'cancelled': (_error, const Color(0xFFFFEEEE)),
      'expired': (_textMuted, const Color(0xFFF0F0F0)),
    };
    final pair = colors[status] ?? (_textMuted, const Color(0xFFF0F0F0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: pair.$2,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: pair.$1,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STUNNING CARD WRAPPER
  // ═══════════════════════════════════════════════════════════
  Widget _stunningCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  static String? _nestedName(dynamic value) =>
      value is Map ? value['name']?.toString() : null;

  static String _statusLabel(String status) {
    const labels = {
      'pending': 'في انتظار المراجعة',
      'accepted': 'تم القبول',
      'rejected': 'مرفوض',
      'volunteer_assigned': 'تم تعيين المتطوع',
      'institution_ready': 'جاهز للتسليم',
      'volunteer_departed': 'المتطوع في الطريق',
      'picked_up': 'تم الاستلام',
      'completed': 'تم التسليم',
      'cancelled': 'ملغي',
      'expired': 'منتهي',
    };
    return labels[status] ?? 'حالة غير معروفة';
  }
}

// ═══════════════════════════════════════════════════════════
// Volunteer Info Card
// ═══════════════════════════════════════════════════════════

class _VolunteerInfoCard extends StatelessWidget {
  final String name;
  final String phone;

  const _VolunteerInfoCard({
    required this.name,
    required this.phone,
  });

  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFFE8F5EE);
  static const Color _textDark = Color(0xFF123F31);
  static const Color _textMuted = Color(0xFF7A8E87);
  static const Color _purple = Color(0xFF8A5BB7);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBF8FE), Color(0xFFF4EEFB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _purple.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: _purple,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المندوب المسؤول',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'هو اللي هيجي يستلم التبرع منك',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── بيانات المندوب
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _purple.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الاسم',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name.isEmpty ? 'غير مسجل' : name,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: _purple.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: _primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'رقم التواصل',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      SelectableText(
                        phone,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '؟';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first;
    }
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }
}

// ═══════════════════════════════════════════════════════════
// Pickup Code Entry Sheet
// ═══════════════════════════════════════════════════════════

class _PickupCodeEntrySheet extends StatefulWidget {
  const _PickupCodeEntrySheet();

  @override
  State<_PickupCodeEntrySheet> createState() => _PickupCodeEntrySheetState();
}

class _PickupCodeEntrySheetState extends State<_PickupCodeEntrySheet> {
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFFE8F5EE);
  static const Color _textDark = Color(0xFF123F31);
  static const Color _textMuted = Color(0xFF7A8E87);
  static const Color _error = Color(0xFFD64545);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length != 6) {
      setState(() => _errorText = 'الكود لازم يكون 6 أرقام');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBE3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.password_rounded,
                          color: _primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إدخال كود الاستلام',
                              style: TextStyle(
                                color: _textDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'المندوب هيوريك كود من 6 أرقام، دخله هنا',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 11.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: _textDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5EEEA)),
                const SizedBox(height: 24),

                // ── Code Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F8F6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _errorText != null
                                ? _error
                                : const Color(0xFFE1ECE6),
                            width: _errorText != null ? 1.5 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(
                            fontSize: 34,
                            letterSpacing: 14,
                            fontWeight: FontWeight.w900,
                            color: _primary,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            hintStyle: TextStyle(
                              color: _textMuted.withValues(alpha: 0.3),
                              fontSize: 34,
                              letterSpacing: 14,
                              fontWeight: FontWeight.w900,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() => _errorText = null);
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, right: 6),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: _error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text(
                            'تحقق من الكود',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'الكود بيتم التحقق منه مرة واحدة فقط',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Notice Card
// ═══════════════════════════════════════════════════════════

class _DonationNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _DonationNoticeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  static const Color _textMuted = Color(0xFF7A8E87);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
