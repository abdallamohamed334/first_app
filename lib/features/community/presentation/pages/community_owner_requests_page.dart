import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_requests_repository.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'community_qr_scanner_page.dart';

class CommunityOwnerRequestsPage extends StatefulWidget {
  const CommunityOwnerRequestsPage({super.key});

  @override
  State<CommunityOwnerRequestsPage> createState() =>
      _CommunityOwnerRequestsPageState();
}

class _CommunityOwnerRequestsPageState
    extends State<CommunityOwnerRequestsPage> {
  final _repository = CommunityRequestsRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyRequestId;
  final Map<String, String> _statusOverrides = <String, String>{};

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  @override
  void initState() {
    super.initState();
    _future = _repository.getOwnerRequests();
  }

  Future<void> _refresh() async {
    final next = _repository.getOwnerRequests();
    setState(() => _future = next);
    await next;
  }

  Future<void> _changeStatus(String requestId, String status) async {
    setState(() => _busyRequestId = requestId);
    try {
      await _repository.updateRequestStatus(
        requestId: requestId,
        status: status,
      );
      // تحديث فوري للواجهة حتى يظهر زر الخطوة التالية بدون انتظار realtime.
      _statusOverrides[requestId] = status;
      if (!mounted) return;
      final message = switch (status) {
        'accepted' => 'تم قبول الطلب',
        'rejected' => 'تم رفض الطلب',
        'ready_for_pickup' => 'تم تجهيز العرض وأصبح جاهزًا للاستلام',
        _ => 'تم تحديث الطلب',
      };
      _showMessage(message, success: status != 'rejected');
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppErrorMapper.message(
            error,
            fallback: 'تعذر تحديث الطلب. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _confirmReject(String requestId) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الطلب؟'),
          content: const Text('سيعود العرض متاحًا للمستخدمين الآخرين.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB54747)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('رفض الطلب'),
            ),
          ],
        ),
      ),
    );
    if (shouldReject == true) {
      await _changeStatus(requestId, 'rejected');
    }
  }

  Future<void> _scanPickupQr(String requestId) async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityQrScannerPage()),
    );
    if (completed == true && mounted) {
      _showMessage('تم تأكيد الاستلام وإكمال الطلب', success: true);
      await _refresh();
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
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
          title: const Text('طلبات عروضك'),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.cloud_off_rounded,
                title: 'تعذر تحميل الطلبات',
                action: _refresh,
              );
            }

            final requests = (snapshot.data ?? const <Map<String, dynamic>>[])
                .where(_matchesFilter)
                .toList();

            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _buildIntro(),
                  const SizedBox(height: 14),
                  _buildFilters(),
                  const SizedBox(height: 14),
                  if (requests.isEmpty)
                    _MessageState(
                      icon: Icons.inbox_rounded,
                      title: 'لا توجد طلبات هنا',
                      action: _refresh,
                    )
                  else
                    ...requests.map(_buildRequestCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _matchesFilter(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final rawStatus = request['status']?.toString() ?? 'pending';
    final status = _statusOverrides[id] ?? _normalizeStatus(rawStatus);
    return _filter == 'all' || status == _filter;
  }

  String _normalizeStatus(String value) {
    switch (value.toLowerCase().trim()) {
      case 'approved':
        return 'accepted';
      case 'ready':
      case 'ready_for_pickup':
        return 'ready_for_pickup';
      case 'done':
        return 'completed';
      default:
        return value.toLowerCase().trim();
    }
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF2BAA76)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلبات الناس على عروضك',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('راجع الطلب، تواصل مع صاحبه، ثم اختر القبول أو الرفض.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.45)),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 40),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = <String, String>{
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز للاستلام',
      'completed': 'مكتمل',
    };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final key = filters.keys.elementAt(index);
          final active = _filter == key;
          return FilterChip(
            selected: active,
            onSelected: (_) => setState(() => _filter = key),
            label: Text(filters[key]!),
            selectedColor: const Color(0xFFDDF3E8),
            backgroundColor: Colors.white,
            checkmarkColor: _green,
            labelStyle: TextStyle(
                color: active ? _green : const Color(0xFF5F786C),
                fontWeight: FontWeight.w800,
                fontSize: 11),
            side: BorderSide(color: active ? _green : const Color(0xFFE0EBE5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final rawStatus = request['status']?.toString() ?? 'pending';
    final status = _statusOverrides[id] ?? _normalizeStatus(rawStatus);
    final offer = request['community_offers'] is Map
        ? Map<String, dynamic>.from(request['community_offers'] as Map)
        : <String, dynamic>{};
    final title = offer['title']?.toString() ?? 'عرض بدون عنوان';
    final image = offer['image']?.toString();
    final message = request['message']?.toString();
    final requester = request['requester'] is Map
        ? Map<String, dynamic>.from(request['requester'] as Map)
        : <String, dynamic>{};
    final requesterName = requester['name']?.toString().trim();
    final requesterPhone = requester['phone']?.toString().trim();
    final requesterEmail = requester['email']?.toString().trim();
    final isBusy = _busyRequestId == id;

    return InkWell(
      onTap: () => _showRequesterDetails(request),
      borderRadius: BorderRadius.circular(21),
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE1ECE6)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 13,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 66,
                    height: 66,
                    child: image == null || image.isEmpty
                        ? Container(
                            color: const Color(0xFFE8F5EE),
                            child: const Icon(Icons.volunteer_activism_rounded,
                                color: _green))
                        : Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8F5EE),
                                child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: _green))))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  _statusPill(status)
                ])),
          ]),
          if (requesterName != null && requesterName.isNotEmpty) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFD5E9FA),
                    child: Icon(Icons.person_rounded, color: Color(0xFF2F6DA5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مقدم الطلب',
                          style: TextStyle(
                            color: Color(0xFF5B7B98),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          requesterName,
                          style: const TextStyle(
                            color: _darkGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (requesterPhone != null && requesterPhone.isNotEmpty)
                          Text(
                            requesterPhone,
                            style: const TextStyle(
                              color: Color(0xFF5B7B98),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded,
                      color: Color(0xFF2F6DA5)),
                ],
              ),
            ),
          ],
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 13),
            const Text('رسالة صاحب الطلب',
                style: TextStyle(
                    color: _darkGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
            const SizedBox(height: 5),
            Text(message,
                style: const TextStyle(
                    color: Color(0xFF71837C), fontSize: 12, height: 1.4))
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : () => _confirmReject(id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB54747),
                      side: const BorderSide(color: Color(0xFFE7B9B9)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        isBusy ? null : () => _changeStatus(id, 'accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('قبول'),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'accepted') ...[
            const SizedBox(height: 12),
            const Text(
                'تم قبول الطلب. جهّز العرض ثم اضغط جاهز للاستلام لإبلاغ صاحب الطلب.',
                style: TextStyle(
                    color: Color(0xFF39755B), fontSize: 12, height: 1.4)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    isBusy ? null : () => _changeStatus(id, 'ready_for_pickup'),
                icon: isBusy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('جاهز للاستلام'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
          if (status == 'ready_for_pickup') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : () => _scanPickupQr(id),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                label: const Text('مسح كود الاستلام'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                'العرض جاهز. انتظر صاحب الطلب لإتمام الاستلام.',
                style: TextStyle(
                  color: Color(0xFF2F6DA5),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _showRequesterDetails(Map<String, dynamic> request) async {
    final requester = request['requester'] is Map
        ? Map<String, dynamic>.from(request['requester'] as Map)
        : <String, dynamic>{};
    final name = requester['name']?.toString().trim();
    final phone = requester['phone']?.toString().trim();
    final email = requester['email']?.toString().trim();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بيانات مقدم الطلب',
                style: TextStyle(
                  color: _darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              _detailRow(Icons.person_rounded, 'الاسم', name),
              _detailRow(Icons.phone_rounded, 'رقم الهاتف', phone),
              _detailRow(Icons.email_rounded, 'البريد الإلكتروني', email),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: phone == null || phone.isEmpty
                      ? null
                      : () =>
                          _showMessage('رقم مقدم الطلب: $phone', success: true),
                  icon: const Icon(Icons.contact_phone_rounded),
                  label: const Text('التواصل مع مقدم الطلب'),
                  style: FilledButton.styleFrom(backgroundColor: _green),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    final text = value == null || value.isEmpty ? 'غير متوفر' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 19),
          const SizedBox(width: 9),
          Text('$label: ', style: const TextStyle(color: Color(0xFF71837C))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _darkGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final data = {
          'pending': (
            'في الانتظار',
            const Color(0xFFFFF0D6),
            const Color(0xFF946313)
          ),
          'accepted': ('مقبول', const Color(0xFFDDF3E8), _green),
          'completed': (
            'مكتمل',
            const Color(0xFFDCEBFA),
            const Color(0xFF2F6DA5)
          ),
          'rejected': (
            'مرفوض',
            const Color(0xFFFBE4E4),
            const Color(0xFFB54747)
          ),
        }[status] ??
        ('ملغي', const Color(0xFFF0F1F0), const Color(0xFF71837C));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: data.$2, borderRadius: BorderRadius.circular(20)),
        child: Text(data.$1,
            style: TextStyle(
                color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final Future<void> Function() action;

  const _MessageState(
      {required this.icon, required this.title, required this.action});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF0B7650), size: 48),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF123F31),
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: action,
          child: const Text('تحديث'),
        )
      ]));
}
