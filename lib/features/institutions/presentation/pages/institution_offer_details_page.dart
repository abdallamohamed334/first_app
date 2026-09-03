// lib/features/institutions/presentation/pages/institution_offer_details_page.dart

import 'package:flutter/material.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import '../../domain/entities/institution_offer_request.dart';

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
  int _imageIndex = 0;
  late final PageController _imageController;

  static const _primary = Color(0xFF0B7650);
  static const _primaryDark = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceVariant = Color(0xFFE8F0EC);
  static const _muted = Color(0xFF71837C);
  static const _accent = Color(0xFFE28B00);
  static const _error = Color(0xFFD64545);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _imageController = PageController();
    _loadOwnership();
    _loadMyRequest();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRequest() async {
    try {
      final request = await _repository.getMyRequestForOffer(widget.offer.id);
      if (!mounted) return;
      setState(() {
        _myRequest = request;
        _loadingRequest = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRequest = false);
    }
  }

  Future<void> _generatePickupCode() async {
    final request = _myRequest;
    if (_generatingCode || request == null) return;
    setState(() => _generatingCode = true);
    try {
      final result = await _repository.generatePickupCode(request.id);
      if (!mounted) return;
      setState(() => _pickupCode = result['pickup_code']?.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إنشاء كود الاستلام. اعرضه للمؤسسة عند الاستلام.'),
          backgroundColor: _primary,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ تعذر إنشاء كود الاستلام حاليًا'),
          backgroundColor: _error,
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

  Future<void> _requestOffer() async {
    if (_loading || _isOwner || _myRequest != null) return;
    setState(() => _loading = true);
    try {
      await _repository.requestOffer(
        offerId: widget.offer.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال طلبك بنجاح'),
          backgroundColor: _primary,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ تعذر طلب العرض حاليًا، حاول مرة أخرى'),
          backgroundColor: _error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ حساب حالة الصلاحية
  Map<String, dynamic> _getExpiryStatus() {
    final expiryDate = widget.offer.expiresAt;
    if (expiryDate == null) {
      return {
        'label': 'صلاحية غير محددة',
        'color': _muted,
        'icon': Icons.help_outline_rounded,
      };
    }

    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) {
      return {
        'label': 'منتهي الصلاحية',
        'color': _error,
        'icon': Icons.warning_amber_rounded,
      };
    } else if (daysLeft <= 3) {
      return {
        'label': 'ينتهي خلال $daysLeft أيام',
        'color': _accent,
        'icon': Icons.timer_outlined,
      };
    } else if (daysLeft <= 7) {
      return {
        'label': 'طازج - $daysLeft يوم متبقي',
        'color': _primary,
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
    final maxQuantity = offer.remainingQuantity.clamp(1, 999999);
    final expiryStatus = _getExpiryStatus();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'تفاصيل العرض',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _primaryDark,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(offer),
            const SizedBox(height: 16),
            _buildMainCard(offer, expiryStatus),
            const SizedBox(height: 16),
            _buildMetricsCard(offer),
            const SizedBox(height: 16),
            _buildAdditionalInfoCard(offer),
            const SizedBox(height: 16),
            if (offer.description.isNotEmpty) _buildDescriptionCard(offer),
            const SizedBox(height: 16),
            _buildPickupCard(offer),
            const SizedBox(height: 16),
            _buildActionSection(offer, maxQuantity),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(InstitutionOffer offer) {
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
                          color: _surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: _primary,
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
                  color:
                      index == _imageIndex ? _primary : const Color(0xFFB9CEC3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMainCard(
      InstitutionOffer offer, Map<String, dynamic> expiryStatus) {
    return Card(
      elevation: 0,
      color: _surface,
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
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: _primaryDark,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 17,
                  color: _primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${offer.institutionName} • ${offer.institutionType ?? 'مؤسسة'}',
                    style: const TextStyle(
                      color: _muted,
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
                // ✅ عرض حالة الصلاحية
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (expiryStatus['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (expiryStatus['color'] as Color).withOpacity(0.2),
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

  Widget _buildMetricsCard(InstitutionOffer offer) {
    return Card(
      elevation: 0,
      color: _surface,
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

  Widget _buildAdditionalInfoCard(InstitutionOffer offer) {
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
        color: _primary,
      ));
    }

    chips.add(_buildInfoChip(
      label: isHalal ? '✅ حلال' : '❌ غير حلال',
      icon: isHalal ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: isHalal ? _primary : _error,
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
      color: _getConditionColor(foodCondition),
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
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات إضافية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _primaryDark,
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
                  color: _surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.note_rounded,
                      size: 16,
                      color: _muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '📝 ${offer.pickupNotes}',
                        style: const TextStyle(
                          color: _muted,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
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

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'new':
        return _primary;
      case 'very_good':
        return const Color(0xFF3679C8);
      case 'good':
        return const Color(0xFFB77700);
      case 'needs_repair':
        return _error;
      default:
        return _muted;
    }
  }

  Widget _buildDescriptionCard(InstitutionOffer offer) {
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 الوصف',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offer.description,
              style: const TextStyle(
                color: _muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupCard(InstitutionOffer offer) {
    return Card(
      elevation: 0,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.location_on_outlined,
          color: _primary,
        ),
        title: const Text(
          'مكان الاستلام',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          offer.pickupLocation ?? 'يحدد لاحقاً',
          style: const TextStyle(
            color: _muted,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: _muted,
        ),
      ),
    );
  }

  Widget _buildActionSection(InstitutionOffer offer, int maxQuantity) {
    if (_checkingOwner) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(
            color: _primary,
          ),
        ),
      );
    }

    if (_isOwner) {
      return Card(
        elevation: 0,
        color: const Color(0xFFE8F3ED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: _primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'هذا العرض تابع لمؤسستك. الكمية تُدار من صفحة عروضي ولا يمكن طلبه من حساب المالك.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
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
          child: CircularProgressIndicator(
            color: _primary,
          ),
        ),
      );
    }

    if (_myRequest != null) {
      return _ExistingRequestCard(
        request: _myRequest!,
        pickupCode: _pickupCode,
        generatingCode: _generatingCode,
        onGenerateCode: _generatePickupCode,
      );
    }

    return Column(
      children: [
        Card(
          elevation: 0,
          color: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'الكمية المطلوبة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _quantity <= 1 ? null : () => setState(() => _quantity--),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: _primary,
                  ),
                ),
                Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _primaryDark,
                  ),
                ),
                IconButton(
                  onPressed: _quantity >= maxQuantity
                      ? null
                      : () => setState(() => _quantity++),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: _primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: offer.isActive && !_loading ? _requestOffer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(
              _loading ? 'جارٍ إرسال الطلب...' : 'اطلب العرض الآن',
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
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFDDEBE4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 56,
          color: Color(0xFF0B7650),
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
    final active = status == 'active';
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle : Icons.pause_circle,
        size: 18,
        color: active ? const Color(0xFF0B7650) : const Color(0xFF8B5E34),
      ),
      label: Text(
        active ? 'العرض متاح' : 'العرض غير متاح',
        style: TextStyle(
          color: active ? const Color(0xFF0B7650) : const Color(0xFF8B5E34),
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: active
          ? const Color(0xFF0B7650).withOpacity(0.1)
          : const Color(0xFF8B5E34).withOpacity(0.1),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B7650),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black54,
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
  final bool generatingCode;
  final VoidCallback onGenerateCode;

  const _ExistingRequestCard({
    required this.request,
    required this.pickupCode,
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
    final canCreateCode = request.status == 'ready_for_pickup';

    return Card(
      elevation: 0,
      color: _statusColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _statusColor.withOpacity(0.15),
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
                const Text(
                  'الكمية المطلوبة: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF123F31),
                  ),
                ),
                Text(
                  '${request.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0B7650),
                  ),
                ),
              ],
            ),
            if (canCreateCode && pickupCode == null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: generatingCode ? null : onGenerateCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B7650),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    : const Icon(Icons.pin_outlined),
                label: Text(
                  generatingCode
                      ? 'جارٍ إنشاء الكود...'
                      : '🔑 إنشاء كود الاستلام',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            if (pickupCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0B7650).withOpacity(0.15),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'اعرض هذا الكود للمؤسسة عند الاستلام',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF123F31),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B7650).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pickupCode!,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 30,
                          letterSpacing: 8,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0B7650),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⏰ الكود صالح لمدة 24 ساعة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!canCreateCode && pickupCode == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'لن يظهر زر طلب العرض مرة أخرى لهذا الحساب. تابع حالة طلبك من طلباتي.',
                  style: TextStyle(
                    color: Colors.black54,
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
