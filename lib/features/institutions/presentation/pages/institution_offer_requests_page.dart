import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer_request.dart';
import 'institution_offer_request_details_page.dart';

class InstitutionOfferRequestsPage extends StatefulWidget {
  final InstitutionOffersRepository? repository;

  const InstitutionOfferRequestsPage({super.key, this.repository});

  @override
  State<InstitutionOfferRequestsPage> createState() =>
      _InstitutionOfferRequestsPageState();
}

class _InstitutionOfferRequestsPageState
    extends State<InstitutionOfferRequestsPage> {
  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOfferRequest>> _future;
  StreamSubscription? _subscription;
  String _selectedFilter = 'all';
  final Map<String, String> _pickupCodes = <String, String>{};

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF5F9F7);
  static const _muted = Color(0xFF71837C);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _future = _repository.listMyRequests();
    _subscribe();
  }

  void _subscribe() {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    _subscription = SupabaseService()
        .client
        .from('institution_offer_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', userId)
        .listen((_) {
          if (!mounted) return;
          _setFuture(_repository.listMyRequests());
        }, onError: (error) {
          debugPrint('[InstitutionRequests] realtime error: $error');
        });
  }

  void _setFuture(Future<List<InstitutionOfferRequest>> future) {
    if (!mounted) return;
    setState(() => _future = future);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = _repository.listMyRequests();
    _setFuture(future);
    await future;
  }

  Future<void> _showPickupCode(String requestId) async {
    String? code = _pickupCodes[requestId];

    if (code == null || code.isEmpty) {
      try {
        final preferences = await SharedPreferences.getInstance();
        code = preferences.getString(_pickupCodeKey(requestId));
        if (code != null && code.isNotEmpty) {
          _pickupCodes[requestId] = code;
        }
      } catch (error) {
        debugPrint(
            '[InstitutionRequests] local pickup-code read unavailable: $error');
      }
    }

    if (code == null || code.isEmpty) {
      try {
        final result = await _repository.generatePickupCode(requestId);
        code = result['pickup_code']?.toString().trim();
        if (code == null || code.isEmpty) {
          if (mounted) {
            _showMessage('تعذر الحصول على كود الاستلام', isError: true);
          }
          return;
        }
        // لا نطلب كودًا جديدًا عند الضغط مرة أخرى؛ نعيد عرض نفس الكود.
        _pickupCodes[requestId] = code;
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(_pickupCodeKey(requestId), code);
        } catch (error) {
          debugPrint(
              '[InstitutionRequests] local pickup-code write unavailable: $error');
        }
      } catch (error) {
        debugPrint('[InstitutionRequests] pickup code error: $error');
        if (mounted) {
          _showMessage(
            'يوجد كود استلام صالح بالفعل. افتح الصفحة نفسها لإظهاره مرة أخرى.',
            isError: true,
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final displayCode = code ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('كود الاستلام الخاص بك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اعرض هذا الكود للمؤسسة عند استلام طلبك.'),
            const SizedBox(height: 18),
            SelectableText(
              displayCode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _darkGreen,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  String _pickupCodeKey(String requestId) =>
      'loqma.pickup_code.${requestId.trim()}';

  Future<void> _complete(String requestId) async {
    try {
      await _repository.completeRequest(requestId);
      if (!mounted) return;
      _showMessage('تم تأكيد اكتمال الطلب', isError: false);
      await _reload();
    } catch (error) {
      debugPrint('[InstitutionRequests] complete error: $error');
      if (!mounted) return;
      _showMessage('تعذر تأكيد اكتمال الطلب', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFD64545) : _darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 20,
          title: const Text(
            'طلبات المؤسسات',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث الطلبات',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: _darkGreen),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<InstitutionOfferRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _RequestsLoading();
            }

            if (snapshot.hasError) {
              return _RequestsError(onRetry: _reload);
            }

            final requests = snapshot.data ?? const <InstitutionOfferRequest>[];
            return _buildContent(requests);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<InstitutionOfferRequest> requests) {
    final currentRequests =
        requests.where((request) => !_isExpired(request)).toList();
    final visibleRequests = currentRequests.where((request) {
      if (_selectedFilter == 'all') return true;
      return request.status == _selectedFilter;
    }).toList();

    return RefreshIndicator(
      color: _green,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _buildHero(currentRequests),
          const SizedBox(height: 18),
          _buildSummary(currentRequests),
          const SizedBox(height: 20),
          _buildFilterBar(currentRequests),
          const SizedBox(height: 16),
          if (visibleRequests.isEmpty)
            _EmptyRequests(hasFilter: _selectedFilter != 'all')
          else
            ...visibleRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RequestCard(
                  request: request,
                  onOpen: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InstitutionOfferRequestDetailsPage(
                          request: request,
                          repository: _repository,
                        ),
                      ),
                    );
                    if (mounted) await _reload();
                  },
                  onShowCode: request.status == 'ready_for_pickup'
                      ? () => _showPickupCode(request.id)
                      : null,
                  onComplete: request.status == 'picked_up'
                      ? () => _complete(request.id)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(List<InstitutionOfferRequest> requests) {
    final activeCount = requests.where((request) {
      return request.status != 'completed' &&
          request.status != 'rejected' &&
          request.status != 'cancelled' &&
          request.status != 'expired';
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _green.withAlpha(38),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_mall_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تابع طلباتك بسهولة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  activeCount == 0
                      ? 'كل طلباتك محدثة أولًا بأول'
                      : '$activeCount طلب نشط يحتاج متابعتك',
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 17),
        ],
      ),
    );
  }

  Widget _buildSummary(List<InstitutionOfferRequest> requests) {
    final active = requests.where((item) => _isActive(item.status)).length;
    final completed =
        requests.where((item) => item.status == 'completed').length;
    final waiting = requests
        .where((item) => item.status == 'pending' || item.status == 'requested')
        .length;

    return Row(
      children: [
        Expanded(
            child:
                _SummaryTile(value: '$active', label: 'نشطة', color: _green)),
        const SizedBox(width: 10),
        Expanded(
            child: _SummaryTile(
                value: '$waiting',
                label: 'قيد المراجعة',
                color: const Color(0xFFB77700))),
        const SizedBox(width: 10),
        Expanded(
            child: _SummaryTile(
                value: '$completed',
                label: 'مكتملة',
                color: const Color(0xFF1976A8))),
      ],
    );
  }

  Widget _buildFilterBar(List<InstitutionOfferRequest> requests) {
    final filters = <String, String>{
      'all': 'الكل',
      'pending': 'قيد المراجعة',
      'accepted': 'مقبولة',
      'ready_for_pickup': 'جاهزة',
      'completed': 'مكتملة',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'طلباتك',
          style: TextStyle(
              color: _darkGreen, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final key = filters.keys.elementAt(index);
              final selected = key == _selectedFilter;
              final count = key == 'all'
                  ? requests.length
                  : requests.where((item) => item.status == key).length;
              return ChoiceChip(
                selected: selected,
                label: Text('${filters[key]}  $count'),
                onSelected: (_) => setState(() => _selectedFilter = key),
                selectedColor: _green,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? _green : const Color(0xFFE0EAE5),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isActive(String status) => !{
        'completed',
        'rejected',
        'cancelled',
        'expired',
      }.contains(status);

  bool _isExpired(InstitutionOfferRequest request) {
    if (request.status == 'expired') return true;
    final expiresAt = request.offer?['expires_at'];
    final parsed = expiresAt is DateTime
        ? expiresAt
        : DateTime.tryParse(expiresAt?.toString() ?? '');
    return parsed != null && !parsed.toUtc().isAfter(DateTime.now().toUtc());
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryTile(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EEE9)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF71837C),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final InstitutionOfferRequest request;
  final VoidCallback onOpen;
  final VoidCallback? onShowCode;
  final VoidCallback? onComplete;

  const _RequestCard({
    required this.request,
    required this.onOpen,
    this.onShowCode,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final offer = request.offer ?? const <String, dynamic>{};
    final title = _text(offer['title']) ?? 'عرض مؤسسة';
    final description = _text(offer['description']);
    final institution = offer['institutions'] is Map
        ? Map<String, dynamic>.from(offer['institutions'] as Map)
        : const <String, dynamic>{};
    final institutionName = _text(institution['name']) ?? 'مؤسسة';
    final images = _offerImages(offer);
    final image = images.isNotEmpty ? images.first : null;
    final price = _text(offer['symbolic_price']);
    final remaining = _int(offer['remaining_quantity']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 166,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const _OfferPlaceholder(showLoading: true),
                      errorBuilder: (_, __, ___) => const _OfferPlaceholder(),
                    )
                  else
                    const _OfferPlaceholder(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA123F31)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 13,
                    right: 13,
                    child: _StatusChip(status: request.status),
                  ),
                  if (images.length > 1)
                    Positioned(
                      top: 13,
                      left: 13,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(110),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('${images.length} صور',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 13,
                    right: 15,
                    left: 15,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: Color(0xFF0B7650), size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          institutionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF405B50),
                              fontSize: 13,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF9BAEA5)),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 12,
                            height: 1.4)),
                  ],
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      _MetaPill(
                          icon: Icons.inventory_2_outlined,
                          label: 'الكمية ${request.quantity}'),
                      const SizedBox(width: 8),
                      if (price != null)
                        _MetaPill(
                            icon: Icons.payments_outlined,
                            label: '$price جنيه'),
                      if (remaining > 0) ...[
                        const SizedBox(width: 8),
                        _MetaPill(
                          icon: Icons.inventory_2_outlined,
                          label: 'متاح الآن $remaining',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 15),
                  _Progress(status: request.status),
                  if (onShowCode != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onShowCode,
                        icon: const Icon(Icons.password_rounded),
                        label: const Text('إظهار كود الاستلام'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B7650),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (onComplete != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onComplete,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF123F31),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('تأكيد اكتمال الطلب',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _offerImages(Map<String, dynamic> offer) {
    final result = <String>[];

    void add(dynamic value) {
      final image = value?.toString().trim();
      if (image != null && image.isNotEmpty && !result.contains(image)) {
        result.add(image);
      }
    }

    void readValue(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            add(item['url']);
            add(item['image_url']);
            add(item['path']);
          } else {
            add(item);
          }
        }
        return;
      }

      if (value is String && value.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            readValue(decoded);
            return;
          }
        } catch (_) {
          // Some legacy rows contain one plain URL instead of JSON.
        }
        add(value);
      }
    }

    readValue(offer['images']);
    readValue(offer['image_urls']);
    readValue(offer['offer_images']);
    readValue(offer['institution_offer_images']);
    add(offer['image']);
    add(offer['image_url']);
    add(offer['photo_url']);
    return result;
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF0B7650)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF315A49),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
      child: Text(_label(status),
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  static Color _color(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFF1976A8);
      case 'ready_for_pickup':
        return const Color(0xFFB77700);
      case 'picked_up':
        return const Color(0xFF8A5A00);
      case 'completed':
        return const Color(0xFF208A5A);
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return const Color(0xFFD64545);
      default:
        return const Color(0xFF8A6B20);
    }
  }

  static String _label(String status) {
    switch (status) {
      case 'accepted':
        return 'تم القبول';
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

class _Progress extends StatelessWidget {
  final String status;
  const _Progress({required this.status});

  @override
  Widget build(BuildContext context) {
    const labels = ['أرسلته', 'تم القبول', 'جاهز', 'تم الاستلام', 'مكتمل'];
    final current = switch (status) {
      'accepted' => 1,
      'ready_for_pickup' => 2,
      'picked_up' => 3,
      'completed' => 4,
      _ => 0,
    };

    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Container(
                          height: 3,
                          color: index == 0
                              ? Colors.transparent
                              : (active
                                  ? const Color(0xFF0B7650)
                                  : const Color(0xFFE1ECE6)))),
                  Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF0B7650)
                              : const Color(0xFFE1ECE6),
                          shape: BoxShape.circle),
                      child: Icon(active ? Icons.check_rounded : Icons.circle,
                          size: 11,
                          color:
                              active ? Colors.white : const Color(0xFF9BAEA5))),
                  Expanded(
                      child: Container(
                          height: 3,
                          color: index == labels.length - 1
                              ? Colors.transparent
                              : (index < current
                                  ? const Color(0xFF0B7650)
                                  : const Color(0xFFE1ECE6)))),
                ],
              ),
              const SizedBox(height: 5),
              Text(labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 8,
                      color: active
                          ? const Color(0xFF315A49)
                          : const Color(0xFF9BAEA5),
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        );
      }),
    );
  }
}

