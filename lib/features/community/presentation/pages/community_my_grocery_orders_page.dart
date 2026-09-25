// lib/features/community/presentation/pages/community_my_grocery_orders_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer_request.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';

enum _OrderFilter { active, finished }

class CommunityMyGroceryOrdersPage extends StatefulWidget {
  const CommunityMyGroceryOrdersPage({super.key});

  @override
  State<CommunityMyGroceryOrdersPage> createState() =>
      _CommunityMyGroceryOrdersPageState();
}

class _CommunityMyGroceryOrdersPageState
    extends State<CommunityMyGroceryOrdersPage> {
  final InstitutionOffersRepository _repository = InstitutionOffersRepository();
  late Future<List<InstitutionOfferRequest>> _future;
  _OrderFilter _filter = _OrderFilter.active;

  @override
  void initState() {
    super.initState();
    _future = _repository.listMyRequests();
  }

  Future<void> _refresh() async {
    final next = _repository.listMyRequests();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          ' طلبات البقاله والمحلات ',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.onSurface),
      ),
      body: FutureBuilder<List<InstitutionOfferRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return _EmptyState(onRefresh: _refresh);
          }

          final activeCount = requests.where((r) => r.isActive).length;
          final finishedCount = requests.length - activeCount;

          final filtered = requests
              .where(
                (r) =>
                    _filter == _OrderFilter.active ? r.isActive : !r.isActive,
              )
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _FilterBar(
                  selected: _filter,
                  activeCount: activeCount,
                  finishedCount: finishedCount,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        onRefresh: _refresh,
                        title: _filter == _OrderFilter.active
                            ? 'لا توجد طلبات نشطة حاليًا'
                            : 'لا توجد طلبات منتهية بعد',
                        subtitle: _filter == _OrderFilter.active
                            ? 'الطلبات الجارية والمقبولة هتظهر هنا'
                            : 'الطلبات المكتملة أو الملغاة هتظهر هنا',
                      )
                    : RefreshIndicator(
                        color: colors.primary,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final request = filtered[index];
                            return _GroceryOrderTrackingCard(
                              request: request,
                              onTap: () => _openOfferDetails(context, request),
                              onShowCode: () =>
                                  _handleShowCode(context, request),
                              onShowRoute: () {
                                // TODO: افتح صفحة الـ Tracking بالخريطة هنا
                              },
                              onRate: () {
                                // TODO: افتح صفحة التقييم
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openOfferDetails(
    BuildContext context,
    InstitutionOfferRequest request,
  ) {
    final offerMap = request.offer;

    if (offerMap == null || offerMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر عرض تفاصيل هذا العرض حاليًا')),
      );
      return;
    }

    late final InstitutionOffer offer;
    try {
      offer = InstitutionOffer.fromJson(offerMap);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر عرض تفاصيل هذا العرض حاليًا')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstitutionOfferDetailsPage(offer: offer),
      ),
    );
  }

  // ✅ المستخدم يطلب كود الاستلام
  Future<void> _handleShowCode(
    BuildContext context,
    InstitutionOfferRequest request,
  ) async {
    try {
      final result = await _repository.generatePickupCodeForUser(request.id);
      if (!context.mounted) return;

      final code = result['pickup_code']?.toString() ?? '';
      if (code.isEmpty) {
        throw Exception('لم يتم إرجاع كود');
      }

      final offer = request.offer ?? {};
      final institutions = offer['institutions'] as Map<String, dynamic>?;
      final address = offer['pickup_location']?.toString().trim();
      final fallbackAddress = institutions?['address']?.toString().trim();

      showDialog(
        context: context,
        builder: (_) => _PickupCodeDialog(
          code: code,
          address: (address?.isNotEmpty ?? false)
              ? address!
              : (fallbackAddress ?? ''),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء كود الاستلام: $e')),
        );
      }
    }
  }
}

// ============================================================
// شريط الفلتر: نشط / منتهي
// ============================================================

class _FilterBar extends StatelessWidget {
  final _OrderFilter selected;
  final int activeCount;
  final int finishedCount;
  final ValueChanged<_OrderFilter> onChanged;

