// lib/features/location/presentation/pages/location_picker_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../routes/app_router.dart';

/// صفحة تحديد الموقع — تظهر بعد نجاح تسجيل الدخول مباشرة وقبل الدخول للهوم.
///
/// بخلاف النسخة القديمة، الصفحة دي بتفترض إن المستخدم مسجّل دخول بالفعل
/// (auth.currentUser موجود)، فبتحفظ الموقع في جدول users على طول من غير
/// أي تخزين مؤقت.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _green = Color(0xFF0B7650);

  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _initialMoveDone = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final locationService = LocationService();

      final isServiceEnabled = await locationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'خدمة الموقع مغلقة. فعّلها من إعدادات الجهاز.';
          _currentLocation ??= const LatLng(30.0444, 31.2357);
        });
        return;
      }

      var permission = await locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationService.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              'يرجى السماح للتطبيق بالوصول لموقعك، أو حدده يدويًا على الخريطة.';
          _currentLocation ??= const LatLng(30.0444, 31.2357);
        });
        return;
      }

      final position = await locationService.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
        _selectedLocation = location;
        _isLoading = false;
        _statusMessage = 'تم تحديد موقعك — اضغط "متابعة" للتأكيد.';
      });

      if (_mapReady && !_initialMoveDone) {
        _mapController.move(location, 15);
        _initialMoveDone = true;
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'تعذر تحديد موقعك تلقائيًا. اختره يدويًا على الخريطة.';
        // موقع افتراضي (القاهرة) عشان الخريطة تظهر حتى لو GPS فشل.
        _currentLocation ??= const LatLng(30.0444, 31.2357);
      });
    }
  }

  Future<void> _confirmAndContinue() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد موقعك على الخريطة أولاً')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = SupabaseService();
      final userId = supabase.client.auth.currentUser?.id;

      if (userId == null) {
        // حالة غير متوقعة: الصفحة دي مفروض تظهر بعد تسجيل الدخول بس.
        if (mounted) context.go(AppRouter.login);
        return;
      }

      await supabase.client.from('users').update({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (!mounted) return;
      context.go(AppRouter.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الموقع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skip() {
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            'حدد موقعك',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          actions: [
            TextButton(
              onPressed: _skip,
              child: const Text(
                'تخطي',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_currentLocation != null)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation!,
                  initialZoom: 15,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    if (_currentLocation != null && !_initialMoveDone) {
                      _mapController.move(_currentLocation!, 15);
                      _initialMoveDone = true;
                    }
                  },
                  onTap: (_, point) {
                    setState(() {
                      _selectedLocation = point;
                      _statusMessage =
                          '📍 تم تحديد موقع جديد. اضغط "متابعة" للتأكيد.';
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.loqma.app',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              )
            else
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: _green),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage ?? 'جاري تحديد موقعك...',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (_statusMessage != null && _currentLocation != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F7EC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFE7CE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'my-location',
                mini: true,
                backgroundColor: Colors.blue,
                onPressed: _isLoading ? null : _getCurrentLocation,
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || _selectedLocation == null
                      ? null
                      : _confirmAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _isSaving ? 'جارٍ الحفظ...' : 'متابعة إلى الرئيسية',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
