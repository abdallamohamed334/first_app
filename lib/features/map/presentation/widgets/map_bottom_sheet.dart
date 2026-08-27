import 'package:flutter/material.dart';
import '../../../offers/domain/entities/food_offer.dart';
import 'map_offer_card.dart';

class MapBottomSheet extends StatefulWidget {
  final List<FoodOffer> offers;
  final FoodOffer? selectedOffer;
  final Function(FoodOffer) onOfferTap;
  final Function(FoodOffer) onShowDetails;
  final VoidCallback? onViewAll;
  final double? userLatitude;
  final double? userLongitude;

  const MapBottomSheet({
    super.key,
    required this.offers,
    this.selectedOffer,
    required this.onOfferTap,
    required this.onShowDetails,
    this.onViewAll,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<MapBottomSheet> createState() => _MapBottomSheetState();
}

class _MapBottomSheetState extends State<MapBottomSheet> {
  // ✅ 0.0 = مطوي (بس الهيدر), 1.0 = مفتوح كامل
  double _sheetPosition = 0.0;
  final double _minPosition = 0.0;
  final double _maxPosition = 1.0;

  // ✅ ارتفاعات
  double get _peekHeight => 156; // هيدر مختصر بدون تغطية الخريطة
  double get _fullHeight => (MediaQuery.of(context).size.height * 0.78)
      .clamp(430.0, 720.0)
      .toDouble();

  double get _currentHeight =>
      _peekHeight + (_fullHeight - _peekHeight) * _sheetPosition;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final availableTravel =
        (_fullHeight - _peekHeight).clamp(1.0, double.infinity).toDouble();
    final delta = details.delta.dy / availableTravel;
    setState(() {
      _sheetPosition =
          (_sheetPosition - delta).clamp(_minPosition, _maxPosition);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    setState(() {
      if (velocity < -300 || _sheetPosition > 0.5) {
        _sheetPosition = _maxPosition; // افتح
      } else if (velocity > 300 || _sheetPosition <= 0.5) {
        _sheetPosition = _minPosition; // اقفل
      }
    });
  }

  void _toggleSheet() {
    setState(() {
      _sheetPosition = _sheetPosition == 0.0 ? _maxPosition : _minPosition;
    });
  }

  void _selectOffer(FoodOffer offer) {
    setState(() => _sheetPosition = _maxPosition);
    widget.onOfferTap(offer);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      onTap: _sheetPosition == 0.0 ? _toggleSheet : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: _currentHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ✅ Drag Handle (دايماً ظاهر)
            GestureDetector(
              onTap: _toggleSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

            // ✅ الهيدر المختصر (ظاهر دايماً)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.offers.length} وجبات قريبة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'اسحب لفوق للعرض',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.offers.isNotEmpty)
                    TextButton.icon(
                      onPressed: widget.onViewAll,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('عرض الكل'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),

            // ✅ القائمة (تظهر لما تسحب)
            if (_sheetPosition > 0.1) ...[
              const SizedBox(height: 8),
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              Expanded(
                child: widget.offers.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        physics: const ClampingScrollPhysics(),
                        itemCount: widget.offers.length,
                        itemBuilder: (context, index) {
                          final offer = widget.offers[index];
                          final isSelected =
                              widget.selectedOffer?.id == offer.id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: MapOfferCard(
                              offer: offer,
                              isSelected: isSelected,
                              onTap: () => _selectOffer(offer),
                              onShowDetails: () => widget.onShowDetails(offer),
                              userLatitude: widget.userLatitude,
                              userLongitude: widget.userLongitude,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد وجبات متاحة حاليًا',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'سنحدّث العروض تلقائيًا عند توفر وجبة جديدة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}


