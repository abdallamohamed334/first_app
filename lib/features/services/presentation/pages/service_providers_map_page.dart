import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:loqma/features/services/data/repositories/service_categories_repository.dart';
import 'package:loqma/features/services/domain/entities/service_category.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/presentation/pages/service_provider_details_page.dart';

class ServiceProvidersMapPage extends StatefulWidget {
  final List<ServiceProvider> providers;
  final double userLatitude;
  final double userLongitude;
  final String city;

  const ServiceProvidersMapPage({
    super.key,
    required this.providers,
    required this.userLatitude,
    required this.userLongitude,
    required this.city,
  });

  @override
  State<ServiceProvidersMapPage> createState() => _ServiceProvidersMapPageState();
}

class _ServiceProvidersMapPageState extends State<ServiceProvidersMapPage> {
  final _mapController = MapController();
  ServiceProvider? _selected;
  List<ServiceCategory> _categories = const [];
  String? _selectedCategoryId;
  String? _categoriesError;
  bool _loadingCategories = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ServiceCategoriesRepository().listCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _categoriesError = null;
        });
      }
    } catch (error) {
      debugPrint('⚠️ [ServiceProvidersMap] categories error: $error');
      if (mounted) {
        setState(() => _categoriesError = 'تعذر تحميل تصنيفات الخدمات');
      }
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  List<ServiceProvider> get _filteredProviders {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return widget.providers;
    return widget.providers
        .where((provider) => provider.categoryId == categoryId)
        .toList(growable: false);
  }

  void _selectCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selected = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final located = _filteredProviders
          .where((p) => p.latitude != null && p.longitude != null)
          .toList(growable: false);
      final center = _providersMapCenter(
        located,
        LatLng(widget.userLatitude, widget.userLongitude),
      );
      final userLocation = LatLng(widget.userLatitude, widget.userLongitude);
      _mapController.move(center, _providersMapZoom(located, userLocation));
    });
  }

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final providers = _filteredProviders;
    final points = providers
        .where((provider) => provider.latitude != null && provider.longitude != null)
        .toList(growable: false);
    final userLocation = LatLng(widget.userLatitude, widget.userLongitude);
    final center = _providersMapCenter(points, userLocation);
    final initialZoom = _providersMapZoom(points, userLocation);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text(
            'مقدمو الخدمات حولك',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  '${points.length} مقدم',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: initialZoom,
                  onMapReady: () => _mapReady = true,
                  onTap: (_, __) => setState(() => _selected = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.khedma.app',
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                  MarkerLayer(
                    markers: points.map((provider) {
                      final selected = _selected?.id == provider.id;
                      return Marker(
                        point: LatLng(provider.latitude!, provider.longitude!),
                        width: selected ? 58 : 48,
                        height: selected ? 70 : 62,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = provider),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: selected ? 48 : 40,
                                height: selected ? 48 : 40,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE31C25)
                                      : const Color(0xFF3679C8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  provider.isCompany
                                      ? Icons.business_rounded
                                      : Icons.handyman_rounded,
                                  color: Colors.white,
                                  size: selected ? 23 : 19,
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                color: selected
                                    ? const Color(0xFFE31C25)
                                    : const Color(0xFF3679C8),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: userLocation,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF3679C8),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: Color(0xFF3679C8),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                color: _surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                child: _buildCategoryFilter(),
              ),
            ),
            Positioned(
              top: 78,
              right: 14,
              child: _mapPill(
                icon: Icons.location_on_rounded,
                label: widget.city,
              ),
            ),
            Positioned(
              bottom: _selected == null ? 16 : 142,
              left: 14,
              child: FloatingActionButton.small(
                heroTag: 'service-map-center',
                backgroundColor: _surface,
                foregroundColor: const Color(0xFF3679C8),
                onPressed: () => _mapController.move(userLocation, 13),
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
            if (points.isEmpty)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    _selectedCategoryId == null
                        ? 'لا يوجد مقدمو خدمة بموقع مسجل في منطقتك حاليًا'
                        : 'لا يوجد مقدمو خدمة لهذا النوع على الخريطة حاليًا',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (_selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildProviderCard(_selected!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    if (_categoriesError != null && _categories.isEmpty) {
      return SizedBox(
        height: 62,
        child: Center(
          child: TextButton.icon(
            onPressed: _loadingCategories ? null : _loadCategories,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(_categoriesError!),
          ),
        ),
      );
    }
    if (_loadingCategories && _categories.isEmpty) {
      return const SizedBox(
        height: 58,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    const selectedColor = Color(0xFF3679C8);
    return SizedBox(
      height: 62,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : _categories[index - 1];
          final selected = isAll
              ? _selectedCategoryId == null
              : _selectedCategoryId == category!.id;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => _selectCategory(category?.id),
            selectedColor: selectedColor,
            backgroundColor: _surface,
            side: BorderSide(
              color: selected ? selectedColor : _muted.withValues(alpha: 0.25),
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAll && category?.icon?.isNotEmpty == true) ...[
                  Text(category!.icon!),
                  const SizedBox(width: 5),
                ] else if (isAll) ...[
                  const Icon(Icons.apps_rounded, size: 16),
                  const SizedBox(width: 5),
                ],
                Text(isAll ? 'كل الخدمات' : category!.nameAr),
              ],
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  LatLng _providersMapCenter(
    List<ServiceProvider> providers,
    LatLng fallback,
  ) {
    if (providers.isEmpty) return fallback;
    var minLat = providers.first.latitude!;
    var maxLat = minLat;
    var minLng = providers.first.longitude!;
    var maxLng = minLng;
    for (final provider in providers.skip(1)) {
      minLat = minLat < provider.latitude! ? minLat : provider.latitude!;
      maxLat = maxLat > provider.latitude! ? maxLat : provider.latitude!;
      minLng = minLng < provider.longitude! ? minLng : provider.longitude!;
      maxLng = maxLng > provider.longitude! ? maxLng : provider.longitude!;
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _providersMapZoom(
    List<ServiceProvider> providers,
    LatLng userLocation,
  ) {
    var minLat = userLocation.latitude;
    var maxLat = minLat;
    var minLng = userLocation.longitude;
    var maxLng = minLng;
    for (final provider in providers) {
      minLat = minLat < provider.latitude! ? minLat : provider.latitude!;
      maxLat = maxLat > provider.latitude! ? maxLat : provider.latitude!;
      minLng = minLng < provider.longitude! ? minLng : provider.longitude!;
      maxLng = maxLng > provider.longitude! ? maxLng : provider.longitude!;
    }
    final span = (maxLat - minLat) > (maxLng - minLng)
        ? maxLat - minLat
        : maxLng - minLng;
    if (span > 2.0) return 7.0;
    if (span > 1.0) return 8.0;
    if (span > 0.55) return 9.0;
    if (span > 0.30) return 10.0;
    if (span > 0.15) return 11.0;
    if (span > 0.07) return 12.0;
    return 13.0;
  }

  Widget _mapPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE31C25), size: 15),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildProviderCard(ServiceProvider provider) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ServiceProviderDetailsPage(provider: provider),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isDark ? const Color(0xFF30463B) : const Color(0xFFE4E9EF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _providerImage(provider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Color(0xFF3679C8)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.categoryName ?? 'مقدم خدمة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFE31C25)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            provider.address ?? provider.city ?? widget.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 11),
                          ),
                        ),
                        if (provider.ratingAvg > 0) ...[
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFE28B00)),
                          const SizedBox(width: 2),
                          Text(
                            provider.ratingAvg.toStringAsFixed(1),
                            style: TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w800),
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

  Widget _providerImage(ServiceProvider provider) {
    final image = provider.profileImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        height: 82,
        child: image == null || image.isEmpty
            ? Container(
                color: const Color(0xFF3679C8).withValues(alpha: 0.12),
                child: const Icon(Icons.person_rounded, color: Color(0xFF3679C8), size: 30),
              )
            : CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF3679C8).withValues(alpha: 0.12),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF3679C8), size: 30),
                ),
              ),
      ),
    );
  }
}
