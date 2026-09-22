// lib/core/services/location_service.dart

import 'package:geolocator/geolocator.dart';

class LocationService {
  static const int defaultRadiusMeters = 100000;

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  Future<Position> getCurrentPosition() async {
    print('📍 [LocationService] getCurrentPosition called');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print(
          '📍 [LocationService] Position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('📍 [LocationService] Error: $e');
      rethrow;
    }
  }

  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  String getPermissionStatusMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'يرجى السماح للتطبيق بالوصول إلى موقعك';
      case LocationPermission.deniedForever:
        return 'فعّل صلاحية الموقع من إعدادات الهاتف لعرض العروض القريبة منك';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return '';
      case LocationPermission.unableToDetermine:
        return 'تعذر تحديد صلاحية الموقع';
    }
  }
}
