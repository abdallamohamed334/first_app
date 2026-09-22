import 'package:flutter/material.dart';

import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_offer_details_page.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';

class BusinessRestaurantOffersPage extends StatefulWidget {
  const BusinessRestaurantOffersPage({super.key});

  @override
  State<BusinessRestaurantOffersPage> createState() =>
      _BusinessRestaurantOffersPageState();
}

class _BusinessRestaurantOffersPageState
    extends State<BusinessRestaurantOffersPage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);

  final _repository = BusinessRestaurantRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _repository.listMyOffers();
  }

  Future<void> _refresh() async {
    final next = _repository.listMyOffers();
    if (mounted) {
      setState(() {
        _future = next;
      });
    }
    await next;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    return rows.where((row) {
      final status = _normalizedStatus(row);
      switch (_filter) {
        case 'active':
          return status == 'active';
        case 'paused':
          return status == 'paused';
        case 'expired':
          return status == 'expired';
        case 'completed':
          return status == 'completed';
        default:
          return true;
      }
    }).toList();
  }

  String _normalizedStatus(Map<String, dynamic> row) {
    if (row['is_paused'] == true || row['paused'] == true) return 'paused';
    final status = (row['status'] ?? '').toString().toLowerCase().trim();
    if (status == 'sold_out' || status == 'soldout' || status == 'completed') {
      return 'completed';
    }
    if (status == 'expired' || _isExpired(row['expiry_time'])) return 'expired';
    if (status == 'cancelled' || status == 'canceled') return 'expired';
    return 'active';
  }

  bool _isExpired(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date != null && date.isBefore(DateTime.now());
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paused':
        return 'موقوف مؤقتًا';
      case 'expired':
        return 'منتهي';
      case 'completed':
        return 'مكتمل';
      default:
        return 'نشط';
    }
  }

  Future<void> _toggleOffer(Map<String, dynamic> offer) async {
    final current = _normalizedStatus(offer);
    if (current != 'active' && current != 'paused') return;
    final paused = current == 'active';
    try {
      await _repository.setOfferPaused(
        offerId: offer['id'].toString(),
        paused: paused,
      );
      if (!mounted) return;
      await _refresh();
      RestaurantOperationFeedback.success(
        context,
        paused ? 'تم إيقاف العرض بنجاح.' : 'تم استئناف العرض بنجاح.',
      );
    } catch (error) {
      if (!mounted) return;
      RestaurantOperationFeedback.error(
          context, 'تعذر تحديث العرض حاليًا. حاول مرة أخرى.');
    }
  }

  void _openDetails(Map<String, dynamic> offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessRestaurantOfferDetailsPage(offer: offer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
          surfaceTintColor: Colors.white,
          titleSpacing: 18,
          title: const Row(
            children: [
              Icon(Icons.restaurant_rounded, color: green, size: 22),
              SizedBox(width: 8),
              Text('جُود',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث العروض',
              onPressed: () {
                _refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _OffersLoadingView();
            }
            if (snapshot.hasError) {
              return _OffersErrorView(
                message:
                    'تعذر تحميل العروض حاليًا. اسحب لأسفل للمحاولة مرة أخرى.',
                onRetry: () async {
                  await _refresh();
                },
              );
            }
            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final visible = _filtered(all);
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
                children: [
                  const Text('عروضي المنشورة',
                      style: TextStyle(
                          color: primary,
                          fontSize: 29,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('إدارة ومتابعة العروض المتاحة للإنقاذ.',
                      style: TextStyle(color: muted, fontSize: 15)),
                  const SizedBox(height: 22),
                  _filterBar(all),
                  const SizedBox(height: 18),
                  if (visible.isEmpty)
                    _OffersEmptyView(
                      filter: _filter,
                      onAdd: () => Navigator.pop(context),
                    )
                  else
                    ...visible.map((offer) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _OfferCard(
                            offer: offer,
                            status: _normalizedStatus(offer),
                            statusLabel: _statusLabel(_normalizedStatus(offer)),
                            onOpen: () => _openDetails(offer),
                            onToggle: () => _toggleOffer(offer),
                          ),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filterBar(List<Map<String, dynamic>> rows) {
    final filters = <String, String>{
      'all': 'الكل',
      'active': 'نشط',
      'paused': 'موقوف',
      'expired': 'منتهي',
      'completed': 'مكتمل',
    };
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = filters.keys.elementAt(index);
          final selected = _filter == key;
          final count = key == 'all'
              ? rows.length
              : rows.where((row) => _normalizedStatus(row) == key).length;
          return ChoiceChip(
            selected: selected,
            label: Text('${filters[key]}  $count'),
            onSelected: (_) => setState(() => _filter = key),
            selectedColor: const Color(0xFF064E3B),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            side: BorderSide(
              color:
                  selected ? const Color(0xFF064E3B) : const Color(0xFFBFC9C3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final String status;
  final String statusLabel;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  const _OfferCard({
    required this.offer,
    required this.status,
    required this.statusLabel,
    required this.onOpen,
    required this.onToggle,
  });

  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'موعد غير محدد';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _price(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '—';
    return '${value.toString()} جنيه';
  }

  @override
  Widget build(BuildContext context) {
    final paused = status == 'paused';
    final terminal = status == 'expired' || status == 'completed';
    final title = offer['title']?.toString().trim().isNotEmpty == true
        ? offer['title'].toString()
        : 'عرض بدون عنوان';
    final quantity = offer['quantity']?.toString() ?? '—';
    // معالجة الصورة داخل build نفسه، بدون الاعتماد على دالة خارجية.
    final imageUrl = () {
      final candidates = <dynamic>[
        offer['image_url'],
        offer['image'],
        offer['cover_image'],
        if (offer['images'] is List) ...List<dynamic>.from(offer['images']),
      ];

      for (final candidate in candidates) {
        final raw = candidate?.toString().trim() ?? '';
        if (raw.isEmpty || raw == 'null') continue;
        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          return raw;
        }

        var path = raw.replaceFirst(RegExp(r'^/+'), '');
        const bucket = 'restaurant-offers';
        if (path.startsWith('$bucket/')) {
          path = path.substring(bucket.length + 1);
        }
        if (path.isNotEmpty) {
          return 'https://gsrhoqdtcyfdmvgahqvl.supabase.co'
              '/storage/v1/object/public/$bucket/$path';
        }
      }
      return null;
    }();
    final borderColor = status == 'active'
        ? const Color(0xFF0B7650)
        : status == 'expired'
            ? const Color(0xFFBA1A1A)
            : status == 'paused'
                ? const Color(0xFFFFB95F)
                : const Color(0xFFBFC9C3);
    final borderWidth = status == 'active' || status == 'expired' ? 1.8 : 1.2;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080B7650),
                  blurRadius: 13,
                  offset: Offset(0, 5)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 142,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _OfferImageFallback(),
                      )
                    else
                      const _OfferImageFallback(),
                    if (paused)
                      Container(color: Colors.white.withValues(alpha: .45)),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _StatusBadge(label: statusLabel, status: status),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('متبقي $quantity حصة',
                        style: const TextStyle(color: Color(0xFF5F6F68))),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (offer['original_price'] != null)
                                Text(_price(offer['original_price']),
                                    style: const TextStyle(
                                        color: Color(0xFF8A9791),
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 12)),
                              Text(_price(offer['sale_price']),
                                  style: const TextStyle(
                                      color: green,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        if (!terminal)
                          Text('ينتهي ${_date(offer['expiry_time'])}',
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                  color: Color(0xFF8A5B13),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              if (!terminal)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Color(0xFFE0EAE5)))),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: onOpen,
                          child: const Text('التفاصيل'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: onToggle,
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  paused ? green : const Color(0xFFBA1A1A)),
                          child: Text(paused ? 'استئناف' : 'إيقاف'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;
  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final paused = status == 'paused';
    final completed = status == 'completed';
    final color = paused
        ? const Color(0xFF8A5B13)
        : completed
            ? const Color(0xFF5F6F68)
            : status == 'expired'
                ? const Color(0xFFBA1A1A)
                : Colors.white;
    final background = paused
        ? const Color(0xFFFFF3D9)
        : completed
            ? const Color(0xFFE6EEFF)
            : status == 'expired'
                ? const Color(0xFFFFE5E1)
                : const Color(0xFF064E3B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .28))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _OfferImageFallback extends StatelessWidget {
  const _OfferImageFallback();
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE6EEFF),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_rounded,
            color: Color(0xFFBFC9C3), size: 48),
      );
}

class _OffersEmptyView extends StatelessWidget {
  final String filter;
  final VoidCallback onAdd;
  const _OffersEmptyView({required this.filter, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final title = filter == 'all'
        ? 'لا توجد عروض منشورة بعد'
        : 'لا توجد عروض في هذا التصنيف';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EAE5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: Color(0xFF7B8B84), size: 52),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF003527),
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('ستظهر عروض المطعم هنا عند نشرها من مساحة التشغيل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5F6F68))),
          if (filter == 'all') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة عرض')),
          ],
        ],
      ),
    );
  }
}

class _OffersLoadingView extends StatelessWidget {
  const _OffersLoadingView();
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          height: 260,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: const Color(0xFFE6EEFF),
              borderRadius: BorderRadius.circular(16)),
        ),
      );
}

class _OffersErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _OffersErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 50, color: Color(0xFF71837C)),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}
