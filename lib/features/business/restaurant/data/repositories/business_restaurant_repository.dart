import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/services/loqma_image_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/domain/entities/business_capability.dart';

class BusinessRestaurantRepository {
  final SupabaseClient _client;
  final LoqmaImageStorageService _imageStorage;

  BusinessRestaurantRepository({
    SupabaseClient? client,
    LoqmaImageStorageService? imageStorage,
  })  : _client = client ?? SupabaseService().client,
        _imageStorage =
            imageStorage ?? LoqmaImageStorageService(client: client);

  Future<Map<String, dynamic>> getCurrentRestaurantProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('جلسة المطعم غير صالحة');
    }
    final identity = await _client
        .from('users')
        .select('user_type')
        .eq('id', userId)
        .maybeSingle();
    final userType = identity?['user_type']?.toString().trim().toLowerCase();
    if (userType != 'restaurant') {
      throw const FormatException('هذا الحساب ليس حساب مطعم');
    }
    final row = await _client
        .from('restaurants')
        .select('*')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    if (row == null) {
      throw const FormatException('لم يتم العثور على مطعم نشط مرتبط بالحساب');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> listMyOffers() async {
    final rows = await _client.rpc('restaurant_list_my_offers');
    final offers = _maps(rows);

    // توحيد حقول الصور حتى تعمل كل الشاشات سواء رجعت image أو images.
    for (final offer in offers) {
      final image = _firstImage(offer);
      if (image != null && image.isNotEmpty) {
        offer['image'] = image;
        final currentImages = offer['images'];
        if (currentImages is! List || currentImages.isEmpty) {
          offer['images'] = <String>[image];
        }
      }
    }

    return offers;
  }

  Future<List<Map<String, dynamic>>> listMyRequests() async {
    final rows = await _client.rpc('restaurant_list_my_offer_requests');
    return _maps(rows);
  }

  Future<Map<String, dynamic>> createFoodOffer({
    required String title,
    required String description,
    required int quantity,
    required String foodType,
    required DateTime expiryTime,
    required DateTime pickupBefore,
    required double salePrice,
    double? originalPrice,
    String? pickupLocation,
    String? image,
  }) async {
    final cleanImage = image?.trim();
    final databaseImage =
        cleanImage == null || cleanImage.isEmpty ? null : cleanImage;

    print('📌 createFoodOffer p_image = $databaseImage');

    final result = await _client.rpc(
      'restaurant_create_food_offer',
      params: {
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_quantity': quantity,
        'p_food_type': foodType.trim(),
        'p_expiry_time': expiryTime.toUtc().toIso8601String(),
        'p_pickup_before': pickupBefore.toUtc().toIso8601String(),
        'p_sale_price': salePrice,
        'p_original_price': originalPrice,
        'p_pickup_location': pickupLocation?.trim(),
        'p_image': databaseImage,
      },
    );
    return _map(result);
  }

  // ✅ إنشاء عرض مع صورة واحدة - معدل
  Future<Map<String, dynamic>> createFoodOfferWithImage({
    required XFile image,
    required String title,
    required String description,
    required int quantity,
    required String foodType,
    required DateTime expiryTime,
    required DateTime pickupBefore,
    required double salePrice,
    double? originalPrice,
    String? pickupLocation,
  }) async {
    final imagePath = await _imageStorage.uploadRestaurantOfferImage(image);
    try {
      return await createFoodOffer(
        title: title,
        description: description,
        quantity: quantity,
        foodType: foodType,
        expiryTime: expiryTime,
        pickupBefore: pickupBefore,
        salePrice: salePrice,
        originalPrice: originalPrice,
        pickupLocation: pickupLocation,
        image: imagePath,
      );
    } catch (_) {
      // The database error remains the user-visible error; orphan cleanup can
      // be added server-side later without hiding the original failure.
      rethrow;
    }
  }

  // ✅ إنشاء عرض مع صور متعددة - جديد
  Future<Map<String, dynamic>> createFoodOfferWithImages({
    required List<XFile> images,
    required String title,
    required String description,
    required int quantity,
    required String foodType,
    required DateTime expiryTime,
    required DateTime pickupBefore,
    required double salePrice,
    double? originalPrice,
    String? pickupLocation,
  }) async {
    try {
      // ✅ 1. رفع الصور أولاً
      final imagePaths =
          await _imageStorage.uploadRestaurantOfferImages(images);

      // ✅ 2. إنشاء العرض مع الصور
      final result = await _client.rpc(
        'restaurant_create_food_offer',
        params: {
          'p_title': title.trim(),
          'p_description': description.trim(),
          'p_quantity': quantity,
          'p_food_type': foodType.trim(),
          'p_expiry_time': expiryTime.toUtc().toIso8601String(),
          'p_pickup_before': pickupBefore.toUtc().toIso8601String(),
          'p_sale_price': salePrice,
          'p_original_price': originalPrice,
          'p_pickup_location': pickupLocation?.trim(),
          'p_image': imagePaths.isNotEmpty ? imagePaths.first : null,
          'p_images': imagePaths,
        },
      );

      print('✅ Food offer created with ${imagePaths.length} images');
      return _map(result);
    } catch (e) {
      print('❌ Error creating food offer with images: $e');
      rethrow;
    }
  }

  Future<String> uploadOfferImage(XFile image) =>
      _imageStorage.uploadRestaurantOfferImage(image);

  Future<Map<String, dynamic>> updateRequestStatus({
    required String requestId,
    required String status,
  }) async {
    final cleanId = requestId.trim();
    final cleanStatus = status.trim().toLowerCase();
    if (cleanId.isEmpty) {
      throw const FormatException('معرف الطلب غير موجود');
    }
    if (!const {'accepted', 'rejected', 'ready_for_pickup'}
        .contains(cleanStatus)) {
      throw const FormatException('حالة الطلب غير صحيحة');
    }

    final result = await _client.rpc(
      'restaurant_update_offer_request_status',
      params: {
        'p_request_id': cleanId,
        'p_status': cleanStatus,
      },
    );
    return _map(result);
  }

  Future<Map<String, dynamic>> setOfferPaused({
    required String offerId,
    required bool paused,
    String? reason,
  }) async {
    final result = await _client.rpc(
      'set_food_offer_paused',
      params: {
        'p_offer_id': offerId,
        'p_paused': paused,
        'p_reason': reason?.trim(),
      },
    );
    return _map(result);
  }

  Future<Map<String, dynamic>> verifyPickupCode(String code) async {
    final value = code.trim();
    if (value.isEmpty) throw const FormatException('اكتب كود الاستلام أولًا');
    final result = await _client.rpc(
      'restaurant_verify_pickup_code',
      params: {'p_token': value},
    );
    return _map(result);
  }

  Future<List<Map<String, dynamic>>> listActiveCharities() async {
    final rows = await _client
        .from('charities')
        .select(
            'id, name, logo, image_url, logo_url, address, description, is_verified')
        .eq('status', 'active')
        .eq('is_verified', true)
        .order('name');
    return _maps(rows).map((row) {
      row['image_url'] = _firstImage(row);
      return row;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> listMyCharityDonations() async {
    final restaurant = await getCurrentRestaurantProfile();
    final restaurantId = restaurant['id']?.toString();
    if (restaurantId == null || restaurantId.isEmpty) {
      throw const FormatException('بيانات المطعم غير مكتملة');
    }
    final rows = await _client
        .from('restaurant_charity_donations')
        .select('*, charities(id, name, logo, image_url, logo_url)')
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false);
    return _maps(rows).map((row) {
      final charity = row['charities'];
      if (charity is Map) {
        final charityMap = Map<String, dynamic>.from(charity);
        row['charity_name'] ??= charityMap['name'];
        row['charity_image_url'] = _firstImage(charityMap);
      }
      return row;
    }).toList();
  }

  Future<Set<BusinessCapability>> getCurrentCapabilities() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const <BusinessCapability>{};
    final row = await _client
        .from('businesses')
        .select('capabilities')
        .eq('user_id', userId)
        .maybeSingle();
    final raw = row?['capabilities'];
    if (raw is! List) return const <BusinessCapability>{};
    return raw.whereType<String>().map(BusinessCapability.fromString).toSet();
  }

  Future<Map<String, dynamic>> createCharityDonation({
    required String charityId,
    required String itemTitle,
    required String description,
    required int quantity,
    required String condition,
    List<String> images = const [],
  }) async {
    final result = await _client.rpc(
      'restaurant_create_charity_donation',
      params: {
        'p_charity_id': charityId,
        'p_item_title': itemTitle.trim(),
        'p_description': description.trim(),
        'p_quantity': quantity,
        'p_item_condition': condition.trim(),
        'p_images': images,
      },
    );
    return _map(result);
  }

  Future<List<String>> uploadCharityDonationImages(List<XFile> images) async {
    final urls = <String>[];
    for (final image in images) {
      urls.add(await _imageStorage.uploadCharityDonationImage(image));
    }
    return urls;
  }

  // ✅ دالة تحديث حالة التبرع
  Future<Map<String, dynamic>> updateDonationStatus(
      String donationId, String status) async {
    try {
      print('📌 Updating donation status: $donationId -> $status');

      final result = await _client
          .from('restaurant_charity_donations')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', donationId)
          .select()
          .single();

      print('✅ Donation status updated to: $status');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('❌ Error updating donation status: $e');
      rethrow;
    }
  }

  // ✅ دالة تأكيد جاهزية التبرع
  Future<Map<String, dynamic>> markDonationReady(String donationId) async {
    try {
      return await updateDonationStatus(donationId, 'institution_ready');
    } catch (e) {
      print('❌ Error marking donation ready: $e');
      rethrow;
    }
  }

  // ✅ دالة إنشاء كود الاستلام
  Future<Map<String, dynamic>> generateDonationPickupCode(
      String donationId) async {
    try {
      print('📌 Generating pickup code for donation: $donationId');

      final result = await _client.rpc(
          'restaurant_generate_charity_donation_pickup_code',
          params: {'p_donation_id': donationId});

      await updateDonationStatus(donationId, 'code_generated');

      print('✅ Pickup code generated: $result');
      return _map(result);
    } catch (e) {
      print('❌ Error generating pickup code: $e');
      rethrow;
    }
  }

  // ✅ دالة التحقق من كود الاستلام
  Future<Map<String, dynamic>> verifyCharityDonationPickupCode(
      {required String donationId, required String code}) async {
    final value = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      throw const FormatException('كود الاستلام يجب أن يتكون من 6 أرقام');
    }
    final result = await _client.rpc(
        'restaurant_verify_charity_donation_pickup_code',
        params: {'p_donation_id': donationId, 'p_token': value});
    return _map(result);
  }

  static String? _firstImage(Map<String, dynamic> row) {
    for (final key in ['image_url', 'logo_url', 'logo', 'image']) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final images = row['images'];
    if (images is List) {
      for (final value in images) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('استجابة غير صالحة من الخادم');
  }
}
