import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DirectionService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  Future<DirectionResult?> getDirections({
    required LatLng start,
    required LatLng end,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return DirectionResult.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

class DirectionResult {
  final List<MapRoute> routes;
  final String code;

  const DirectionResult({required this.routes, required this.code});

  factory DirectionResult.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    final routes = rawRoutes is List
        ? rawRoutes
            .whereType<Map>()
            .map((route) => MapRoute.fromJson(Map<String, dynamic>.from(route)))
            .toList(growable: false)
        : const <MapRoute>[];

    return DirectionResult(
      routes: routes,
      code: json['code']?.toString() ?? '',
    );
  }
}

class MapRoute {
  final double distance;
  final double duration;
  final List<LatLng> polylinePoints;

  const MapRoute({
    required this.distance,
    required this.duration,
    required this.polylinePoints,
  });

  factory MapRoute.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    final points = <LatLng>[];

    if (coordinates is List) {
      for (final rawPoint in coordinates) {
        if (rawPoint is! List || rawPoint.length < 2) continue;
        final longitude = _toDouble(rawPoint[0]);
        final latitude = _toDouble(rawPoint[1]);
        if (longitude == null || latitude == null) continue;
        points.add(LatLng(latitude, longitude));
      }
    }

    return MapRoute(
      distance: _toDouble(json['distance']) ?? 0,
      duration: _toDouble(json['duration']) ?? 0,
      polylinePoints: points,
    );
  }

  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '$hours ساعة'
        : '$hours ساعة $remainingMinutes د';
  }

  String get distanceText {
    if (distance < 1000) return '${distance.round()} متر';
    return '${(distance / 1000).toStringAsFixed(1)} كم';
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
