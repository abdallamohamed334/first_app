import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:wasla/features/services/domain/entities/service_provider.dart';
import 'package:wasla/features/services/presentation/pages/service_provider_details_page.dart';

class ServiceProvidersMapPage extends StatefulWidget {
  final List<ServiceProvider> providers;
  final double latitude;
  final double longitude;
  final String city;

  const ServiceProvidersMapPage({
    super.key,
    required this.providers,
    required this.latitude,
    required this.longitude,
    required this.city,
  });

  @override
  State<ServiceProvidersMapPage> createState() => _ServiceProvidersMapPageState();
}

class _ServiceProvidersMapPageState extends State<ServiceProvidersMapPage> {
  final _mapController = MapController();
  ServiceProvider? _selected;

  Color get _surface => Theme.of(context).colorScheme.surface;
  Color get _text => Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.latitude, widget.longitude);
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
                  '${widget.providers.length} مقدم',
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
        body: Column(
          children: [
            SizedBox(
              height: 390,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 12.5,
                      onTap: (_, __) => setState(() => _selected = null),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wasla.app',
                      ),
                      MarkerLayer(
                        markers: widget.providers
                            .where((p) => p.latitude != null && p.longitude != null)
                            .map((provider) {
                          final selected = _selected?.id == provider.id;
                          return Marker(
                            point: LatLng(provider.latitude!, provider.longitude!),
                            width: selected ? 58 : 48,
                            height: selected ? 66 : 56,
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
                    ],
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _mapPill(
                      icon: Icons.location_on_rounded,
                      label: widget.city,
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    left: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'service-map-center',
                      backgroundColor: _surface,
                      foregroundColor: const Color(0xFF3679C8),
                      onPressed: () => _mapController.move(center, 12.5),
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _selected == null
                    ? _buildMapHint()
                    : SingleChildScrollView(
                        key: ValueKey(_selected!.id),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        child: _buildProviderCard(_selected!),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
          const Icon(Icons.location_on_rounded, color: Color(0xFFE31C25), size: 15),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildMapHint() {
    return Center(
      key: const ValueKey('map-hint'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, color: const Color(0xFF3679C8), size: 38),
            const SizedBox(height: 10),
            Text(
              'اضغط على أي علامة في الخريطة',
              style: TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'هتظهر بيانات مقدم الخدمة هنا',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
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
