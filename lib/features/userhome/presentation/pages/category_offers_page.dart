// lib/features/userhome/presentation/pages/category_offers_page.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/config/app_config.dart';

import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';

import 'package:loqma/features/marketplace/domain/entities/marketplace_attribute.dart';
import 'package:loqma/features/marketplace/domain/entities/marketplace_attribute_option.dart';
import 'package:loqma/features/marketplace/domain/entities/marketplace_offer.dart';
import 'package:loqma/features/marketplace/presentation/bloc/marketplace_bloc.dart';
import 'package:loqma/features/marketplace/presentation/bloc/marketplace_event.dart';
import 'package:loqma/features/marketplace/presentation/bloc/marketplace_state.dart';

import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/domain/user_home_policy.dart';

// ═══════════════════════════════════════════════════════════
// ✅ FEATURE FLAGS
// ═══════════════════════════════════════════════════════════
class _AppFeatures {
  static bool showRestaurants = false;
}

class CategoryOffersPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? categorySlug;

  CategoryOffersPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.categorySlug,
  });

  @override
  State<CategoryOffersPage> createState() => _CategoryOffersPageState();
}

class _CategoryOffersPageState extends State<CategoryOffersPage> {
  static Color get _bg => HomePalette.bg;
  static Color get _card => HomePalette.card;
  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  late final MarketplaceBloc _marketplaceBloc;

  bool get _usesDirectOfferPath {
    final slug = widget.categorySlug?.trim().toLowerCase() ?? '';
    return slug == 'institution-offers' ||
        UserHomePolicy.isAllowedCatalogSlug(slug);
  }

