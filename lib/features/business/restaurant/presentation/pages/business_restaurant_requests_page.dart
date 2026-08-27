import 'package:flutter/material.dart';

import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_page.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_pickup_page.dart';
import 'package:loqma/features/business/restaurant/presentation/widgets/business_restaurant_state_widgets.dart';
import 'package:loqma/features/business/restaurant/presentation/widgets/business_restaurant_widgets.dart';

class BusinessRestaurantRequestsPage extends StatefulWidget {
  final BusinessRestaurantRepository? repository;

  const BusinessRestaurantRequestsPage({super.key, this.repository});

  @override
  State<BusinessRestaurantRequestsPage> createState() =>
      _BusinessRestaurantRequestsPageState();
}

class _BusinessRestaurantRequestsPageState
    extends State<BusinessRestaurantRequestsPage> {
  static const green = Color(0xFF0B7650);
  static const darkGreen = Color(0xFF123F31);
  static const background = Color(0xFFF6FAF8);

  late final BusinessRestaurantRepository _repository;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BusinessRestaurantRepository();
    _future = _repository.listMyRequests();
  }

  Future<void> _refresh() async {
    final next = _repository.listMyRequests();
    if (!mounted) {
      await next;
      return;
    }
    setState(() => _future = next);
    await next;
  }

  Future<void> _updateRequestStatus(
    Map<String, dynamic> request,
    String status,
  ) async {
    final requestId =
        (request['request_id'] ?? request['id'])?.toString() ?? '';
    try {
      await _repository.updateRequestStatus(
        requestId: requestId,
        status: status,
      );
      if (!mounted) return;
      await _refresh();
      RestaurantOperationFeedback.success(
        context,
        status == 'accepted'
            ? 'تم قبول الطلب بنجاح.'
            : status == 'ready_for_pickup'
                ? 'تم تجهيز الطلب للاستلام.'
                : 'تم رفض الطلب.',
      );
    } catch (error) {
      if (!mounted) return;
      RestaurantOperationFeedback.error(context, error);
    }
  }

  void _openPickupScanner() {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BusinessRestaurantPickupScannerPage(
          repository: _repository,
        ),
      ),
    )
        .then((completed) {
      if (completed == true && mounted) _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: darkGreen,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const Text(
            'متابعة الطلبات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث الطلبات',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const BusinessRestaurantLoadingView();
            }
            if (snapshot.hasError) {
              return BusinessRestaurantErrorView(
                message: 'تعذر تحميل طلبات العروض حاليًا.',
                onRetry: _refresh,
              );
            }

            final requests = snapshot.data ?? const <Map<String, dynamic>>[];
            if (requests.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: const [
                    SizedBox(height: 90),
                    BusinessRestaurantEmptyView(
                      icon: Icons.inbox_rounded,
                      title: 'لا توجد طلبات حتى الآن',
                      message: 'ستظهر هنا طلبات المستخدمين على عروضك المنشورة.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) => _RequestCard(
                  request: requests[index],
                  onOpen: () => _showDetails(requests[index]),
                  onVerify: _openPickupScanner,
                  onAccept: () =>
                      _updateRequestStatus(requests[index], 'accepted'),
                  onReady: () =>
                      _updateRequestStatus(requests[index], 'ready_for_pickup'),
                  onReject: () =>
                      _updateRequestStatus(requests[index], 'rejected'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDetails(Map<String, dynamic> request) async {
    final status = _statusValue(request);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تفاصيل الطلب',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _detail('العرض', request['offer_title'] ?? 'عرض المطعم'),
              _detail('المستخدم', request['requester_name'] ?? 'مستخدم Loqma'),
              _detail('الكمية', request['quantity'] ?? 'غير محددة'),
              _detail('الحالة', _statusLabel(status)),
              if (status == 'accepted') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateRequestStatus(request, 'ready_for_pickup');
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('تجهيز الطلب للاستلام'),
                  ),
                ),
              ] else if (status == 'ready_for_pickup') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openPickupScanner();
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('التحقق من كود الاستلام'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String title, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text('$title: ',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Expanded(child: Text(value?.toString() ?? 'غير محدد')),
          ],
        ),
      );

  String _statusValue(Map<String, dynamic> request) =>
      (request['request_status'] ?? request['status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();

  String _statusLabel(String value) => switch (value) {
        'accepted' => 'مقبول',
        'ready_for_pickup' => 'جاهز للاستلام',
        'picked_up' => 'تم استلام الطلب',
        'completed' => 'مكتمل',
        'rejected' => 'مرفوض',
        'cancelled' => 'ملغي',
        'expired' => 'منتهي',
        _ => 'قيد المراجعة',
      };
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onOpen;
  final VoidCallback onVerify;
  final VoidCallback onAccept;
  final VoidCallback onReady;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onOpen,
    required this.onVerify,
    required this.onAccept,
    required this.onReady,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = (request['request_status'] ?? request['status'] ?? 'pending')
        .toString()
        .toLowerCase();
    final offerTitle = request['offer_title']?.toString() ?? 'عرض المطعم';
    final requester = request['requester_name']?.toString() ?? 'مستخدم Loqma';
    final isActionable = status == 'ready_for_pickup';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F5ED),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF0B7650)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(offerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF123F31),
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('طلب من $requester',
                            style: const TextStyle(
                                color: Color(0xFF71837C), fontSize: 12)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              _RequestTimeline(status: status),
              if (request['quantity'] != null) ...[
                const SizedBox(height: 14),
                Text('الكمية المطلوبة: ${request['quantity']}',
                    style: const TextStyle(
                        color: Color(0xFF123F31), fontWeight: FontWeight.w800)),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('قبول الطلب'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('رفض الطلب'),
                      ),
                    ),
                  ],
                ),
              ] else if (status == 'accepted') ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onReady,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('تجهيز للاستلام'),
                  ),
                ),
              ] else if (isActionable) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('التحقق من الاستلام'),
                  ),
                ),
              ],
            ],
          ),
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
    final rejected =
        status == 'rejected' || status == 'cancelled' || status == 'expired';
    final completed = status == 'completed' || status == 'picked_up';
    final color = rejected
        ? const Color(0xFFD84B4B)
        : completed
            ? const Color(0xFF208A5A)
            : const Color(0xFFE28B00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: color.withAlpha(22), borderRadius: BorderRadius.circular(30)),
      child: Text(
        switch (status) {
          'accepted' => 'مقبول',
          'ready_for_pickup' => 'جاهز',
          'picked_up' => 'تم الاستلام',
          'completed' => 'مكتمل',
          'rejected' => 'مرفوض',
          'cancelled' => 'ملغي',
          'expired' => 'منتهي',
          _ => 'قيد المراجعة',
        },
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RequestTimeline extends StatelessWidget {
  final String status;
  const _RequestTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final current = switch (status) {
      'accepted' => 1,
      'ready_for_pickup' => 2,
      'picked_up' => 3,
      'completed' => 4,
      _ => 0,
    };
    const labels = [
      'طلب جديد',
      'تم القبول',
      'جاهز للاستلام',
      'تم الاستلام',
      'مكتمل'
    ];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor:
                    active ? const Color(0xFF0B7650) : const Color(0xFFDCEBE3),
                child: Icon(active ? Icons.check_rounded : Icons.circle,
                    size: 12,
                    color: active ? Colors.white : const Color(0xFF8DA097)),
              ),
              const SizedBox(height: 4),
              Text(labels[index],
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 9, color: Color(0xFF71837C))),
            ],
          ),
        );
      }),
    );
  }
}
