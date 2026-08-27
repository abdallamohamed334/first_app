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
            content:
                Text('تم إنشاء كود الاستلام. اعرضه للمؤسسة عند الاستلام.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء كود الاستلام حاليًا')),
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
        const SnackBar(content: Text('تم إرسال طلبك بنجاح')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر طلب العرض حاليًا، حاول مرة أخرى')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final maxQuantity = offer.remainingQuantity.clamp(1, 999999);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F9F7),
        appBar: AppBar(
          title: const Text('تفاصيل العرض',
              style: TextStyle(fontWeight: FontWeight.w900)),
          centerTitle: true,
          backgroundColor: const Color(0xFFF6F9F7),
          foregroundColor: const Color(0xFF123F31),
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (offer.images.isNotEmpty)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 1.18,
                      child: PageView.builder(
                        controller: _imageController,
                        itemCount: offer.images.length,
                        onPageChanged: (index) =>
                            setState(() => _imageIndex = index),
                        itemBuilder: (_, index) => Image.network(
                          offer.images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImageFallback(),
                        ),
                      ),
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
                                ? const Color(0xFF0B7650)
                                : const Color(0xFFB9CEC3),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              const _ImageFallback(),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title,
                        style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF064E3B))),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 17, color: Color(0xFF0B7650)),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                '${offer.institutionName} • ${offer.institutionType ?? 'مؤسسة'}',
                                style: const TextStyle(
                                    color: Color(0xFF71837C),
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StatusBadge(status: offer.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
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
                            value:
                                '${offer.symbolicPrice.toStringAsFixed(2)} جنيه')),
                    SizedBox(
                        width: 82,
                        child: _Metric(
                            label: 'إجمالي الكمية',
                            value: '${offer.quantity}')),
                    SizedBox(
                        width: 82,
                        child: _Metric(
                            label: 'المتبقي',
                            value: '${offer.remainingQuantity}')),
                  ],
                ),
              ),
            ),
            if (offer.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                  elevation: 0,
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(offer.description))),
            ],
            const SizedBox(height: 12),
            Card(
                elevation: 0,
                child: ListTile(
                    leading: const Icon(Icons.location_on_outlined,
                        color: Color(0xFF0B7650)),
                    title: const Text('مكان الاستلام'),
                    subtitle: Text(offer.pickupLocation ?? 'يحدد لاحقًا'))),
            const SizedBox(height: 14),
            if (_checkingOwner)
              const SizedBox(
                height: 52,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_isOwner)
              Card(
                elevation: 0,
                color: const Color(0xFFE8F3ED),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF0B7650)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذا العرض تابع لمؤسستك. الكمية تُدار من صفحة عروضي ولا يمكن طلبه من حساب المالك.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_loadingRequest)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myRequest != null)
              _ExistingRequestCard(
                request: _myRequest!,
                pickupCode: _pickupCode,
                generatingCode: _generatingCode,
                onGenerateCode: _generatePickupCode,
              )
            else ...[
              Row(
                children: [
                  const Expanded(
                      child: Text('الكمية المطلوبة',
                          style: TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: _quantity <= 1
                          ? null
                          : () => setState(() => _quantity--),
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$_quantity',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18)),
                  IconButton(
                      onPressed: _quantity >= maxQuantity
                          ? null
                          : () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: offer.isActive && !_loading ? _requestOffer : null,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                      _loading ? 'جارٍ إرسال الطلب...' : 'اطلب العرض الآن'),
                ),
              ),
            ],
          ],
        ),
      ),
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
        return 'طلبك قيد المراجعة';
      case 'accepted':
        return 'تم قبول طلبك';
      case 'ready_for_pickup':
        return 'طلبك جاهز للاستلام';
      case 'picked_up':
        return 'تم تأكيد الاستلام';
      case 'completed':
        return 'اكتمل الطلب';
      default:
        return 'لديك طلب سابق على هذا العرض';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreateCode = request.status == 'ready_for_pickup';
    return Card(
      elevation: 0,
      color: const Color(0xFFE8F3ED),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: Color(0xFF0B7650)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_statusLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF064E3B)))),
              ],
            ),
            const SizedBox(height: 8),
            Text('الكمية المطلوبة: ${request.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (canCreateCode && pickupCode == null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: generatingCode ? null : onGenerateCode,
                icon: generatingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.pin_outlined),
                label: Text(generatingCode
                    ? 'جارٍ إنشاء الكود...'
                    : 'إنشاء كود الاستلام'),
              ),
            ],
            if (pickupCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text('اعرض هذا الكود للمؤسسة عند الاستلام والدفع',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(pickupCode!,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontSize: 30,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0B7650))),
                  ],
                ),
              ),
            ],
            if (!canCreateCode && pickupCode == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'لن يظهر زر طلب العرض مرة أخرى لهذا الحساب. تابع حالة طلبك من طلباتي.',
                    style: TextStyle(color: Colors.black54)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => Container(
      height: 190,
      decoration: BoxDecoration(
          color: const Color(0xFFDDEBE4),
          borderRadius: BorderRadius.circular(22)),
      child: const Center(
          child:
              Icon(Icons.image_outlined, size: 56, color: Color(0xFF0B7650))));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    return Chip(
        avatar: Icon(active ? Icons.check_circle : Icons.pause_circle,
            size: 18,
            color: active ? const Color(0xFF0B7650) : const Color(0xFF8B5E34)),
        label: Text(active ? 'العرض متاح' : 'العرض غير متاح'));
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B7650))),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54))
      ]);
}