  @override
  void initState() {
    super.initState();

    debugPrint(
      '🔵 [CategoryOffers] initState: '
      'categoryId=${widget.categoryId}, '
      'categoryName=${widget.categoryName}, '
      'categorySlug=${widget.categorySlug}',
    );

    _marketplaceBloc = MarketplaceBloc();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      debugPrint(
        '🔵 [CategoryOffers] Sending LoadMarketplaceCategory '
        'with categoryId=${widget.categoryId}',
      );

      if (_usesDirectOfferPath) {
        debugPrint('🔵 [CategoryOffers] Using direct offers path for '
            'slug=${widget.categorySlug}');
        context.read<UserHomeBloc>().add(
              SelectCategory(
                categoryId: widget.categoryId,
                categoryName: widget.categoryName,
                categorySlug: widget.categorySlug,
              ),
            );
      } else {
        _marketplaceBloc.add(
          LoadMarketplaceCategory(
            categoryId: widget.categoryId,
            categoryName: widget.categoryName,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _marketplaceBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _marketplaceBloc,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: _bg,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _primaryRed,
              surface: _bg,
              onSurface: _textPrimary,
            ),
          ),
          child: Scaffold(
            backgroundColor: _bg,
            appBar: AppBar(
              backgroundColor: _bg,
              surfaceTintColor: _bg,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: _textPrimary),
              title: Text(
                widget.categoryName,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            body: _usesDirectOfferPath
                ? _buildDirectOffers(context)
                : BlocBuilder<MarketplaceBloc, MarketplaceState>(
              builder: (context, marketplaceState) {
                // 1️⃣ Loading
                if (marketplaceState.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(color: _primaryRed),
                  );
                }

                // 2️⃣ ✅ لو الـ marketplace bloc اشتغل (categoryId اتحدد)
                final hasCategory = marketplaceState.categoryId != null &&
                    marketplaceState.categoryId!.isNotEmpty;

                if (hasCategory) {
                  if (marketplaceState.errorMessage != null &&
                      marketplaceState.offers.isEmpty) {
                    return _buildMarketplaceError(
                      context,
                      marketplaceState.errorMessage!,
                    );
                  }

                  return _MarketplaceFlowWithOffers(
                    state: marketplaceState,
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                  );
                }

                // 3️⃣ Legacy fallback
                return BlocBuilder<UserHomeBloc, UserHomeState>(
                  builder: (context, state) {
                    if (state is! UserHomeLoaded) {
                      return Center(
                        child: CircularProgressIndicator(color: _primaryRed),
                      );
                    }

                    if (state.categoryOffersLoading) {
                      return Center(
                        child: CircularProgressIndicator(color: _primaryRed),
                      );
                    }

                    if (state.categoryOffers.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return RefreshIndicator(
                      color: _primaryRed,
                      backgroundColor: _card,
                      onRefresh: () async {
                        context.read<UserHomeBloc>().add(
                              SelectCategory(
                                categoryId: widget.categoryId,
                                categoryName: widget.categoryName,
                                categorySlug: widget.categorySlug,
                              ),
                            );
                      },
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                        physics: AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: state.categoryOffers.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemBuilder: (context, index) {
                          final offer = state.categoryOffers[index];
                          return _DubizzleStyleCard(
                            offer: offer,
                            onTap: () => _openOfferDetails(context, offer),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectOffers(BuildContext context) {
    return BlocBuilder<UserHomeBloc, UserHomeState>(
      builder: (context, state) {
        if (state is! UserHomeLoaded || state.categoryOffersLoading) {
          return Center(
            child: CircularProgressIndicator(color: _primaryRed),
          );
        }
        if (state.categoryOffers.isEmpty) {
          return _buildEmptyState(context);
        }
        final offers = [...state.categoryOffers]
          ..sort((a, b) {
            final aDistance = a.distanceMeters;
            final bDistance = b.distanceMeters;
            if (aDistance != null && bDistance != null) {
              return aDistance.compareTo(bDistance);
            }
            if (aDistance != null) return -1;
            if (bDistance != null) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
        return RefreshIndicator(
          color: _primaryRed,
          backgroundColor: _card,
          onRefresh: () async {
            context.read<UserHomeBloc>().add(
                  SelectCategory(
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                    categorySlug: widget.categorySlug,
                  ),
                );
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _InstitutionCategoryOfferCard(
                offer: offer,
                onTap: () => _openOfferDetails(context, offer),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _cardSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: _primaryRed,
                size: 42,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'حصل خطأ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                _marketplaceBloc.add(
                  LoadMarketplaceCategory(
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                  ),
                );
              },
              icon: Icon(Icons.refresh_rounded),
              label: Text('حاول مرة أخرى'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _cardSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                color: _primaryRed,
                size: 42,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'لا توجد عروض حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'مفيش عروض في تصنيف "${widget.categoryName}" قريبة منك دلوقتي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOfferDetails(BuildContext context, CategoryOffer offer) {
    if (!_AppFeatures.showRestaurants) {
      if (_isFoodCategory() || offer.ownerType == 'restaurant') {
        debugPrint(
          '🚫 [CategoryOffers] Restaurants disabled — blocking offer '
          'slug=${widget.categorySlug} ownerType=${offer.ownerType}',
        );
        return;
      }
    }

    if (_isFoodCategory() || offer.ownerType == 'restaurant') {
      _openFoodDetails(context, offer);
      return;
    }

    if (offer.isCommunity) {
      _openCommunityDetails(context, offer);
      return;
    }

    _openInstitutionDetails(context, offer);
  }

  bool _isFoodCategory() {
    final slug = widget.categorySlug?.toLowerCase().trim() ?? '';
    final name = widget.categoryName.trim();

    return slug == 'food' ||
        slug == 'foods' ||
        name.contains('طعام') ||
        name.contains('أطعمة') ||
        name.contains('مأكولات') ||
        name.contains('وجبات');
  }

  void _openCommunityDetails(BuildContext context, CategoryOffer offer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityOfferDetailsPage(offer: offer.raw),
      ),
    );
  }

  void _openFoodDetails(BuildContext context, CategoryOffer offer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonOfferDetailsPage(offer: offer.raw),
      ),
    );
  }

  void _openInstitutionDetails(BuildContext context, CategoryOffer offer) {
    try {
      final institutionJson = _buildInstitutionJson(offer);
      final institutionOffer = InstitutionOffer.fromJson(institutionJson);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InstitutionOfferDetailsPage(offer: institutionOffer),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to open institution details: $e');
      _openFoodDetails(context, offer);
    }
  }

  Map<String, dynamic> _buildInstitutionJson(CategoryOffer offer) {
    final raw = offer.raw;

    final institutionRaw =
        raw['institutions'] ?? raw['business'] ?? raw['institution'];

    final institution = institutionRaw is Map
        ? Map<String, dynamic>.from(institutionRaw)
        : <String, dynamic>{};

    final institutionId = _firstNonEmpty([
      raw['institution_id'],
      raw['business_id'],
      institution['id'],
      raw['owner_id'],
    ]);

    final category = _firstNonEmpty([
      raw['category'],
      raw['category_slug'],
      raw['category_name'],
      widget.categorySlug,
      'other',
    ]);

    final ownerName = _firstNonEmpty([
      institution['name'],
      raw['owner_name'],
      raw['user_name'],
      'مؤسسة',
    ]);

    return {
      'id': offer.id,
      'title': offer.title,
      'description': offer.description ?? '',
      'category': category,
      'quantity': raw['quantity'] ?? 0,
      'remaining_quantity': raw['remaining_quantity'] ?? raw['quantity'] ?? 0,
      'symbolic_price': raw['symbolic_price'] ?? raw['price'] ?? 0,
      'original_price': raw['original_price'],
      'images': raw['images'] ?? [],
      'pickup_location': raw['pickup_location'] ?? '',
      'expires_at': raw['expires_at'] ?? raw['expiry_time'],
      'pickup_before': raw['pickup_before'],
      'pickup_start': raw['pickup_start'],
      'pickup_end': raw['pickup_end'],
      'product_expiry_at': raw['product_expiry_at'],
      'status': raw['status'] ?? 'active',
      'created_at': raw['created_at'],
      'updated_at': raw['updated_at'],
      'institution_id': institutionId?.toString() ?? '',
      'institutions': {
        'id': institution['id']?.toString() ?? institutionId?.toString() ?? '',
        'name': ownerName?.toString() ?? 'مؤسسة',
        'logo_url': institution['logo_url']?.toString() ??
            institution['logo']?.toString() ??
            institution['image_url']?.toString(),
        'institution_type': institution['institution_type']?.toString() ??
            institution['business_type']?.toString() ??
            'grocery',
        'address':
            institution['address']?.toString() ?? raw['address']?.toString(),
        'phone': institution['phone']?.toString() ?? raw['phone']?.toString(),
        'latitude': institution['latitude'] ?? raw['latitude'],
        'longitude': institution['longitude'] ?? raw['longitude'],
      },
      'food_type': raw['food_type'],
      'food_condition': raw['food_condition'],
      'is_halal': raw['is_halal'] ?? true,
      'is_vegetarian': raw['is_vegetarian'] ?? false,
      'requires_refrigeration': raw['requires_refrigeration'] ?? false,
      'pickup_notes': raw['pickup_notes'],
      'contact_phone': raw['contact_phone'],
      'pickup_time': raw['pickup_time'],
      'storage_condition': raw['storage_condition'],
      'product_subcategory': raw['product_subcategory'],
      'meat_cut': raw['meat_cut'],
      'product_weight': raw['product_weight'],
      'product_prepared_at': raw['product_prepared_at'],
      'min_booking_quantity': raw['min_booking_quantity'] ?? 1,
      'max_booking_quantity': raw['max_booking_quantity'],
      'is_bookable': raw['is_bookable'] ?? true,
    };
  }

  dynamic _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return value;
    }
    return null;
  }
}

// ============================================================================
// MARKETPLACE FLOW WITH OFFERS
// ============================================================================

class _MarketplaceFlowWithOffers extends StatelessWidget {
  final MarketplaceState state;
  final String categoryId;
  final String categoryName;

  _MarketplaceFlowWithOffers({
    required this.state,
    required this.categoryId,
    required this.categoryName,
  });

  static Color get _bg => HomePalette.bg;
  static Color get _card => HomePalette.card;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildFiltersSection(context),
          Expanded(child: _buildOffersSection(context)),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(BuildContext context) {
    final visibleAttributes = _getVisibleAttributes();

    // ✅ لو مفيش خصائص للفلترة، نخفي القسم بالكامل
    if (visibleAttributes.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          bottom: BorderSide(color: Color(0xFF252527), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: _primaryRed, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'حدد مواصفات البحث',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (state.selectedValues.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    context.read<MarketplaceBloc>().add(
                          ResetMarketplaceFilters(),
                        );
                  },
                  icon: Icon(Icons.clear_rounded, size: 16),
                  label: Text('مسح'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryRed,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size(0, 32),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10),
          _buildDynamicAttributes(context, visibleAttributes),
        ],
      ),
    );
  }

  Widget _buildDynamicAttributes(
    BuildContext context,
    List<MarketplaceAttribute> attributes,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attributes.map((attribute) {
        final rawOptions = state.optionsByAttribute[attribute.slug] ??
            <MarketplaceAttributeOption>[];

        final options = _deduplicateOptions(rawOptions);
        final selectedId = state.selectedOptionIds[attribute.slug];

        final isLoading = state.isLoadingOptions && options.isEmpty;

        return SizedBox(
          width: _getFilterWidth(context),
          child: _FilterDropdown(
            attribute: attribute,
            options: options,
            selectedOptionId: selectedId,
            enabled: true,
            isLoading: isLoading,
            onSelected: (option) {
              context.read<MarketplaceBloc>().add(
                    SelectMarketplaceOption(
                      attribute: attribute,
                      optionId: option.id,
                      value: option.value,
                    ),
                  );
            },
          ),
        );
      }).toList(),
    );
  }

  List<MarketplaceAttributeOption> _deduplicateOptions(
    List<MarketplaceAttributeOption> options,
  ) {
    final seen = <String>{};
    final result = <MarketplaceAttributeOption>[];

    for (final option in options) {
      final id = option.id.trim();
      if (id.isEmpty) continue;
      if (seen.add(id)) result.add(option);
    }

    return result;
  }

  double _getFilterWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 700) return (width - 48) / 3;
    return (width - 40) / 2;
  }

  // ✅ نعرض فقط "الحالة" و "الماركة" بس عشان الفلاتر متبقاش ضخمة
  List<MarketplaceAttribute> _getVisibleAttributes() {
    if (state.attributes.isEmpty) return [];

    const allowedSlugs = {'condition', 'brand'};
    final seenSlugs = <String>{};

    return state.attributes.where((attr) {
      final slug = attr.slug.trim();
      return attr.inputType == 'select' &&
          allowedSlugs.contains(slug) &&
          seenSlugs.add(slug);
    }).toList(growable: false);
  }

  Widget _buildOffersSection(BuildContext context) {
    if (state.isLoadingResults && state.offers.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: _primaryRed),
      );
    }

    if (state.offers.isEmpty) {
      return _EmptyOffersView();
    }

    return RefreshIndicator(
      color: _primaryRed,
      backgroundColor: _card,
      onRefresh: () async {
        context.read<MarketplaceBloc>().add(
              LoadMarketplaceResults(),
            );
      },
      child: Stack(
        children: [
          GridView.builder(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: state.offers.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemBuilder: (context, index) {
              final offer = state.offers[index];
              return _MarketplaceOfferCard(offer: offer);
            },
          ),
          if (state.isLoadingResults)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: _primaryRed,
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER DROPDOWN
// ============================================================================

class _FilterDropdown extends StatelessWidget {
  final MarketplaceAttribute attribute;
  final List<MarketplaceAttributeOption> options;
  final String? selectedOptionId;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<MarketplaceAttributeOption> onSelected;

  _FilterDropdown({
    required this.attribute,
    required this.options,
    required this.selectedOptionId,
    required this.enabled,
    required this.isLoading,
    required this.onSelected,
  });

  static Color get _card => HomePalette.card;
  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF252527)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                attribute.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: _textSecondary,
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryRed,
            ),
          ),
        ),
      );
    }

    if (options.isEmpty) {
      return Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF252527)),
        ),
        child: Center(
          child: Text(
            '${attribute.nameAr}: لا توجد خيارات',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    final normalizedSelectedOptionId = selectedOptionId?.trim();

    final validSelectedOptionId = normalizedSelectedOptionId != null &&
            normalizedSelectedOptionId.isNotEmpty &&
            options.any((option) => option.id == normalizedSelectedOptionId)
        ? normalizedSelectedOptionId
        : null;

    final selectedOption = validSelectedOptionId == null
        ? null
        : options.firstWhere((option) => option.id == validSelectedOptionId);

    final hasSelection = selectedOption != null;

    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: hasSelection ? _primaryRed.withValues(alpha: 0.15) : _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelection ? _primaryRed : Color(0xFF303033),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validSelectedOptionId,
          isExpanded: true,
          hint: Text(
            attribute.nameAr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasSelection ? _primaryRed : _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          dropdownColor: _cardSoft,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: hasSelection ? _primaryRed : _textSecondary,
            size: 18,
          ),
          style: TextStyle(
            color: hasSelection ? _primaryRed : _textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          items: options.map((option) {
            final isSelected = option.id == validSelectedOptionId;

            return DropdownMenuItem<String>(
              value: option.id,
              child: Row(
                children: [
                  if (isSelected) ...[
                    Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: _primaryRed,
                    ),
                    SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      option.labelAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? _primaryRed : _textPrimary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null || value.trim().isEmpty) return;

            MarketplaceAttributeOption? option;
            for (final item in options) {
              if (item.id == value) {
                option = item;
                break;
              }
            }
            if (option == null) return;

            onSelected(option);
          },
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY OFFERS VIEW
// ============================================================================

class _EmptyOffersView extends StatelessWidget {
  _EmptyOffersView();

  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: _primaryRed, size: 56),
            SizedBox(height: 16),
            Text(
              'مفيش عروض مطابقة',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'جرب تغير الفلاتر أو امسحها.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MARKETPLACE OFFER CARD
// ============================================================================

class _MarketplaceOfferCard extends StatelessWidget {
  final MarketplaceOffer offer;

  _MarketplaceOfferCard({
    required this.offer,
  });

  static Color get _card => HomePalette.card;
  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;
  static Color _successGreen = Color(0xFF2E7D32);
  static Color _warningOrange = Color(0xFFE28B00);

  @override
  Widget build(BuildContext context) {
    final images = offer.images.isNotEmpty
        ? offer.images
        : (offer.image != null && offer.image!.isNotEmpty
            ? [offer.image!]
            : <String>[]);

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFF2A2A2A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _OfferImagesCarousel(images: images),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SourceBadge(sourceType: offer.sourceType),
                  ),
                  if (offer.isLowStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _warningOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'آخر ${offer.availableQuantity}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 7,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (offer.hasPrice)
                          Text(
                            _formatPrice(offer.price!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryRed,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        else
                          Text(
                            'سعر رمزي',
                            style: TextStyle(
                              color: _primaryRed,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        SizedBox(width: 3),
                        if (offer.hasPrice)
                          Text(
                            'ج.م',
                            style: TextStyle(
                              color: _primaryRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    if (offer.description != null &&
                        offer.description!.isNotEmpty)
                      Text(
                        offer.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    Spacer(),
                    if (offer.ownerName != null && offer.ownerName!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            _OwnerAvatar(url: offer.ownerAvatar, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                offer.ownerName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (offer.pickupLocation != null &&
                            offer.pickupLocation!.isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 10,
                                  color: _textSecondary,
                                ),
                                SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    offer.pickupLocation!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (offer.conditionLabel != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _successGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              offer.conditionLabel!,
                              style: TextStyle(
                                color: _successGreen,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
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
      ),
    );
  }

  static String _formatPrice(double price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(1)}k';
    }
    return price.toStringAsFixed(0);
  }

  void _openDetails(BuildContext context) {
    switch (offer.sourceType) {
      case 'community':
        _openCommunityDetails(context);
        break;

      case 'institution':
        _openInstitutionDetails(context);
        break;

      case 'business':
        _openBusinessDetails(context);
        break;

      default:
        debugPrint('⚠️ Unknown source_type: ${offer.sourceType}');
    }
  }

  void _openCommunityDetails(BuildContext context) {
    debugPrint(
      '🚀 Opening community offer details: '
      'sourceId=${offer.sourceId}, '
      'ownerId=${offer.ownerId}, '
      'ownerName=${offer.ownerName}',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityOfferDetailsPage(
          offer: <String, dynamic>{
            'id': offer.sourceId,
            'title': offer.title,
            'description': offer.description,
            'price': offer.price,
            'image': offer.image,
            'images': offer.images,
            'pickup_location': offer.pickupLocation,
            'latitude': offer.latitude,
            'longitude': offer.longitude,
            'status': offer.status,
            'created_at': offer.createdAt?.toIso8601String(),
            'source_type': offer.sourceType,
            'owner_id': offer.ownerId,
            'owner_name': offer.ownerName,
            'avatar_url': offer.ownerAvatar,
          },
        ),
      ),
    );
  }

  void _openInstitutionDetails(BuildContext context) {
    try {
      final institutionJson = <String, dynamic>{
        'id': offer.sourceId,
        'title': offer.title,
        'description': offer.description ?? '',
        'category': offer.categorySlug,
        'quantity': offer.quantity,
        'remaining_quantity': offer.remainingQuantity ?? offer.quantity,
        'symbolic_price': offer.price ?? 0,
        'original_price': offer.originalPrice,
        'images': offer.images,
        'pickup_location': offer.pickupLocation ?? '',
        'expires_at': null,
        'pickup_before': null,
        'status': offer.status,
        'created_at': offer.createdAt?.toIso8601String(),
        'updated_at': offer.createdAt?.toIso8601String(),
        'institution_id': offer.sourceId,
        'institutions': {
          'id': offer.sourceId,
          'name': offer.ownerName ?? 'مؤسسة',
          'logo_url': offer.ownerAvatar,
          'institution_type': 'grocery',
          'address': offer.pickupLocation,
          'phone': null,
          'latitude': offer.latitude,
          'longitude': offer.longitude,
        },
      };

      final institutionOffer = InstitutionOffer.fromJson(institutionJson);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InstitutionOfferDetailsPage(
            offer: institutionOffer,
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to open institution details: $e');
      _openCommunityDetails(context);
    }
  }

  void _openBusinessDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonOfferDetailsPage(
          offer: <String, dynamic>{
            'id': offer.sourceId,
            'title': offer.title,
            'description': offer.description,
            'price': offer.price,
            'image': offer.image,
            'images': offer.images,
            'pickup_location': offer.pickupLocation,
            'latitude': offer.latitude,
            'longitude': offer.longitude,
            'status': offer.status,
            'created_at': offer.createdAt?.toIso8601String(),
            'source_type': offer.sourceType,
          },
        ),
      ),
    );
  }
}

// ============================================================================
// OFFER IMAGES CAROUSEL
// ============================================================================

class _OfferImagesCarousel extends StatefulWidget {
  final List<String> images;

  _OfferImagesCarousel({
    required this.images,
  });

  @override
  State<_OfferImagesCarousel> createState() => _OfferImagesCarouselState();
}

class _OfferImagesCarouselState extends State<_OfferImagesCarousel> {
  late final PageController _controller;

  int _currentIndex = 0;

  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: _cardSoft,
        child: Icon(
          Icons.image_not_supported_rounded,
          color: _textSecondary,
          size: 38,
        ),
      );
    }

    if (widget.images.length == 1) {
      return _SingleImage(url: widget.images.first);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return _SingleImage(url: widget.images[index]);
          },
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 2),
                width: _currentIndex == index ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                  size: 9,
                ),
                SizedBox(width: 2),
                Text(
                  '${_currentIndex + 1}/${widget.images.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SINGLE IMAGE
// ============================================================================

class _SingleImage extends StatelessWidget {
  final String url;

  _SingleImage({
    required this.url,
  });

  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || url == 'null') {
      return Container(
        color: _cardSoft,
        child: Icon(
          Icons.image_not_supported_rounded,
          color: _textSecondary,
          size: 38,
        ),
      );
    }

    final resolvedUrl = _resolveImageUrl(url);

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: _cardSoft,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryRed,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: _cardSoft,
        child: Icon(
          Icons.image_not_supported_rounded,
          color: _textSecondary,
          size: 38,
        ),
      ),
    );
  }

  static String _resolveImageUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return AppConfig.storagePublicUrl('community-offers', raw);
  }
}

// ============================================================================
// OWNER AVATAR
// ============================================================================

class _OwnerAvatar extends StatelessWidget {
  final String? url;
  final double size;

  _OwnerAvatar({
    required this.url,
    this.size = 16,
  });

  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || url == 'null') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _cardSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          size: size * 0.6,
          color: _textSecondary,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: _cardSoft,
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: _cardSoft,
          child: Icon(
            Icons.person_rounded,
            size: size * 0.6,
            color: _textSecondary,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SOURCE BADGE
// ============================================================================

class _SourceBadge extends StatelessWidget {
  final String sourceType;

  _SourceBadge({
    required this.sourceType,
  });

  @override
  Widget build(BuildContext context) {
    late Color color;
    late IconData icon;
    late String label;

    switch (sourceType) {
      case 'community':
        color = Color(0xFF2E7D32);
        icon = Icons.person_rounded;
        label = 'مستخدم';
        break;

      case 'institution':
        color = Color(0xFF1565C0);
        icon = Icons.storefront_rounded;
        label = 'محل';
        break;

      case 'business':
        color = Color(0xFFE28B00);
        icon = Icons.business_rounded;
        label = 'مؤسسة';
        break;

      default:
        color = Color(0xFF555555);
        icon = Icons.storefront_rounded;
        label = 'عرض';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 9),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FULL-WIDTH INSTITUTION CATEGORY CARD
// ============================================================================

class _InstitutionCategoryOfferCard extends StatelessWidget {
  final CategoryOffer offer;
  final VoidCallback onTap;

  const _InstitutionCategoryOfferCard({
    required this.offer,
    required this.onTap,
  });

  static Color get _card => HomePalette.card;
  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.image?.trim() ?? '';
    final description = offer.description?.trim() ?? '';
    final ownerName = offer.ownerName?.trim();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 166,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _textSecondary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 116,
                  height: 146,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isEmpty)
                        Container(
                          color: _cardSoft,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.fastfood_rounded,
                            color: _textSecondary,
                            size: 32,
                          ),
                        )
                      else
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: _cardSoft,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_outlined,
                              color: _textSecondary,
                              size: 28,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: _cardSoft,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: _textSecondary,
                              size: 28,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _OwnerBadge(ownerType: offer.ownerType),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: _primaryRed,
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            offer.distanceDisplay ?? 'المسافة غير متاحة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: offer.distanceDisplay == null
                                  ? _textSecondary
                                  : _primaryRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _textSecondary.withValues(alpha: 0.7),
                          size: 13,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.storefront_rounded,
                          color: _textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            ownerName == null || ownerName.isEmpty
                                ? 'مؤسسة'
                                : ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.priceDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryRed,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (offer.originalPriceDisplay != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              offer.originalPriceDisplay!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LEGACY CARD (Dubizzle Style)
// ============================================================================

class _DubizzleStyleCard extends StatelessWidget {
  final CategoryOffer offer;
  final VoidCallback onTap;

  _DubizzleStyleCard({
    required this.offer,
    required this.onTap,
  });

  static Color get _card => HomePalette.card;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFF2A2A2A), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _SingleImage(url: offer.image ?? ''),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _OwnerBadge(ownerType: offer.ownerType),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.priceDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    Spacer(),
                    Row(
                      children: [
                        if (offer.distanceDisplay != null) ...[
                          Icon(
                            Icons.location_on_rounded,
                            size: 11,
                            color: _textSecondary,
                          ),
                          SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              offer.distanceDisplay!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ] else if (offer.categoryName != null) ...[
                          Flexible(
                            child: Text(
                              offer.categoryName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        Spacer(),
                        if (offer.originalPriceDisplay != null)
                          Flexible(
                            child: Text(
                              offer.originalPriceDisplay!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
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
      ),
    );
  }
}

// ============================================================================
// OWNER BADGE
// ============================================================================

class _OwnerBadge extends StatelessWidget {
  final String ownerType;

  _OwnerBadge({
    required this.ownerType,
  });

  @override
  Widget build(BuildContext context) {
    late Color color;
    late IconData icon;
    late String label;

    switch (ownerType) {
      case 'community':
        color = Color(0xFF2E7D32);
        icon = Icons.person_rounded;
        label = 'مستخدم';
        break;

      case 'restaurant':
        if (!_AppFeatures.showRestaurants) {
          color = Color(0xFF1565C0);
          icon = Icons.storefront_rounded;
          label = 'محل';
        } else {
          color = Color(0xFFE28B00);
          icon = Icons.restaurant_rounded;
          label = 'مطعم';
        }
        break;

      case 'institution':
      default:
        color = Color(0xFF1565C0);
        icon = Icons.storefront_rounded;
        label = 'محل';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
