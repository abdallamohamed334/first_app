import 'package:supabase_flutter/supabase_flutter.dart';

class OfferCard {
  final String id, title, image, foodType, businessName;
  final int quantity, reservedQuantity;
  final double? salePrice, originalPrice, distanceKm;
  final DateTime? pickupBefore, expiryTime;

  const OfferCard(
      {required this.id,
      required this.title,
      required this.image,
      required this.foodType,
      required this.businessName,
      required this.quantity,
      required this.reservedQuantity,
      this.salePrice,
      this.originalPrice,
      this.distanceKm,
      this.pickupBefore,
      this.expiryTime});

  int get remaining => quantity - reservedQuantity;
  bool get hasDiscount =>
      (originalPrice ?? 0) > (salePrice ?? 0) && salePrice != null;

  factory OfferCard.fromJson(Map<String, dynamic> j) => OfferCard(
        id: j['id'],
        title: j['title'] ?? '',
        image: j['image'] ?? '',
        foodType: j['food_type'] ?? '',
        businessName: j['business_name'] ?? '',
        quantity: j['quantity'] ?? 0,
        reservedQuantity: j['reserved_quantity'] ?? 0,
        salePrice: (j['sale_price'] as num?)?.toDouble(),
        originalPrice: (j['original_price'] as num?)?.toDouble(),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        pickupBefore: DateTime.tryParse(j['pickup_before'] ?? ''),
        expiryTime: DateTime.tryParse(j['expiry_time'] ?? ''),
      );
}

class RescueTask {
  final String id, title, donorName, charityName, pickupAddress;
  final int quantity;
  final DateTime pickupBefore;
  final double? distanceKm;
  const RescueTask(
      {required this.id,
      required this.title,
      required this.donorName,
      required this.charityName,
      required this.pickupAddress,
      required this.quantity,
      required this.pickupBefore,
      this.distanceKm});
  factory RescueTask.fromJson(Map<String, dynamic> j) => RescueTask(
        id: j['id'],
        title: j['title'] ?? '',
        donorName: j['donor_name'] ?? '',
        charityName: j['charity_name'] ?? '',
        pickupAddress: j['pickup_address'] ?? '',
        quantity: j['quantity'] ?? 1,
        pickupBefore: DateTime.parse(j['pickup_before']),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
      );
}

class BookingStatus {
  final String requestId, status, offerTitle, businessName;
  final DateTime? deadline;
  const BookingStatus(
      {required this.requestId,
      required this.status,
      required this.offerTitle,
      required this.businessName,
      this.deadline});
}

class HomeFeedData {
  final List<OfferCard> offers;
  final List<OfferCard> topSavings;
  final List<RescueTask> rescueTasks;
  final BookingStatus? activeBooking;
  final Set<String> favorites;
  const HomeFeedData(
      {required this.offers,
      required this.topSavings,
      required this.rescueTasks,
      this.activeBooking,
      this.favorites = const {}});
}

class HomeRepository {
  final SupabaseClient _db;
  HomeRepository(this._db);

  Future<HomeFeedData> getHomeFeed(
      double lat, double lng, String userId) async {
    final results = await Future.wait<dynamic>([
      _db.rpc('nearby_food_offers', params: {'p_lat': lat, 'p_lng': lng}),
      _db.rpc('nearby_rescue_tasks', params: {'p_lat': lat, 'p_lng': lng}),
      _db
          .from('offer_requests')
          .select('''
        id, status, food_offers!inner(title, pickup_before,
          businesses(name))''')
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'accepted', 'ready_for_pickup'])
          .order('updated_at', ascending: false)
          .limit(5),
      _db
          .from('favorites')
          .select('target_id')
          .eq('user_id', userId)
          .eq('target_type', 'food_offer'),
    ]);

    final offers = (results[0] as List)
        .map((e) => OfferCard.fromJson(e as Map<String, dynamic>))
        .toList();
    final rescue = (results[1] as List)
        .map((e) => RescueTask.fromJson(e as Map<String, dynamic>))
        .toList();
    final favs = (results[3] as List)
        .map((e) => (e as Map<String, dynamic>)['target_id'] as String)
        .toSet();

    final rows =
        (results[2] as List).map((e) => e as Map<String, dynamic>).toList();
    BookingStatus? booking;
    if (rows.isNotEmpty) {
      rows.sort((a, b) => (a['food_offers']['pickup_before'] ?? '')
          .compareTo(b['food_offers']['pickup_before'] ?? ''));
      final r = rows.first;
      final o = r['food_offers'];
      booking = BookingStatus(
        requestId: r['id'],
        status: r['status'],
        offerTitle: o['title'] ?? '',
        businessName: (o['businesses']?['name']) ?? '',
        deadline: DateTime.tryParse(o['pickup_before'] ?? ''),
      );
    }

    final savings = [...offers]
      ..sort((a, b) => (b.discount - a.discount).toDouble().compareTo(0));
    final topSavings = savings.where((o) => o.hasDiscount).take(5).toList();

    return HomeFeedData(
        offers: offers,
        topSavings: topSavings,
        rescueTasks: rescue,
        activeBooking: booking,
        favorites: favs);
  }

  Future<String?> reserveOffer(String offerId, int quantity) async {
    final res = await _db.rpc('reserve_food_offer', params: {
      'p_offer_id': offerId,
      'p_user_id': _db.auth.currentUser!.id,
      'p_quantity': quantity,
    });
    return (res as Map<String, dynamic>)['ok'] == true
        ? null
        : (res['error'] as String? ?? 'UNKNOWN');
  }

  Future<bool> claimRescueTask(String taskId) => _db.rpc('claim_delivery_task',
      params: {'p_task_id': taskId, 'p_user_id': _db.auth.currentUser!.id});

  Future<void> toggleFavorite(String offerId, bool isFav) async {
    final uid = _db.auth.currentUser!.id;
    if (isFav) {
      await _db.from('favorites').insert(
          {'user_id': uid, 'target_type': 'food_offer', 'target_id': offerId});
    } else {
      await _db
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('target_type', 'food_offer')
          .eq('target_id', offerId);
    }
  }
}

extension on OfferCard {
  double get discount =>
      hasDiscount ? (1 - salePrice! / originalPrice!) * 100 : 0;
}
