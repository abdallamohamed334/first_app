import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/data/repositories/business_repository.dart';

class PickupRequestsPage extends StatefulWidget {
  final String businessId;

  const PickupRequestsPage({
    super.key,
    required this.businessId,
  });

  @override
  State<PickupRequestsPage> createState() => _PickupRequestsPageState();
}

class _PickupRequestsPageState extends State<PickupRequestsPage> {
  late final BusinessRepository _repository;
  StreamSubscription<List<Map<String, dynamic>>>? _requestsSubscription;

  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'all';
  String? _processingRequestId;

  final List<String> _filters = const [
    'all',
    'pending',
    'accepted',
    'cancelled',
    'ready_for_pickup',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _repository = BusinessRepository(SupabaseService());
    _loadRequests();
    _subscribeToRequests();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToRequests() async {
    await _requestsSubscription?.cancel();

    final client = SupabaseService().client;
    _requestsSubscription = client
        .from('offer_requests')
        .stream(primaryKey: ['id'])
        .order('requested_at', ascending: false)
        .listen(
          (_) {
            if (!mounted) return;
            // أي Insert أو Update أو Delete يعيد تحميل البيانات المرتبطة بالمطعم.
            _loadRequests(showLoader: false);
          },
          onError: (error) {
            debugPrint('❌ Offer request realtime error: $error');
          },
        );
  }

  Future<void> _loadRequests({bool showLoader = true}) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final status = _filter == 'all' ? null : _filter;
      final requests = await _repository.getPickupRequests(
        widget.businessId,
        status: status,
      );

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء تحميل الطلبات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    final confirmed = await _showResponseDialog(accept: accept);
    if (!confirmed || !mounted) return;

    setState(() => _processingRequestId = requestId);

    final success = await _repository.respondToRequest(
      requestId: requestId,
      businessId: widget.businessId,
      accept: accept,
    );

    if (!mounted) return;
    setState(() => _processingRequestId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (accept
                  ? '✅ تم قبول الطلب وإرسال إشعار للمستخدم'
                  : '✅ تم رفض الطلب وإرسال إشعار للمستخدم')
              : '❌ لم يتم تحديث الطلب، ربما تمت معالجته من جهاز آخر',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (success) {
      await _loadRequests(showLoader: false);
    }
  }

  Future<bool> _showResponseDialog({required bool accept}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(accept ? 'قبول طلب الحجز؟' : 'رفض طلب الحجز؟'),
          content: Text(
            accept
                ? 'سيتم قبول الطلب وتغيير حالة العرض إلى محجوز، وسيصل إشعار للمستخدم.'
                : 'سيتم رفض الطلب وإلغاء الحجز، وسيعود العرض إلى الحالة المتاحة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: accept ? Colors.green : Colors.red,
              ),
              child: Text(accept ? 'قبول' : 'رفض'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'طلبات الحجز',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => _loadRequests(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pendingCount =
        _requests.where((r) => r['status'] == 'pending').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF087F5B), Color(0xFF12B886)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلبات العملاء',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pendingCount == 0
                      ? 'لا توجد طلبات معلقة حاليًا'
                      : 'لديك $pendingCount طلب يحتاج إلى مراجعة',
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF087F5B),
              child: Text(
                '$pendingCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 62,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = filter == _filter;

          return ChoiceChip(
            label: Text(_getFilterLabel(filter)),
            selected: selected,
            onSelected: (_) {
              setState(() => _filter = filter);
              _loadRequests();
            },
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: const Color(0xFFF1F3F5),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 58, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadRequests(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadRequests(showLoader: false),
        child: ListView(
          children: const [
            SizedBox(height: 150),
            Icon(Icons.inbox_rounded, size: 76, color: Colors.grey),
            SizedBox(height: 14),
            Center(child: Text('لا توجد طلبات في هذه الحالة')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRequests(showLoader: false),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final user = request['users'] is Map
        ? Map<String, dynamic>.from(request['users'] as Map)
        : <String, dynamic>{};
    final offer = request['food_offers'] is Map
        ? Map<String, dynamic>.from(request['food_offers'] as Map)
        : <String, dynamic>{};
    final status = request['status']?.toString() ?? 'pending';
    final requestId = request['id']?.toString() ?? '';
    final isProcessing = _processingRequestId == requestId;
    final requestedAt =
        DateTime.tryParse(request['requested_at']?.toString() ?? '');

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: _getStatusColor(status).withAlpha(35),
                  child: Icon(
                    Icons.person_rounded,
                    color: _getStatusColor(status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name']?.toString() ?? 'مستخدم',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['phone']?.toString() ?? 'بدون رقم هاتف',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer['title']?.toString() ?? 'عرض طعام',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'الكمية: ${offer['quantity'] ?? 0}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  requestedAt == null
                      ? 'وقت غير معروف'
                      : _formatDateTime(requestedAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              if (isProcessing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _respondToRequest(
                          requestId: requestId,
                          accept: false,
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _respondToRequest(
                          requestId: requestId,
                          accept: true,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('قبول'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            if (status == 'accepted') ...[
              _infoMessage('تم قبول الطلب. جهّز العرض ثم اضغط «جهزت الطلب».',
                  Colors.blue),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _markReadyForPickup(requestId),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_rounded),
                  label: Text(isProcessing ? 'جاري التحديث...' : 'جهزت الطلب'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            if (status == 'cancelled')
              _infoMessage('تم رفض أو إلغاء هذا الطلب.', Colors.red),
            if (status == 'ready_for_pickup') ...[
              _infoMessage('العرض جاهز للاستلام.', Colors.green),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final confirmed = await _showConfirmPickupDialog();
                    if (confirmed) await _confirmPickup(requestId);
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('تأكيد الاستلام'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
            if (status == 'completed')
              _infoMessage('تم إكمال عملية الاستلام.', Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withAlpha(28),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoMessage(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Future<bool> _showConfirmPickupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: const Text('هل تم استلام الطعام فعلًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _markReadyForPickup(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجهيز الطلب'),
        content: const Text(
          'بعد التأكيد سيصل للمستخدم إشعار بأن الطلب جاهز للاستلام.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد التجهيز'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingRequestId = requestId);

    final success = await _repository.markReadyForPickup(
      requestId: requestId,
      businessId: widget.businessId,
    );

    if (!mounted) return;
    setState(() => _processingRequestId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ تم تحديث الطلب إلى جاهز للاستلام وإرسال الإشعار'
              : '❌ لم يتم تحديث الطلب، ربما تمت معالجته من جهاز آخر',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) await _loadRequests(showLoader: false);
  }

  Future<void> _confirmPickup(String requestId) async {
    final success = await _repository.confirmPickup(
      requestId: requestId,
      businessId: widget.businessId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(success ? '✅ تم تأكيد الاستلام' : '❌ لم يتم تأكيد الاستلام'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    if (success) await _loadRequests(showLoader: false);
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'الكل';
      case 'pending':
        return 'معلقة';
      case 'accepted':
        return 'مقبولة';
      case 'cancelled':
        return 'مرفوضة';
      case 'ready_for_pickup':
        return 'جاهزة للاستلام';
      case 'completed':
        return 'مكتملة';
      default:
        return filter;
    }
  }

  String _getStatusLabel(String status) => _getFilterLabel(status);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
