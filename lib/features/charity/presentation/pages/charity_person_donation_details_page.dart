// lib/features/charity/presentation/pages/charity_person_donation_details_page.dart

import 'package:flutter/material.dart';

import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';

class CharityPersonDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const CharityPersonDonationDetailsPage({
    super.key,
    required this.donation,
  });

  @override
  State<CharityPersonDonationDetailsPage> createState() =>
      _CharityPersonDonationDetailsPageState();
}

class _CharityPersonDonationDetailsPageState
    extends State<CharityPersonDonationDetailsPage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF087A52);
  static const _greenLight = Color(0xFF2BAA76);
  static const _deepGreen = Color(0xFF123D31);
  static const _mint = Color(0xFFE9F7F0);
  static const _background = Color(0xFFF5F8F6);
  static const _purple = Color(0xFF6651B5);
  static const _orange = Color(0xFFE28B00);
  static const _blue = Color(0xFF3679C8);
  static const _red = Color(0xFFB54747);

  final _repository = SeparateCharityDonationRepository();
  bool _loading = false;
  bool _assignmentDialogOpen = false;
  late String _status;
  late AnimationController _animationController;

  Map<String, dynamic> get donation => widget.donation;
  String get donationId => donation['id']?.toString() ?? '';
  String get title => donation['title']?.toString().trim().isNotEmpty == true
      ? donation['title'].toString()
      : 'تبرع من مستخدم';
  String get donorName =>
      donation['donor_name']?.toString() ??
      donation['user_name']?.toString() ??
      _nestedName(donation['users']) ??
      'متبرع';

  String get deliveryType =>
      donation['delivery_type']?.toString() ?? 'charity_volunteer';
  bool get isIndependent => deliveryType == 'independent_volunteer';

  List<String> get _images {
    final raw = donation['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _status = donation['status']?.toString().trim().toLowerCase() ?? 'pending';
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  /// ✅ قبول التبرع (مسار الجمعية)
  Future<void> _acceptWithCharityVolunteer() async {
    if (_loading || donationId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await _repository.charityAcceptDonation(
        requestId: donationId,
        openToVolunteers: false,
      );
      if (!mounted) return;
      setState(() => _status = result['status']?.toString() ?? 'accepted');
      CharityActionFeedback.showSuccess(
        context,
        '✅ تم قبول التبرع — بانتظار جاهزية المتبرع',
      );
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ قبول التبرع (مسار المتطوعين)
  Future<void> _acceptOpenForVolunteers() async {
    if (_loading || donationId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await _repository.charityAcceptDonation(
        requestId: donationId,
        openToVolunteers: true,
      );
      if (!mounted) return;
      setState(
          () => _status = result['status']?.toString() ?? 'volunteer_needed');
      CharityActionFeedback.showSuccess(
        context,
        '✅ تم قبول التبرع وإتاحته للمتطوعين المستقلين',
      );
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ رفض التبرع
  Future<void> _rejectDonation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _red),
            SizedBox(width: 8),
            Text('رفض التبرع'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد؟ هيتم إعلام المتبرع بالرفض.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _repository.charityRejectDonation(requestId: donationId);
      if (!mounted) return;
      setState(() => _status = 'rejected');
      CharityActionFeedback.showSuccess(context, 'تم رفض التبرع');
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ تعيين مندوب
  Future<void> _assignVolunteer() async {
    if (_assignmentDialogOpen || _loading || donationId.isEmpty || !mounted) {
      return;
    }
    _assignmentDialogOpen = true;

    try {
      final volunteers = await _repository.getMyCharityVolunteers();
      if (!mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      final activeVolunteers = volunteers
          .where((v) => v['status']?.toString() == 'active')
          .toList(growable: false);

      final assignment = await showModalBottomSheet<_VolunteerAssignment>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => _VolunteerBottomSheet(
          volunteers: activeVolunteers,
        ),
      );

      if (assignment == null || !mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      setState(() => _loading = true);

      final isExternal = assignment.id == null;

      await _repository.charityAssignVolunteer(
        requestId: donationId,
        volunteerId: assignment.id,
        externalName: isExternal ? assignment.name : null,
        externalPhone: isExternal ? assignment.phone : null,
      );

      if (!mounted) return;
      setState(() => _status = 'volunteer_assigned');
      CharityActionFeedback.showSuccess(context, '✅ تم تعيين المندوب بنجاح');
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      _assignmentDialogOpen = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ التحقق من كود المتبرع
  Future<void> _verifyPickup() async {
    if (_loading || donationId.isEmpty) return;
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: _green),
            SizedBox(width: 8),
            Text('تأكيد استلام التبرع'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل كود الاستلام من المندوب',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'كود الاستلام',
                hintText: 'LD-XXXX...',
                prefixIcon: Icon(Icons.password_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
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
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().isEmpty || !mounted) return;

    setState(() => _loading = true);
    try {
      await _repository.confirmPickup(
        requestId: donationId,
        token: token.trim(),
      );
      if (!mounted) return;
      setState(() => _status = 'picked_up_from_donor');
      CharityActionFeedback.showSuccess(
        context,
        '✅ تم تأكيد استلام التبرع بنجاح',
      );
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ✅ تحديث الحالة (in_transit / completed)
  Future<void> _updateStatus(String nextStatus) async {
    if (_loading || donationId.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repository.updateStatus(
        requestId: donationId,
        status: nextStatus,
        isRestaurantDonation: false,
      );
      if (!mounted) return;
      setState(() => _status = nextStatus);
      CharityActionFeedback.showSuccess(context, _statusMessage(nextStatus));
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusMessage(String value) {
    switch (value) {
      case 'in_transit':
        return 'تم تسجيل أن التبرع في الطريق';
      case 'completed':
        return 'تم تأكيد وصول التبرع بنجاح';
      default:
        return 'تم تحديث حالة التبرع';
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('permission') ||
        value.contains('row-level') ||
        value.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية.';
    }
    if (value.contains('status') || value.contains('الحالة')) {
      return 'لا يمكن تنفيذ العملية من الحالة الحالية.';
    }
    if (value.contains('code') ||
        value.contains('token') ||
        value.contains('كود')) {
      return 'كود الاستلام غير صحيح أو منتهي.';
    }
    return 'تعذر تنفيذ العملية. حاول مرة أخرى.';
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'تفاصيل التبرع',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: _background,
          foregroundColor: _deepGreen,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: FadeTransition(
          opacity: _animationController,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              _buildStatusCard(),
              const SizedBox(height: 12),
              _buildDetailsCard(),
              if (_images.length > 1) ...[
                const SizedBox(height: 12),
                _buildImagesCard(),
              ],
              const SizedBox(height: 16),
              _buildTimeline(),
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO
  // ═══════════════════════════════════════════════════════════

  Widget _buildHero() {
    final images = _images;
    final heroImage = images.isNotEmpty ? images.first : null;

    return Container(
      height: 200,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (heroImage == null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_deepGreen, _green],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            )
          else
            Image.network(
              heroImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_deepGreen, _green],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Status Badge
          Positioned(
            top: 14,
            right: 14,
            child: _buildStatusBadge(),
          ),
          // Delivery Badge
          Positioned(
            top: 14,
            left: 14,
            child: _buildDeliveryBadge(),
          ),
          // Title + Donor
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        donorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = _statusColor(_status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(_status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBadge() {
    final color = isIndependent ? _purple : _blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIndependent ? Icons.people_alt_rounded : Icons.badge_outlined,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isIndependent ? 'متطوعين' : 'مندوب الجمعية',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATUS CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatusCard() {
    final color = _statusColor(_status);
    final icon = _statusIcon(_status);
    final description = _statusDescription(_status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(_status),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DETAILS CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.04),
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'بيانات التبرع',
                style: TextStyle(
                  color: _deepGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.person_outline_rounded, 'المتبرع', donorName),
          _buildDetailRow(Icons.inventory_2_outlined, 'الكمية',
              '${donation['quantity'] ?? 1}'),
          if (donation['description']?.toString().isNotEmpty == true)
            _buildDetailRow(Icons.description_outlined, 'الوصف',
                donation['description'].toString()),
          _buildDetailRow(Icons.location_on_outlined, 'العنوان',
              donation['pickup_address']?.toString() ?? 'غير محدد'),
          if (donation['pickup_city']?.toString().isNotEmpty == true)
            _buildDetailRow(Icons.location_city_outlined, 'المدينة',
                donation['pickup_city'].toString()),
          // Volunteer info
          if (donation['volunteer_name']?.toString().isNotEmpty == true)
            _buildDetailRow(
              isIndependent ? Icons.person_rounded : Icons.badge_outlined,
              isIndependent ? 'المتطوع' : 'المندوب',
              '${donation['volunteer_name']}${donation['volunteer_phone']?.toString().isNotEmpty == true ? ' - ${donation['volunteer_phone']}' : ''}',
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _deepGreen,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // IMAGES CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildImagesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.04),
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'صور إضافية',
                style: TextStyle(
                  color: _deepGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length - 1}',
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length - 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _images[index + 1],
                  width: 120,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 100,
                    color: _green.withValues(alpha: 0.08),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: _green,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TIMELINE
  // ═══════════════════════════════════════════════════════════

  Widget _buildTimeline() {
    // ✅ خطوات حسب المسار
    final steps = <(String, String, IconData)>[
      ('pending', 'أرسل التبرع', Icons.send_rounded),
      if (isIndependent) ...[
        ('volunteer_needed', 'مفتوح للمتطوعين', Icons.people_alt_rounded),
      ] else ...[
        ('accepted', 'قبلت الجمعية', Icons.fact_check_outlined),
      ],
      ('donor_ready', 'المتبرع جاهز', Icons.front_hand_rounded),
      ('volunteer_assigned', 'تم تعيين المندوب', Icons.badge_outlined),
      ('picked_up_from_donor', 'استلم المندوب', Icons.verified_user_outlined),
      ('in_transit', 'في الطريق', Icons.local_shipping_rounded),
      ('completed', 'وصل للجمعية', Icons.done_all_rounded),
    ];

    // ✅ تحديد الـ index الحالي
    int current;
    if (isIndependent) {
      current = switch (_status) {
        'pending' => 0,
        'volunteer_needed' => 1,
        'accepted' => 1, // احتياطي
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' => 4,
        'in_transit' => 5,
        'completed' => 6,
        _ => 0,
      };
    } else {
      current = switch (_status) {
        'pending' => 0,
        'accepted' => 1,
        'volunteer_needed' => 1, // احتياطي
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' => 4,
        'in_transit' => 5,
        'completed' => 6,
        _ => 0,
      };
    }

    final activeColor = _statusColor(_status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
        boxShadow: [
          BoxShadow(
            color: _deepGreen.withValues(alpha: 0.04),
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
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'خط سير التبرع',
                style: TextStyle(
                  color: _deepGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final active = index <= current;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? activeColor : const Color(0xFFE5EEE9),
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        steps[index].$3,
                        color: active ? Colors.white : const Color(0xFF9AACA3),
                        size: 16,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 3,
                        height: 28,
                        color: index < current
                            ? activeColor
                            : const Color(0xFFE5EEE9),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    steps[index].$2,
                    style: TextStyle(
                      color: active ? _deepGreen : const Color(0xFF98A9A1),
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  Widget _buildActions() {
    // ✅ رفض أو ملغي
    if (_status == 'rejected') {
      return _buildInfoBanner(
        icon: Icons.cancel_rounded,
        color: _red,
        title: 'تم رفض هذا التبرع',
        subtitle: 'تم إعلام المتبرع بالرفض.',
      );
    }

    if (_status == 'cancelled') {
      return _buildInfoBanner(
        icon: Icons.block_rounded,
        color: Colors.grey.shade700,
        title: 'تم إلغاء التبرع',
        subtitle: 'المتبرع ألغى التبرع.',
      );
    }

    // ✅ completed
    if (_status == 'completed') {
      return _buildInfoBanner(
        icon: Icons.verified_rounded,
        color: _green,
        title: '🎉 تم استلام التبرع',
        subtitle: 'وصل التبرع للجمعية بنجاح.',
      );
    }

    // ✅ pending → أزرار القبول
    if (_status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionButton(
            label: '✅ اقبل وعيّن مندوبي',
            icon: Icons.badge_outlined,
            onTap: _acceptWithCharityVolunteer,
          ),
          const SizedBox(height: 10),
          _buildActionButton(
            label: '🤝 اقبل واسيبه للمتطوعين',
            icon: Icons.groups_outlined,
            onTap: _acceptOpenForVolunteers,
            outlined: true,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _loading ? null : _rejectDonation,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text(
                'رفض التبرع',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ accepted
    if (_status == 'accepted') {
      return Column(
        children: [
          _buildInfoBanner(
            icon: Icons.hourglass_top_rounded,
            color: _orange,
            title: 'بانتظار جاهزية المتبرع',
            subtitle: 'هيتم إشعارك عند إعلان المتبرع جاهزيته.',
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'إرسال مندوب الجمعية',
            icon: Icons.badge_outlined,
            onTap: _assignVolunteer,
            outlined: true,
          ),
        ],
      );
    }

    // ✅ volunteer_needed
    if (_status == 'volunteer_needed') {
      return Column(
        children: [
          _buildInfoBanner(
            icon: Icons.people_alt_rounded,
            color: _purple,
            title: 'مفتوح للمتطوعين المستقلين',
            subtitle: 'التبرع معروض للمتطوعين. في انتظار حد يحجزه.',
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'إرسال مندوب الجمعية',
            icon: Icons.badge_outlined,
            onTap: _assignVolunteer,
            outlined: true,
          ),
        ],
      );
    }

    // ✅ donor_ready → إرسال مندوب
    if (_status == 'donor_ready') {
      return _buildActionButton(
        label: 'إرسال مندوب الجمعية',
        icon: Icons.badge_outlined,
        onTap: _assignVolunteer,
      );
    }

    // ✅ volunteer_assigned → التحقق من الكود
    if (_status == 'volunteer_assigned') {
      return Column(
        children: [
          _buildInfoBanner(
            icon: Icons.qr_code_2_rounded,
            color: _blue,
            title: 'المندوب في طريقه',
            subtitle: 'عند وصوله، اطلب منه كود الاستلام وأدخله هنا.',
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            label: 'إدخال كود الاستلام والتحقق',
            icon: Icons.verified_user_outlined,
            onTap: _verifyPickup,
          ),
        ],
      );
    }

    // ✅ picked_up_from_donor → في الطريق
    if (_status == 'picked_up_from_donor') {
      return _buildActionButton(
        label: 'التبرع في الطريق للجمعية',
        icon: Icons.local_shipping_rounded,
        onTap: () => _updateStatus('in_transit'),
      );
    }

    // ✅ in_transit → تأكيد الوصول
    if (_status == 'in_transit') {
      return _buildActionButton(
        label: 'تأكيد وصول التبرع للجمعية',
        icon: Icons.done_all_rounded,
        onTap: () => _updateStatus('completed'),
      );
    }

    return _buildInfoBanner(
      icon: Icons.info_outline_rounded,
      color: Colors.grey.shade700,
      title: 'لا يوجد إجراء متاح',
      subtitle: 'هذه الحالة لا تحتاج أي إجراء حاليًا.',
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    final child = _loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 20);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: _loading ? null : onTap,
              icon: Icon(icon, size: 20),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: _loading ? null : onTap,
              icon: child,
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _statusLabel(String value) =>
      <String, String>{
        'pending': 'في انتظار المراجعة',
        'accepted': 'تم القبول',
        'volunteer_needed': 'مفتوح للمتطوعين',
        'donor_ready': 'المتبرع جاهز',
        'volunteer_assigned': 'تم تعيين المندوب',
        'picked_up_from_donor': 'استلم المندوب',
        'in_transit': 'في الطريق',
        'completed': 'وصل للجمعية',
        'rejected': 'مرفوض',
        'cancelled': 'ملغي',
        'expired': 'منتهي',
      }[value] ??
      value;

  String _statusDescription(String value) =>
      <String, String>{
        'pending': 'التبرع في انتظار قرار الجمعية.',
        'accepted': 'الجمعية قبلت التبرع. في انتظار جاهزية المتبرع.',
        'volunteer_needed':
            'التبرع مفتوح للمتطوعين المستقلين. في انتظار حد يحجزه.',
        'donor_ready': 'المتبرع أعلن جاهزيته. يمكنك إرسال مندوب الآن.',
        'volunteer_assigned': 'تم تعيين المندوب. في انتظاره يستلم التبرع.',
        'picked_up_from_donor': 'المندوب استلم التبرع من المتبرع.',
        'in_transit': 'التبرع في الطريق للجمعية.',
        'completed': 'وصل التبرع للجمعية بنجاح. 🎉',
        'rejected': 'تم رفض التبرع.',
        'cancelled': 'تم إلغاء التبرع.',
        'expired': 'انتهت مهلة التبرع.',
      }[value] ??
      'حالة غير معروفة';

  IconData _statusIcon(String value) =>
      <String, IconData>{
        'pending': Icons.hourglass_top_rounded,
        'accepted': Icons.fact_check_outlined,
        'volunteer_needed': Icons.people_alt_rounded,
        'donor_ready': Icons.front_hand_rounded,
        'volunteer_assigned': Icons.badge_outlined,
        'picked_up_from_donor': Icons.verified_user_outlined,
        'in_transit': Icons.local_shipping_rounded,
        'completed': Icons.verified_rounded,
        'rejected': Icons.cancel_rounded,
        'cancelled': Icons.block_rounded,
        'expired': Icons.timer_off_rounded,
      }[value] ??
      Icons.info_outline_rounded;

  Color _statusColor(String value) {
    switch (value) {
      case 'pending':
        return _orange;
      case 'accepted':
        return _blue;
      case 'volunteer_needed':
        return _purple;
      case 'donor_ready':
        return _blue;
      case 'volunteer_assigned':
        return _purple;
      case 'picked_up_from_donor':
      case 'in_transit':
        return _orange;
      case 'completed':
        return _green;
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return _red;
      default:
        return _green;
    }
  }

  String? _nestedName(dynamic value) {
    if (value is Map) {
      final name = value['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════
// VOLUNTEER ASSIGNMENT MODELS
// ═══════════════════════════════════════════════════════════

class _VolunteerAssignment {
  final String? id;
  final String name;
  final String phone;

  const _VolunteerAssignment({
    required this.id,
    required this.name,
    required this.phone,
  });
}

// ═══════════════════════════════════════════════════════════
// VOLUNTEER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════

class _VolunteerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> volunteers;

  const _VolunteerBottomSheet({required this.volunteers});

  @override
  State<_VolunteerBottomSheet> createState() => _VolunteerBottomSheetState();
}

class _VolunteerBottomSheetState extends State<_VolunteerBottomSheet> {
  static const _green = Color(0xFF087A52);
  static const _mint = Color(0xFFE9F7F0);
  static const _deepGreen = Color(0xFF123D31);

  bool _fromCharity = true;
  String? _selectedId;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: _green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'تعيين مندوب للتبرع',
                        style: TextStyle(
                          color: _deepGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Segmented Button
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('من الجمعية'),
                      icon: Icon(Icons.groups_outlined, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('خارجي'),
                      icon: Icon(Icons.person_add_alt_1, size: 18),
                    ),
                  ],
                  selected: {_fromCharity},
                  onSelectionChanged: (values) {
                    setState(() {
                      _fromCharity = values.first;
                      _selectedId = null;
                      _nameController.clear();
                      _phoneController.clear();
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _mint;
                      }
                      return Colors.white;
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // Charity Volunteer Dropdown
                if (_fromCharity)
                  widget.volunteers.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                color: Colors.grey,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'لا يوجد مندوبون نشطون',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'اختر المندوب',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF8FBF9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0EBE5),
                              ),
                            ),
                          ),
                          items: widget.volunteers.map((item) {
                            final itemId = item['id']?.toString() ?? '';
                            final itemName =
                                item['name']?.toString() ?? 'مندوب';
                            final itemPhone = item['phone']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: itemId,
                              child: Text(
                                '$itemName${itemPhone.isEmpty ? '' : ' — $itemPhone'}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedId = value),
                        )
                else ...[
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'اسم المندوب',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: const Color(0xFFF8FBF9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0EBE5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF8FBF9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0EBE5),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _deepGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          if (_fromCharity) {
                            if (_selectedId == null) return;
                            final selected = widget.volunteers.firstWhere(
                              (v) => v['id']?.toString() == _selectedId,
                            );
                            Navigator.pop(
                              context,
                              _VolunteerAssignment(
                                id: selected['id']?.toString(),
                                name: selected['name']?.toString().trim() ?? '',
                                phone:
                                    selected['phone']?.toString().trim() ?? '',
                              ),
                            );
                          } else {
                            if (_nameController.text.trim().isEmpty ||
                                _phoneController.text.trim().isEmpty) {
                              return;
                            }
                            Navigator.pop(
                              context,
                              _VolunteerAssignment(
                                id: null,
                                name: _nameController.text.trim(),
                                phone: _phoneController.text.trim(),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'تعيين المندوب',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
