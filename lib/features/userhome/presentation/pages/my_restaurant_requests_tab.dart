// lib/features/userhome/presentation/widgets/my_restaurant_requests_tab.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loqma/core/services/supabase_service.dart';

class MyRestaurantRequestsTab extends StatefulWidget {
  const MyRestaurantRequestsTab({super.key});

  @override
  State<MyRestaurantRequestsTab> createState() =>
      _MyRestaurantRequestsTabState();
}

class _MyRestaurantRequestsTabState extends State<MyRestaurantRequestsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _loadRequests();
  }

  // ============================================================
  // LOAD REQUESTS
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final user = SupabaseService().client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    final response = await SupabaseService().client.rpc(
          'user_list_my_food_requests',
        );

    if (response is! List) return <Map<String, dynamic>>[];

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _refresh() async {
    final next = _loadRequests();
    setState(() => _future = next);
    await next;
  }

  // ============================================================
  // CANCEL REQUEST
  // ============================================================

  Future<void> _cancel(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: const Text(
            'سيتم إلغاء طلبك على الوجبة. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB54747),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyId = requestId);

    try {
      await SupabaseService().client.rpc(
        'update_food_offer_request_status',
        params: {
          'p_request_id': requestId,
          'p_next_status': 'cancelled',
        },
      );

      if (!mounted) return;
      _showMessage('تم إلغاء الطلب', success: true);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر إلغاء الطلب: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ============================================================
  // SHOW PICKUP CODE (✅ جديد — بيثبّت الكود 12 ساعة)
  // ============================================================

  Future<void> _showPickupQr(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';

    if (requestId.isEmpty) {
      _showMessage('بيانات الطلب غير صحيحة');
      return;
    }

    setState(() => _busyId = requestId);

    try {
      // ✅ نادي الـ RPC الجديدة
      final result = await SupabaseService().client.rpc(
        'generate_restaurant_pickup_code',
        params: {'p_request_id': requestId},
      );

      if (!mounted) return;

      // استخرج النتيجة
      Map<String, dynamic>? data;

      if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else if (result is List && result.isNotEmpty) {
        final first = result.first;
        if (first is Map) {
          data = Map<String, dynamic>.from(first);
        }
      }

      if (data == null) {
        throw Exception('استجابة غير صحيحة من الخادم');
      }

      final success = data['success'] == true;

      if (!success) {
        throw Exception(data['message'] ?? 'تعذر إنشاء الكود');
      }

      final token = data['token']?.toString() ?? '';
      final expiresStr = data['expires_at']?.toString();
      final isNew = data['is_new'] == true;

      if (token.isEmpty) {
        throw Exception('لم يتم استلام الكود من الخادم');
      }

      final expiresAt =
          expiresStr != null ? DateTime.tryParse(expiresStr) : null;

      debugPrint(
        '🔑 Pickup code: $token, '
        'is_new: $isNew, '
        'expires_at: $expiresAt',
      );

      if (!mounted) return;

      // ✅ عرض الـ Dialog
      await showDialog<void>(
        context: context,
        builder: (ctx) => _PickupCodeDialog(
          token: token,
          expiresAt: expiresAt,
        ),
      );

      // تحديث القائمة (الحالة ممكن تتغير)
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر إنشاء كود الاستلام: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor:
            success ? colorScheme.primary : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return _messageState(
              context,
              icon: Icons.cloud_off_rounded,
              title: 'تعذر تحميل طلباتك',
              subtitle: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final all = snapshot.data ?? const <Map<String, dynamic>>[];
          final requests = all.where(_matchesFilter).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _buildIntro(colorScheme),
              const SizedBox(height: 14),
              _buildFilters(colorScheme),
              const SizedBox(height: 14),
              if (requests.isEmpty)
                _messageState(
                  context,
                  icon: Icons.receipt_long_rounded,
                  title: 'لا توجد طلبات بهذا الفلتر',
                  subtitle: _filter == 'all'
                      ? 'لم تقم بأي طلبات على المطاعم بعد.'
                      : 'جرّب اختيار فلتر مختلف.',
                  onRetry: _refresh,
                )
              else
                ...requests.map((r) => _buildRequestCard(context, r)),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // INTRO HEADER
  // ============================================================

  Widget _buildIntro(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📋 تابع طلباتك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'اعرف حالة طلبك على الوجبات ومتى تستلمها.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 42,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  bool _matchesFilter(Map<String, dynamic> row) {
    if (_filter == 'all') return true;
    return row['status']?.toString() == _filter;
  }

  Widget _buildFilters(ColorScheme colorScheme) {
    final filters = {
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز للاستلام',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
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
            selectedColor: colorScheme.primary.withValues(alpha: 0.15),
            backgroundColor: colorScheme.surface,
            checkmarkColor: colorScheme.primary,
            labelStyle: TextStyle(
              color:
                  active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            side: BorderSide(
              color: active ? colorScheme.primary : colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // REQUEST CARD
  // ============================================================

  Widget _buildRequestCard(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final id = request['id']?.toString() ?? '';
    final status = request['status']?.toString() ?? 'pending';
    final busy = _busyId == id;

    final offerTitle = request['offer_title']?.toString() ?? 'وجبة';
    final offerImage = request['offer_image']?.toString();
    final price = (request['offer_sale_price'] as num?)?.toDouble() ?? 0.0;
    final originalPrice = (request['offer_original_price'] as num?)?.toDouble();

    final businessName = request['business_name']?.toString() ?? 'مطعم';
    final businessLogo = request['business_logo']?.toString();
    final businessAddress = request['business_address']?.toString() ?? '';

    final quantity = (request['quantity'] as num?)?.toInt() ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── صورة الوجبة + التفاصيل ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: offerImage != null && offerImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: offerImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.restaurant_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offerTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            backgroundImage: (businessLogo != null &&
                                    businessLogo.isNotEmpty)
                                ? NetworkImage(businessLogo)
                                : null,
                            child:
                                (businessLogo == null || businessLogo.isEmpty)
                                    ? Icon(
                                        Icons.storefront_rounded,
                                        size: 10,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (price > 0)
                            Text(
                              '${price.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (originalPrice != null &&
                              originalPrice > price) ...[
                            const SizedBox(width: 5),
                            Text(
                              originalPrice.toStringAsFixed(0),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'الكمية: $quantity',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
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
          ),

          // ─── Timeline ───
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.3 : 0.5,
              ),
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: _buildTimeline(context, status),
          ),

          // ─── العنوان ───
          if (businessAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      businessAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Actions ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildActions(
              context,
              id: id,
              status: status,
              request: request,
              busy: busy,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget _buildTimeline(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;

    const steps = [
      'pending',
      'accepted',
      'ready_for_pickup',
      'completed',
    ];

    const labels = {
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز',
      'completed': 'مكتمل',
    };

    final isTerminated =
        status == 'cancelled' || status == 'rejected' || status == 'expired';

    final currentIndex = isTerminated ? -1 : steps.indexOf(status);

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isEven) {
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= currentIndex;
              final isCurrent = stepIndex == currentIndex;

              return Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isActive
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : null,
              );
            }

            final lineIndex = index ~/ 2;
            final lineActive = lineIndex < currentIndex;

            return Expanded(
              child: Container(
                height: 3,
                color: lineActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: steps.map((step) {
            final stepIndex = steps.indexOf(step);
            final isActive = stepIndex <= currentIndex;
            final isCurrent = stepIndex == currentIndex;

            return Expanded(
              child: Text(
                labels[step]!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isCurrent
                      ? colorScheme.primary
                      : isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _buildActions(
    BuildContext context, {
    required String id,
    required String status,
    required Map<String, dynamic> request,
    required bool busy,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (status == 'ready_for_pickup') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : () => _showPickupQr(request),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.qr_code_2_rounded, size: 18),
          label: const Text('عرض كود الاستلام'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (status == 'pending' || status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy ? null : () => _cancel(id),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('إلغاء الطلب'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB54747),
            side: const BorderSide(color: Color(0xFFE7B9B9)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (status == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '✅ تم استلام الطلب',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'expired') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '⏳ انتهت صلاحية الطلب',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBE4E4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cancel_rounded,
            size: 16,
            color: Color(0xFFB54747),
          ),
          const SizedBox(width: 6),
          Text(
            status == 'rejected' ? '❌ تم رفض الطلب' : '🚫 تم إلغاء الطلب',
            style: const TextStyle(
              color: Color(0xFFB54747),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE STATE
  // ============================================================

  Widget _messageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Future<void> Function() onRetry,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 56),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ✅ PICKUP CODE DIALOG (جديد — كود ثابت + عداد 12 ساعة)
// ============================================================

class _PickupCodeDialog extends StatefulWidget {
  final String token;
  final DateTime? expiresAt;

  const _PickupCodeDialog({
    required this.token,
    required this.expiresAt,
  });

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  Timer? _timer;
  Duration _remaining = const Duration(hours: 12);
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    if (!mounted) return;

    if (widget.expiresAt == null) {
      setState(() {
        _remaining = const Duration(hours: 12);
        _isExpired = false;
      });
      return;
    }

    final diff = widget.expiresAt!.difference(DateTime.now());

    setState(() {
      if (diff.isNegative) {
        _remaining = Duration.zero;
        _isExpired = true;
      } else {
        _remaining = diff;
        _isExpired = false;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    if (_isExpired) return 'انتهت الصلاحية';

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Header ───
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'كود الاستلام',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'اعرض هذا الكود للمطعم عند الاستلام.',
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),

                // ─── QR ───
                Center(
                  child: Opacity(
                    opacity: _isExpired ? 0.35 : 1,
                    child: QrImageView(
                      data: widget.token,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ─── الكود النصي ───
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          widget.token,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'نسخ الكود',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.token),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ الكود'),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          Icons.copy_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── العداد التنازلي ───
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isExpired
                        ? const Color(0xFFFBE4E4)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isExpired
                            ? Icons.timer_off_rounded
                            : Icons.timer_rounded,
                        size: 18,
                        color: _isExpired
                            ? const Color(0xFFB54747)
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isExpired
                            ? 'انتهت صلاحية الكود'
                            : 'متبقي: ${_formatRemaining()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _isExpired
                              ? const Color(0xFFB54747)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'لا تشارك الكود قبل وصولك واستلام الطلب. الكود صالح لمدة 12 ساعة فقط.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF71837C),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
