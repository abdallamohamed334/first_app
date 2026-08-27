// lib/core/services/supabase_service.dart

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/community_stats.dart';

class RewardData {
  final String id;
  final String title;
  final String description;
  final int pointsRequired;
  final String? imageUrl;
  final bool isActive;

  const RewardData({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    this.imageUrl,
    this.isActive = true,
  });

  factory RewardData.fromJson(Map<String, dynamic> json) {
    return RewardData(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      pointsRequired: json['points_required'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'points_required': pointsRequired,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // لا تضع Service Role Key داخل تطبيق Flutter.
  // هذا getter مؤقت للتوافق البرمجي فقط، ويستخدم عميل المستخدم.
  // العمليات الإدارية يجب نقلها لاحقًا إلى Edge Functions أو RPC آمنة.
  SupabaseClient get adminClient => client;

  // ============ AUTH ============

  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<Session?> signIn(String email, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.session;
    } catch (e) {
      print('❌ SignIn error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
  }

  Future<void> updatePasswordInAuth(String email, String newPassword) async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول قبل تغيير كلمة المرور');
      }

      if (newPassword.trim().length < 6) {
        throw Exception('كلمة المرور يجب أن تحتوي على 6 أحرف على الأقل');
      }

      // التغيير يتم عبر Supabase Auth للمستخدم الحالي فقط.
      // لا نبحث عن مستخدم بالبريد من الهاتف، ولا نخزن كلمة المرور في public.users.
      await client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );

      print('✅ Auth password updated for user: ${currentUser.id}');
    } catch (e) {
      print('❌ Error updating Auth password: $e');
      rethrow;
    }
  }

  Future<void> saveOtp(String email, String code) async {
    try {
      await client.from('otp_codes').insert({
        'email': email,
        'code': code,
        'is_used': false,
        'expires_at':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      });
      print('✅ OTP saved for $email');
    } catch (e) {
      print('❌ Error saving OTP: $e');
      rethrow;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    try {
      print('📌 Verifying OTP for $email: $code');

      final response = await client
          .from('otp_codes')
          .select()
          .eq('email', email)
          .eq('code', code)
          .eq('is_used', false)
          .maybeSingle();

      if (response == null) {
        print('❌ OTP not found or already used');
        return false;
      }

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        print('❌ OTP expired');
        await client.from('otp_codes').delete().eq('id', response['id']);
        return false;
      }

      await client
          .from('otp_codes')
          .update({'is_used': true}).eq('id', response['id']);
      print('✅ OTP verified successfully');
      return true;
    } catch (e) {
      print('❌ OTP verification error: $e');
      return false;
    }
  }

  String generateOtp() {
    final random = String.fromCharCodes(
      List.generate(6, (_) => 48 + (DateTime.now().microsecond % 10)),
    );
    return random;
  }

  // ============ USERS ============

