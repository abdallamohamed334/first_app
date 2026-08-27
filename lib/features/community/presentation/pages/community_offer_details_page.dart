import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_requests_repository.dart';

class CommunityOfferDetailsPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const CommunityOfferDetailsPage({super.key, required this.offer});

  @override
  State<CommunityOfferDetailsPage> createState() =>
      _CommunityOfferDetailsPageState();
}

class _CommunityOfferDetailsPageState extends State<CommunityOfferDetailsPage> {
  final _requestsRepository = CommunityRequestsRepository();
  Map<String, dynamic>? _myRequest;
  bool _loadingRequest = true;
  bool _submitting = false;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      final requests = await _requestsRepository.getMyRequests();
      final offerId = widget.offer['id']?.toString();
      final matches = requests.where((request) {
        return request['offer_id']?.toString() == offerId;
      }).toList();
      if (!mounted) return;
      setState(() {
        _myRequest = matches.isEmpty ? null : matches.first;
        _loadingRequest = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingRequest = false);
    }
  }

  Future<void> _requestOffer() async {
    final offerId = widget.offer['id']?.toString();
    if (offerId == null || offerId.isEmpty) {
      _showMessage('العرض غير صالح');
      return;
    }

    final ownerId = widget.offer['owner_id']?.toString();
    final currentUser = _requestsRepository.currentUserId;
    if (ownerId != null && ownerId == currentUser) {
      _showMessage('لا يمكنك طلب العرض الذي نشرته أنت');
      return;
    }

    final message = await _showRequestMessageDialog();
    if (message == null) return;

    setState(() => _submitting = true);
    try {
      final request = await _requestsRepository.createRequest(
        offerId: offerId,
        message: message,
      );
      if (!mounted) return;
      setState(() => _myRequest = request);
      _showMessage('تم إرسال طلبك لصاحب العرض', success: true);
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _showRequestMessageDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _RequestMessageDialog(),
    );
    return result?.trim();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('community_requests_one_active') ||
        text.contains('duplicate key')) {
      return 'يوجد طلب نشط بالفعل لهذا العرض';
    }
    if (text.contains('العرض غير متاح')) return 'العرض لم يعد متاحًا';
    return 'تعذر إرسال الطلب. حاول مرة أخرى';
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.offer['title'] ?? 'عرض').toString();
    final description =
        (widget.offer['description'] ?? 'لا يوجد وصف').toString();
    final image = _imageUrl();
    final type = widget.offer['listing_type']?.toString() ?? 'donation';
    final category = widget.offer['category']?.toString() ?? 'clothing';
    final price = (widget.offer['price'] as num?)?.toDouble() ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF8),
        appBar: AppBar(
          title: const Text('تفاصيل العرض'),
          centerTitle: true,
          backgroundColor: const Color(0xFFF6FAF8),
          foregroundColor: _darkGreen,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 250,
                child: image == null
                    ? _fallbackImage(category)
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(category),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _tag(_categoryLabel(category), const Color(0xFFE8F5EE), _green),
                _tag(
                    type == 'symbolic_sale'
                        ? '${price.toStringAsFixed(0)} جنيه'
                        : type == 'charity_donation'
                            ? 'تبرع لجمعية'
                            : 'تبرع مجاني',
                    type == 'symbolic_sale'
                        ? const Color(0xFFFFF0DA)
                        : const Color(0xFFE8F5EE),
                    type == 'symbolic_sale' ? const Color(0xFFB36B12) : _green),
              ],
            ),
            const SizedBox(height: 18),
            _infoCard(description),
            const SizedBox(height: 16),
            _requestSection(),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String description) {
    final location = (widget.offer['pickup_location'] ?? 'غير محدد').toString();
    final condition =
        _conditionLabel(widget.offer['item_condition']?.toString());
    final quantity = widget.offer['quantity']?.toString() ?? '1';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1ECE6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('عن العرض',
            style: TextStyle(
                color: _darkGreen, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(description,
            style: const TextStyle(
                color: Color(0xFF5F786C), fontSize: 14, height: 1.6)),
        const SizedBox(height: 15),
        _row(Icons.check_circle_outline_rounded, 'الحالة', condition),
        _row(Icons.inventory_2_outlined, 'الكمية', quantity),
        _row(Icons.location_on_outlined, 'مكان الاستلام', location),
      ]),
    );
  }

  Widget _requestSection() {
    if (_loadingRequest) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _green)));
    }
    final status = _myRequest?['status']?.toString();
    if (status != null &&
        status != 'rejected' &&
        status != 'cancelled' &&
        status != 'expired') {
      return _statusCard(status);
    }
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _requestOffer,
        icon: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded),
        label: Text(_submitting ? 'جاري إرسال الطلب...' : 'اطلب العرض'),
        style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _statusCard(String status) {
    final label = {
          'pending': 'طلبك في انتظار موافقة صاحب العرض',
          'accepted': 'تم قبول طلبك، اتفق على موعد الاستلام',
          'completed': 'تم استلام العرض بنجاح'
        }[status] ??
        'حالة الطلب: $status';
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.timeline_rounded, color: _green, size: 28),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w800,
                      height: 1.4)))
        ]));
  }

  Widget _row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(icon, color: _green, size: 18),
        const SizedBox(width: 7),
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF71837C), fontSize: 12)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)))
      ]));

  Widget _tag(String text, Color background, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 11, fontWeight: FontWeight.w900)));

  Widget _fallbackImage(String category) => Container(
      color: const Color(0xFFE8F5EE),
      alignment: Alignment.center,
      child: Icon(
          category == 'furniture'
              ? Icons.chair_rounded
              : Icons.checkroom_rounded,
          color: _green,
          size: 70));

  String? _imageUrl() {
    final direct = widget.offer['image']?.toString();
    if (direct != null && direct.isNotEmpty && direct != 'null') return direct;
    final images = widget.offer['images'];
    if (images is List && images.isNotEmpty) return images.first?.toString();
    return null;
  }

  String _categoryLabel(String value) =>
      value == 'furniture' ? 'أثاث' : 'ملابس';

  String _conditionLabel(String? value) =>
      {
        'new': 'جديد أو شبه جديد',
        'very_good': 'جيد جدًا',
        'good': 'جيد',
        'needs_repair': 'يحتاج إصلاحًا بسيطًا'
      }[value] ??
      'غير محددة';
}

class _RequestMessageDialog extends StatefulWidget {
  const _RequestMessageDialog();

  @override
  State<_RequestMessageDialog> createState() => _RequestMessageDialogState();
}

class _RequestMessageDialogState extends State<_RequestMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('أرسل طلب العرض'),
        content: TextField(
          controller: _controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب رسالة قصيرة لصاحب العرض، مثل موعد الاستلام المناسب',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }
}
