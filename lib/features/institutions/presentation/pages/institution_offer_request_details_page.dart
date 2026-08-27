import 'package:flutter/material.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer_request.dart';

class InstitutionOfferRequestDetailsPage extends StatefulWidget {
  final InstitutionOfferRequest request;
  final InstitutionOffersRepository? repository;

  const InstitutionOfferRequestDetailsPage({
    super.key,
    required this.request,
    this.repository,
  });

  @override
  State<InstitutionOfferRequestDetailsPage> createState() =>
      _InstitutionOfferRequestDetailsPageState();
}

class _InstitutionOfferRequestDetailsPageState
    extends State<InstitutionOfferRequestDetailsPage> {
  late final InstitutionOffersRepository _repository;
  late InstitutionOfferRequest _request;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _request = widget.request;
  }

  Future<void> _complete() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _repository.completeRequest(_request.id);
      if (!mounted) return;
      setState(() {
        _request = InstitutionOfferRequest.fromJson({
          'id': _request.id,
          'offer_id': _request.offerId,
          'requester_id': _request.requesterId,
          'quantity': _request.quantity,
          'status': 'completed',
          'created_at': _request.createdAt?.toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'institution_offers': _request.offer,
        });
      });
      _showMessage('تم تأكيد اكتمال الطلب', isError: false);
    } catch (error) {
      debugPrint('[InstitutionRequestDetails] complete error: $error');
      if (mounted) _showMessage('تعذر تأكيد اكتمال الطلب', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFD64545) : const Color(0xFF123F31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = _request.offer ?? const <String, dynamic>{};
    final title = _text(offer['title']) ?? 'عرض مؤسسة';
    final description = _text(offer['description']);
    final institution = offer['institutions'] is Map
        ? Map<String, dynamic>.from(offer['institutions'] as Map)
        : const <String, dynamic>{};
    final institutionName = _text(institution['name']) ?? 'مؤسسة';
    final images = _imagesFromOffer(offer);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F9F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF5F9F7),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'تفاصيل الطلب',
            style: TextStyle(
                color: Color(0xFF123F31), fontWeight: FontWeight.w900),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF123F31)),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: [
            _OfferGallery(
                images: images, title: title, status: _request.status),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 26,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: Color(0xFF0B7650), size: 19),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(institutionName,
                        style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 14,
                            fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 18),
            _RequestProgress(status: _request.status),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                    child: _InfoCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'الكمية المطلوبة',
                        value: '${_request.quantity}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _InfoCard(
                        icon: Icons.payments_outlined,
                        label: 'السعر الرمزي',
                        value: '${offer['symbolic_price'] ?? '—'} جنيه')),
              ],
            ),
            const SizedBox(height: 10),
            _WideInfoCard(
                icon: Icons.location_on_outlined,
                label: 'مكان الاستلام',
                value: '${offer['pickup_location'] ?? 'يحدد لاحقًا'}'),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: 'عن العرض',
                icon: Icons.notes_rounded,
                child: Text(description,
                    style: const TextStyle(
                        color: Color(0xFF405B50), height: 1.7, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 18),
            if (_request.status == 'ready_for_pickup')
              const _NoticeCard(
                icon: Icons.info_outline_rounded,
                title: 'العرض جاهز للاستلام',
                message:
                    'توجه إلى نقطة التسليم واتبع تعليمات المؤسسة لإتمام الاستلام.',
              ),
            if (_request.status == 'picked_up') ...[
              const _NoticeCard(
                icon: Icons.task_alt_rounded,
                title: 'تم استلام الطلب',
                message: 'أكد اكتمال الطلب بعد استلام الكمية المطلوبة بالكامل.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _complete,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF123F31),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_loading ? 'جارٍ الحفظ...' : 'تأكيد اكتمال الطلب',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static List<String> _imagesFromOffer(Map<String, dynamic> offer) {
    final result = <String>[];
    final rawImages = offer['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        final image = item?.toString().trim();
        if (image != null && image.isNotEmpty && !result.contains(image))
          result.add(image);
      }
    }
    for (final key in ['image', 'image_url']) {
      final image = _text(offer[key]);
      if (image != null && !result.contains(image)) result.add(image);
    }
    return result;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'تم قبول الطلب';
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      case 'expired':
        return 'منتهي';
      default:
        return 'قيد المراجعة';
    }
  }
}

class _OfferGallery extends StatefulWidget {
  final List<String> images;
  final String title;
  final String status;

  const _OfferGallery(
      {required this.images, required this.title, required this.status});

  @override
  State<_OfferGallery> createState() => _OfferGalleryState();
}

