import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:math' show cos, sqrt, asin;
import '../../../../core/services/direction_service.dart';
import '../bloc/map_bloc.dart';
import '../bloc/map_event.dart';
import '../bloc/map_state.dart';
import '../widgets/map_search_bar.dart';
import '../widgets/map_bottom_sheet.dart';
import '../widgets/map_filter_chips.dart';
import '../widgets/map_radius_slider.dart';
import '../../../offers/domain/entities/food_offer.dart';
import '../../../donation/presentation/pages/offer_details_page.dart';
import '../../../../core/services/supabase_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final DirectionService _directionService = DirectionService();
  bool _isWeb = false;
  bool _mapReady = false;
  final Set<String> _reservedOfferIds = <String>{};

  List<Polyline> _polylines = [];
  MapRoute? _currentRoute;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    try {
      _isWeb = html.window.navigator.userAgent.contains('Chrome') ||
          html.window.navigator.userAgent.contains('Firefox') ||
          html.window.navigator.userAgent.contains('Safari');
    } catch (e) {
      _isWeb = false;
    }
    context.read<MapBloc>().add(const MapStarted());
    _loadReservedOfferIds();
  }

  Future<void> _loadReservedOfferIds() async {
    try {
      final response = await SupabaseService()
          .client
          .from('offer_requests')
          .select('offer_id, status')
          .inFilter('status', const [
        'pending',
        'accepted',
        'ready_for_pickup',
      ]);

      if (!mounted) return;
      setState(() {
        _reservedOfferIds
          ..clear()
          ..addAll(
            (response as List)
                .map((row) => row['offer_id']?.toString())
                .whereType<String>(),
          );
      });
    } catch (e) {
      debugPrint('Map: unable to load reserved offers: $e');
    }
  }

  List<FoodOffer> _visibleOffers(List<FoodOffer> offers) {
    return offers.where((offer) {
      final status = offer.status.value.toLowerCase();
      final isActiveStatus = status == 'available' || status == 'active';
      final isReserved = _reservedOfferIds.contains(offer.id);
      return isActiveStatus && !offer.isExpired && !isReserved;
    }).toList();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _loadDirections(FoodOffer offer) async {
    final currentState = context.read<MapBloc>().state;
    if (currentState is! MapLoaded) return;

    final userLat = currentState.userLatitude ?? 30.0444;
    final userLng = currentState.userLongitude ?? 31.2357;
    final destLat = offer.mapLatitude;
    final destLng = offer.mapLongitude;

    final distance = _calculateDistance(userLat, userLng, destLat, destLng);

    final result = await _directionService.getDirections(
      start: LatLng(userLat, userLng),
      end: LatLng(destLat, destLng),
    );

    if (result != null && result.routes.isNotEmpty && mounted) {
      setState(() {
        _currentRoute = result.routes.first;
        _distanceKm = distance;
        _polylines = [
          Polyline(
            points: result.routes.first.polylinePoints,
            color: Colors.blue.shade700,
            strokeWidth: 5,
            borderStrokeWidth: 2,
            borderColor: Colors.white,
          ),
        ];
      });

      if (_mapReady) {
        _mapController.move(LatLng(destLat, destLng), 14);
      }
    }
  }

  void _onOfferSelected(FoodOffer offer) {
    context.read<MapBloc>().add(SelectOffer(offer));

    // Move directly to the restaurant that created the offer.
    if (!_hasValidLocation(offer)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موقع المطعم غير متاح لهذا العرض حاليًا')),
      );
      return;
    }

    if (_mapReady) {
      _mapController.move(
        LatLng(offer.mapLatitude, offer.mapLongitude),
        16,
      );
    }

    _loadDirections(offer);
  }

  void _onShowDetails(FoodOffer offer) {
    if (!_isOfferVisible(offer)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العرض لم يعد متاحًا')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferDetailsPage(offer: _offerDetailsMap(offer)),
      ),
    ).then((_) => _loadReservedOfferIds());
  }

  bool _hasValidLocation(FoodOffer offer) {
    return offer.mapLatitude.isFinite &&
        offer.mapLongitude.isFinite &&
        offer.mapLatitude.abs() <= 90 &&
        offer.mapLongitude.abs() <= 180;
  }

  bool _isOfferVisible(FoodOffer offer) {
    final status = offer.status.value.toLowerCase();
    return (status == 'available' || status == 'active') &&
        !offer.isExpired &&
        !_reservedOfferIds.contains(offer.id);
  }

  Map<String, dynamic> _offerDetailsMap(FoodOffer offer) {
    // Keep this adapter limited to fields already used by MapPage/FoodOffer.
    // OfferDetailsPage can still render the core offer information safely.
    return {
      'id': offer.id,
      'title': offer.title,
      'description': '',
      'quantity': 0,
      'food_type': '',
      'expiry_time':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'pickup_before':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'pickup_location': 'موقع المطعم على الخريطة',
      'latitude': offer.mapLatitude,
      'longitude': offer.mapLongitude,
      'status': offer.status.value,
      'image': null,
      'images': const <dynamic>[],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'restaurants': const {'name': 'مطعم قريب'},
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<MapBloc, MapState>(
        listener: (context, state) {
          if (state is MapLoaded) {
            // 🔥 لما يجيب الموقع الحقيقي، حرك الخريطة له
            if (_mapReady &&
                state.userLatitude != null &&
                state.userLongitude != null) {
              _mapController.move(
                LatLng(state.userLatitude!, state.userLongitude!),
                16, // zoom عالي عشان يبين الموقع بالظبط
              );

              // ✅ تأكيد للمستخدم
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ تم تحديد موقعك: ${state.userLatitude!.toStringAsFixed(4)}, ${state.userLongitude!.toStringAsFixed(4)}',
                    textAlign: TextAlign.right,
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
          if (state is MapError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  textAlign: TextAlign.right,
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is MapLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MapLoaded) {
            final visibleOffers = _visibleOffers(state.filteredOffers);
            if (_isWeb) return _buildWebPlaceholder(state, visibleOffers);

            final userLat = state.userLatitude;
            final userLng = state.userLongitude;

            final offerMarkers = visibleOffers.map((offer) {
              final isSelected = state.selectedOffer?.id == offer.id;
              return Marker(
                point: LatLng(offer.mapLatitude, offer.mapLongitude),
                width: isSelected ? 55 : 45,
                height: isSelected ? 55 : 45,
                child: GestureDetector(
                  onTap: () => _onOfferSelected(offer),
                  child: _buildMarkerIcon(offer, isSelected),
                ),
              );
            }).toList();

            // ✅ Marker موقعك الحقيقي (دائرة زرقاء متحركة)
            final List<Marker> userMarkers = [];
            if (userLat != null && userLng != null) {
              userMarkers.add(
                Marker(
                  point: LatLng(userLat, userLng),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              body: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        state.userLatitude ?? 30.0444,
                        state.userLongitude ?? 31.2357,
                      ),
                      initialZoom: 13,
                      onMapReady: () => setState(() => _mapReady = true),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=pk.eyJ1IjoiYWJkby0xMjQzNCIsImEiOiJjbXNsbGwzcWcxNXY5MnpwOThuZnY0Zm91In0.BlZ2_ALaPohK3AOu3Re71w',
                        additionalOptions: const {
                          'accessToken':
                              'pk.eyJ1IjoiYWJkby0xMjQzNCIsImEiOiJjbXNsbGwzcWcxNXY5MnpwOThuZnY0Zm91In0.BlZ2_ALaPohK3AOu3Re71w',
                        },
                      ),
                      MarkerLayer(markers: [...offerMarkers, ...userMarkers]),
                      PolylineLayer(polylines: _polylines),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: MapSearchBar(
                      onSearch: (query) {
                        context.read<MapBloc>().add(SearchLocation(query));
                      },
                    ),
                  ),
                  Positioned(
                    top: 80,
                    left: 16,
                    right: 16,
                    child: MapFilterChips(
                      selectedFilter: state.selectedFilter,
                      onFilterSelected: (filter) {
                        context.read<MapBloc>().add(FilterOffers(filter));
                      },
                    ),
                  ),
                  if (_currentRoute != null)
                    Positioned(
                      top: 140,
                      left: 16,
                      right: 16,
                      child: _buildRouteCard(),
                    ),
                  // ✅ زرار "موقعي" — بيجيب GPS حقيقي
                  Positioned(
                    bottom: 320,
                    right: 16,
                    child: FloatingActionButton(
                      heroTag: 'location',
                      onPressed: () {
                        context.read<MapBloc>().add(const GoToMyLocation());
                      },
                      mini: true,
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ),
                  if (_polylines.isNotEmpty)
                    Positioned(
                      bottom: 380,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'clear',
                        onPressed: () => setState(() {
                          _polylines = [];
                          _currentRoute = null;
                          _distanceKm = null;
                        }),
                        mini: true,
                        backgroundColor: Colors.red.shade100,
                        child: const Icon(Icons.clear, color: Colors.red),
                      ),
                    ),
                  Positioned(
                    bottom: 300,
                    left: 16,
                    right: 100,
                    child: MapRadiusSlider(
                      radius: state.radius,
                      onRadiusChanged: (radius) {
                        context.read<MapBloc>().add(ChangeRadius(radius));
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: MapBottomSheet(
                      offers: visibleOffers,
                      selectedOffer: state.selectedOffer,
                      onOfferTap: _onOfferSelected,
                      onShowDetails: _onShowDetails,
                      onViewAll: () => print('عرض الكل'),
                      userLatitude: state.userLatitude,
                      userLongitude: state.userLongitude,
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildRouteCard() {
    return Card(
      elevation: 8,
      color: Colors.blue.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.directions, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'المسافة: ${_distanceKm?.toStringAsFixed(1)} كم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'الوقت بالسيارة: ${_currentRoute!.durationText}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _polylines = [];
                _currentRoute = null;
                _distanceKm = null;
              }),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerIcon(FoodOffer offer, bool isSelected) {
    Color markerColor;
    if (offer.isExpired) {
      markerColor = Colors.red;
    } else if (offer.isUrgent) {
      markerColor = Colors.orange;
    } else {
      markerColor = Colors.green;
    }

    return AnimatedScale(
      scale: isSelected ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Icon(
        Icons.location_on,
        color: markerColor,
        size: isSelected ? 50 : 40,
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
    );
  }

  Widget _buildWebPlaceholder(MapLoaded state, List<FoodOffer> visibleOffers) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: colorScheme.surfaceContainerHigh,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map,
                      size: 80,
                      color: colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('الخريطة غير متاحة على الويب',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('يتم عرض الوجبات القريبة منك في القائمة أدناه'),
                  const SizedBox(height: 24),
                  Text('${visibleOffers.length} وجبة قريبة منك',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MapBottomSheet(
              offers: visibleOffers,
              selectedOffer: state.selectedOffer,
              onOfferTap: _onOfferSelected,
              onShowDetails: _onShowDetails,
              onViewAll: () => print('عرض الكل'),
              userLatitude: state.userLatitude,
              userLongitude: state.userLongitude,
            ),
          ),
        ],
      ),
    );
  }
}
