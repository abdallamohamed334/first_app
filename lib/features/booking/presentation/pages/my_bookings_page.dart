import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/pickup/presentation/pages/pickup_qr_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:loqma/features/booking/domain/entities/booking.dart';
import '../bloc/booking_bloc.dart';
import 'booking_details_page.dart';

class MyBookingsPage extends StatelessWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BookingBloc(BookingRepository(SupabaseService())),
      child: const _MyBookingsView(),
    );
  }
}

class _MyBookingsView extends StatefulWidget {
  const _MyBookingsView();

  @override
  State<_MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<_MyBookingsView> {
  String? _userId;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await SupabaseService().getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      setState(() => _userId = '');
      return;
    }
    setState(() => _userId = user.id);
    context.read<BookingBloc>().add(LoadBookings(user.id));
  }

  void _refresh() {
    final id = _userId;
    if (id != null && id.isNotEmpty) {
      context.read<BookingBloc>().add(RefreshBookings(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('حجوزاتي',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            tooltip: 'تحديث الحجوزات',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (!mounted) return;
          if (state is BookingLoaded && _cancellingId != null) {
            setState(() => _cancellingId = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إلغاء الحجز وتحديث القائمة بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is BookingError) {
            setState(() => _cancellingId = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (_userId == null || state is BookingLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_userId!.isEmpty) return _empty(context, loggedOut: true);
          if (state is BookingError) return _error(context, state.message);
          if (state is BookingLoaded) {
            if (state.bookings.isEmpty) return _empty(context);
            return RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await Future<void>.delayed(const Duration(milliseconds: 600));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  _summaryHeader(context, state.bookings),
                  const SizedBox(height: 16),
                  ...state.bookings.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BookingCard(
                        booking: booking,
                        isCancelling: _cancellingId == booking.id,
                        onCancel: () => _confirmCancel(booking),
                        onShowQR: () => _showQR(booking),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BookingDetailsPage(bookingId: booking.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _summaryHeader(BuildContext context, List<Booking> bookings) {
    final colors = Theme.of(context).colorScheme;
    final active = bookings
        .where((b) =>
            b.status != BookingStatus.cancelled &&
            b.status != BookingStatus.completed)
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: colors.primary.withAlpha(45),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رحلة إنقاذ الطعام',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('$active طلب نشط',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              const Text('تابع حالة كل وجبة حتى الاستلام',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('إلغاء الحجز')
        ]),
        content: Text(
            'هل أنت متأكد من إلغاء حجز «${booking.offerTitle ?? 'الوجبة'}»؟\n\nسيتم تحديث حالة الحجز في قاعدة البيانات.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('الاحتفاظ بالحجز')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancellingId = booking.id);
    context.read<BookingBloc>().add(CancelBooking(booking.id));
  }

  Future<void> _showQR(Booking booking) async {
    final id = booking.businessId ?? booking.restaurantId ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد مطعم مرتبط بهذا الطلب')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PickupQRPage(
          requestId: booking.id,
          businessId: id,
          existingToken: booking.pickupTokenHash,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Widget _empty(BuildContext context, {bool loggedOut = false}) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: colors.primary.withAlpha(18), shape: BoxShape.circle),
              child: Icon(loggedOut ? Icons.login_rounded : Icons.inbox_rounded,
                  size: 52, color: colors.primary)),
          const SizedBox(height: 20),
          Text(loggedOut ? 'سجّل الدخول أولًا' : 'لا توجد حجوزات حتى الآن',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              loggedOut
                  ? 'سجّل الدخول لمتابعة طلباتك.'
                  : 'ابدأ بإنقاذ وجبة من العروض المتاحة.',
              style: TextStyle(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('استعراض العروض')),
        ]),
      ),
    );
  }

  Widget _error(BuildContext context, String message) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded, size: 58, color: Colors.red),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'))
            ])));
  }
}

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;
  final VoidCallback onShowQR;
  final VoidCallback onTap;
  final bool isCancelling;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onCancel,
    required this.onShowQR,
    required this.onTap,
    this.isCancelling = false,
  });

  bool get canCancel =>
      booking.status == BookingStatus.pending ||
      booking.status == BookingStatus.accepted;
  bool get canShowQr => booking.status == BookingStatus.readyForPickup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = booking.status.color;
    final image = booking.offerImage;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant.withAlpha(90)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                      width: 82,
                      height: 82,
                      child: image != null && image.isNotEmpty
                          ? Image.network(image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(colors))
                          : _placeholder(colors))),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(booking.offerTitle ?? 'عرض طعام',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.storefront_rounded,
                          size: 15, color: colors.primary),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(booking.businessNameDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 13)))
                    ]),
                    const SizedBox(height: 8),
                    _statusPill(statusColor),
                  ])),
              const Icon(Icons.chevron_left_rounded),
            ]),
            const SizedBox(height: 14),
            Container(height: 1, color: colors.outlineVariant.withAlpha(70)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.fastfood_rounded,
                  size: 17, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Text('${booking.quantity ?? 0} وجبات',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.calendar_today_rounded,
                  size: 15, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                  '${booking.requestedAt.day}/${booking.requestedAt.month}/${booking.requestedAt.year}',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12))
            ]),
            if (canShowQr || canCancel) ...[
              const SizedBox(height: 13),
              Row(children: [
                if (canShowQr)
                  Expanded(
                      child: FilledButton.icon(
                          onPressed: onShowQR,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.green),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text('رمز الاستلام'))),
                if (canShowQr && canCancel) const SizedBox(width: 9),
                if (canCancel)
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: isCancelling ? null : onCancel,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                          icon: isCancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cancel_outlined, size: 18),
                          label: Text(
                              isCancelling ? 'جاري الإلغاء' : 'إلغاء الحجز'))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colors) => Container(
      color: colors.primary.withAlpha(18),
      child: Icon(Icons.restaurant_rounded, color: colors.primary, size: 32));

  Widget _statusPill(Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withAlpha(22), borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(booking.status.icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(booking.status.displayName,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w900))
      ]));
}