class _OfferPlaceholder extends StatelessWidget {
  final bool showLoading;
  const _OfferPlaceholder({this.showLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDDF3E8),
      child: Center(
        child: showLoading
            ? const CircularProgressIndicator(color: Color(0xFF0B7650))
            : const Icon(Icons.storefront_rounded,
                size: 56, color: Color(0xFF0B7650)),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  final bool hasFilter;
  const _EmptyRequests({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4EEE9))),
      child: Column(
        children: [
          Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                  color: Color(0xFFF0F8F3), shape: BoxShape.circle),
              child: const Icon(Icons.inbox_rounded,
                  color: Color(0xFF0B7650), size: 34)),
          const SizedBox(height: 16),
          Text(
              hasFilter
                  ? 'لا توجد طلبات بهذه الحالة'
                  : 'لم تطلب أي عرض مؤسسات حتى الآن',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF123F31),
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          const Text(
              'عندما تطلب عرضًا من مؤسسة سيظهر هنا ويمكنك متابعة حالته خطوة بخطوة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF71837C), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

class _RequestsLoading extends StatelessWidget {
  const _RequestsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
            height: 120,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(26))),
        const SizedBox(height: 16),
        Row(
          children: List<Widget>.generate(
            3,
            (_) => Expanded(
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...List<Widget>.generate(
          2,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestsError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _RequestsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFD64545), size: 48),
            const SizedBox(height: 14),
            const Text('تعذر تحميل طلباتك',
                style: TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('تحقق من الاتصال وحاول مرة أخرى.',
                style: TextStyle(color: Color(0xFF71837C))),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}
