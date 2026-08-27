import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'map_event.dart';
import 'map_state.dart';

@injectable
class MapBloc extends Bloc<MapEvent, MapState> {
  final SupabaseService _supabaseService;

  MapBloc(this._supabaseService) : super(const MapInitial()) {
    on<MapStarted>(_onStarted);
    on<SelectOffer>(_onSelectOffer);
    on<FilterOffers>(_onFilterOffers);
    on<SearchLocation>(_onSearchLocation);
    on<ChangeRadius>(_onChangeRadius);
    on<GoToMyLocation>(_onGoToMyLocation);
  }

  Future<void> _onStarted(
    MapStarted event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLoading());

    try {
      final offersData = await _supabaseService.getFoodOffers();
      final offers = <FoodOffer>[];

      for (final data in offersData) {
        try {
          offers.add(FoodOffer.fromJson(data));
        } catch (e) {
          print('❌ Error parsing offer: $e');
        }
      }

      emit(MapLoaded(
        allOffers: offers,
        filteredOffers: offers,
        selectedOffer: offers.isNotEmpty ? offers.first : null,
        selectedFilter: 'كل الوجبات',
        radius: 5.0,
        userLatitude: 30.0444,
        userLongitude: 31.2357,
      ));
    } catch (e) {
      emit(MapError('حدث خطأ أثناء تحميل البيانات: $e'));
    }
  }

  void _onSelectOffer(SelectOffer event, Emitter<MapState> emit) {
    final currentState = state;
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(selectedOffer: event.offer));
    }
  }

  void _onFilterOffers(FilterOffers event, Emitter<MapState> emit) {
    final currentState = state;
    if (currentState is! MapLoaded) return;

    final filtered = event.filter == 'كل الوجبات'
        ? currentState.allOffers
        : currentState.allOffers
            .where((offer) => offer.foodType.contains(event.filter))
            .toList();

    emit(currentState.copyWith(
      filteredOffers: filtered,
      selectedFilter: event.filter,
      selectedOffer: filtered.isNotEmpty ? filtered.first : null,
    ));
  }

  Future<void> _onSearchLocation(
    SearchLocation event,
    Emitter<MapState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    final currentState = state;
    if (currentState is! MapLoaded) return;

    print('🔎 Searching for location: $query');

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        <String, String>{
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
          'addressdetails': '1',
          'accept-language': 'ar,en',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Loqma-Food-Rescue-App/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Geocoding HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        emit(MapError(
            'لم نجد المكان "$query". جرّب اسم المدينة أو البلد بالإنجليزية.'));
        return;
      }

      final result = decoded.first as Map<String, dynamic>;
      final latitude = double.tryParse(result['lat']?.toString() ?? '');
      final longitude = double.tryParse(result['lon']?.toString() ?? '');

      if (latitude == null || longitude == null) {
        emit(const MapError('تعذر قراءة إحداثيات المكان الذي اخترته.'));
        return;
      }

      print('📍 Found $query at $latitude, $longitude');

      // MapPage يستمع إلى MapLoaded ويحرّك MapController عند تغيّر الإحداثيات.
      emit(currentState.copyWith(
        userLatitude: latitude,
        userLongitude: longitude,
      ));
    } catch (e) {
      print('❌ Location search error: $e');
      emit(MapError(
          'تعذر البحث عن "$query". تأكد من اتصال الإنترنت وحاول مرة أخرى.'));
    }
  }

  void _onChangeRadius(ChangeRadius event, Emitter<MapState> emit) {
    final currentState = state;
    if (currentState is MapLoaded) {
      emit(currentState.copyWith(radius: event.radius));
    }
  }

  Future<void> _onGoToMyLocation(
    GoToMyLocation event,
    Emitter<MapState> emit,
  ) async {
    final currentState = state;
    if (currentState is! MapLoaded) return;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(const MapError('افتح GPS من إعدادات الهاتف أولًا.'));
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        emit(const MapError('تم رفض صلاحية الوصول إلى موقعك.'));
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        emit(const MapError(
          'صلاحية الموقع مرفوضة نهائيًا. فعّلها من إعدادات التطبيق.',
        ));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 User location: ${position.latitude}, ${position.longitude}');

      emit(currentState.copyWith(
        userLatitude: position.latitude,
        userLongitude: position.longitude,
      ));
    } catch (e) {
      print('❌ GPS error: $e');
      emit(const MapError('تعذر جلب موقعك. تأكد من تشغيل GPS.'));
    }
  }
}
