// lib/features/map/presentation/cubit/map_cubit.dart

import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../../offers/domain/entities/food_offer.dart';
import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  final LocationService _locationService;
  final MapRepositoryImpl _repository;

  MapCubit({
    LocationService? locationService,
    MapRepositoryImpl? repository,
  })  : _locationService = locationService ?? LocationService(),
        _repository = repository ?? MapRepositoryImpl(),
        super(const MapState());

  Future<void> initialize() async {
    emit(state.copyWith(status: MapStatus.loadingLocation, isLoading: true));

    // 1. Check if location service is enabled
    final isServiceEnabled = await _locationService.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      emit(state.copyWith(
        status: MapStatus.locationServiceDisabled,
        errorMessage: 'خدمة الموقع مغلقة. فعّل الموقع لعرض العروض القريبة منك.',
        isLoading: false,
      ));
      return;
    }

    // 2. Check permission
    final permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      final newPermission = await _locationService.requestPermission();
      if (newPermission == LocationPermission.denied) {
        emit(state.copyWith(
          status: MapStatus.permissionDenied,
          errorMessage: 'يرجى السماح للتطبيق بالوصول إلى موقعك',
          isLoading: false,
        ));
        return;
      }
      if (newPermission == LocationPermission.deniedForever) {
        emit(state.copyWith(
          status: MapStatus.permissionDeniedForever,
          errorMessage:
              'فعّل صلاحية الموقع من إعدادات الهاتف لعرض العروض القريبة منك.',
          isLoading: false,
        ));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      emit(state.copyWith(
        status: MapStatus.permissionDeniedForever,
        errorMessage:
            'فعّل صلاحية الموقع من إعدادات الهاتف لعرض العروض القريبة منك.',
        isLoading: false,
      ));
      return;
    }

    // 3. Get current position
    try {
      final position = await _locationService.getCurrentPosition();
      final userLocation = LatLng(position.latitude, position.longitude);

      emit(state.copyWith(
        status: MapStatus.locationLoaded,
        userLocation: userLocation,
      ));

      // 4. Load nearby offers
      await _loadNearbyOffers(position.latitude, position.longitude);
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: 'تعذر تحديد موقعك. حاول مرة أخرى.',
        isLoading: false,
      ));
    }
  }

  Future<void> _loadNearbyOffers(double latitude, double longitude) async {
    emit(state.copyWith(
      status: MapStatus.loadingOffers,
      isLoading: true,
    ));

    try {
      final offers = await _repository.getNearbyOffers(
        latitude: latitude,
        longitude: longitude,
      );

      emit(state.copyWith(
        status: MapStatus.offersLoaded,
        nearbyOffers: offers,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        isLoading: false,
      ));
    }
  }

  Future<void> refreshLocation() async {
    await initialize();
  }

  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  void selectOffer(FoodOffer offer) {
    // TODO: Navigate to offer details
  }
}
