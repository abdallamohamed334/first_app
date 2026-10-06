// lib/features/institutions/presentation/pages/institution_offer_request_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // ── ألوان وِصلة ──
  static const _green = Color(0xFF0B7650);
  static const _greenLight = Color(0xFF25B77C);
  static const _greenDark = Color(0xFF064D34);
  static const _cream = Color(0xFFF8FBF8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF61756D);
  static const _cardBg = Colors.white;

  late final InstitutionOffersRepository _repository;
  late InstitutionOfferRequest _request;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _request = widget.request;
  }

  // ============================================================
  // Getters
  // ============================================================

  Map<String, dynamic> get _offer {
    return _request.offer ?? <String, dynamic>{};
  }

  /// ✅ كارت المستخدم اللي طلب
  /// بنحاول نوصله من أكتر من مكان
  Map<String, dynamic> get _requester {
    try {
      // لو الـ entity بيخزنها في حقل requester
      final dynamic raw = (_request as dynamic).requester;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}

    try {
      // لو الـ entity بيخزن users
      final dynamic raw = (_request as dynamic).users;
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {}

    // fallback: من offer.users (مش متوقع بس للأمان)
    final offerUsers = _offer['users'];
    if (offerUsers is Map) {
      return Map<String, dynamic>.from(offerUsers);
    }

    return <String, dynamic>{};
  }

  String get _requesterName {
    final name = _requester['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'مستخدم وِصلة';
  }

  String get _requesterPhone {
    return _requester['phone']?.toString().trim() ?? '';
  }

  String get _requesterAvatar {
    return _requester['avatar_url']?.toString().trim() ?? '';
  }

  String get _requesterCity {
    return _requester['city']?.toString().trim() ?? '';
  }

  String get _title {
    final value = _offer['title']?.toString().trim();
    return (value == null || value.isEmpty) ? 'عرض غذائي' : value;
  }

  String get _description {
    final value = _offer['description']?.toString().trim();
    return (value == null || value.isEmpty) ? 'لا يوجد وصف للعرض' : value;
  }

  String get _category {
    final value = _offer['category']?.toString().trim();
    return (value == null || value.isEmpty) ? 'أخرى' : value;
  }

  String get _pickupLocation {
    final value = _offer['pickup_location']?.toString().trim();
    if (value != null && value.isNotEmpty) return value;

    // fallback من المؤسسة
    final institution = _offer['institutions'];
    if (institution is Map) {
      final addr = institution['address']?.toString().trim();
      if (addr != null && addr.isNotEmpty) return addr;
    }

    return 'لم يتم تحديد مكان الاستلام';
  }

  String get _pickupTime {
    return _offer['pickup_time']?.toString().trim() ?? '';
  }

  String get _pickupNotes {
    return _offer['pickup_notes']?.toString().trim() ?? '';
  }

  String get _symbolicPrice {
    final value = _offer['symbolic_price'];
    if (value == null) return '0';
    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }
    return value.toString();
  }

  String get _originalPrice {
    final value = _offer['original_price'];
    if (value == null) return '';
    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }
    return value.toString();
  }

  bool get _hasDiscount {
    final orig = num.tryParse(_originalPrice);
    final sym = num.tryParse(_symbolicPrice);
    if (orig == null || sym == null) return false;
    return orig > sym && sym >= 0;
  }

  int get _discountPercent {
    if (!_hasDiscount) return 0;
    final orig = num.tryParse(_originalPrice)!;
    final sym = num.tryParse(_symbolicPrice)!;
    return (((orig - sym) / orig) * 100).round();
  }

  String get _institutionName {
    final inst = _offer['institutions'];
    if (inst is Map) {
      return inst['name']?.toString().trim() ?? '';
    }
    return '';
  }

  List<String> get _images {
    final images = _offer['images'];

    if (images is List) {
      return images
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    }

    if (images is String) {
      final value = images.trim();
      if (value.isEmpty || value == 'null') return [];
      return [value];
    }

    return [];
  }

  // ============================================================
  // Status helpers
  // ============================================================

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'accepted':
        return 'مقبول';
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
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE28B00);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'ready_for_pickup':
        return _green;
      case 'picked_up':
        return const Color(0xFF6651B5);
      case 'completed':
        return _green;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return const Color(0xFFB54747);
      default:
        return _inkSoft;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'ready_for_pickup':
        return Icons.inventory_2_outlined;
      case 'picked_up':
        return Icons.local_shipping_outlined;
      case 'completed':
        return Icons.done_all_rounded;
      case 'rejected':
        return Icons.close_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'expired':
        return Icons.timer_off_outlined;
      default:
        return Icons.info_outline;
    }
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _updateStatus(String status) async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _repository.updateOfferRequest(
        requestId: _request.id,
        accept: status == 'accepted',
      );

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus(status);
      });

      _showMessage(
        status == 'accepted' ? 'تم قبول الطلب بنجاح' : 'تم رفض الطلب بنجاح',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InstitutionOfferRequest _copyRequestWithStatus(
    String status, {
    String? cancellationReason,
  }) {
    return InstitutionOfferRequest.fromJson({
      'id': _request.id,
      'offer_id': _request.offerId,
      'requester_id': _request.requesterId,
      'quantity': _request.quantity,
      'status': status,
      'created_at': _request.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'accepted_at': _request.acceptedAt?.toIso8601String(),
      'ready_at': _request.readyAt?.toIso8601String(),
      'picked_up_at': _request.pickedUpAt?.toIso8601String(),
      'completed_at': _request.completedAt?.toIso8601String(),
      'pickup_code': _request.pickupCode,
      'booking_code': _request.bookingCode,
      'cancellation_reason': cancellationReason ?? _request.cancellationReason,
      'institution_offers': _offer,
      // ✅ نمرر بيانات المستخدم لو كانت موجودة
      if (_requester.isNotEmpty) 'users': _requester,
    });
  }

  Future<void> _showAcceptConfirmation() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'قبول الطلب',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'هل أنت متأكد من قبول هذا الطلب؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('قبول الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _updateStatus('accepted');
  }

  Future<void> _showRejectConfirmation() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'رفض الطلب',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'هل أنت متأكد من رفض هذا الطلب؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB54747),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _updateStatus('rejected');
  }

  Future<void> _prepareForPickup() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _repository.markOfferRequestReady(_request.id);

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus('ready_for_pickup');
      });

      _showMessage('تم تجهيز الطلب للاستلام', success: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPickupCode() async {
    if (_loading) return;

    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PickupCodeDialog(),
    );

    if (code == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final result = await _repository.verifyOfferRequestPickupCode(
        requestId: _request.id,
        code: code,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _request = _copyRequestWithStatus('picked_up');
        });

        _showMessage('✅ تم تأكيد الاستلام بنجاح', success: true);
        Navigator.of(context).pop(true);
      } else {
        _showMessage(
          result['error']?.toString() ??
              result['message']?.toString() ??
              'فشل التحقق من الكود',
          success: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeRequest() async {
    if (_loading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'إكمال الطلب',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'هل تم استلام الطلب بالفعل وتريد تسجيله كمكتمل؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إكمال الطلب'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    try {
      await _repository.completeRequest(_request.id);

      if (!mounted) return;

      setState(() {
        _request = _copyRequestWithStatus('completed');
      });

      _showMessage('تم إكمال الطلب بنجاح', success: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_loading) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'إلغاء الطلب؟',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سيتم إلغاء الطلب وإعادة الكمية المحجوزة إلى العرض. يمكنك إضافة سبب اختياري.',
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 300,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'سبب الإلغاء (اختياري)',
                  hintText: 'اكتب سبب الإلغاء',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB54747),
              ),
              onPressed: () => Navigator.pop(
                dialogContext,
                reasonController.text.trim(),
              ),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();

    if (reason == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await _repository.cancelOfferRequest(
        requestId: _request.id,
        reason: reason,
      );

      if (!mounted) return;
      setState(() {
        _request = _copyRequestWithStatus(
          'cancelled',
          cancellationReason: reason,
        );
      });
      _showMessage('تم إلغاء الطلب وإعادة الكمية للعرض', success: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e), success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // Helpers
  // ============================================================

  String _friendlyError(Object error) {
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('not authorized') ||
          msg.contains('permission') ||
          error.code == '42501') {
        return 'غير مصرح لك بهذا الإجراء';
      }
      if (msg.contains('not found') || error.code == 'PGRST116') {
        return 'الطلب غير موجود';
      }
      if (msg.contains('expired')) {
        return 'انتهت صلاحية الطلب';
      }
      return 'تعذر إتمام العملية، حاول مرة أخرى';
    }

    if (error is AuthException) {
      return 'يجب تسجيل الدخول أولًا';
    }

    final msg = error.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isEmpty || msg.contains('Exception')) {
      return 'تعذر إتمام العملية، حاول مرة أخرى';
    }
    return msg;
  }

  void _showMessage(String message, {required bool success}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.right),
          backgroundColor: success ? _green : const Color(0xFFB54747),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _callRequester() {
    if (_requesterPhone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _requesterPhone));
    _showMessage('تم نسخ رقم الهاتف: $_requesterPhone', success: true);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final images = _images;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── SliverAppBar مع صورة العرض
                  SliverAppBar(
                    expandedHeight: images.isNotEmpty ? 280 : 130,
                    pinned: true,
                    stretch: true,
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: images.isNotEmpty
                          ? _HeroGallery(images: images)
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_green, _greenLight],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.fastfood_outlined,
                                  size: 70,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // ── المحتوى
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Status Banner
                          _StatusBanner(
                            status: _request.status,
                            label: _statusLabel(_request.status),
                            color: _statusColor(_request.status),
                            icon: _statusIcon(_request.status),
                          ),
                          const SizedBox(height: 16),

                          // ── كارت العرض
                          _OfferCard(
                            title: _title,
                            category: _category,
                            price: _symbolicPrice,
                            originalPrice: _hasDiscount ? _originalPrice : null,
                            discount: _discountPercent,
                            quantity: _request.quantity,
                          ),
                          const SizedBox(height: 14),

                          // ── كارت المستخدم اللي طلب
                          _RequesterCard(
                            name: _requesterName,
                            phone: _requesterPhone,
                            avatarUrl: _requesterAvatar,
                            city: _requesterCity,
                            onCall: _requesterPhone.isNotEmpty
                                ? _callRequester
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // ── تفاصيل الاستلام
                          _PickupCard(
                            location: _pickupLocation,
                            time: _pickupTime,
                            notes: _pickupNotes,
                          ),

                          // ── الوصف
                          if (_description.isNotEmpty &&
                              _description != 'لا يوجد وصف للعرض') ...[
                            const SizedBox(height: 14),
                            _DescriptionCard(description: _description),
                          ],

                          const SizedBox(height: 14),

                          // ── Progress Tracker
                          _RequestProgress(status: _request.status),

                          const SizedBox(height: 22),

                          // ── الأزرار
                          _buildActions(),

                          if (_loading) ...[
                            const SizedBox(height: 14),
                            const Center(
                              child: CircularProgressIndicator(
                                color: _green,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancelButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _cancelRequest,
        icon: const Icon(Icons.cancel_outlined),
        label: const Text(
          'إلغاء الطلب',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB54747),
          side: const BorderSide(color: Color(0xFFE5BABA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    switch (_request.status) {
      case 'pending':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _showAcceptConfirmation,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'قبول الطلب',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _showRejectConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB54747),
                  side: const BorderSide(color: Color(0xFFE5BABA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text(
                  'رفض الطلب',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _cancelButton(),
          ],
        );

      case 'accepted':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _prepareForPickup,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text(
                  'تجهيز الطلب للاستلام',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _cancelButton(),
          ],
        );

      case 'ready_for_pickup':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NoticeCard(
              icon: Icons.pin_outlined,
              title: 'في انتظار كود الاستلام',
              message:
                  'اطلب من المستخدم إظهار كود الاستلام المكوّن من 6 أرقام، ثم تحقّق منه من الزر أدناه.',
              color: Color(0xFF3679C8),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _verifyPickupCode,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(
                  _loading ? 'جارٍ التحقق...' : '🔑 تحقق من كود الاستلام',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _cancelButton(),
          ],
        );

      case 'picked_up':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NoticeCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'تم استلام الطلب',
              message:
                  'تم التحقق من كود الاستلام بنجاح. يمكنك الآن تسجيل الطلب كمكتمل.',
              color: Color(0xFF6651B5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _completeRequest,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text(
                  'إكمال الطلب',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'completed':
        return const _NoticeCard(
          icon: Icons.done_all_rounded,
          title: 'الطلب مكتمل',
          message: 'تم استلام الطلب وإكمال العملية بنجاح.',
          color: Color(0xFF0B7650),
        );

      case 'rejected':
        return const _NoticeCard(
          icon: Icons.close_rounded,
          title: 'تم رفض الطلب',
          message: 'تم رفض هذا الطلب.',
          color: Color(0xFFB54747),
        );

      case 'cancelled':
        return const _NoticeCard(
          icon: Icons.cancel_outlined,
          title: 'الطلب ملغي',
          message: 'تم إلغاء هذا الطلب.',
          color: Color(0xFFB54747),
        );

      case 'expired':
        return const _NoticeCard(
          icon: Icons.timer_off_outlined,
          title: 'الطلب منتهي',
          message: 'انتهت صلاحية هذا الطلب.',
          color: Color(0xFFB54747),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ================================================================
// HERO GALLERY
// ================================================================

class _HeroGallery extends StatefulWidget {
  final List<String> images;
  const _HeroGallery({required this.images});

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, index) {
            return Image.network(
              widget.images[index],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _InstitutionOfferRequestDetailsPageState._greenDark,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: _InstitutionOfferRequestDetailsPageState._greenDark,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
            );
          },
        ),
        // ── Gradient خفيف أسفل عشان الأيقونات تبان
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 90,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Dots
        if (widget.images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ================================================================
// STATUS BANNER
// ================================================================

class _StatusBanner extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBanner({
    required this.status,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حالة الطلب',
                  style: TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// OFFER CARD
// ================================================================

class _OfferCard extends StatelessWidget {
  final String title;
  final String category;
  final String price;
  final String? originalPrice;
  final int discount;
  final int quantity;

  const _OfferCard({
    required this.title,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A123F31),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── العنوان + شارة الخصم
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
              if (discount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD64545),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '-$discount%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── التصنيف
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _InstitutionOfferRequestDetailsPageState._green
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: _InstitutionOfferRequestDetailsPageState._green,
                ),
                const SizedBox(width: 5),
                Text(
                  category,
                  style: const TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._green,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── السعر والكمية
          Row(
            children: [
              // السعر
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _InstitutionOfferRequestDetailsPageState._green
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _InstitutionOfferRequestDetailsPageState._green
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 14,
                            color: _InstitutionOfferRequestDetailsPageState
                                ._inkSoft,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'السعر الرمزي',
                            style: TextStyle(
                              color: _InstitutionOfferRequestDetailsPageState
                                  ._inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: _InstitutionOfferRequestDetailsPageState
                                  ._green,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'جنيه',
                              style: TextStyle(
                                color: _InstitutionOfferRequestDetailsPageState
                                    ._inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text(
                                originalPrice!,
                                style: const TextStyle(
                                  color:
                                      _InstitutionOfferRequestDetailsPageState
                                          ._inkSoft,
                                  fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // الكمية
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3679C8).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF3679C8).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 14,
                            color: _InstitutionOfferRequestDetailsPageState
                                ._inkSoft,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'الكمية المطلوبة',
                            style: TextStyle(
                              color: _InstitutionOfferRequestDetailsPageState
                                  ._inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Color(0xFF3679C8),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'وحدة',
                              style: TextStyle(
                                color: _InstitutionOfferRequestDetailsPageState
                                    ._inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REQUESTER CARD
// ================================================================

class _RequesterCard extends StatelessWidget {
  final String name;
  final String phone;
  final String avatarUrl;
  final String city;
  final VoidCallback? onCall;

  const _RequesterCard({
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.city,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A123F31),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── الأفاتار
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _InstitutionOfferRequestDetailsPageState._green
                    .withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
          ),
          const SizedBox(width: 14),

          // ── البيانات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'صاحب الطلب',
                  style: TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: const TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        size: 13,
                        color:
                            _InstitutionOfferRequestDetailsPageState._inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: const TextStyle(
                          color:
                              _InstitutionOfferRequestDetailsPageState._inkSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color:
                            _InstitutionOfferRequestDetailsPageState._inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        city,
                        style: const TextStyle(
                          color:
                              _InstitutionOfferRequestDetailsPageState._inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── زر الاتصال
          if (onCall != null)
            Material(
              color: _InstitutionOfferRequestDetailsPageState._green
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.phone_rounded,
                    color: _InstitutionOfferRequestDetailsPageState._green,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: _InstitutionOfferRequestDetailsPageState._green
          .withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        color: _InstitutionOfferRequestDetailsPageState._green,
        size: 30,
      ),
    );
  }
}

// ================================================================
// PICKUP CARD
// ================================================================

class _PickupCard extends StatelessWidget {
  final String location;
  final String time;
  final String notes;

  const _PickupCard({
    required this.location,
    required this.time,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A123F31),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _InstitutionOfferRequestDetailsPageState._green
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: _InstitutionOfferRequestDetailsPageState._green,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'معلومات الاستلام',
                style: TextStyle(
                  color: _InstitutionOfferRequestDetailsPageState._ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(
            icon: Icons.place_outlined,
            label: 'مكان الاستلام',
            value: location,
          ),
          if (time.isNotEmpty)
            _InfoLine(
              icon: Icons.access_time_outlined,
              label: 'وقت الاستلام',
              value: time,
            ),
          if (notes.isNotEmpty)
            _InfoLine(
              icon: Icons.notes_outlined,
              label: 'ملاحظات',
              value: notes,
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: _InstitutionOfferRequestDetailsPageState._inkSoft,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: _InstitutionOfferRequestDetailsPageState._inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _InstitutionOfferRequestDetailsPageState._ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// DESCRIPTION CARD
// ================================================================

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A123F31),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _InstitutionOfferRequestDetailsPageState._green
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: _InstitutionOfferRequestDetailsPageState._green,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'وصف العرض',
                style: TextStyle(
                  color: _InstitutionOfferRequestDetailsPageState._ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: _InstitutionOfferRequestDetailsPageState._inkSoft,
              fontSize: 13.5,
              height: 1.7,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REQUEST PROGRESS
// ================================================================

class _RequestProgress extends StatelessWidget {
  final String status;
  const _RequestProgress({required this.status});

  int get _currentStep {
    switch (status) {
      case 'pending':
        return 0;
      case 'accepted':
        return 1;
      case 'ready_for_pickup':
        return 2;
      case 'picked_up':
        return 3;
      case 'completed':
        return 4;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;
    if (current < 0) return const SizedBox.shrink();

    const steps = [
      (title: 'طلب', icon: Icons.receipt_long_outlined),
      (title: 'قبول', icon: Icons.check_circle_outline_rounded),
      (title: 'تجهيز', icon: Icons.inventory_2_outlined),
      (title: 'استلام', icon: Icons.local_shipping_outlined),
      (title: 'إكمال', icon: Icons.done_all_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A123F31),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مراحل الطلب',
            style: TextStyle(
              color: _InstitutionOfferRequestDetailsPageState._ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(steps.length, (index) {
              final completed = index <= current;
              final isCurrent = index == current;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: index <= current
                                  ? _InstitutionOfferRequestDetailsPageState
                                      ._green
                                  : const Color(0xFFE1E8E4),
                            ),
                          ),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: completed
                                ? _InstitutionOfferRequestDetailsPageState
                                    ._green
                                : Colors.white,
                            border: Border.all(
                              color: completed
                                  ? _InstitutionOfferRequestDetailsPageState
                                      ._green
                                  : const Color(0xFFE1E8E4),
                              width: 2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color:
                                          _InstitutionOfferRequestDetailsPageState
                                              ._green
                                              .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            steps[index].icon,
                            size: 15,
                            color: completed
                                ? Colors.white
                                : const Color(0xFFB8C8C0),
                          ),
                        ),
                        if (index < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: index < current
                                  ? _InstitutionOfferRequestDetailsPageState
                                      ._green
                                  : const Color(0xFFE1E8E4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index].title,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            completed ? FontWeight.w900 : FontWeight.w600,
                        color: completed
                            ? _InstitutionOfferRequestDetailsPageState._ink
                            : _InstitutionOfferRequestDetailsPageState._inkSoft,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// NOTICE CARD
// ================================================================

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: _InstitutionOfferRequestDetailsPageState._inkSoft,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PICKUP CODE DIALOG
// ================================================================

class _PickupCodeDialog extends StatefulWidget {
  const _PickupCodeDialog();

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length == 6) {
      Navigator.pop(context, code);
    } else {
      setState(() => _errorText = 'أدخل 6 أرقام');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Text(
          'تحقق من كود الاستلام',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل كود الاستلام المكون من 6 أرقام',
              style: TextStyle(fontSize: 13, color: Color(0xFF71837C)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF123F31),
                letterSpacing: 4,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                errorText: _errorText,
                filled: true,
                fillColor: const Color(0xFFF4F8F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0B7650)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B7650),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تحقق',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
