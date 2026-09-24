// lib/features/auth/presentation/pages/location_picker_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _primary = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);

  // ═══════════════════════════════════════════════════════════
  // ✅ Mapbox Token — ضع التوكن بتاعك هنا
  // ═══════════════════════════════════════════════════════════
  static const _mapboxToken =
      'pk.eyJ1IjoiYWJkby0xMjQzNCIsImEiOiJjbXNsbGwzcWcxNXY5MnpwOThuZnY0Zm91In0.BlZ2_ALaPohK3AOu3Re71w';

  static const _mapboxStyle = 'mapbox/streets-v12'; // ممكن تغيرها

  final _mapController = MapController();
  LatLng? _selected;
  bool _locating = false;

  // ✅ افتراضي: طنطا
  static const _defaultLat = 30.7865;
  static const _defaultLng = 31.0004;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 تحديد موقع المستخدم الحالي
  // ═══════════════════════════════════════════════════════════
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          _snack('لازم تسمح بالوصول للموقع');
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final target = LatLng(pos.latitude, pos.longitude);

      // ✅ نحفظ الإحداثي ونتحرك بالخريطة
      setState(() => _selected = target);
      _mapController.move(target, 16);
    } catch (e) {
      debugPrint('❌ location error: $e');
      _snack('تعذر تحديد موقعك، حاول تاني');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final initial = _selected ?? const LatLng(_defaultLat, _defaultLng);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8F6),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F8F6),
                        foregroundColor: _darkGreen,
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'حدّد موقعك',
                        style: TextStyle(
                          color: _darkGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initial,
                        initialZoom: _selected != null ? 16 : 12,
                        minZoom: 5,
                        maxZoom: 19,
                        onTap: (_, point) {
                          setState(() => _selected = point);
                        },
                      ),
                      children: [
                        // ✅ Mapbox Tiles
                        TileLayer(
                          urlTemplate:
                              'https://api.mapbox.com/styles/v1/$_mapboxStyle/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                          userAgentPackageName: 'com.example.first_app',
                          tileProvider: CancellableNetworkTileProvider(),
                          maxZoom: 19,
                        ),

                        // ✅ الدبوس
                        if (_selected != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selected!,
                                width: 50,
                                height: 50,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: _primary,
                                  size: 48,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // ── crosshair في المنتصف لو مفيش marker
                    if (_selected == null)
                      const IgnorePointer(
                        child: Center(
                          child: Icon(
                            Icons.location_on_rounded,
                            color: _primary,
                            size: 48,
                          ),
                        ),
                      ),

                    // ── زر موقعي الحالي
                    Positioned(
                      top: 16,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'my_loc',
                        onPressed: _locating ? null : _goToMyLocation,
                        backgroundColor: Colors.white,
                        foregroundColor: _primary,
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),

                    // ── تلميح
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 70,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Text(
                          'اضغط على الخريطة لتحديد الموقع',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _darkGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom Sheet
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: _primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'الموقع المحدد',
                          style: TextStyle(
                            color: _darkGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_selected == null)
                      Text(
                        'اختار نقطة على الخريطة',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      )
                    else ...[
                      const Text(
                        'الإحداثيات:',
                        style: TextStyle(
                          color: _darkGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selected!.latitude.toStringAsFixed(5)}, '
                        '${_selected!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontSize: 13,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '💡 اكتب اسم الشارع/المنطقة في خانة "العنوان" في الصفحة السابقة',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.4),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _selected == null
                            ? null
                            : () => Navigator.pop(context, {
                                  'lat': _selected!.latitude,
                                  'lng': _selected!.longitude,
                                }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor:
                              _primary.withValues(alpha: 0.4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'تأكيد الموقع',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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
      ),
    );
  }
}