  const _FilterBar({
    required this.selected,
    required this.activeCount,
    required this.finishedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEAF3EE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterTab(
              label: 'نشط',
              count: activeCount,
              isSelected: selected == _OrderFilter.active,
              onTap: () => onChanged(_OrderFilter.active),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _FilterTab(
              label: 'منتهي',
              count: finishedCount,
              isSelected: selected == _OrderFilter.finished,
              onTap: () => onChanged(_OrderFilter.finished),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? colors.onPrimary : colors.onSurface,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.onPrimary.withValues(alpha: 0.25)
                      : colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? colors.onPrimary : colors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// كارت تتبّع الطلب
// ============================================================

class _GroceryOrderTrackingCard extends StatelessWidget {
  final InstitutionOfferRequest request;
  final VoidCallback onTap;
  final VoidCallback onShowCode;
  final VoidCallback onShowRoute;
  final VoidCallback onRate;

  const _GroceryOrderTrackingCard({
    required this.request,
    required this.onTap,
    required this.onShowCode,
    required this.onShowRoute,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final offer = request.offer ?? const <String, dynamic>{};
    final institution = offer['institutions'] as Map<String, dynamic>?;

    final title = (offer['title']?.toString() ?? '').trim();
    final institutionName = (institution?['name']?.toString() ?? '').trim();
    final institutionLogo = institution?['logo_url']?.toString() ?? '';

    final locationParts = <String>[
      if ((institution?['address']?.toString() ?? '').trim().isNotEmpty)
        institution!['address'].toString().trim(),
      if ((institution?['city']?.toString() ?? '').trim().isNotEmpty)
        institution!['city'].toString().trim(),
    ];

    final price = (offer['symbolic_price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (offer['original_price'] as num?)?.toDouble() ?? 0;
    final hasDiscount = originalPrice > price && price >= 0;
    final discountPercent = hasDiscount
        ? (((originalPrice - price) / originalPrice) * 100).round()
        : 0;

    final images = (offer['images'] as List?)?.cast<String>() ?? [];
    final isCancelled = request.isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0x0A123F31),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- شريط المؤسسة العلوي ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    _InstitutionAvatar(logoUrl: institutionLogo),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        institutionName.isNotEmpty ? institutionName : 'بقالة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(request: request),
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Divider(height: 1, color: colors.outlineVariant),
              ),

              // ---------- تفاصيل المنتج ----------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProductThumbnail(
                      images: images,
                      discountPercent: discountPercent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isNotEmpty ? title : 'عنصر بقالة',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (locationParts.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined,
                                    size: 14, color: colors.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationParts.join('، '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: colors.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _QuantityBadge(quantity: request.quantity),
                              const SizedBox(width: 8),
                              if (hasDiscount)
                                Text(
                                  '${_formatPrice(originalPrice)} جنيه',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              if (hasDiscount) const SizedBox(width: 6),
                              Text(
                                '${_formatPrice(price)} جنيه',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          // ✅ كود التتبع (كود الحجز) - bookingCode
                          if (request.bookingCode != null &&
                              request.bookingCode!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'كود التتبع: ${request.bookingCode}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ---------- شريط تتبّع الحالة ----------
              if (!isCancelled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _StatusTracker(request: request),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _CancelledBanner(request: request),
                ),

              const SizedBox(height: 14),

              // ---------- الأزرار حسب الحالة ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: GestureDetector(
                  onTap: () {},
                  child: _ActionArea(
                    request: request,
                    onShowCode: onShowCode,
                    onShowRoute: onShowRoute,
                    onRate: onRate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPrice(double value) {
  if (value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

// ============================================================
// أفاتار شعار المؤسسة
// ============================================================

class _InstitutionAvatar extends StatelessWidget {
  final String logoUrl;
  const _InstitutionAvatar({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 28,
        height: 28,
        child: logoUrl.isNotEmpty
            ? Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(context),
              )
            : _fallbackAvatar(context),
      ),
    );
  }

  Widget _fallbackAvatar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.primary.withValues(alpha: 0.12),
      child: Icon(Icons.storefront_rounded, size: 16, color: colors.primary),
    );
  }
}

// ============================================================
// صورة المنتج + شارة الخصم
// ============================================================

class _ProductThumbnail extends StatelessWidget {
  final List<String> images;
  final int discountPercent;

  const _ProductThumbnail({
    required this.images,
    required this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 78,
            height: 78,
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackImage(context),
                  )
                : _fallbackImage(context),
          ),
        ),
        if (discountPercent > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD64545),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$discountPercent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallbackImage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.primary.withValues(alpha: 0.1),
      child:
          Icon(Icons.shopping_basket_outlined, color: colors.primary, size: 30),
    );
  }
}

// ============================================================
// شارة الكمية
// ============================================================

class _QuantityBadge extends StatelessWidget {
  final int quantity;
  const _QuantityBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'الكمية: $quantity',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ============================================================
// شريحة الحالة العلوية
// ============================================================

class _StatusChip extends StatelessWidget {
  final InstitutionOfferRequest request;
  const _StatusChip({required this.request});

  @override
  Widget build(BuildContext context) {
    final color = request.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        request.statusDisplay,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// شريط تتبّع الحالة (Stepper أفقي)
// ============================================================

class _StatusTracker extends StatelessWidget {
  final InstitutionOfferRequest request;
  const _StatusTracker({required this.request});

  int get _currentStep {
    if (request.isCompleted) return 3;
    if (request.isPickedUp) return 3;
    if (request.isReadyForPickup) return 2;
    if (request.isAccepted) return 1;
    return 0;
  }

  static const _labels = ['قيد المراجعة', 'مقبول', 'جاهز للاستلام', 'مكتمل'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = _currentStep;

    return Row(
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIndex = i ~/ 2;
          final isDone = lineIndex < current;
          return Expanded(
            child: Container(
              height: 2,
              color: isDone ? colors.primary : colors.outlineVariant,
            ),
          );
        }

        final stepIndex = i ~/ 2;
        final isDone = stepIndex < current;
        final isCurrent = stepIndex == current;
        final isActive = isDone || isCurrent;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? colors.primary : colors.surface,
                border: Border.all(
                  color: isActive ? colors.primary : colors.outlineVariant,
                  width: 2,
                ),
              ),
              child: isDone
                  ? Icon(Icons.check, size: 13, color: colors.onPrimary)
                  : isCurrent
                      ? Center(
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.onPrimary,
                            ),
                          ),
                        )
                      : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              child: Text(
                _labels[stepIndex],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ============================================================
// شريط الإلغاء
// ============================================================

class _CancelledBanner extends StatelessWidget {
  final InstitutionOfferRequest request;
  const _CancelledBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE9E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: Color(0xFFD64545), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (request.cancellationReason?.trim().isNotEmpty ?? false)
                  ? request.cancellationReason!.trim()
                  : 'تم إلغاء هذا الطلب',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A2E2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// منطقة الأزرار حسب الحالة
// ============================================================

class _ActionArea extends StatelessWidget {
  final InstitutionOfferRequest request;
  final VoidCallback onShowCode;
  final VoidCallback onShowRoute;
  final VoidCallback onRate;

  const _ActionArea({
    required this.request,
    required this.onShowCode,
    required this.onShowRoute,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (request.isPending) {
      return const _TurnBanner(
        icon: Icons.hourglass_top_rounded,
        color: Color(0xFFE28B00),
        turnLabel: 'الدور على المؤسسة',
        message: 'بانتظار مراجعة طلبك',
      );
    }

    if (request.isAccepted) {
      return const _TurnBanner(
        icon: Icons.inventory_2_outlined,
        color: Color(0xFF3679C8),
        turnLabel: 'الدور على المؤسسة',
        message: 'تم قبول طلبك، وجاري تجهيزه الآن',
      );
    }

    if (request.isReadyForPickup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TurnBanner(
            icon: Icons.notifications_active_rounded,
            color: colors.primary,
            turnLabel: 'الدور عليك',
            message: 'طلبك جاهز — استلمه دلوقتي',
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onShowCode,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('عرض كود الاستلام'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShowRoute,
              icon: const Icon(Icons.directions_outlined),
              label: const Text('عرض الطريق للبقالة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    if (request.isPickedUp) {
      return const _TurnBanner(
        icon: Icons.check_circle_outline_rounded,
        color: Color(0xFF2F6DA5),
        turnLabel: 'الدور على المؤسسة',
        message: 'تم الاستلام — بانتظار إكمال الطلب',
      );
    }

    if (request.isCompleted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TurnBanner(
            icon: Icons.celebration_outlined,
            color: colors.primary,
            turnLabel: 'اكتمل الطلب',
            message: 'نتمنى إنك استفدت من العرض',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRate,
            icon: const Icon(Icons.star_outline_rounded),
            label: const Text('قيّم تجربتك'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade800,
              side: BorderSide(color: Colors.amber.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ============================================================
// شريط "الدور على مين"
// ============================================================

class _TurnBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String turnLabel;
  final String message;

  const _TurnBanner({
    required this.icon,
    required this.color,
    required this.turnLabel,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  turnLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85),
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

// ============================================================
// كود الاستلام
// ============================================================

class _PickupCodeDialog extends StatelessWidget {
  final String code;
  final String address;
  const _PickupCodeDialog({required this.code, required this.address});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: colors.primary),
            const SizedBox(height: 12),
            const Text('🔐 كود الاستلام',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'خده معاك عند استلام الطلب من: $address',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// حالة الخطأ
// ============================================================

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  color: colors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'تعذر تحميل الطلبات',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تأكد من اتصال الإنترنت وحاول مرة أخرى',
              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// حالة فارغة
// ============================================================

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.onRefresh,
    this.title = 'لا توجد طلبات بقالة',
    this.subtitle =
        'عندما تطلب من البقالة، ستظهر طلباتك هنا\nويمكنك متابعة حالتها خطوة بخطوة',
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: colors.primary,
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_basket_outlined,
                            color: colors.primary, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
