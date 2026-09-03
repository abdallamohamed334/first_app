import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/presentation/pages/user_profile_page.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionsRepository();
    debugPrint(
        '[InstitutionRequests] init institutionId=${widget.institutionId}');
    _future = _loadRequests();

    try {
      _subscription = SupabaseService()
          .client
          .from('institution_offer_requests')
          .stream(primaryKey: ['id']).handleError((error) {
        debugPrint('[InstitutionRequests] realtime error: $error');
      }).listen((_) {
        _reloadAfterFrame();
      });
    } catch (e) {
      debugPrint('[InstitutionRequests] realtime setup failed: $e');
    }
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
    if (!mounted) return;
    setState(() {
      _future = _loadRequests();
    });
    await _future;
  }

  void _reloadAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload().catchError((error) {
        debugPrint('[InstitutionRequests] deferred reload error=$error');
      });
    });
  }

  void _showMessage(String message, {bool isError = false}) {
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

  void _handleError(dynamic error, {String? customMessage}) {
    debugPrint('[InstitutionRequests] Error: $error');
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
          message = error.message ?? message;
      }
    }

    _showMessage(message, isError: true);
  }

  Future<void> _ready(String requestId) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _repository.markOfferRequestReady(requestId);
      if (!mounted) return;
      _showMessage('✅ تم تجهيز الطلب للاستلام');
      await _reload();
    } catch (error) {
      _handleError(error, customMessage: 'تعذر تجهيز الطلب للاستلام');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _verifyCode(String requestId) async {
    if (!mounted || _isVerifying) return;
    _isVerifying = true;
    final controller = TextEditingController();

    try {
      final rawCode = await showDialog<String>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) {
          var invalidCode = false;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('تحقق من كود المستخدم'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اطلب من المستخدم إعطائك الكود المكون من 6 أرقام',
                    style: TextStyle(fontSize: 13, color: Color(0xFF71837C)),
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
                      if (invalidCode)
                        setDialogState(() => invalidCode = false);
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
                        borderSide: const BorderSide(color: Color(0xFF0B7650)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Color(0xFF71837C))),
                ),
                FilledButton(
                  onPressed: () {
                    final normalized = _normalizeDigits(controller.text);
                    if (normalized != null) {
                      Navigator.of(dialogContext).pop(normalized);
                    } else {
                      setDialogState(() => invalidCode = true);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B7650),
                  ),
                  child: const Text('تحقق'),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted || rawCode == null) return;
      final code = _normalizeDigits(rawCode);
      if (code == null) {
        _showMessage('اكتب كودًا مكونًا من 6 أرقام', isError: true);
        return;
      }

      debugPrint(
          '[InstitutionRequests] verifying user pickup code request=$requestId');
      await _repository.verifyOfferRequestPickupCode(
          requestId: requestId, code: code);
      if (!mounted) return;
      _showMessage('تم التحقق واستلام الطلب بنجاح');
      await _reload();
    } catch (error) {
      if (mounted) {
        _handleError(error, customMessage: 'كود الاستلام غير صحيح أو منتهي');
      }
    } finally {
      controller.dispose();
      _isVerifying = false;
    }
  }

  Future<void> _decide(String requestId, bool accept) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _repository.updateOfferRequest(
          requestId: requestId, accept: accept);
      if (!mounted) return;
      _showMessage(accept ? '✅ تم قبول الطلب' : '❌ تم رفض الطلب');
      await _reload();
    } catch (error) {
      _handleError(error, customMessage: 'تعذر تحديث الطلب حاليًا');
    } finally {
      _isProcessing = false;
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

  List<Map<String, dynamic>> _groupRequestsByOffer(
      List<Map<String, dynamic>> requests) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var request in requests) {
      final offer = request['institution_offers_core'] as Map? ?? {};
      final offerId = offer['id']?.toString() ?? 'unknown';

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

      grouped[offerId]!['requests'].add(request);
      grouped[offerId]!['totalQuantity'] =
          (grouped[offerId]!['totalQuantity'] as int) +
              (request['quantity'] as int? ?? 0);

      final status = request['status']?.toString() ?? '';
      if (status == 'pending') {
        grouped[offerId]!['pendingCount'] =
            (grouped[offerId]!['pendingCount'] as int) + 1;
      } else if (status == 'accepted') {
        grouped[offerId]!['acceptedCount'] =
            (grouped[offerId]!['acceptedCount'] as int) + 1;
      } else if (status == 'ready_for_pickup') {
        grouped[offerId]!['readyCount'] =
            (grouped[offerId]!['readyCount'] as int) + 1;
      } else if (status == 'completed' || status == 'picked_up') {
        grouped[offerId]!['completedCount'] =
            (grouped[offerId]!['completedCount'] as int) + 1;
      }
    }

    return grouped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات العملاء'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF123F31),
        ),
        backgroundColor: const Color(0xFFFCF9F2),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
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
                    const SizedBox(height: 12),
                    Text(
                      'حدث خطأ أثناء التحميل',
                      style: const TextStyle(
                        color: Color(0xFF123F31),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
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
                    const SizedBox(height: 12),
                    const Text(
                      'لا توجد طلبات على عروضك حتى الآن',
                      style: TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عندما يطلب العملاء عروضك، ستظهر هنا',
                      style: TextStyle(
                        color: Color(0xFF71837C).withOpacity(0.7),
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
                padding: const EdgeInsets.all(16),
                itemCount: groupedOffers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _OfferGroupCard(
                  group: groupedOffers[index],
                  onAccept: (requestId) => _decide(requestId, true),
                  onReject: (requestId) => _decide(requestId, false),
                  onReady: (requestId) => _ready(requestId),
                  onVerifyCode: (requestId) => _verifyCode(requestId),
                  isProcessing: _isProcessing,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// ✅ كارد تجميع الطلبات حسب العرض
// ============================================================

class _OfferGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final Function(String) onAccept;
  final Function(String) onReject;
  final Function(String) onReady;
  final Function(String) onVerifyCode;
  final bool isProcessing;

  const _OfferGroupCard({
    required this.group,
    required this.onAccept,
    required this.onReject,
    required this.onReady,
    required this.onVerifyCode,
    this.isProcessing = false,
  });

  void _showAllRequesters(
      BuildContext context, List<Map<String, dynamic>> requests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
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
                  'جميع المستخدمين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123F31),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final request = requests[index];
                    final requester = request['users'] as Map? ?? {};
                    final name =
                        requester['name']?.toString().trim().isNotEmpty == true
                            ? requester['name'].toString().trim()
                            : 'مستخدم Loqma';
                    final avatar =
                        requester['avatar_url']?.toString().trim() ?? '';
                    final quantity = request['quantity']?.toString() ?? '1';
                    final status = request['status']?.toString() ?? 'pending';
                    final userId = requester['id']?.toString().trim() ?? '';
                    final userPhone =
                        requester['phone']?.toString().trim() ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE8F5EE),
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: Color(0xFF0B7650),
                                size: 22,
                              )
                            : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123F31),
                        ),
                      ),
                      subtitle: Text(
                        'طلب $quantity وحدة • ${_getStatusLabel(status)}',
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (userId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfilePage(
                                  userId: userId,
                                  userName: name,
                                  userAvatar: avatar,
                                  userPhone: userPhone,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF0B7650),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (userId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfilePage(
                                userId: userId,
                                userName: name,
                                userAvatar: avatar,
                                userPhone: userPhone,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'accepted':
        return 'مقبول';
      case 'ready_for_pickup':
        return 'جاهز';
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

  @override
  Widget build(BuildContext context) {
    final offer = group['offer'] as Map<String, dynamic>? ?? {};
    final requests = group['requests'] as List<Map<String, dynamic>>? ?? [];
    final totalQuantity = group['totalQuantity'] as int? ?? 0;
    final pendingCount = group['pendingCount'] as int? ?? 0;
    final acceptedCount = group['acceptedCount'] as int? ?? 0;
    final readyCount = group['readyCount'] as int? ?? 0;
    final completedCount = group['completedCount'] as int? ?? 0;

    final title = offer['title']?.toString().trim() ?? 'عرض بدون عنوان';
    final images = offer['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;

    final totalRequests = requests.length;
    final hasPending = pendingCount > 0;

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Container(
                      width: 54,
                      height: 54,
                      color: const Color(0xFFE8F5EE),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.shopping_bag_outlined,
                                color: Color(0xFF0B7650),
                                size: 28,
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: Color(0xFF0B7650),
                              size: 28,
                            ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF123F31),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalRequests طلب • $totalQuantity وحدة',
                          style: const TextStyle(
                            color: Color(0xFF53665E),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0DA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount جديد',
                        style: const TextStyle(
                          color: Color(0xFFB36B12),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  _buildStatChip(
                      '⏳ قيد المراجعة', pendingCount, const Color(0xFFB36B12)),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      '✅ مقبول', acceptedCount, const Color(0xFF3679C8)),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      '📦 جاهز', readyCount, const Color(0xFF0B7650)),
                  const SizedBox(width: 8),
                  _buildStatChip(
                      '🎉 مكتمل', completedCount, const Color(0xFF2F6DA5)),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE7ECE8)),
            if (requests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  children: [
                    ...requests.take(3).map(
                        (request) => _buildRequesterTile(context, request)),
                    if (requests.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () {
                            _showAllRequesters(context, requests);
                          },
                          icon: const Icon(Icons.people_outline_rounded,
                              size: 18),
                          label: Text(
                            'عرض كل المستخدمين (${requests.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0B7650),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
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
          const SizedBox(width: 2),
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

  Widget _buildRequesterTile(
      BuildContext context, Map<String, dynamic> request) {
    final requester = request['users'] as Map? ?? {};
    final name = requester['name']?.toString().trim().isNotEmpty == true
        ? requester['name'].toString().trim()
        : 'مستخدم Loqma';
    final avatar = requester['avatar_url']?.toString().trim() ?? '';
    final quantity = request['quantity']?.toString() ?? '1';
    final status = request['status']?.toString() ?? 'pending';
    final userId = requester['id']?.toString().trim() ?? '';
    final userPhone = requester['phone']?.toString().trim() ?? '';

    final statusColors = {
      'pending': (const Color(0xFFB36B12), '⏳'),
      'accepted': (const Color(0xFF3679C8), '✅'),
      'ready_for_pickup': (const Color(0xFF0B7650), '📦'),
      'picked_up': (const Color(0xFF6651B5), '📋'),
      'completed': (const Color(0xFF0B7650), '🎉'),
      'rejected': (const Color(0xFFB04444), '❌'),
      'cancelled': (const Color(0xFFB04444), '🚫'),
      'expired': (const Color(0xFF71837C), '⏰'),
    };
    final statusInfo = statusColors[status] ?? (const Color(0xFF71837C), '🔄');

    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userId: userId,
                userName: name,
                userAvatar: avatar,
                userPhone: userPhone,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFE7ECE8).withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE8F5EE),
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0B7650),
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF123F31),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'طلب $quantity وحدة',
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusInfo.$1.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${statusInfo.$2} ${_getStatusLabel(status)}',
                          style: TextStyle(
                            color: statusInfo.$1,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: const Color(0xFF71837C),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
