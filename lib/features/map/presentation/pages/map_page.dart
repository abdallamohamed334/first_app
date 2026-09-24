// lib/features/map/presentation/pages/map_page.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:loqma/routes/app_router.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../core/services/location_service.dart';
import '../../../../core/services/supabase_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  bool _isWeb = false;
  bool _mapReady = false;
  bool _initialMoveDone = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  bool _isLocationSaved = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    print('📍 [MapPage] initState');
    try {
      _isWeb = html.window.navigator.userAgent.contains('Chrome') ||
          html.window.navigator.userAgent.contains('Firefox') ||
          html.window.navigator.userAgent.contains('Safari');
    } catch (e) {
      _isWeb = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndGetLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ✅ التحقق من حالة تسجيل الدخول أولاً
  Future<void> _checkAuthAndGetLocation() async {
    final supabase = SupabaseService();
    final user = supabase.client.auth.currentUser;

    if (user == null) {
      // ❌ مش مسجل - يروح للتسجيل
      print('❌ [MapPage] User not logged in, redirecting to login');
      if (mounted) {
        context.go(AppRouter.login);
      }
      return;
    }

    // ✅ مسجل - يكمل للخريطة
    print('✅ [MapPage] User logged in: ${user.email}');
    setState(() {
      _isLoggedIn = true;
    });
    await _getCurrentLocation();
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _getCurrentLocation() async {
    if (!_isLoggedIn) {
      context.go(AppRouter.login);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locationService = LocationService();

      final isServiceEnabled = await locationService.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'خدمة الموقع مغلقة. فعّل الموقع من الإعدادات.';
        });
        _showPermissionDialog(
          title: 'خدمة الموقع مغلقة',
          message: 'فعّل الموقع من الإعدادات لتحديد موقعك.',
          buttonText: 'فتح الإعدادات',
          onPressed: () => locationService.openLocationSettings(),
        );
        return;
      }

      var permission = await locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locationService.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'يرجى السماح للتطبيق بالوصول إلى موقعك.';
          });
          _showPermissionDialog(
            title: 'صلاحية الموقع مطلوبة',
            message: 'يرجى السماح للتطبيق بالوصول إلى موقعك لتحديد موقعك.',
            buttonText: 'طلب الصلاحية',
            onPressed: _getCurrentLocation,
          );
          return;
        }
        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'فعّل صلاحية الموقع من إعدادات الهاتف.';
          });
          _showPermissionDialog(
            title: 'صلاحية الموقع مرفوضة نهائياً',
            message: 'فعّل صلاحية الموقع من إعدادات الهاتف لتحديد موقعك.',
            buttonText: 'فتح الإعدادات',
            onPressed: () => locationService.openAppSettings(),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فعّل صلاحية الموقع من إعدادات الهاتف.';
        });
        _showPermissionDialog(
          title: 'صلاحية الموقع مرفوضة نهائياً',
          message: 'فعّل صلاحية الموقع من إعدادات الهاتف لتحديد موقعك.',
          buttonText: 'فتح الإعدادات',
          onPressed: () => locationService.openAppSettings(),
        );
        return;
      }

      final position = await locationService.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      print(
          '📍 [MapPage] Current location: ${location.latitude}, ${location.longitude}');

      setState(() {
        _currentLocation = location;
        _selectedLocation = location;
        _isLoading = false;
        _isLocationSaved = false;
      });

      if (_mapReady) {
        _mapController.move(location, 15);
        _initialMoveDone = true;
      }

      await _checkLocationInDatabase(location);
    } catch (e) {
      print('📍 [MapPage] Error getting location: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحديد موقعك. حاول مرة أخرى.';
      });
      _showPermissionDialog(
        title: 'حدث خطأ',
        message: 'تعذر تحديد موقعك. حاول مرة أخرى.',
        buttonText: 'إعادة المحاولة',
        onPressed: _getCurrentLocation,
      );
    }
  }

  Future<void> _checkLocationInDatabase(LatLng location) async {
    if (!_isLoggedIn) return;

    try {
      final supabase = SupabaseService();
      final userId = supabase.client.auth.currentUser?.id;

      if (userId == null) {
        print('⚠️ [MapPage] User not logged in');
        context.go(AppRouter.login);
        return;
      }

      final userData = await supabase.client
          .from('users')
          .select('latitude, longitude, address, city')
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) {
        print('⚠️ [MapPage] User data not found');
        setState(() {
          _errorMessage = '⚠️ لم يتم العثور على بيانات المستخدم';
        });
        return;
      }

      final dbLat = userData['latitude'] as double?;
      final dbLng = userData['longitude'] as double?;

      if (dbLat != null && dbLng != null) {
        print('📍 [MapPage] Location already in database: $dbLat, $dbLng');
        _isLocationSaved = true;

        final distance = _calculateDistance(
            dbLat, dbLng, location.latitude, location.longitude);

        print('📍 [MapPage] Distance between DB and current: $distance km');

        if (distance > 0.5) {
          setState(() {
            _errorMessage = '⚠️ موقعك مختلف عن المسجل. قم بتحديث موقعك.';
            _isLocationSaved = false;
          });
        } else {
          setState(() {
            _errorMessage = '✅ موقعك مسجل بالفعل في النظام.';
            _isLocationSaved = true;
          });
        }
        return;
      }

      print('📍 [MapPage] Location NOT in database, needs to be saved');
      setState(() {
        _errorMessage = '⚠️ لم يتم تسجيل موقعك بعد. اضغط "حفظ الموقع" لتسجيله.';
        _isLocationSaved = false;
      });
    } catch (e) {
      print('❌ [MapPage] Error checking location in DB: $e');
      setState(() {
        _errorMessage = '❌ تعذر التحقق من الموقع في النظام';
      });
    }
  }

  Future<void> _saveLocation() async {
    if (!_isLoggedIn) {
      context.go(AppRouter.login);
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final supabase = SupabaseService();
      final userId = supabase.client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final location = _selectedLocation!;

      print(
          '📍 [MapPage] Saving location: ${location.latitude}, ${location.longitude}');

      await supabase.client.from('users').update({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      print('📍 [MapPage] Update executed successfully');

      await Future.delayed(const Duration(seconds: 1));

      final updatedUser = await supabase.client
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();

      print('📍 [MapPage] Retrieved user after update: $updatedUser');

      if (updatedUser == null) {
        throw Exception('لم يتم العثور على بيانات المستخدم بعد التحديث');
      }

      final savedLat = updatedUser['latitude'] as double?;
      final savedLng = updatedUser['longitude'] as double?;

      if (savedLat == null || savedLng == null) {
        throw Exception('البيانات المحفوظة غير مكتملة');
      }

      final distance = _calculateDistance(
          savedLat, savedLng, location.latitude, location.longitude);

      print('📍 [MapPage] Distance between saved and selected: $distance km');

      if (distance < 0.05) {
        setState(() {
          _isSaving = false;
          _isLocationSaved = true;
          _currentLocation = location;
          _errorMessage = '✅ تم حفظ موقعك بنجاح!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ موقعك بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      throw Exception(
          'الموقع المحفوظ لا يطابق الموقع المختار (المسافة: ${distance.toStringAsFixed(3)} كم)');
    } catch (e) {
      print('❌ [MapPage] Error saving location: $e');
      setState(() {
        _isSaving = false;
        _errorMessage =
            '❌ تعذر حفظ الموقع: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ تعذر حفظ الموقع: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToApp() {
    context.go(AppRouter.home);
  }

  void _showPermissionDialog({
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              title.contains('مغلقة')
                  ? Icons.gps_off_rounded
                  : title.contains('نهائياً')
                      ? Icons.block_rounded
                      : Icons.location_off_rounded,
              color: Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تخطي'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onPressed();
            },
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B7650),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'تحديد الموقع',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
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
                    print('📍 [MapPage] Map ready');
                    setState(() => _mapReady = true);
                    if (_currentLocation != null && !_initialMoveDone) {
                      _mapController.move(_currentLocation!, 15);
                      _initialMoveDone = true;
                    }
                  },
                  onTap: (_, point) {
                    setState(() {
                      _selectedLocation = point;
                      _errorMessage =
                          '📍 تم تحديد موقع جديد. اضغط "حفظ الموقع" لتأكيد.';
                      _isLocationSaved = false;
                    });
                    print(
                        '📍 [MapPage] User selected location: ${point.latitude}, ${point.longitude}');
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
                              color: _isLocationSaved
                                  ? Colors.green
                                  : Colors.orange,
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
                            child: Icon(
                              _isLocationSaved
                                  ? Icons.check
                                  : Icons.location_on,
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
                      const CircularProgressIndicator(color: Color(0xFF0B7650)),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'جاري تحديد موقعك...',
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

            // ✅ رسالة الحالة
            if (_errorMessage != null && _currentLocation != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _errorMessage!.contains('✅')
                        ? Colors.green.shade50
                        : _errorMessage!.contains('⚠️')
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorMessage!.contains('✅')
                          ? Colors.green.shade200
                          : _errorMessage!.contains('⚠️')
                              ? Colors.orange.shade200
                              : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _errorMessage!.contains('✅')
                            ? Icons.check_circle_rounded
                            : _errorMessage!.contains('⚠️')
                                ? Icons.warning_amber_rounded
                                : Icons.error_outline_rounded,
                        color: _errorMessage!.contains('✅')
                            ? Colors.green
                            : _errorMessage!.contains('⚠️')
                                ? Colors.orange
                                : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: _errorMessage!.contains('✅')
                                ? Colors.green.shade700
                                : _errorMessage!.contains('⚠️')
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ زر تحديد الموقع (GPS)
            Positioned(
              bottom: 160,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'location',
                onPressed: _isLoading ? null : _getCurrentLocation,
                mini: true,
                backgroundColor: Colors.blue,
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

            // ✅ زر حفظ الموقع + متابعة
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // ✅ زر حفظ الموقع
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ||
                              _selectedLocation == null ||
                              _isLocationSaved
                          ? null
                          : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocationSaved
                            ? Colors.green
                            : const Color(0xFF0B7650),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _isLocationSaved
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isLocationSaved
                                  ? Icons.check_circle_rounded
                                  : Icons.save_rounded,
                              size: 24,
                            ),
                      label: Text(
                        _isSaving
                            ? 'جاري الحفظ...'
                            : _isLocationSaved
                                ? '✅ تم الحفظ'
                                : 'حفظ الموقع',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // ✅ زر "متابعة إلى التطبيق" - يظهر فقط بعد حفظ الموقع
                  if (_isLocationSaved) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _goToApp,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'متابعة إلى التطبيق',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0B7650),
                          side: const BorderSide(color: Color(0xFF0B7650)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
