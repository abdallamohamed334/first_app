import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

import '../../data/repositories/institutions_repository.dart';
import 'institution_offer_request_details_page.dart';
import '../../domain/entities/institution_offer_request.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? InstitutionsRepository();

    debugPrint(
      '[InstitutionRequests] init institutionId=${widget.institutionId}',
    );

    _future = _loadRequests();

    _setupRealtime();
  }

  void _setupRealtime() {
    try {
      _subscription = SupabaseService()
          .client
          .from('institution_offer_requests')
          .stream(primaryKey: ['id']).handleError((error) {
        debugPrint(
          '[InstitutionRequests] realtime error: $error',
        );
      }).listen((_) {
        _reloadAfterFrame();
      });
    } catch (e) {
      debugPrint(
        '[InstitutionRequests] realtime setup failed: $e',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    debugPrint(
      '[InstitutionRequests] loading institutionId=${widget.institutionId}',
    );

    final rows = await _repository.listOfferRequestsForInstitution(
      widget.institutionId,
    );

    debugPrint(
      '[InstitutionRequests] returned count=${rows.length}',
    );

    return rows;
  }

  Future<void> _reload() async {
    if (!mounted) return;

    setState(() {
      _future = _loadRequests();
    });

    try {
      await _future;
    } catch (e) {
      debugPrint(
        '[InstitutionRequests] reload error=$e',
      );
    }
  }

  void _reloadAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _reload().catchError((error) {
        debugPrint(
          '[InstitutionRequests] deferred reload error=$error',
        );
      });
    });
  }

  // ============================================================
  // MESSAGES / ERRORS
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFD64545) : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  void _handleError(
    dynamic error, {
    String? customMessage,
  }) {
    debugPrint(
      '[InstitutionRequests] Error: $error',
    );

    String message = customMessage ?? 'حدث خطأ غير متوقع';

    if (error is PostgrestException) {
      switch (error.code) {
        case 'PGRST116':
          message = 'الطلب غير موجود أو تم حذفه';
          break;

        case '23505':
          message = 'حدث تعارض في البيانات';
          break;

        case '42501':
          message = 'غير مصرح لك بهذا الإجراء';
          break;

        default:
          if (error.message.isNotEmpty) {
            message = error.message;
          }
      }
    }

    _showMessage(
      message,
      isError: true,
    );
  }

  // ============================================================
  // OPEN REQUEST DETAILS
  // ============================================================

  void _openRequestDetails(
    BuildContext context,
    Map<String, dynamic> requestMap,
  ) {
    print('📌🔴 _openRequestDetails: requestMap=$requestMap');

    try {
      final request = InstitutionOfferRequest.fromJson(
        requestMap,
      );

      print('📌🔴 _openRequestDetails: request parsed successfully');
      print('📌🔴 request.id=${request.id}');
      print('📌🔴 request.status=${request.status}');
      print('📌🔴 request.pickupCode=${request.pickupCode}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InstitutionOfferRequestDetailsPage(
            request: request,
          ),
        ),
      ).then((_) {
        // ✅ بعد العودة من صفحة التفاصيل، أعد تحميل الطلبات
        _reload();
      });
    } catch (error) {
      print('❌ _openRequestDetails error=$error');
      _showMessage(
        'تعذر فتح تفاصيل الطلب',
        isError: true,
      );
    }
  }

  // ============================================================
  // READY
  // ============================================================

  Future<void> _ready(
    String requestId,
  ) async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      await _repository.markOfferRequestReady(
        requestId,
      );

      if (!mounted) return;

      _showMessage(
        '✅ تم تجهيز الطلب للاستلام',
      );

      await _reload();
    } catch (error) {
      _handleError(
        error,
        customMessage: 'تعذر تجهيز الطلب للاستلام',
      );
    } finally {
      _isProcessing = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ============================================================
  // VERIFY PICKUP CODE
  // ============================================================

  Future<void> _verifyCode(
    String requestId,
  ) async {
    if (!mounted || _isVerifying) return;

    _isVerifying = true;

    if (mounted) {
      setState(() {});
    }

    final controller = TextEditingController();

    try {
      final rawCode = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool invalidCode = false;

          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'تحقق من كود المستخدم',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'اطلب من المستخدم إعطائك الكود المكون من 6 أرقام',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF71837C),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF123F31),
                      ),
                      onChanged: (_) {
                        if (invalidCode) {
                          setDialogState(
                            () => invalidCode = false,
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        errorText: invalidCode ? 'أدخل 6 أرقام' : null,
                        filled: true,
                        fillColor: const Color(0xFFF4F8F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF0B7650),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        color: Color(0xFF71837C),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      final normalized = _normalizeDigits(
                        controller.text,
                      );

                      if (normalized != null) {
                        Navigator.of(
                          dialogContext,
                        ).pop(normalized);
                      } else {
                        setDialogState(
                          () => invalidCode = true,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B7650),
                    ),
                    child: const Text('تحقق'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || rawCode == null) return;

      final code = _normalizeDigits(rawCode);

      if (code == null) {
        _showMessage(
          'اكتب كودًا مكونًا من 6 أرقام',
          isError: true,
        );
        return;
      }

      print('📌🔴 _verifyCode: requestId=$requestId, code=$code');

      debugPrint(
        '[InstitutionRequests] verifying user pickup code '
        'request=$requestId',
      );

      print(
          '📌🔴 _verifyCode: calling repository.verifyOfferRequestPickupCode');

      await _repository.verifyOfferRequestPickupCode(
        requestId: requestId,
        code: code,
      );

      print('📌🔴 _verifyCode: success!');

      if (!mounted) return;

      _showMessage(
        '✅ تم التحقق واستلام الطلب بنجاح',
      );

      await _reload();
    } catch (error) {
      print('❌ _verifyCode error: $error');
      if (mounted) {
        _handleError(
          error,
          customMessage: 'كود الاستلام غير صحيح أو منتهي',
        );
      }
    } finally {
      controller.dispose();
      _isVerifying = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ============================================================
  // ACCEPT / REJECT
  // ============================================================

  Future<void> _decide(
    String requestId,
    bool accept,
  ) async {
    if (_isProcessing) return;

    _isProcessing = true;

    if (mounted) {
      setState(() {});
    }

    try {
      await _repository.updateOfferRequest(
        requestId: requestId,
        accept: accept,
      );

      if (!mounted) return;

      _showMessage(
        accept ? '✅ تم قبول الطلب' : '❌ تم رفض الطلب',
      );

      await _reload();
    } catch (error) {
      _handleError(
        error,
        customMessage: 'تعذر تحديث الطلب حاليًا',
      );
    } finally {
      _isProcessing = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ============================================================
  // DIGITS
  // ============================================================

  String? _normalizeDigits(
    String? value,
  ) {
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
        .replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

    return RegExp(
      r'^\d{6}$',
    ).hasMatch(normalized)
        ? normalized
        : null;
  }

  // ============================================================
  // SAFE MAP CONVERSION
  // ============================================================

  Map<String, dynamic> _safeMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _safeMapList(
    dynamic value,
  ) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  int _safeInt(
    dynamic value,
  ) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // GROUP REQUESTS BY OFFER
  // ============================================================

  List<Map<String, dynamic>> _groupRequestsByOffer(
    List<Map<String, dynamic>> requests,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final originalRequest in requests) {
      final request = _safeMap(originalRequest);

      final offer = _safeMap(
        request['institution_offers'],
      );

      final offerId = offer['id']?.toString().trim().isNotEmpty == true
          ? offer['id'].toString().trim()
          : request['offer_id']?.toString().trim().isNotEmpty == true
              ? request['offer_id'].toString().trim()
              : 'unknown';

      if (!grouped.containsKey(offerId)) {
        grouped[offerId] = {
          'offer': offer,
          'requests': <Map<String, dynamic>>[],
          'totalQuantity': 0,
          'pendingCount': 0,
          'acceptedCount': 0,
          'readyCount': 0,
          'completedCount': 0,
        };
      }

      final group = grouped[offerId]!;

      final requestList = _safeMapList(
        group['requests'],
      );

      requestList.add(request);

      group['requests'] = requestList;

      final quantity = _safeInt(
        request['quantity'],
      );

      group['totalQuantity'] = _safeInt(group['totalQuantity']) + quantity;

      final status = request['status']?.toString().trim() ?? '';

      switch (status) {
        case 'pending':
          group['pendingCount'] = _safeInt(group['pendingCount']) + 1;
          break;

        case 'accepted':
          group['acceptedCount'] = _safeInt(group['acceptedCount']) + 1;
          break;

        case 'ready_for_pickup':
          group['readyCount'] = _safeInt(group['readyCount']) + 1;
          break;

        case 'completed':
        case 'picked_up':
          group['completedCount'] = _safeInt(group['completedCount']) + 1;
          break;
      }
    }

    return grouped.values.toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'طلبات العملاء',
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF123F31),
        ),
        backgroundColor: const Color(0xFFFCF9F2),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (
            context,
            snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0B7650),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Color(0xFFD64545),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'حدث خطأ أثناء التحميل',
                      style: TextStyle(
                        color: Color(0xFF123F31),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text(
                        'إعادة المحاولة',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0B7650),
                      ),
                    ),
                  ],
                ),
              );
            }

            final requests = snapshot.data ?? const <Map<String, dynamic>>[];

            if (requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inbox_rounded,
                      size: 64,
                      color: Color(0xFFB8C8C0),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const Text(
                      'لا توجد طلبات على عروضك حتى الآن',
                      style: TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'عندما يطلب العملاء عروضك، ستظهر هنا',
                      style: TextStyle(
                        color: const Color(
                          0xFF71837C,
                        ).withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            final groupedOffers = _groupRequestsByOffer(requests);

            return RefreshIndicator(
              onRefresh: _reload,
              color: const Color(0xFF0B7650),
              child: ListView.separated(
                padding: const EdgeInsets.all(
                  16,
                ),
                itemCount: groupedOffers.length,
                separatorBuilder: (_, __) => const SizedBox(
                  height: 12,
                ),
                itemBuilder: (
                  _,
                  index,
                ) {
                  return _OfferGroupCard(
                    group: groupedOffers[index],
                    onAccept: (requestId) => _decide(
                      requestId,
                      true,
                    ),
                    onReject: (requestId) => _decide(
                      requestId,
                      false,
                    ),
                    onReady: (requestId) => _ready(
                      requestId,
                    ),
                    onVerifyCode: (requestId) => _verifyCode(
                      requestId,
                    ),
                    onOpenRequest: (requestMap) => _openRequestDetails(
                      context,
                      requestMap,
                    ),
                    isProcessing: _isProcessing || _isVerifying,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// OFFER GROUP CARD
// ============================================================

class _OfferGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;

  final Function(String) onAccept;
  final Function(String) onReject;
  final Function(String) onReady;
  final Function(String) onVerifyCode;
  final Function(Map<String, dynamic>) onOpenRequest;

  final bool isProcessing;

  const _OfferGroupCard({
    required this.group,
    required this.onAccept,
    required this.onReject,
    required this.onReady,
    required this.onVerifyCode,
    required this.onOpenRequest,
    this.isProcessing = false,
  });

  // ============================================================
  // SAFE MAP
  // ============================================================

  Map<String, dynamic> _safeMap(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _safeMapList(
    dynamic value,
  ) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  int _safeInt(
    dynamic value,
  ) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String _getStatusLabel(
    String status,
  ) {
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

  // ============================================================
  // STATUS INFO
  // ============================================================

  ({Color color, String icon}) _getStatusInfo(
    String status,
  ) {
    switch (status) {
      case 'pending':
        return (
          color: const Color(0xFFB36B12),
          icon: '⏳',
        );

      case 'accepted':
        return (
          color: const Color(0xFF3679C8),
          icon: '✅',
        );

      case 'ready_for_pickup':
        return (
          color: const Color(0xFF0B7650),
          icon: '📦',
        );

      case 'picked_up':
        return (
          color: const Color(0xFF6651B5),
          icon: '📋',
        );

      case 'completed':
        return (
          color: const Color(0xFF0B7650),
          icon: '🎉',
        );

      case 'rejected':
        return (
          color: const Color(0xFFB04444),
          icon: '❌',
        );

      case 'cancelled':
        return (
          color: const Color(0xFFB04444),
          icon: '🚫',
        );

      case 'expired':
        return (
          color: const Color(0xFF71837C),
          icon: '⏰',
        );

      default:
        return (
          color: const Color(0xFF71837C),
          icon: '🔄',
        );
    }
  }

  // ============================================================
  // REQUEST ACTIONS
  // ============================================================

  Widget _buildRequestActions(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    final requestId = request['id']?.toString().trim() ?? '';

    final status = request['status']?.toString().trim() ?? 'pending';

    if (requestId.isEmpty) {
      return const SizedBox.shrink();
    }

    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : () => onReject(requestId),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                ),
                label: const Text(
                  'رفض الطلب',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB04444),
                  side: const BorderSide(
                    color: Color(0xFFE5BABA),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: FilledButton.icon(
                onPressed: isProcessing ? null : () => onAccept(requestId),
                icon: const Icon(
                  Icons.check_rounded,
                  size: 18,
                ),
                label: const Text(
                  'قبول الطلب',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B7650),
                  padding: const EdgeInsets.symmetric(
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isProcessing ? null : () => onReady(requestId),
            icon: const Icon(
              Icons.inventory_2_outlined,
              size: 19,
            ),
            label: const Text(
              'تجهيز الطلب للاستلام',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0B7650),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'ready_for_pickup':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isProcessing ? null : () => onVerifyCode(requestId),
            icon: const Icon(
              Icons.verified_user_outlined,
              size: 19,
            ),
            label: const Text(
              'تحقق من كود الاستلام',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3679C8),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'picked_up':
        return _buildSimpleStatus(
          'تم استلام الطلب',
          'الطلب تم استلامه بالفعل',
          const Color(0xFF6651B5),
          Icons.done_all_rounded,
        );

      case 'completed':
        return _buildSimpleStatus(
          'الطلب مكتمل',
          'تم إنهاء الطلب بنجاح',
          const Color(0xFF0B7650),
          Icons.celebration_rounded,
        );

      case 'rejected':
        return _buildSimpleStatus(
          'تم رفض الطلب',
          'هذا الطلب لم يتم قبوله',
          const Color(0xFFB04444),
          Icons.close_rounded,
        );

      case 'cancelled':
        return _buildSimpleStatus(
          'الطلب ملغي',
          'قام المستخدم أو النظام بإلغاء الطلب',
          const Color(0xFFB04444),
          Icons.block_rounded,
        );

      case 'expired':
        return _buildSimpleStatus(
          'الطلب منتهي',
          'انتهت صلاحية هذا الطلب',
          const Color(0xFF71837C),
          Icons.timer_off_outlined,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSimpleStatus(
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF71837C),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUESTER LIST
  // ============================================================

  void _showAllRequesters(
    BuildContext context,
    List<Map<String, dynamic>> requests,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (
          context,
          scrollController,
        ) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(
                    top: 8,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBE3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'جميع طلبات العملاء',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123F31),
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(
                      height: 10,
                    ),
                    itemBuilder: (
                      _,
                      index,
                    ) {
                      return _buildRequesterTile(
                        context,
                        requests[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final offer = _safeMap(
      group['offer'],
    );

    final requests = _safeMapList(
      group['requests'],
    );

    final totalQuantity = _safeInt(
      group['totalQuantity'],
    );

    final pendingCount = _safeInt(
      group['pendingCount'],
    );

    final acceptedCount = _safeInt(
      group['acceptedCount'],
    );

    final readyCount = _safeInt(
      group['readyCount'],
    );

    final completedCount = _safeInt(
      group['completedCount'],
    );

    final title = offer['title']?.toString().trim().isNotEmpty == true
        ? offer['title'].toString().trim()
        : 'عرض بدون عنوان';

    final imagesData = offer['images'];

    final images = imagesData is List ? imagesData : <dynamic>[];

    final imageUrl = images.isNotEmpty ? images.first.toString().trim() : null;

    final totalRequests = requests.length;

    final hasPending = pendingCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7ECE8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10123F31),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==================================================
            // OFFER HEADER
            // ==================================================

            Container(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF2F7F1),
                    Color(0xFFFFFFFF),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      17,
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: const Color(
                        0xFFE8F5EE,
                      ),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (
                                _,
                                __,
                                ___,
                              ) =>
                                  const Icon(
                                Icons.shopping_bag_outlined,
                                color: Color(
                                  0xFF0B7650,
                                ),
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(
                                0xFF0B7650,
                              ),
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(
                    width: 13,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(
                              0xFF123F31,
                            ),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          '$totalRequests طلب • $totalQuantity وحدة',
                          style: const TextStyle(
                            color: Color(
                              0xFF53665E,
                            ),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFFFF0DA,
                        ),
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Text(
                        '$pendingCount جديد',
                        style: const TextStyle(
                          color: Color(
                            0xFFB36B12,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ==================================================
            // STATS
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                8,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatChip(
                      '⏳ قيد المراجعة',
                      pendingCount,
                      const Color(
                        0xFFB36B12,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    _buildStatChip(
                      '✅ مقبول',
                      acceptedCount,
                      const Color(
                        0xFF3679C8,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    _buildStatChip(
                      '📦 جاهز',
                      readyCount,
                      const Color(
                        0xFF0B7650,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    _buildStatChip(
                      '🎉 مكتمل',
                      completedCount,
                      const Color(
                        0xFF2F6DA5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(
              height: 1,
              color: Color(0xFFE7ECE8),
            ),

            // ==================================================
            // REQUESTERS
            // ==================================================

            if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  12,
                ),
                child: Column(
                  children: [
                    ...requests.take(3).map(
                          (request) => _buildRequesterTile(
                            context,
                            request,
                          ),
                        ),
                    if (requests.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            _showAllRequesters(
                              context,
                              requests,
                            );
                          },
                          icon: const Icon(
                            Icons.people_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            'عرض كل الطلبات (${requests.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(
                              0xFF0B7650,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STAT CHIP
  // ============================================================

  Widget _buildStatChip(
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(
            width: 2,
          ),
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUESTER TILE
  // ============================================================

  Widget _buildRequesterTile(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    final safeRequest = _safeMap(request);

    final requester = _safeMap(
      safeRequest['users'],
    );

    final offer = _safeMap(
      safeRequest['institution_offers'],
    );

    final name = requester['name']?.toString().trim().isNotEmpty == true
        ? requester['name'].toString().trim()
        : 'مستخدم loqma';

    final avatar = requester['avatar_url']?.toString().trim() ?? '';

    final quantity = safeRequest['quantity']?.toString() ?? '1';

    final status = safeRequest['status']?.toString().trim() ?? 'pending';

    final requestId = safeRequest['id']?.toString().trim() ?? '';

    final productImages = offer['images'];

    final images = productImages is List ? productImages : <dynamic>[];

    final productImage =
        images.isNotEmpty ? images.first.toString().trim() : '';

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(
            0xFFE7ECE8,
          ),
        ),
      ),
      child: Column(
        children: [
          // ====================================================
          // USER + PRODUCT
          // ====================================================

          InkWell(
            borderRadius: BorderRadius.circular(
              12,
            ),
            onTap: requestId.isEmpty
                ? null
                : () {
                    onOpenRequest(
                      safeRequest,
                    );
                  },
            child: Row(
              children: [
                // PRODUCT IMAGE
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: const Color(
                      0xFFE8F5EE,
                    ),
                    child: productImage.isNotEmpty
                        ? Image.network(
                            productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              _,
                              __,
                              ___,
                            ) =>
                                const Icon(
                              Icons.restaurant_outlined,
                              color: Color(
                                0xFF0B7650,
                              ),
                              size: 25,
                            ),
                          )
                        : const Icon(
                            Icons.restaurant_outlined,
                            color: Color(
                              0xFF0B7650,
                            ),
                            size: 25,
                          ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // USER INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(
                              0xFFE8F5EE,
                            ),
                            backgroundImage: avatar.isNotEmpty
                                ? NetworkImage(
                                    avatar,
                                  )
                                : null,
                            child: avatar.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Color(
                                      0xFF0B7650,
                                    ),
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(
                                  0xFF123F31,
                                ),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'طلب $quantity وحدة',
                        style: const TextStyle(
                          color: Color(
                            0xFF71837C,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // STATUS
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: statusInfo.color.withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        statusInfo.icon,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      _getStatusLabel(
                        status,
                      ),
                      style: TextStyle(
                        color: statusInfo.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  width: 4,
                ),

                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(
                    0xFF71837C,
                  ),
                  size: 20,
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ====================================================
          // ACTION BUTTONS
          // ====================================================

          _buildRequestActions(
            context,
            safeRequest,
          ),
        ],
      ),
    );
  }
}
