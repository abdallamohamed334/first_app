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

  // ═══════════════════════════════════════════════════════════
  // ✅ الحد اليومي لطلبات البقالة
  // ═══════════════════════════════════════════════════════════
  int _remainingToday =
      InstitutionOffersRepository.dailyInstitutionRequestLimit;
  bool _loadingLimit = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _imageController = PageController();
    _loadOwnership();
    _loadMyRequest();
    _loadRemainingLimit();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ تحميل العداد المتبقي
  // ═══════════════════════════════════════════════════════════
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
      final request = await _repository.getMyRequestForOffer(widget.offer.id);
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

  // ═══════════════════════════════════════════════════════════
  // ✅ إنشاء كود الاستلام (للمستخدم العادي)
  // ═══════════════════════════════════════════════════════════
  Future<void> _generatePickupCode() async {
    final request = _myRequest;
    final colors = Theme.of(context).colorScheme;

    if (_generatingCode || request == null) return;

    if (_hasPickupCode && _pickupCode != null && _pickupCode!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📋 الكود موجود بالفعل'),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _generatingCode = true);
    try {
      // ✅ للمستخدم العادي — مش للمؤسسة
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: colors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $msg'),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _loadOwnership() async {
    try {
      final isOwner =
          await _repository.isOwnerOfOffer(widget.offer.institutionId);
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

  // ═══════════════════════════════════════════════════════════
  // ✅ طلب العرض (مع تعطيل الزر فوراً عند الحد الأقصى)
  // ═══════════════════════════════════════════════════════════
  Future<void> _requestOffer() async {
    final colors = Theme.of(context).colorScheme;

    // ✅ حماية: مش بيسمح بأي ضغطة جديدة
    if (_loading || _isOwner || _myRequest != null) return;

    // ✅ لو الحد خلص أصلاً → نعرض رسالة بس
    if (_remainingToday <= 0) {
      _showErrorSnack(
        'وصلت للحد الأقصى من الطلبات اليومية '
        '(${InstitutionOffersRepository.dailyInstitutionRequestLimit}). '
        'حاول تاني بكرة.',
      );
      return;
    }

    // ✅ نقفل الزر فوراً قبل أي request (يمنع double-click)
    setState(() => _loading = true);

    try {
      await _repository.requestOffer(
        offerId: widget.offer.id,
        quantity: _quantity,
      );

      if (!mounted) return;

      // ✅ نجح → SnackBar + pop
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ تم إرسال طلبك بنجاح'),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      final msg = _cleanErrorMessage(e);
      _showErrorSnack('❌ $msg');

      // ═══════════════════════════════════════════════════════════
      // ✅ لو الخطأ "حد أقصى" → نصفّر العداد فوراً
      //    وبكده الزر يبقى معطّل نهائياً (مش محتاج reload)
      // ═══════════════════════════════════════════════════════════
      if (msg.contains('الحد الأقصى')) {
        setState(() => _remainingToday = 0);

        // ✅ نجدد من السيرفر (للتأكيد)
        _loadRemainingLimit();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Helper: تنظيف رسالة الخطأ
  // ═══════════════════════════════════════════════════════════
  String _cleanErrorMessage(Object e) {
    var text = e.toString();

    // 1) شيل "Exception: " لو موجودة في الأول
    text = text.replaceFirst(RegExp(r'^Exception:\s*'), '');

    // 2) لو لسه فيه PostgrestException — استخرج الرسالة النظيفة
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

    // 3) شيل أي `PostgrestException(...)` طويلة لو لسه موجودة
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(text);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    return text;
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Helper: عرض SnackBar خطأ بشكل موحّد
  // ═══════════════════════════════════════════════════════════
  void _showErrorSnack(String message) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ✅ فتح صفحة الإبلاغ
  void _openReportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportProductPage(offerId: widget.offer.id),
      ),
    );
  }

  // ✅ حساب حالة الصلاحية
  Map<String, dynamic> _getExpiryStatus() {
    final colors = Theme.of(context).colorScheme;
    final expiryDate = widget.offer.expiresAt;

    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) {
      return {
        'label': 'منتهي الصلاحية',
        'color': colors.error,
        'icon': Icons.warning_amber_rounded,
      };
    } else if (daysLeft <= 3) {
      return {
        'label': 'ينتهي خلال $daysLeft أيام',
        'color': const Color(0xFFE28B00),
        'icon': Icons.timer_outlined,
      };
    } else if (daysLeft <= 7) {
      return {
        'label': 'طازج - $daysLeft يوم متبقي',
        'color': colors.primary,
        'icon': Icons.fiber_new_rounded,
      };
    } else {
      return {
        'label': 'صلاحية متبقية $daysLeft يوم',
        'color': const Color(0xFF3679C8),
        'icon': Icons.inventory_2_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxQuantity = offer.remainingQuantity.clamp(1, 999999);
    final expiryStatus = _getExpiryStatus();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text(
            'تفاصيل العرض',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : colors.surface,
          foregroundColor: colors.onSurface,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(offer, colors),
            const SizedBox(height: 16),
            _buildMainCard(offer, expiryStatus, colors),
            const SizedBox(height: 16),
            _buildMetricsCard(offer, colors),
            const SizedBox(height: 16),
            _buildAdditionalInfoCard(offer, colors),
            const SizedBox(height: 16),
            if (offer.description.isNotEmpty)
              _buildDescriptionCard(offer, colors),
            const SizedBox(height: 16),
            _buildPickupCard(offer, colors),
            const SizedBox(height: 16),
            _buildActionSection(offer, maxQuantity, colors),
            const SizedBox(height: 16),

            // ✅ زر الإبلاغ عن منتج
            _buildReportButton(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(ColorScheme colors) {
    return OutlinedButton.icon(
      onPressed: _openReportPage,
      icon: const Icon(Icons.flag_rounded, size: 18),
      label: const Text('الإبلاغ عن منتج'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE28B00),
        side: BorderSide(color: const Color(0xFFE28B00).withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildImageSection(InstitutionOffer offer, ColorScheme colors) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.18,
            child: offer.images.isNotEmpty
                ? PageView.builder(
                    controller: _imageController,
                    itemCount: offer.images.length,
                    onPageChanged: (index) =>
                        setState(() => _imageIndex = index),
                    itemBuilder: (_, index) => Image.network(
                      offer.images[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: colors.primary.withValues(alpha: 0.1),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const _ImageFallback(),
                    ),
                  )
                : const _ImageFallback(),
          ),
        ),
        if (offer.images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              offer.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _imageIndex ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: index == _imageIndex
                      ? colors.primary
                      : colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainCard(InstitutionOffer offer,
      Map<String, dynamic> expiryStatus, ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              offer.title,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 17,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${offer.institutionName} • ${offer.institutionType ?? 'مؤسسة'}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatusBadge(status: offer.status),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        (expiryStatus['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (expiryStatus['color'] as Color)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expiryStatus['icon'],
                        size: 14,
                        color: expiryStatus['color'],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expiryStatus['label'],
                        style: TextStyle(
                          color: expiryStatus['color'],
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(InstitutionOffer offer, ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 12,
          spacing: 8,
          children: [
            SizedBox(
              width: 112,
              child: _Metric(
                label: 'السعر الرمزي',
                value: '${offer.symbolicPrice.toStringAsFixed(2)} ج.م',
              ),
            ),
            SizedBox(
              width: 82,
              child: _Metric(
                label: 'الكمية',
                value: '${offer.quantity}',
              ),
            ),
            SizedBox(
              width: 82,
              child: _Metric(
                label: 'المتبقي',
                value: '${offer.remainingQuantity}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard(InstitutionOffer offer, ColorScheme colors) {
    final isHalal = offer.isHalal ?? true;
    final isVegetarian = offer.isVegetarian ?? false;
    final requiresRefrigeration = offer.requiresRefrigeration ?? false;
    final foodCondition = offer.foodCondition ?? 'good';
    final foodType = offer.foodType ?? 'وجبات';

    final List<Widget> chips = [];

    if (foodType.isNotEmpty) {
      chips.add(_buildInfoChip(
        label: foodType,
        icon: Icons.restaurant_rounded,
        color: colors.primary,
      ));
    }

    chips.add(_buildInfoChip(
      label: isHalal ? '✅ حلال' : '❌ غير حلال',
      icon: isHalal ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: isHalal ? colors.primary : colors.error,
    ));

    if (isVegetarian) {
      chips.add(_buildInfoChip(
        label: '🌱 نباتي',
        icon: Icons.eco_rounded,
        color: const Color(0xFF3679C8),
      ));
    }

    if (requiresRefrigeration) {
      chips.add(_buildInfoChip(
        label: '❄️ يحتاج تبريد',
        icon: Icons.ac_unit_rounded,
        color: const Color(0xFF3679C8),
      ));
    }

    chips.add(_buildInfoChip(
      label: _getConditionLabel(foodCondition),
      icon: Icons.verified_outlined,
      color: _getConditionColor(foodCondition, colors),
    ));

    if (offer.pickupNotes != null && offer.pickupNotes!.isNotEmpty) {
      chips.add(_buildInfoChip(
        label: '📝 ملاحظات',
        icon: Icons.note_rounded,
        color: const Color(0xFFB77700),
      ));
    }

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات إضافية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (offer.pickupNotes != null && offer.pickupNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '📝 ${offer.pickupNotes}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
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

  Color _getConditionColor(String condition, ColorScheme colors) {
    switch (condition) {
      case 'new':
        return colors.primary;
      case 'very_good':
        return const Color(0xFF3679C8);
      case 'good':
        return const Color(0xFFB77700);
      case 'needs_repair':
        return colors.error;
      default:
        return colors.onSurfaceVariant;
    }
  }

  Widget _buildDescriptionCard(InstitutionOffer offer, ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 الوصف',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offer.description,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupCard(InstitutionOffer offer, ColorScheme colors) {
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: ListTile(
        leading: Icon(
          Icons.location_on_outlined,
          color: colors.primary,
        ),
        title: Text(
          'مكان الاستلام',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        subtitle: Text(
          offer.pickupLocation ?? 'يحدد لاحقاً',
          style: TextStyle(
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Action Section (مع تعطيل الزر عند الحد الأقصى)
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionSection(
      InstitutionOffer offer, int maxQuantity, ColorScheme colors) {
    if (_checkingOwner) {
      return SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (_isOwner) {
      return Card(
        elevation: 0,
        color: colors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'هذا العرض تابع لمؤسستك. الكمية تُدار من صفحة عروضي ولا يمكن طلبه من حساب المالك.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingRequest) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (_myRequest != null) {
      return _ExistingRequestCard(
        request: _myRequest!,
        pickupCode: _pickupCode,
        hasPickupCode: _hasPickupCode,
        generatingCode: _generatingCode,
        onGenerateCode: _generatePickupCode,
      );
    }

    // ✅ حدد حالة الزر
    final limitReached = _remainingToday <= 0;
    final showLimitWarning = _remainingToday <= 2 && !limitReached;
    final isButtonDisabled = _loading || limitReached || !offer.isActive;

    return Column(
      children: [
        // ✅ عرض العداد المتبقي
        if (!_loadingLimit && (limitReached || showLimitWarning))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: limitReached
                    ? colors.error.withValues(alpha: 0.1)
                    : const Color(0xFFE28B00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: limitReached
                      ? colors.error.withValues(alpha: 0.3)
                      : const Color(0xFFE28B00).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    limitReached
                        ? Icons.block_rounded
                        : Icons.warning_amber_rounded,
                    color:
                        limitReached ? colors.error : const Color(0xFFE28B00),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      limitReached
                          ? 'وصلت للحد الأقصى من الطلبات اليومية '
                              '(${InstitutionOffersRepository.dailyInstitutionRequestLimit}). '
                              'حاول تاني بكرة.'
                          : 'متبقي لك $_remainingToday من '
                              '${InstitutionOffersRepository.dailyInstitutionRequestLimit} '
                              'طلبات النهارده',
                      style: TextStyle(
                        color: limitReached
                            ? colors.error
                            : const Color(0xFFB77700),
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

        Card(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'الكمية المطلوبة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: (_quantity <= 1 || isButtonDisabled)
                      ? null
                      : () => setState(() => _quantity--),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colors.primary,
                  ),
                ),
                Text(
                  '$_quantity',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: colors.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: (_quantity >= maxQuantity || isButtonDisabled)
                      ? null
                      : () => setState(() => _quantity++),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ✅ الزر معطّل نهائياً عند الحد الأقصى أو أثناء التحميل
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isButtonDisabled ? null : _requestOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.primary.withValues(alpha: 0.25),
              disabledForegroundColor: colors.onPrimary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Icon(
                    limitReached
                        ? Icons.lock_rounded
                        : Icons.shopping_bag_outlined,
                  ),
            label: Text(
              _loading
                  ? 'جارٍ إرسال الطلب...'
                  : (limitReached ? 'وصلت للحد اليومي' : 'اطلب العرض الآن'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ✅ Widgets مساعدة
// ============================================================

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 56,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = status == 'active';
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.pause_circle,
        size: 18,
        color: active ? colors.primary : const Color(0xFF8B5E34),
      ),
      label: Text(
        active ? 'العرض متاح' : 'العرض غير متاح',
        style: TextStyle(
          color: active ? colors.primary : const Color(0xFF8B5E34),
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: active
          ? colors.primary.withValues(alpha: 0.1)
          : const Color(0xFF8B5E34).withValues(alpha: 0.1),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ExistingRequestCard extends StatelessWidget {
  final InstitutionOfferRequest request;
  final String? pickupCode;
  final bool hasPickupCode;
  final bool generatingCode;
  final VoidCallback onGenerateCode;

  const _ExistingRequestCard({
    required this.request,
    required this.pickupCode,
    required this.hasPickupCode,
    required this.generatingCode,
    required this.onGenerateCode,
  });

  String get _statusLabel {
    switch (request.status) {
      case 'pending':
        return '⏳ طلبك قيد المراجعة';
      case 'accepted':
        return '✅ تم قبول طلبك';
      case 'ready_for_pickup':
        return '📦 طلبك جاهز للاستلام';
      case 'picked_up':
        return '📋 تم تأكيد الاستلام';
      case 'completed':
        return '🎉 اكتمل الطلب';
      default:
        return '📌 لديك طلب سابق على هذا العرض';
    }
  }

  Color get _statusColor {
    switch (request.status) {
      case 'pending':
        return const Color(0xFFE28B00);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'ready_for_pickup':
        return const Color(0xFF0B7650);
      case 'picked_up':
        return const Color(0xFF6651B5);
      case 'completed':
        return const Color(0xFF0B7650);
      default:
        return const Color(0xFF71837C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canCreateCode = request.status == 'ready_for_pickup';
    final showCode =
        hasPickupCode && pickupCode != null && pickupCode!.isNotEmpty;

    return Card(
      elevation: 0,
      color: _statusColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _statusColor.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: _statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'الكمية المطلوبة: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  '${request.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            if (canCreateCode) ...[
              const SizedBox(height: 14),
              if (showCode) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '✅ كود الاستلام',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pickupCode!,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 32,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w900,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⏰ اعرض هذا الكود للمؤسسة عند الاستلام',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: pickupCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📋 تم نسخ الكود'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('نسخ الكود'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: generatingCode ? null : onGenerateCode,
                        icon: generatingCode
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('تحديث الكود'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
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
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: generatingCode ? null : onGenerateCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: generatingCode
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.pin_outlined),
                    label: Text(
                      generatingCode
                          ? 'جارٍ إنشاء الكود...'
                          : '🔑 إنشاء كود الاستلام',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (!canCreateCode && !showCode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'لن يظهر زر طلب العرض مرة أخرى لهذا الحساب. تابع حالة طلبك من طلباتي.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
