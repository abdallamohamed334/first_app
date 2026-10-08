// lib/features/institutions/presentation/pages/institution_booking_details_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';

// ✅ تعريف الألوان خارج الكلاس
const Color _primary = Color(0xFF0B7650);
const Color _primaryDark = Color(0xFF123F31);
const Color _background = Color(0xFFF6FAF8);
const Color _surface = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF71837C);
const Color _accent = Color(0xFFE28B00);
const Color _errorColor = Color(0xFFD64545);

class InstitutionBookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final InstitutionOffersRepository repository;

  const InstitutionBookingDetailsPage({
    super.key,
    required this.booking,
    required this.repository,
  });

  @override
  State<InstitutionBookingDetailsPage> createState() =>
      _InstitutionBookingDetailsPageState();
}

class _InstitutionBookingDetailsPageState
    extends State<InstitutionBookingDetailsPage> {
  late Map<String, dynamic> _booking;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.repository.findBookingById(
        _booking['id'].toString(),
      );
      if (result != null && mounted) {
        setState(() {
          _booking = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await widget.repository.updateOfferRequest(
        requestId: _booking['id'].toString(),
        accept: newStatus == 'accepted',
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? '✅ تم قبول الحجز بنجاح'
                  : '❌ تم رفض الحجز',
            ),
            backgroundColor: newStatus == 'accepted' ? _primary : _errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _markReady() async {
    setState(() => _isLoading = true);
    try {
      await widget.repository.markOfferRequestReady(
        _booking['id'].toString(),
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📦 تم تجهيز الطلب للاستلام'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  // ✅ البقالة تتحقق من كود العميل
  Future<void> _verifyPickupCode() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('🔐 التحقق من كود العميل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل كود الاستلام الذي أعطاك إياه العميل:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'كود الاستلام (6 أرقام)',
                hintText: 'أدخل الكود من العميل',
                prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
            ),
            child: const Text('تأكيد الاستلام'),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await widget.repository.verifyOfferRequestPickupCode(
        requestId: _booking['id'].toString(),
        code: code.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تأكيد استلام الطلب بنجاح'),
            backgroundColor: _primary,
          ),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: _errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ قيد الانتظار';
      case 'accepted':
        return '✅ مقبول';
      case 'rejected':
        return '❌ مرفوض';
      case 'ready_for_pickup':
        return '📦 جاهز للاستلام';
      case 'picked_up':
        return '📋 تم الاستلام';
      case 'completed':
        return '🎉 مكتمل';
      case 'cancelled':
        return '🚫 ملغي';
      default:
        return '🔄 غير محدد';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return _accent;
      case 'accepted':
        return _primary;
      case 'ready_for_pickup':
        return const Color(0xFF3679C8);
      case 'picked_up':
        return const Color(0xFF7D562D);
      case 'completed':
        return _primary;
      case 'rejected':
      case 'cancelled':
        return _errorColor;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _booking['status']?.toString() ?? 'pending';
    final offer = _booking['offer'] as Map? ?? {};
    final requester = _booking['requester'] as Map? ?? {};
    final quantity = _booking['quantity'] ?? 1;
    final bookingCode = _booking['booking_code']?.toString() ?? 'N/A';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: _primaryDark,
          ),
          title: const Text(
            'تفاصيل الحجز',
            style: TextStyle(
              color: _primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ كود الحجز
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2EEE8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: _primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'كود الحجز',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  bookingCode,
                                  style: const TextStyle(
                                    color: _primaryDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(status)
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              _getStatusLabel(status),
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ معلومات العميل
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2EEE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '👤 معلومات العميل',
                            style: TextStyle(
                              color: _primaryDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'الاسم',
                            value: requester['name']?.toString() ?? 'غير معروف',
                          ),
                          _InfoRow(
                            label: 'الهاتف',
                            value: requester['phone']?.toString() ?? 'غير متاح',
                          ),
                          if (requester['email']?.toString().isNotEmpty ??
                              false)
                            _InfoRow(
                              label: 'البريد الإلكتروني',
                              value: requester['email'].toString(),
                            ),
                          if (requester['city']?.toString().isNotEmpty ?? false)
                            _InfoRow(
                              label: 'المدينة',
                              value: requester['city'].toString(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ معلومات العرض
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2EEE8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🛍️ تفاصيل العرض',
                            style: TextStyle(
                              color: _primaryDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'العنوان',
                            value: offer['title']?.toString() ?? 'غير معروف',
                          ),
                          _InfoRow(
                            label: 'الكمية المطلوبة',
                            value: '$quantity',
                          ),
                          if (offer['symbolic_price'] != null)
                            _InfoRow(
                              label: 'السعر الرمزي',
                              value: '${offer['symbolic_price']} ج.م',
                            ),
                          if (offer['category']?.toString().isNotEmpty ?? false)
                            _InfoRow(
                              label: 'التصنيف',
                              value: offer['category'].toString(),
                            ),
                          if (offer['pickup_location']?.toString().isNotEmpty ??
                              false)
                            _InfoRow(
                              label: 'موقع الاستلام',
                              value: offer['pickup_location'].toString(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ أزرار الإجراءات
                    if (status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _updateStatus('accepted'),
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('قبول الحجز'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () => _updateStatus('rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _errorColor,
                                side: const BorderSide(color: _errorColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('رفض'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (status == 'accepted') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _markReady,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3679C8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.inventory_rounded),
                          label: const Text('تجهيز الطلب للاستلام'),
                        ),
                      ),
                    ],

                    // ✅ البقالة تتحقق من كود العميل
                    if (status == 'ready_for_pickup') ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _verifyPickupCode,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7D562D),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.verified_user_rounded),
                          label: const Text('🔐 التحقق من كود العميل'),
                        ),
                      ),
                    ],

                    if (status == 'picked_up') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: _primary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '✅ تم استلام الطلب بنجاح',
                                style: TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (status == 'completed') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade200,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.celebration_rounded,
                              color: Colors.green,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🎉 تم إكمال الحجز بنجاح',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (status == 'rejected' || status == 'cancelled') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              color: _errorColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                status == 'rejected'
                                    ? '❌ تم رفض هذا الحجز'
                                    : '🚫 تم إلغاء هذا الحجز',
                                style: const TextStyle(
                                  color: _errorColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _errorColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: _errorColor,
                            fontSize: 13,
                          ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
