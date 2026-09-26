// lib/features/institutions/presentation/pages/institution_offer_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import '../../domain/entities/institution_offer_request.dart';
import 'report_product_page.dart';

class InstitutionOfferDetailsPage extends StatefulWidget {
  final InstitutionOffer offer;
  final InstitutionOffersRepository? repository;

  const InstitutionOfferDetailsPage({
    super.key,
    required this.offer,
    this.repository,
  });

  @override
  State<InstitutionOfferDetailsPage> createState() =>
      _InstitutionOfferDetailsPageState();
}

class _InstitutionOfferDetailsPageState
    extends State<InstitutionOfferDetailsPage> {
  late final InstitutionOffersRepository _repository;

  // ✅ العرض الحالي (بيتحدث بعد refresh)
  late InstitutionOffer _offer;

  int _quantity = 1;
  bool _loading = false;
  bool _isOwner = false;
  bool _checkingOwner = true;
  InstitutionOfferRequest? _myRequest;
  bool _loadingRequest = true;
  bool _generatingCode = false;
  String? _pickupCode;
  bool _hasPickupCode = false;
  int _imageIndex = 0;
  late final PageController _imageController;

  // ✅ حالة refresh العرض
  bool _refreshingOffer = false;

  int _remainingToday =
      InstitutionOffersRepository.dailyInstitutionRequestLimit;
  bool _loadingLimit = true;

  // ─── ألوان أساسية ───
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryDark = Color(0xFF054D34);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _red = Color(0xFFDC4C4C);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF7B5EC7);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _cream = Color(0xFFF7FAF8);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _imageController = PageController();
    _offer = widget.offer;

    _loadOwnership();
    _loadMyRequest();
    _loadRemainingLimit();

    // ✅ نجدد العرض من السيرفر لما الصفحة تفتح
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshOffer();
    });
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ تحديث العرض من السيرفر
  // ═══════════════════════════════════════════════════════════
  Future<void> _refreshOffer() async {
    if (_refreshingOffer) return;
    setState(() => _refreshingOffer = true);
    try {
      final fresh = await _repository.getOffer(widget.offer.id);
      if (!mounted) return;
      if (fresh != null) {
        setState(() => _offer = fresh);
      }
    } catch (_) {
      // نتجاهل الخطأ — بنسيب القيمة القديمة
    } finally {
      if (mounted) setState(() => _refreshingOffer = false);
    }
  }

  Future<void> _loadRemainingLimit() async {
    try {
      final remaining = await _repository.getRemainingTodayRequests();
      if (!mounted) return;
      setState(() {
        _remainingToday = remaining;
        _loadingLimit = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLimit = false);
    }
  }

  Future<void> _loadMyRequest() async {
    try {
      final request = await _repository.getMyRequestForOffer(_offer.id);
      if (!mounted) return;
      setState(() {
        _myRequest = request;
        _loadingRequest = false;
        if (request != null &&
            request.pickupCode != null &&
            request.pickupCode!.isNotEmpty) {
          _pickupCode = request.pickupCode;
          _hasPickupCode = true;
        } else {
          _hasPickupCode = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRequest = false);
    }
  }

  Future<void> _generatePickupCode() async {
    final request = _myRequest;
    if (_generatingCode || request == null) return;

    if (_hasPickupCode && _pickupCode != null && _pickupCode!.isNotEmpty) {
      _showSnack('📋 الكود موجود بالفعل', _primary);
      return;
    }

    setState(() => _generatingCode = true);
    try {
      final result = await _repository.generatePickupCodeForUser(request.id);
      if (!mounted) return;

      final code = result['pickup_code']?.toString();
      final alreadyExists = result['already_exists'] ?? false;

      if (code != null && code.isNotEmpty) {
        setState(() {
          _pickupCode = code;
          _hasPickupCode = true;
        });

        final message =
            alreadyExists ? '📋 الكود موجود بالفعل' : '✅ تم إنشاء كود الاستلام';
        _showSnack(message, _primary);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _showSnack('❌ $msg', _red);
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _loadOwnership() async {
    try {
      final isOwner = await _repository.isOwnerOfOffer(_offer.institutionId);
      if (!mounted) return;
      setState(() {
        _isOwner = isOwner;
        _checkingOwner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingOwner = false);
    }
  }

  Future<void> _requestOffer() async {
    if (_loading || _isOwner || _myRequest != null) return;

    if (_remainingToday <= 0) {
      _showSnack(
        'وصلت للحد الأقصى من الطلبات اليومية '
        '(${InstitutionOffersRepository.dailyInstitutionRequestLimit}). '
        'حاول تاني بكرة.',
        _red,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _repository.requestOffer(
        offerId: _offer.id,
        quantity: _quantity,
      );

      if (!mounted) return;

      _showSnack('✅ تم إرسال طلبك بنجاح', _primary);

      // ✅ نجدد العرض عشان نعرض الكمية المحدثة
      await _refreshOffer();
      await _loadMyRequest();

      if (!mounted) return;
      // ❌ شيلنا pop عشان المستخدم يشوف التحديث
      // Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      final msg = _cleanErrorMessage(e);
      _showSnack('❌ $msg', _red);

      if (msg.contains('الحد الأقصى')) {
        setState(() => _remainingToday = 0);
        _loadRemainingLimit();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanErrorMessage(Object e) {
    var text = e.toString();
    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');

    if (text.contains('PostgrestException') ||
        text.contains('DAILY_LIMIT_REACHED') ||
        text.contains('P0310')) {
      if (text.contains('DAILY_LIMIT_REACHED') || text.contains('P0310')) {
        return 'وصلت للحد الأقصى من الطلبات اليومية '
            '(${InstitutionOffersRepository.dailyInstitutionRequestLimit}). '
            'حاول تاني بكرة.';
      }
      return 'تعذر إنشاء طلب العرض. حاول تاني.';
    }

    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    return text;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _openReportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportProductPage(offerId: _offer.id),
      ),
    );
  }

  ({Color color, String label, IconData icon}) _expiryInfo() {
    final expiryDate = _offer.expiresAt;
    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) {
      return (
        color: _red,
        label: 'منتهي الصلاحية',
        icon: Icons.warning_amber_rounded
      );
    } else if (daysLeft <= 3) {
      return (
        color: _orange,
        label: 'ينتهي خلال $daysLeft أيام',
        icon: Icons.timer_outlined
      );
    } else if (daysLeft <= 7) {
      return (
        color: _primary,
        label: 'طازج · $daysLeft يوم متبقي',
        icon: Icons.fiber_new_rounded
      );
    } else {
      return (
        color: _blue,
        label: 'صلاحية متبقية $daysLeft يوم',
        icon: Icons.inventory_2_rounded
      );
    }
  }

  int _reservedQuantity() {
    try {
      final raw = _offer.toJson();
      return (raw['reserved_quantity'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final maxQuantity = offer.remainingQuantity.clamp(1, 999999);
    final expiry = _expiryInfo();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.light().copyWith(
          scaffoldBackgroundColor: _cream,
          colorScheme: const ColorScheme.light(
            primary: _primary,
            surface: _cream,
            onSurface: _ink,
          ),
        ),
        child: Scaffold(
          backgroundColor: _cream,
          body: RefreshIndicator(
            color: _primary,
            onRefresh: () async {
              await Future.wait([
                _refreshOffer(),
                _loadMyRequest(),
                _loadRemainingLimit(),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 380,
                  pinned: true,
                  stretch: true,
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: _glassButton(
                    Icons.arrow_back_rounded,
                    () => Navigator.pop(context),
                  ),
                  actions: [
                    if (_refreshingOffer)
                      Container(
                        margin: const EdgeInsets.all(8),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      _glassButton(
                        Icons.refresh_rounded,
                        () async {
                          await Future.wait([
                            _refreshOffer(),
                            _loadMyRequest(),
                          ]);
                          _showSnack('✅ تم تحديث البيانات', _primary);
                        },
                      ),
                    _glassButton(
                      Icons.flag_outlined,
                      _openReportPage,
                    ),
                    const SizedBox(width: 12),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    background: _buildHeroSection(offer, expiry),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          _buildTitleBlock(offer),
                          const SizedBox(height: 22),
                          _buildStatsRow(offer),
                          const SizedBox(height: 22),
                          if (_hasExtraInfo(offer)) ...[
                            _buildFeaturedBadges(offer),
                            const SizedBox(height: 22),
                          ],
                          if (offer.description.isNotEmpty) ...[
                            _buildDescriptionCard(offer),
                            const SizedBox(height: 22),
                          ],
                          _buildLocationCard(offer),
                          const SizedBox(height: 22),
                          _buildActionSection(offer, maxQuantity),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton.icon(
                              onPressed: _openReportPage,
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: const Text(
                                'الإبلاغ عن منتج',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _inkSoft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    InstitutionOffer offer,
    ({Color color, String label, IconData icon}) expiry,
  ) {
    final images = offer.images;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isNotEmpty)
          PageView.builder(
            controller: _imageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: _primaryDark,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _heroPlaceholder(),
            ),
          )
        else
          _heroPlaceholder(),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          right: 20,
          left: 20,
          child: Row(
            children: [
              _statusPill(offer.status),
              const Spacer(),
              _expiryPill(expiry),
            ],
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _imageIndex ? 26 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == _imageIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: index == _imageIndex
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0,
            child: Container(
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_imageIndex + 1}/${images.length}',
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
      ],
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: Colors.white24,
          size: 100,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final isActive = status == 'active';
    final color = isActive ? _primaryLight : _orange;
    final icon = isActive ? Icons.check_circle : Icons.pause_circle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            isActive ? 'متاح' : 'غير متاح',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiryPill(({Color color, String label, IconData icon}) expiry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(expiry.icon, size: 14, color: expiry.color),
          const SizedBox(width: 5),
          Text(
            expiry.label,
            style: TextStyle(
              color: expiry.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildTitleBlock(InstitutionOffer offer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.title,
          style: const TextStyle(
            color: _ink,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
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
                    color: _primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.institutionName,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          offer.institutionType ?? 'مؤسسة',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: _primary,
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'موثوق',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(InstitutionOffer offer) {
    final reserved = _reservedQuantity();

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_offer_rounded,
                            color: _gold,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'السعر الرمزي',
                          style: TextStyle(
                            color: _inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          offer.symbolicPrice.toStringAsFixed(0),
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'ج.م',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 70,
                color: const Color(0xFFEEF3F0),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: offer.remainingQuantity > 0
                              ? _primary.withValues(alpha: 0.12)
                              : _red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: offer.remainingQuantity > 0 ? _primary : _red,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'المتاح للطلب',
                        style: TextStyle(
                          color: _inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${offer.remainingQuantity}',
                        style: TextStyle(
                          color: offer.remainingQuantity > 0 ? _ink : _red,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        offer.remainingQuantity > 0 ? 'وحدة' : 'خلصت',
                        style: const TextStyle(
                          color: _inkSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (reserved > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: _orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$reserved وحدة محجوزة في طلبات حالية',
                      style: const TextStyle(
                        color: Color(0xFFB77700),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'الإجمالي: ${offer.quantity}',
                    style: const TextStyle(
                      color: Color(0xFFB77700),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

  bool _hasExtraInfo(InstitutionOffer offer) {
    return offer.foodType != null ||
        offer.isHalal != null ||
        offer.isVegetarian == true ||
        offer.requiresRefrigeration == true ||
        offer.foodCondition != null;
  }

  Widget _buildFeaturedBadges(InstitutionOffer offer) {
    final chips = <Widget>[];

    if (offer.foodType != null && offer.foodType!.isNotEmpty) {
      chips.add(_premiumBadge(
        label: offer.foodType!,
        icon: Icons.restaurant_rounded,
        color: _primary,
      ));
    }

    if (offer.isHalal == true) {
      chips.add(_premiumBadge(
        label: 'حلال',
        icon: Icons.verified_rounded,
        color: _primary,
      ));
    }

    if (offer.isVegetarian == true) {
      chips.add(_premiumBadge(
        label: 'نباتي',
        icon: Icons.eco_rounded,
        color: _primaryLight,
      ));
    }

    if (offer.requiresRefrigeration == true) {
      chips.add(_premiumBadge(
        label: 'يحتاج تبريد',
        icon: Icons.ac_unit_rounded,
        color: _blue,
      ));
    }

    if (offer.foodCondition != null && offer.foodCondition!.isNotEmpty) {
      chips.add(_premiumBadge(
        label: _getConditionLabel(offer.foodCondition!),
        icon: Icons.star_rounded,
        color: _gold,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'مميزات',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Widget _premiumBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
    );
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'جديد';
      case 'very_good':
        return 'ممتاز';
      case 'good':
        return 'جيد';
      case 'needs_repair':
        return 'يحتاج إصلاح';
      default:
        return condition;
    }
  }

  Widget _buildDescriptionCard(InstitutionOffer offer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: _primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'عن العرض',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            offer.description,
            style: const TextStyle(
              color: _inkSoft,
              fontSize: 14,
              height: 1.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (offer.pickupNotes != null && offer.pickupNotes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_rounded,
                    color: _orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      offer.pickupNotes!,
                      style: const TextStyle(
                        color: Color(0xFFB77700),
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
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

  Widget _buildLocationCard(InstitutionOffer offer) {
    final location = offer.pickupLocation?.trim() ?? '';
    final hasLocation = location.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasLocation
              ? [
                  _primary.withValues(alpha: 0.08),
                  _primary.withValues(alpha: 0.02)
                ]
              : [Colors.grey.shade100, Colors.grey.shade50],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasLocation
              ? _primary.withValues(alpha: 0.25)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: hasLocation
                  ? const LinearGradient(
                      colors: [_primary, _primaryLight],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              color: hasLocation ? null : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
              boxShadow: hasLocation
                  ? [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: hasLocation ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مكان الاستلام',
                  style: TextStyle(
                    color: _inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLocation ? location : 'غير محدد',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (hasLocation)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_rounded,
                color: _primary,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection(InstitutionOffer offer, int maxQuantity) {
    if (_checkingOwner) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_isOwner) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF7F3), Color(0xFFE3F2EC)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'هذا العرض تابع لمؤسستك. الكمية تُدار من صفحة عروضي.',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadingRequest) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (_myRequest != null) {
      return _ExistingRequestCard(
        request: _myRequest!,
        pickupCode: _pickupCode,
        hasPickupCode: _hasPickupCode,
        generatingCode: _generatingCode,
        onGenerateCode: _generatePickupCode,
        primaryColor: _primary,
        primaryLight: _primaryLight,
        inkColor: _ink,
        inkSoftColor: _inkSoft,
      );
    }

    final limitReached = _remainingToday <= 0;
    final showLimitWarning = _remainingToday <= 2 && !limitReached;
    final isButtonDisabled = _loading || limitReached || !offer.isActive;

    return Column(
      children: [
        if (!_loadingLimit && (limitReached || showLimitWarning))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: limitReached
                    ? _red.withValues(alpha: 0.08)
                    : _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: limitReached
                      ? _red.withValues(alpha: 0.25)
                      : _orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    limitReached
                        ? Icons.block_rounded
                        : Icons.warning_amber_rounded,
                    color: limitReached ? _red : _orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      limitReached
                          ? 'وصلت للحد الأقصى من الطلبات اليومية. حاول بكرة.'
                          : 'متبقي لك $_remainingToday من ${InstitutionOffersRepository.dailyInstitutionRequestLimit} طلبات النهارده',
                      style: TextStyle(
                        color: limitReached ? _red : const Color(0xFFB77700),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEF3F0)),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الكمية المطلوبة',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'من 1 إلى $maxQuantity',
                      style: const TextStyle(
                        color: _inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _qtyBtn(
                      icon: Icons.remove_rounded,
                      enabled: _quantity > 1 && !isButtonDisabled,
                      onTap: () => setState(() => _quantity--),
                    ),
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    _qtyBtn(
                      icon: Icons.add_rounded,
                      enabled: _quantity < maxQuantity && !isButtonDisabled,
                      onTap: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: isButtonDisabled ? null : _requestOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    limitReached
                        ? Icons.lock_rounded
                        : Icons.shopping_bag_rounded,
                    size: 22,
                  ),
                const SizedBox(width: 10),
                Text(
                  _loading
                      ? 'جارٍ إرسال الطلب...'
                      : (limitReached ? 'وصلت للحد اليومي' : 'اطلب الآن'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                enabled ? _primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: enabled ? _primary : _inkSoft.withValues(alpha: 0.4),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EXISTING REQUEST CARD
// ═══════════════════════════════════════════════════════════
class _ExistingRequestCard extends StatelessWidget {
  final InstitutionOfferRequest request;
  final String? pickupCode;
  final bool hasPickupCode;
  final bool generatingCode;
  final VoidCallback onGenerateCode;
  final Color primaryColor;
  final Color primaryLight;
  final Color inkColor;
  final Color inkSoftColor;

  const _ExistingRequestCard({
    required this.request,
    required this.pickupCode,
    required this.hasPickupCode,
    required this.generatingCode,
    required this.onGenerateCode,
    required this.primaryColor,
    required this.primaryLight,
    required this.inkColor,
    required this.inkSoftColor,
  });

  ({String label, Color color, IconData icon}) get _statusInfo {
    switch (request.status) {
      case 'pending':
        return (
          label: 'طلبك قيد المراجعة',
          color: const Color(0xFFE28B00),
          icon: Icons.hourglass_top_rounded
        );
      case 'accepted':
        return (
          label: 'تم قبول طلبك',
          color: const Color(0xFF3679C8),
          icon: Icons.check_circle_outline_rounded
        );
      case 'ready_for_pickup':
        return (
          label: 'طلبك جاهز للاستلام',
          color: primaryColor,
          icon: Icons.inventory_2_rounded
        );
      case 'picked_up':
        return (
          label: 'تم تأكيد الاستلام',
          color: const Color(0xFF7B5EC7),
          icon: Icons.local_shipping_rounded
        );
      case 'completed':
        return (
          label: 'اكتمل الطلب',
          color: primaryColor,
          icon: Icons.emoji_events_rounded
        );
      default:
        return (
          label: 'لديك طلب سابق',
          color: inkSoftColor,
          icon: Icons.info_outline_rounded
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo;
    final canCreateCode = request.status == 'ready_for_pickup';
    final showCode =
        hasPickupCode && pickupCode != null && pickupCode!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: info.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: TextStyle(
                        color: info.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الكمية: ${request.quantity}',
                      style: TextStyle(
                        color: inkSoftColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canCreateCode) ...[
            const SizedBox(height: 16),
            if (showCode) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.08),
                      primaryLight.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pin_rounded,
                          color: primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'كود الاستلام',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        pickupCode!,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          letterSpacing: 10,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'اعرض هذا الكود للمؤسسة عند الاستلام',
                      style: TextStyle(
                        color: inkSoftColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: pickupCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('📋 تم نسخ الكود'),
                            backgroundColor: primaryColor,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('نسخ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: generatingCode ? null : onGenerateCode,
                      icon: generatingCode
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('تحديث'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: generatingCode ? null : onGenerateCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: generatingCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.pin_rounded),
                  label: Text(
                    generatingCode
                        ? 'جارٍ إنشاء الكود...'
                        : 'إنشاء كود الاستلام',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (!canCreateCode && !showCode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'تابع حالة طلبك من صفحة "طلباتي".',
                style: TextStyle(
                  color: inkSoftColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