  Future<UserModel> createUser(Map<String, dynamic> data) async {
    try {
      final cleanData = Map<String, dynamic>.from(data);
      print('📌 Creating user with data: $cleanData');

      final response =
          await adminClient.from('users').insert(cleanData).select().single();

      print('📌 User created: $response');
      return UserModel.fromJson(response);
    } catch (e) {
      print('❌ Error creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      print('📌 Looking for user with email: $email');

      final response = await adminClient
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        print('📌 No user found with email: $email');
        return null;
      }

      print('📌 User found: $response');
      var user = UserModel.fromJson(response);

      // ✅ جلب businessId من جدول businesses
      final userType = user.type.value.toLowerCase();
      if (userType == 'restaurant' ||
          userType == 'business' ||
          userType == 'hotel' ||
          userType == 'supermarket' ||
          userType == 'bakery' ||
          userType == 'cafe') {
        final businessResponse = await adminClient
            .from('businesses')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (businessResponse != null) {
          final businessId = businessResponse['id'] as String;
          print('📌 Found business ID: $businessId');
          user = user.copyWith(
            businessId: businessId,
            restaurantId: businessId,
          );
        } else {
          print('⚠️ No business found for user: ${user.id}');
        }
      }

      // ✅ جلب charityId لو كان جمعية
      if (userType == 'charity') {
        final charityResponse = await adminClient
            .from('charities')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (charityResponse != null) {
          final charityId = charityResponse['id'] as String;
          print('📌 Found charity ID: $charityId');
          user = user.copyWith(charityId: charityId);
        }
      }

      return user;
    } catch (e) {
      print('❌ Error getting user by email: $e');
      return null;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      print('📌 Looking for user with id: $id');

      final response =
          await adminClient.from('users').select().eq('id', id).maybeSingle();

      if (response == null) {
        print('📌 No user found with id: $id');
        return null;
      }

      print('📌 User found: $response');
      var user = UserModel.fromJson(response);

      // ✅ جلب businessId
      final userType = user.type.value.toLowerCase();
      if (userType == 'restaurant' ||
          userType == 'business' ||
          userType == 'hotel' ||
          userType == 'supermarket' ||
          userType == 'bakery' ||
          userType == 'cafe') {
        final businessResponse = await adminClient
            .from('businesses')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (businessResponse != null) {
          final businessId = businessResponse['id'] as String;
          print('📌 Found business ID: $businessId');
          user = user.copyWith(
            businessId: businessId,
            restaurantId: businessId,
          );
        }
      }

      // ✅ جلب charityId
      if (userType == 'charity') {
        final charityResponse = await adminClient
            .from('charities')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (charityResponse != null) {
          final charityId = charityResponse['id'] as String;
          print('📌 Found charity ID: $charityId');
          user = user.copyWith(charityId: charityId);
        }
      }

      return user;
    } catch (e) {
      print('❌ Error getting user by id: $e');
      return null;
    }
  }

  Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    try {
      final response = await adminClient
          .from('users')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      print('📌 User updated: $response');
      return UserModel.fromJson(response);
    } catch (e) {
      print('❌ Error updating user: $e');
      rethrow;
    }
  }

  Future<bool> userExistsByEmail(String email) async {
    try {
      final response =
          await adminClient.from('users').select('id').eq('email', email);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> userExistsByPhone(String phone) async {
    try {
      final response =
          await adminClient.from('users').select('id').eq('phone', phone);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============ BUSINESS ============

  Future<Map<String, dynamic>?> getBusinessByUserId(String userId) async {
    try {
      final response = await adminClient
          .from('businesses')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting business by user id: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessById(String businessId) async {
    try {
      final response = await adminClient
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting business by id: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBusinessesByType(String type) async {
    try {
      final response = await adminClient
          .from('businesses')
          .select()
          .eq('business_type', type)
          .eq('status', 'active')
          .order('rating', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting businesses by type: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createBusiness(Map<String, dynamic> data) async {
    try {
      final response =
          await adminClient.from('businesses').insert(data).select().single();

      return response;
    } catch (e) {
      print('❌ Error creating business: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateBusiness(
    String businessId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await adminClient
          .from('businesses')
          .update(data)
          .eq('id', businessId)
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error updating business: $e');
      rethrow;
    }
  }

  Future<List<String>> getBusinessCapabilities(String businessType) async {
    try {
      final response = await adminClient
          .from('business_capabilities')
          .select('capability')
          .eq('business_type', businessType)
          .eq('is_enabled', true);

      return List<String>.from(response.map((e) => e['capability'] as String));
    } catch (e) {
      print('❌ Error getting business capabilities: $e');
      return [];
    }
  }

  // ============ USER STATS ============

  Future<int> getUserTotalPoints(String userId) async {
    try {
      final response = await adminClient
          .from('reward_points')
          .select('points')
          .eq('user_id', userId);

      int total = 0;
      if (response.isNotEmpty) {
        for (var item in response) {
          total += (item['points'] as int? ?? 0);
        }
      }
      return total;
    } catch (e) {
      print('❌ Error getting user points: $e');
      return 0;
    }
  }

  Future<int> getUserDeliveriesCount(String userId) async {
    try {
      final response = await adminClient
          .from('deliveries')
          .select('id')
          .eq('volunteer_id', userId)
          .eq('status', 'delivered');

      return response.length ?? 0;
    } catch (e) {
      print('❌ Error getting deliveries count: $e');
      return 0;
    }
  }

  Future<int> getUserMealsSaved(String userId) async {
    try {
      final deliveries = await adminClient
          .from('deliveries')
          .select('offer_id')
          .eq('volunteer_id', userId)
          .eq('status', 'delivered');

      if (deliveries.isEmpty) return 0;

      int totalMeals = 0;
      for (var delivery in deliveries) {
        final offer = await adminClient
            .from('food_offers')
            .select('quantity')
            .eq('id', delivery['offer_id'])
            .maybeSingle();
        if (offer != null) {
          totalMeals += (offer['quantity'] as int? ?? 0);
        }
      }
      return totalMeals;
    } catch (e) {
      print('❌ Error getting meals saved: $e');
      return 0;
    }
  }

  Future<int> getUserCompletedTasks(String userId) async {
    try {
      final response = await adminClient
          .from('deliveries')
          .select('id')
          .eq('volunteer_id', userId)
          .eq('status', 'delivered');

      return response.length ?? 0;
    } catch (e) {
      print('❌ Error getting completed tasks: $e');
      return 0;
    }
  }

  Future<List<RewardData>> getUserRewards(String userId) async {
    try {
      final points = await getUserTotalPoints(userId);

      final rewardsResponse = await adminClient
          .from('rewards')
          .select()
          .eq('is_active', true)
          .order('points_required', ascending: true);

      if (rewardsResponse.isEmpty) return [];

      final rewards = <RewardData>[];
      for (var item in rewardsResponse) {
        final reward = RewardData.fromJson(item);
        if (points >= reward.pointsRequired) {
          rewards.add(reward);
        }
      }
      return rewards;
    } catch (e) {
      print('❌ Error getting user rewards: $e');
      return [];
    }
  }

  Future<UserStats> getUserStats(String userId) async {
    try {
      final deliveriesResponse = await client
          .from('deliveries')
          .select('id, food_offers(quantity)')
          .eq('volunteer_id', userId)
          .eq('status', 'delivered');

      final tasksCompleted = deliveriesResponse.length ?? 0;

      int mealsSaved = 0;
      if (deliveriesResponse.isNotEmpty) {
        for (var delivery in deliveriesResponse) {
          final offerData = delivery['food_offers'] as Map<String, dynamic>?;
          if (offerData != null) {
            mealsSaved += offerData['quantity'] as int? ?? 0;
          }
        }
      }

      final pointsResponse = await client
          .from('reward_points')
          .select('points')
          .eq('user_id', userId);

      int totalPoints = 0;
      for (var point in pointsResponse) {
        totalPoints += point['points'] as int? ?? 0;
      }

      return UserStats(
        mealsSaved: mealsSaved,
        tasksCompleted: tasksCompleted,
        points: totalPoints,
      );
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return const UserStats();
    }
  }

  // ============ FOOD OFFERS ============

  Future<void> _expireOverdueFoodOffers() async {
    try {
      await client.rpc('expire_overdue_food_offers');
    } catch (e) {
      // لا نمنع عرض البيانات إذا كانت دالة التنظيف غير متاحة مؤقتًا.
      print('⚠️ Expiry cleanup skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFoodOffers() async {
    await _expireOverdueFoodOffers();
    try {
      print('📌🔴 getFoodOffers: START');

      final response = await client.from('food_offers').select('''
          *,
          businesses:business_id (
            id,
            name,
            logo,
            address,
            phone,
            rating,
            latitude,
            longitude
          )
        ''').eq('status', 'available').order('created_at', ascending: false);

      print('📌🔴 getFoodOffers: response length = ${response.length ?? 0}');

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('❌🔴 getFoodOffers ERROR: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFoodOfferById(String id) async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client.from('food_offers').select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              phone,
              rating,
              description,
              latitude,
              longitude,
              business_type
            )
          ''').eq('id', id).maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting food offer: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUrgentFoodOffers() async {
    await _expireOverdueFoodOffers();
    try {
      final now = DateTime.now();
      final twoHoursLater = now.add(const Duration(hours: 2));

      final response = await client
          .from('food_offers')
          .select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              latitude,
              longitude,
              business_type
            )
          ''')
          .eq('status', 'available')
          .gt('expiry_time', now.toIso8601String())
          .lt('expiry_time', twoHoursLater.toIso8601String())
          .order('expiry_time', ascending: true)
          .limit(10);

      print('📌 Urgent food offers found: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting urgent food offers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyFoodOffers(
    double lat,
    double lng, {
    double radius = 10,
  }) async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client.rpc('get_nearby_offers', params: {
        'lat': lat,
        'lng': lng,
        'radius_km': radius,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('❌ Error getting nearby food offers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableOffers() async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client
          .from('food_offers')
          .select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              phone,
              rating,
              latitude,
              longitude,
              business_type
            )
          ''')
          .eq('status', 'available')
          .gt('expiry_time', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting offers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOfferById(String id) async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client.from('food_offers').select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              phone,
              rating,
              latitude,
              longitude,
              business_type
            )
          ''').eq('id', id).maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting offer: $e');
      return null;
    }
  }

  // ============ COMMUNITY STATS ============

  Future<CommunityStats> getCommunityStats() async {
    try {
      final deliveriesResponse = await client
          .from('deliveries')
          .select('id, food_offers(quantity)')
          .eq('status', 'delivered');

      int mealsSaved = 0;
      for (var delivery in deliveriesResponse) {
        final offerData = delivery['food_offers'] as Map<String, dynamic>?;
        if (offerData != null) {
          mealsSaved += offerData['quantity'] as int? ?? 0;
        }
      }

      final volunteersResponse = await client
          .from('users')
          .select('id')
          .eq('user_type', 'user')
          .eq('is_active', true);

      final restaurantsResponse =
          await client.from('restaurants').select('id').eq('status', 'active');

      final charitiesResponse =
          await client.from('charities').select('id').eq('status', 'active');

      return CommunityStats(
        mealsSaved: mealsSaved,
        activeVolunteers: volunteersResponse.length ?? 0,
        participatingRestaurants: restaurantsResponse.length ?? 0,
        beneficiaryCharities: charitiesResponse.length ?? 0,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error getting community stats: $e');
      return CommunityStats(lastUpdated: DateTime.now());
    }
  }

  // ============ DELIVERIES ============

  Future<Map<String, dynamic>> createDelivery(Map<String, dynamic> data) async {
    final response =
        await client.from('deliveries').insert(data).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getDeliveriesByVolunteer(
      String volunteerId) async {
    try {
      final response = await client
          .from('deliveries')
          .select('*, food_offers(*), charities(*)')
          .eq('volunteer_id', volunteerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting deliveries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> updateDeliveryStatus(
    String id,
    String status,
  ) async {
    try {
      final response = await client
          .from('deliveries')
          .update({'status': status})
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      print('❌ Error updating delivery: $e');
      return null;
    }
  }

  // ============ NOTIFICATIONS ============

  Future<List<Map<String, dynamic>>> getNotificationsByUser(
      String userId) async {
    try {
      final response = await client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      await client.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      print('❌ Error marking notification: $e');
    }
  }

  // ============ REWARD POINTS ============

  Future<void> addPoints({
    required String userId,
    required int points,
    required String reason,
    String? deliveryId,
  }) async {
    try {
      await client.from('reward_points').insert({
        'user_id': userId,
        'points': points,
        'reason': reason,
        'delivery_id': deliveryId,
      });

      await client.rpc('add_user_points', params: {
        'user_id': userId,
        'points_to_add': points,
      });
    } catch (e) {
      print('❌ Error adding points: $e');
    }
  }

  // ============ CHARITIES ============

  Future<List<Map<String, dynamic>>> getCharities() async {
    try {
      print('📌 Getting charities from database...');

      final response = await adminClient
          .from('charities')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      print('📌 Charities found: ${response.length ?? 0}');
      print('📌 Response: $response');

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('❌ Error getting charities: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCharityById(String id) async {
    try {
      final response = await adminClient
          .from('charities')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting charity: $e');
      return null;
    }
  }

  // ============ RESTAURANTS ============

  Future<List<Map<String, dynamic>>> getRestaurants() async {
    try {
      final response =
          await adminClient.from('restaurants').select().eq('status', 'active');
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      print('❌ Error getting restaurants: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRestaurantById(String id) async {
    try {
      final response = await adminClient
          .from('restaurants')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting restaurant: $e');
      return null;
    }
  }

  // ============ PROFILE ============

  Future<UserModel> updateProfile({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? address,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (phone != null && phone.isNotEmpty) data['phone'] = phone;
      if (city != null && city.isNotEmpty) data['city'] = city;
      if (address != null && address.isNotEmpty) data['address'] = address;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        data['avatar_url'] = avatarUrl;
      }

      final response = await adminClient
          .from('users')
          .update(data)
          .eq('id', userId)
          .select()
          .single();

      print('✅ Profile updated: $response');
      return UserModel.fromJson(response);
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }

  Future<String> uploadAvatar(String userId, String imagePath) async {
    try {
      final fileName =
          'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.png';

      final file = File(imagePath);

      await adminClient.storage.from('avatars').upload(fileName, file);

      final publicUrl =
          adminClient.storage.from('avatars').getPublicUrl(fileName);

      await adminClient
          .from('users')
          .update({'avatar_url': publicUrl}).eq('id', userId);

      print('✅ Avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  // ============ OFFER REQUESTS ============

  Future<String?> _resolveRestaurantIdFromBusinessId(
    String businessId,
  ) async {
    final normalizedBusinessId = businessId.trim();
    if (normalizedBusinessId.isEmpty) return null;

    final business = await client
        .from('businesses')
        .select('user_id')
        .eq('id', normalizedBusinessId)
        .maybeSingle();

    final ownerId = business?['user_id']?.toString();
    if (ownerId == null || ownerId.isEmpty) return null;

    final restaurant = await client
        .from('restaurants')
        .select('id')
        .eq('user_id', ownerId)
        .maybeSingle();

    return restaurant?['id']?.toString();
  }

  Future<Map<String, dynamic>> createOfferRequest({
    required String offerId,
    required String userId,
    required String businessId,
  }) async {
    try {
      final restaurantId = await _resolveRestaurantIdFromBusinessId(businessId);

      if (restaurantId == null || restaurantId.isEmpty) {
        throw Exception('لا يوجد مطعم مرتبط بهذا العرض');
      }

      final response = await client
          .from('offer_requests')
          .insert({
            'offer_id': offerId,
            'user_id': userId,
            'restaurant_id': restaurantId,
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ Error creating offer request: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getOfferRequestByUser({
    required String offerId,
    required String userId,
  }) async {
    try {
      final response = await client
          .from('offer_requests')
          .select()
          .eq('offer_id', offerId)
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error getting offer request: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserOfferRequests(String userId) async {
    try {
      final response = await client.from('offer_requests').select('''
            *,
            restaurants:restaurant_id (
              id,
              name,
              logo,
              address,
              phone
            ),
            food_offers:offer_id (
              id,
              title,
              description,
              quantity,
              food_type,
              expiry_time,
              pickup_before,
              pickup_location,
              image,
              images,
              status,
              business_id,
              businesses:business_id (
                id,
                name,
                logo,
                address,
                phone
              )
            )
          ''').eq('user_id', userId).order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting user requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBusinessOfferRequests(
      String businessId) async {
    try {
      final response = await client
          .from('offer_requests')
          .select('''
            *,
            users (
              id,
              name,
              phone,
              avatar_url
            ),
            food_offers!inner (
              id,
              title,
              quantity,
              pickup_location,
              expiry_time,
              business_id,
              businesses:business_id (
                id,
                name,
                logo,
                address,
                phone
              )
            )
          ''')
          .eq('food_offers.business_id', businessId)
          .eq('status', 'pending')
          .order('requested_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting business requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllBusinessOfferRequests(
      String businessId) async {
    try {
      final response = await client
          .from('offer_requests')
          .select('''
            *,
            users (
              id,
              name,
              phone,
              avatar_url
            ),
            food_offers!inner (
              id,
              title,
              quantity,
              pickup_location,
              expiry_time,
              business_id,
              businesses:business_id (
                id,
                name,
                logo,
                address,
                phone
              )
            )
          ''')
          .eq('food_offers.business_id', businessId)
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting business requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateOfferRequestStatus({
    required String requestId,
    required String status,
  }) async {
    try {
      final response = await client.rpc(
        'update_food_offer_request_status',
        params: {
          'p_request_id': requestId,
          'p_next_status': status,
        },
      );

      if (response is! Map) {
        throw Exception('استجابة غير صالحة من قاعدة البيانات');
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('❌ Error updating offer request status: $e');
      rethrow;
    }
  }

  // ============ OFFERS ============

  Future<Map<String, dynamic>?> createOffer(Map<String, dynamic> data) async {
    try {
      final response =
          await adminClient.from('food_offers').insert(data).select().single();

      return response;
    } catch (e) {
      print('❌ createOffer error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateOffer(
    String offerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await adminClient
          .from('food_offers')
          .update(data)
          .eq('id', offerId)
          .select()
          .single();

      return response;
    } catch (e) {
      print('❌ updateOffer error: $e');
      rethrow;
    }
  }

  Future<void> deleteOffer(String offerId) async {
    try {
      await adminClient.from('food_offers').delete().eq('id', offerId);
    } catch (e) {
      print('❌ deleteOffer error: $e');
      rethrow;
    }
  }

  // ============ SESSION ============

  Future<Session?> getCurrentSession() async {
    try {
      final session = client.auth.currentSession;
      return session;
    } catch (e) {
      print('❌ getCurrentSession error: $e');
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final session = await getCurrentSession();
      return session != null;
    } catch (e) {
      return false;
    }
  }

  // ============ FILTERED OFFERS ============

  Future<List<Map<String, dynamic>>> getAvailableOffersFiltered({
    String? city,
    String? foodType,
  }) async {
    try {
      var query = adminClient
          .from('food_offers')
          .select('*, restaurants!inner(*)')
          .eq('status', 'available')
          .gt('expiry_time', DateTime.now().toIso8601String());

      if (city != null && city.isNotEmpty) {
        query = query.eq('restaurants.city', city);
      }
      if (foodType != null && foodType.isNotEmpty) {
        query = query.eq('food_type', foodType);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ getAvailableOffersFiltered error: $e');
      return [];
    }
  }
}
