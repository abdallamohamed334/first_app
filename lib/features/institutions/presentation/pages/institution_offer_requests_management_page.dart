import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

import '../../data/repositories/institutions_repository.dart';

class InstitutionOfferRequestsManagementPage extends StatefulWidget {
  final String institutionId;
  final InstitutionsRepository? repository;

  const InstitutionOfferRequestsManagementPage({
    super.key,
    required this.institutionId,
    this.repository,
  });

  @override
  State<InstitutionOfferRequestsManagementPage> createState() =>
      _InstitutionOfferRequestsManagementPageState();
}

class _InstitutionOfferRequestsManagementPageState
    extends State<InstitutionOfferRequestsManagementPage> {
  late final InstitutionsRepository _repository;
  late Future<List<Map<String, dynamic>>> _future;
  StreamSubscription? _subscription;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionsRepository();
    debugPrint(
        '[InstitutionRequests] init institutionId=${widget.institutionId}');
    _future = _loadRequests();
    _subscription = SupabaseService()
        .client
        .from('institution_offer_requests')
        .stream(primaryKey: ['id']).listen((_) {
      _reloadAfterFrame();
    }, onError: (error, stackTrace) {
      debugPrint('[InstitutionRequests] realtime error=$error');
      debugPrint('[InstitutionRequests] realtime stack=$stackTrace');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    debugPrint(
        '[InstitutionRequests] loading institutionId=${widget.institutionId}');
    final rows =
        await _repository.listOfferRequestsForInstitution(widget.institutionId);
    debugPrint('[InstitutionRequests] returned count=${rows.length}');
    return rows;
  }

  Future<void> _reload() async {
    final future = _loadRequests();
    if (mounted) {
      setState(() => _future = future);
    }
    await future;
  }

  void _reloadAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload().catchError((error, stackTrace) {
        debugPrint('[InstitutionRequests] deferred reload error=$error');
      }));
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  Future<void> _ready(String requestId) async {
    try {
      await _repository.markOfferRequestReady(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تجهيز الطلب للاستلام')),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تجهيز الطلب للاستلام')),
      );
    }
  }

  Future<void> _verifyCode(String requestId) async {
    if (_isVerifying) return;
    _isVerifying = true;
    final controller = TextEditingController();
    String? rawCode;
    try {
      rawCode = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تحقق من كود المستخدم'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF4F8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('تحقق'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    final code = _normalizeDigits(rawCode);
    if (code == null) {
      _isVerifying = false;
      if (mounted) {
        _showMessage('اكتب كودًا مكونًا من 6 أرقام');
      }
      return;
    }

    try {
      debugPrint(
          '[InstitutionRequests] verifying user pickup code request=$requestId');
      await _repository.verifyOfferRequestPickupCode(
          requestId: requestId, code: code);
      _isVerifying = false;
      if (!mounted) return;
      _showMessage('تم التحقق واستلام الطلب');
      _reloadAfterFrame();
    } on PostgrestException catch (error, stackTrace) {
      _isVerifying = false;
      debugPrint('[InstitutionRequests] verify code failed code=${error.code}');
      debugPrint('[InstitutionRequests] verify code message=${error.message}');
      debugPrint('[InstitutionRequests] verify code details=${error.details}');
      debugPrint('[InstitutionRequests] verify code stack=$stackTrace');
      if (!mounted) return;
      _showMessage('كود الاستلام غير صحيح أو منتهي');
    } catch (error, stackTrace) {
      _isVerifying = false;
      debugPrint('[InstitutionRequests] verify unexpected error=$error');
      debugPrint('[InstitutionRequests] verify unexpected stack=$stackTrace');
      if (!mounted) return;
      _showMessage('تعذر التحقق من الكود حاليًا');
    }
  }

  Future<void> _decide(String requestId, bool accept) async {
    try {
      await _repository.updateOfferRequest(
          requestId: requestId, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'تم قبول الطلب' : 'تم رفض الطلب')),
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث الطلب حاليًا')),
      );
    }
  }

  String? _normalizeDigits(String? value) {
    if (value == null) return null;
    final normalized = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^\d{6}$').hasMatch(normalized) ? normalized : null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('طلبات العملاء')),
        backgroundColor: const Color(0xFFFCF9F2),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: FilledButton.tonal(
                      onPressed: _reload, child: const Text('إعادة المحاولة')));
            }
            final requests = snapshot.data ?? const <Map<String, dynamic>>[];
            if (requests.isEmpty)
              return const Center(
                  child: Text('لا توجد طلبات على عروضك حتى الآن'));
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _RequestCard(
                  row: requests[index],
                  onAccept: () =>
                      _decide(requests[index]['id'].toString(), true),
                  onReject: () =>
                      _decide(requests[index]['id'].toString(), false),
                  onReady: () => _ready(requests[index]['id'].toString()),
                  onVerifyCode: () =>
                      _verifyCode(requests[index]['id'].toString()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onReady;
  final VoidCallback onVerifyCode;

  const _RequestCard({
    required this.row,
    required this.onAccept,
    required this.onReject,
    required this.onReady,
    required this.onVerifyCode,
  });

  @override
  Widget build(BuildContext context) {
    final offer = row['institution_offers_core'] is Map
        ? Map<String, dynamic>.from(row['institution_offers_core'] as Map)
        : row['institution_offers'] is Map
            ? Map<String, dynamic>.from(row['institution_offers'] as Map)
            : const <String, dynamic>{};
    final status = row['status']?.toString() ?? 'pending';
    final title = offer['title']?.toString().trim();
    final requester = _firstText(row, const [
      'requester_name',
      'user_name',
      'customer_name',
      'requester_full_name',
    ]);
    final phone =
        _firstText(row, const ['requester_phone', 'user_phone', 'phone']);
    final quantity = row['quantity']?.toString() ?? '1';
    final palette = _statusPalette(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7ECE8)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10123F31), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF2F7F1), Color(0xFFFFFFFF)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF123F31),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title?.isNotEmpty == true
                              ? title!
                              : 'طلب على عرض المؤسسة',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF123F31),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'طلب جديد على عرضك',
                          style: TextStyle(
                              color: const Color(0xFF53665E), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                      label: _statusLabel(status),
                      color: palette.$1,
                      background: palette.$2),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.person_outline,
                          label: 'مقدم الطلب',
                          value: requester ?? 'مستخدم التطبيق',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'الكمية المطلوبة',
                          value: '$quantity وحدة',
                        ),
                      ),
                    ],
                  ),
                  if (phone != null) ...[
                    const SizedBox(height: 10),
                    _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'رقم الهاتف',
                        value: phone),
                  ],
                  const SizedBox(height: 18),
                  _RequestTimeline(status: status),
                  if (status == 'pending') ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('رفض الطلب'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB04444),
                              side: const BorderSide(color: Color(0xFFE7BABA)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onAccept,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('قبول الطلب'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF123F31),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (status == 'accepted') ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: onReady,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('العرض جاهز للاستلام'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF123F31),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ] else if (status == 'ready_for_pickup') ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onVerifyCode,
                        icon: const Icon(Icons.verified_outlined, size: 19),
                        label: const Text('تحقق من كود المستخدم'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF123F31),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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

  String? _firstText(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  (Color, Color) _statusPalette(String status) {
    switch (status) {
      case 'accepted':
      case 'ready_for_pickup':
        return (const Color(0xFF0B7650), const Color(0xFFE5F4EC));
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return (const Color(0xFFB04444), const Color(0xFFFBEAEA));
      case 'picked_up':
      case 'completed':
        return (const Color(0xFF245F9E), const Color(0xFFE9F1FB));
      default:
        return (const Color(0xFF8A6B20), const Color(0xFFFFF4D8));
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'تم القبول';
      case 'rejected':
        return 'تم الرفض';
      case 'ready_for_pickup':
        return 'جاهز للاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'expired':
        return 'منتهي';
      default:
        return 'في انتظار المراجعة';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusBadge(
      {required this.label, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(30)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38715E), size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF718079), fontSize: 11)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF1B332A),
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTimeline extends StatelessWidget {
  final String status;

  const _RequestTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('pending', 'مراجعة الطلب'),
      ('accepted', 'قبول الطلب'),
      ('ready_for_pickup', 'جاهز للاستلام'),
      ('completed', 'اكتمل التسليم'),
    ];
    final current = switch (status) {
      'pending' => 0,
      'accepted' => 1,
      'ready_for_pickup' => 2,
      'picked_up' || 'completed' => 3,
      _ => 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('خط سير الطلب',
            style: TextStyle(
                color: Color(0xFF123F31),
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: List.generate(steps.length, (index) {
            final done = index <= current &&
                status != 'rejected' &&
                status != 'cancelled' &&
                status != 'expired';
            return Expanded(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF123F31)
                              : const Color(0xFFE4EAE5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(done ? Icons.check : Icons.circle,
                            color:
                                done ? Colors.white : const Color(0xFFA8B4AC),
                            size: done ? 15 : 8),
                      ),
                      const SizedBox(height: 6),
                      Text(steps[index].$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: done
                                  ? const Color(0xFF123F31)
                                  : const Color(0xFF89958E),
                              fontSize: 9.5,
                              fontWeight:
                                  done ? FontWeight.w800 : FontWeight.w500)),
                    ],
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                        child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(
                                bottom: 23, left: 5, right: 5),
                            color: index < current
                                ? const Color(0xFF123F31)
                                : const Color(0xFFE4EAE5))),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