class _OfferGalleryState extends State<_OfferGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 285,
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3E8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x190B7650), blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (widget.images.isEmpty)
            const _GalleryPlaceholder()
          else
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, index) => Image.network(
                widget.images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _GalleryPlaceholder(),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const _GalleryPlaceholder(showLoading: true),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xAA123F31)])),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _StatusBadge(status: widget.status),
          ),
          if (widget.images.length > 1)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          if (widget.images.length > 1) ...[
            Positioned(
              right: 12,
              top: 122,
              child: _GalleryButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _controller.previousPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut)),
            ),
            Positioned(
              left: 12,
              top: 122,
              child: _GalleryButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut)),
            ),
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      widget.images.length,
                      (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: index == _index
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(10))))),
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GalleryButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.black.withAlpha(90),
      shape: const CircleBorder(),
      child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(icon, color: Colors.white, size: 23))));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: _color(status), borderRadius: BorderRadius.circular(12)),
      child: Text(_label(status),
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)));
  static Color _color(String status) => status == 'completed'
      ? const Color(0xFF208A5A)
      : status == 'rejected' || status == 'cancelled' || status == 'expired'
          ? const Color(0xFFD64545)
          : status == 'ready_for_pickup'
              ? const Color(0xFFB77700)
              : const Color(0xFF1976A8);
  static String _label(String status) => switch (status) {
        'accepted' => 'مقبول',
        'ready_for_pickup' => 'جاهز للاستلام',
        'picked_up' => 'تم الاستلام',
        'completed' => 'مكتمل',
        'rejected' => 'مرفوض',
        'cancelled' => 'ملغي',
        'expired' => 'منتهي',
        _ => 'قيد المراجعة'
      };
}

class _GalleryPlaceholder extends StatelessWidget {
  final bool showLoading;
  const _GalleryPlaceholder({this.showLoading = false});
  @override
  Widget build(BuildContext context) => Center(
      child: showLoading
          ? const CircularProgressIndicator(color: Color(0xFF0B7650))
          : const Icon(Icons.image_not_supported_outlined,
              color: Color(0xFF0B7650), size: 58));
}

class _RequestProgress extends StatelessWidget {
  final String status;
  const _RequestProgress({required this.status});
  @override
  Widget build(BuildContext context) {
    const labels = ['أرسلته', 'تم القبول', 'جاهز', 'استلمته', 'مكتمل'];
    final current = switch (status) {
      'accepted' => 1,
      'ready_for_pickup' => 2,
      'picked_up' => 3,
      'completed' => 4,
      _ => 0
    };
    return Container(
        padding: const EdgeInsets.fromLTRB(12, 15, 12, 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE3EEE8))),
        child: Row(
            children: List.generate(labels.length, (index) {
          final active = index <= current;
          return Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                  child: Container(
                      height: 3,
                      color: index == 0
                          ? Colors.transparent
                          : (active
                              ? const Color(0xFF0B7650)
                              : const Color(0xFFE1ECE6)))),
              Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF0B7650)
                          : const Color(0xFFE1ECE6),
                      shape: BoxShape.circle),
                  child: Icon(active ? Icons.check_rounded : Icons.circle,
                      size: 11,
                      color: active ? Colors.white : const Color(0xFF9BAEA5))),
              Expanded(
                  child: Container(
                      height: 3,
                      color: index == labels.length - 1
                          ? Colors.transparent
                          : (index < current
                              ? const Color(0xFF0B7650)
                              : const Color(0xFFE1ECE6))))
            ]),
            const SizedBox(height: 5),
            Text(labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 8,
                    color: active
                        ? const Color(0xFF315A49)
                        : const Color(0xFF9BAEA5),
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500))
          ]));
        })));
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE3EEE8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF0B7650), size: 22),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 11,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Color(0xFF123F31),
                fontSize: 15,
                fontWeight: FontWeight.w900))
      ]));
}

class _WideInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WideInfoCard(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFE3EEE8))),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFFF0F8F3), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF0B7650), size: 21)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF71837C),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF123F31),
                  fontSize: 14,
                  fontWeight: FontWeight.w800))
        ]))
      ]));
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE3EEE8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: const Color(0xFF0B7650), size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF123F31),
                  fontSize: 16,
                  fontWeight: FontWeight.w900))
        ]),
        const SizedBox(height: 10),
        child
      ]));
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _NoticeCard(
      {required this.icon, required this.title, required this.message});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFF0D99B))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            color: Color(0xFFB77700), size: 23),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF6C4C1C),
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(message,
              style: const TextStyle(
                  color: Color(0xFF806333), fontSize: 12, height: 1.5))
        ]))
      ]));
}
