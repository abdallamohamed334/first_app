// lib/features/map/presentation/bloc/map_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/services/location_service.dart';
import '../../data/repositories/map_repository_impl.dart';
import '../../../offers/domain/entities/food_offer.dart';
import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final LocationService _locationService;
  final MapRepositoryImpl _mapRepository;

  MapBloc({
    LocationService? locationService,
    MapRepositoryImpl? mapRepository,
  })  : _locationService = locationService ?? LocationService(),
        _mapRepository = mapRepository ?? MapRepositoryImpl(),
        super(const MapState()) {
    on<MapStarted>(_onMapStarted);
    on<MapLocationUpdated>(_onMapLocationUpdated);
    on<MapOffersLoaded>(_onMapOffersLoaded);
    on<SelectOffer>(_onSelectOffer);
    on<ClearSelectedOffer>(_onClearSelectedOffer);
    on<FilterOffers>(_onFilterOffers);
    on<ChangeRadius>(_onChangeRadius);
    on<SearchLocation>(_onSearchLocation);
    on<GoToMyLocation>(_onGoToMyLocation);
    on<RefreshOffers>(_onRefreshOffers);
    on<PermissionDenied>(_onPermissionDenied);
    on<PermissionDeniedForever>(_onPermissionDeniedForever);
    on<LocationServiceDisabled>(_onLocationServiceDisabled);
    on<MapLocationError>(_onMapLocationError);
    on<MapOffersError>(_onMapOffersError);
  }

  Future<void> _onMapStarted(
    MapStarted event,
    Emitter<MapState> emit,
  ) async {
    print('📍 [MapBloc] MapStarted received');
    emit(state.copyWith(status: MapStatus.loadingLocation, isLoading: true));

    final isServiceEnabled = await _locationService.isLocationServiceEnabled();
    print('📍 [MapBloc] isServiceEnabled: $isServiceEnabled');

    if (!isServiceEnabled) {
      print('📍 [MapBloc] Location service DISABLED');
      add(LocationServiceDisabled());
      return;
    }

    final permission = await _locationService.checkPermission();
    print('📍 [MapBloc] permission: $permission');

    if (permission == LocationPermission.denied) {
      print('📍 [MapBloc] Permission denied, requesting...');
      final newPermission = await _locationService.requestPermission();
      print('📍 [MapBloc] New permission: $newPermission');
      if (newPermission == LocationPermission.denied) {
        add(PermissionDenied());
        return;
      }
      if (newPermission == LocationPermission.deniedForever) {
        add(PermissionDeniedForever());
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('📍 [MapBloc] Permission denied FOREVER');
      add(PermissionDeniedForever());
      return;
    }

    try {
      print('📍 [MapBloc] Getting current position...');
      final position = await _locationService.getCurrentPosition();
      print(
          '📍 [MapBloc] Position: ${position.latitude}, ${position.longitude}');
      add(MapLocationUpdated(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (e) {
      print('📍 [MapBloc] Error getting position: $e');
      add(const MapLocationError('تعذر تحديد موقعك. حاول مرة أخرى.'));
    }
  }

  Future<void> _onMapLocationUpdated(
    MapLocationUpdated event,
    Emitter<MapState> emit,
  ) async {
    print(
        '📍 [MapBloc] MapLocationUpdated: ${event.latitude}, ${event.longitude}');
    emit(state.copyWith(
      status: MapStatus.locationLoaded,
      userLatitude: event.latitude,
      userLongitude: event.longitude,
    ));

    emit(state.copyWith(status: MapStatus.loadingOffers, isLoading: true));

    try {
      final offers = await _mapRepository.getNearbyOffers(
        latitude: event.latitude,
        longitude: event.longitude,
        radiusMeters: state.radius,
      );

      add(MapOffersLoaded(offers));
    } catch (e) {
      add(MapOffersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onMapOffersLoaded(
    MapOffersLoaded event,
    Emitter<MapState> emit,
  ) async {
    print('📍 [MapBloc] MapOffersLoaded: ${event.offers.length} offers');
    emit(state.copyWith(
      status: MapStatus.offersLoaded,
      offers: event.offers,
      filteredOffers: _applyFilter(event.offers, state.selectedFilter),
      isLoading: false,
    ));
  }

  Future<void> _onGoToMyLocation(
    GoToMyLocation event,
    Emitter<MapState> emit,
  ) async {
    print('📍 [MapBloc] GoToMyLocation called');

    final isServiceEnabled = await _locationService.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      add(LocationServiceDisabled());
      return;
    }

    final permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      final newPermission = await _locationService.requestPermission();
      if (newPermission == LocationPermission.denied) {
        add(PermissionDenied());
        return;
      }
      if (newPermission == LocationPermission.deniedForever) {
        add(PermissionDeniedForever());
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      add(PermissionDeniedForever());
      return;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      add(MapLocationUpdated(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } catch (e) {
      add(const MapLocationError('تعذر تحديث موقعك. حاول مرة أخرى.'));
    }
  }

  Future<void> _onRefreshOffers(
    RefreshOffers event,
    Emitter<MapState> emit,
  ) async {
    print('📍 [MapBloc] RefreshOffers called');

    if (state.userLatitude == null || state.userLongitude == null) {
      add(GoToMyLocation());
      return;
    }

    emit(state.copyWith(status: MapStatus.loadingOffers, isLoading: true));

    try {
      final offers = await _mapRepository.getNearbyOffers(
        latitude: state.userLatitude!,
        longitude: state.userLongitude!,
        radiusMeters: state.radius,
      );

      add(MapOffersLoaded(offers));
    } catch (e) {
      add(MapOffersError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onChangeRadius(
    ChangeRadius event,
    Emitter<MapState> emit,
  ) async {
    print('📍 [MapBloc] ChangeRadius: ${event.radius}');
    emit(state.copyWith(radius: event.radius));

    if (state.userLatitude != null && state.userLongitude != null) {
      emit(state.copyWith(status: MapStatus.loadingOffers, isLoading: true));

      try {
        final offers = await _mapRepository.getNearbyOffers(
          latitude: state.userLatitude!,
          longitude: state.userLongitude!,
          radiusMeters: event.radius,
        );

        add(MapOffersLoaded(offers));
      } catch (e) {
        add(MapOffersError(e.toString().replaceFirst('Exception: ', '')));
      }
    }
  }

  void _onSelectOffer(
    SelectOffer event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(selectedOffer: event.offer));
  }

  void _onClearSelectedOffer(
    ClearSelectedOffer event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(selectedOffer: null));
  }

  void _onFilterOffers(
    FilterOffers event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(
      selectedFilter: event.filter,
      filteredOffers: _applyFilter(state.offers, event.filter),
    ));
  }

  Future<void> _onSearchLocation(
    SearchLocation event,
    Emitter<MapState> emit,
  ) async {
    // TODO: Implement geocoding search
  }

  void _onPermissionDenied(
    PermissionDenied event,
    Emitter<MapState> emit,
  ) {
    print('📍 [MapBloc] PermissionDenied');
    emit(state.copyWith(
      status: MapStatus.permissionDenied,
      errorMessage: 'يرجى السماح للتطبيق بالوصول إلى موقعك',
      isLoading: false,
    ));
  }

  void _onPermissionDeniedForever(
    PermissionDeniedForever event,
    Emitter<MapState> emit,
  ) {
    print('📍 [MapBloc] PermissionDeniedForever');
    emit(state.copyWith(
      status: MapStatus.permissionDeniedForever,
      errorMessage:
          'فعّل صلاحية الموقع من إعدادات الهاتف لعرض العروض القريبة منك',
      isLoading: false,
    ));
  }

  void _onLocationServiceDisabled(
    LocationServiceDisabled event,
    Emitter<MapState> emit,
  ) {
    print('📍 [MapBloc] LocationServiceDisabled');
    emit(state.copyWith(
      status: MapStatus.locationServiceDisabled,
      errorMessage: 'خدمة الموقع مغلقة. فعّل الموقع لعرض العروض القريبة منك',
      isLoading: false,
    ));
  }

  void _onMapLocationError(
    MapLocationError event,
    Emitter<MapState> emit,
  ) {
    print('📍 [MapBloc] MapLocationError: ${event.message}');
    emit(state.copyWith(
      status: MapStatus.error,
      errorMessage: event.message,
      isLoading: false,
    ));
  }

  void _onMapOffersError(
    MapOffersError event,
    Emitter<MapState> emit,
  ) {
    print('📍 [MapBloc] MapOffersError: ${event.message}');
    emit(state.copyWith(
      status: MapStatus.error,
      errorMessage: event.message,
      isLoading: false,
    ));
  }

  List<FoodOffer> _applyFilter(List<FoodOffer> offers, String? filter) {
    if (filter == null || filter == 'all') return offers;

    return offers.where((offer) {
      if (filter == 'food') {
        return offer.foodType.toLowerCase() == 'وجبات';
      }
      if (filter == 'bakery') {
        return offer.foodType.toLowerCase() == 'مخبوزات';
      }
      if (filter == 'dessert') {
        return offer.foodType.toLowerCase() == 'حلويات';
      }
      if (filter == 'fruit') {
        return offer.foodType.toLowerCase() == 'فواكه';
      }
      if (filter == 'drink') {
        return offer.foodType.toLowerCase() == 'مشروبات';
      }
      if (filter == 'meat') {
        return offer.foodType.toLowerCase() == 'لحوم';
      }
      if (filter == 'halal') {
        return offer.isHalal == true;
      }
      if (filter == 'vegetarian') {
        return offer.isVegetarian == true;
      }
      return true;
    }).toList();
  }
}
