// lib/features/booking/presentation/pages/booking_details_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/core/pickup/presentation/pages/pickup_qr_page.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:loqma/features/booking/domain/entities/booking.dart';

class BookingDetailsPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailsPage({super.key, required this.bookingId});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  Booking? _booking;
  bool _isLoading = true;
  String? _error;
  late BookingRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = BookingRepository(SupabaseService());
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booking = await _repository.getBookingById(widget.bookingId);
      if (!mounted) return;
      if (booking != null) {
        setState(() {
          _booking = booking;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'الحجز غير موجود';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل تفاصيل الحجز حاليًا';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('📋 تفاصيل الحجز'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadBookingDetails();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(context)
              : _booking == null
                  ? _buildEmptyState(context)
                  : _buildContent(context, colorScheme),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBookingDetails,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'الحجز غير موجود',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    final booking = _booking!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ كارد الحالة
          _buildStatusCard(context, colorScheme, booking),

          const SizedBox(height: 16),

          // ✅ كارد تفاصيل العرض
          _buildOfferCard(context, colorScheme, booking),

          const SizedBox(height: 16),

          // ✅ كارد المؤسسة
          _buildBusinessCard(context, colorScheme, booking),

          const SizedBox(height: 16),

          // ✅ كارد الإحصائيات
          _buildStatsCard(context, colorScheme, booking),

          const SizedBox(height: 16),

          // ✅ معلومات إضافية
          _buildExtraInfo(context, colorScheme, booking),

          const SizedBox(height: 24),

          // ✅ أزرار
          _buildActions(context, colorScheme, booking),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: booking.status.color.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: booking.status.color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(
            booking.status.icon,
            size: 48,
            color: booking.status.color,
          ),
          const SizedBox(height: 8),
          Text(
            booking.status.displayName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: booking.status.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(booking.requestedAt),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (booking.completedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'تم التسليم: ${_formatDateTime(booking.completedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 70,
                  height: 70,
                  color: colorScheme.primary.withAlpha(20),
                  child: booking.offerImage != null
                      ? Image.network(
                          booking.offerImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.restaurant_menu,
                            color: colorScheme.primary.withAlpha(50),
                          ),
                        )
                      : Icon(
                          Icons.restaurant_menu,
                          color: colorScheme.primary.withAlpha(50),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.offerTitle ?? 'عرض',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.businessName ?? 'مطعم',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.food_bank,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${booking.quantity ?? 0} وجبات',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50,
                  height: 50,
                  color: colorScheme.primary.withAlpha(20),
                  child: booking.businessLogo != null
                      ? Image.network(
                          booking.businessLogo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.restaurant,
                            color: colorScheme.primary.withAlpha(50),
                          ),
                        )
                      : Icon(
                          Icons.restaurant,
                          color: colorScheme.primary.withAlpha(50),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.businessName ?? 'مطعم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.businessAddress ?? 'طنطا',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 معلومات الحجز',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('📅 تاريخ الطلب', _formatDateTime(booking.requestedAt)),
          if (booking.completedAt != null)
            _buildInfoRow(
                '✅ تاريخ التسليم', _formatDateTime(booking.completedAt!)),
          if (booking.pickupTokenHash != null)
            _buildInfoRow('🔑 كود الاستلام', booking.pickupTokenHash!),
        ],
      ),
    );
  }

  Widget _buildExtraInfo(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📌 معلومات إضافية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('🆔 معرف الحجز', booking.id),
          _buildInfoRow('🆔 معرف العرض', booking.offerId),
          _buildInfoRow('🆔 معرف المؤسسة', booking.businessId ?? ''),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, ColorScheme colorScheme, Booking booking) {
    // ✅ الحصول على businessId
    final businessId = booking.businessId ?? '';

    return Column(
      children: [
        // ✅ زر QR
        if (booking.status == BookingStatus.readyForPickup &&
            businessId.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PickupQRPage(
                      requestId: booking.id,
                      businessId: businessId,
                      existingToken: booking.pickupTokenHash,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                '📱 إظهار QR للاستلام',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ✅ زر إلغاء (للمستخدم)
        if (booking.status == BookingStatus.pending ||
            booking.status == BookingStatus.accepted)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelDialog(context, booking),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                foregroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cancel, size: 20),
              label: const Text(
                'إلغاء الحجز',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // ✅ زر رجوع
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('رجوع'),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز'),
        content: Text('هل أنت متأكد من إلغاء حجز "${booking.offerTitle}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _repository.cancelBooking(booking.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم إلغاء الحجز بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadBookingDetails();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ حدث خطأ في الإلغاء'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
