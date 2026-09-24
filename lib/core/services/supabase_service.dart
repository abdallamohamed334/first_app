// lib/core/services/supabase_service.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../models/community_stats.dart';
import 'fcm_notification_service.dart';

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

  final FcmNotificationService _fcmNotifications = FcmNotificationService();

  SupabaseClient get client => Supabase.instance.client;
  SupabaseClient get adminClient => client;
  SupabaseClient get supabase => client;

  // ═══════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════
  Future<void> setAuthSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await client.auth.setSession(refreshToken);
      debugPrint('✅ Auth session set');
    } catch (e) {
      debugPrint('❌ setAuthSession error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    final userId = client.auth.currentUser?.id;
    try {
      if (userId != null && userId.isNotEmpty) {
        await deactivateCurrentFcmDevice(userId);
      }
    } catch (error) {
      debugPrint('[FCM] logout cleanup skipped: $error');
    }

    await _fcmNotifications.dispose();
    await _fcmNotifications.unregister();
    await client.auth.signOut(scope: SignOutScope.local);
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
  }

  // ═══════════════════════════════════════════════════════════
  // FCM DEVICES
  // ═══════════════════════════════════════════════════════════
  Future<void> initializeFcmForUser(
    String userId, {
    String? webVapidKey,
    FutureOr<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;

    try {
      await _fcmNotifications.dispose();
      await _fcmNotifications.initialize(
        webVapidKey: webVapidKey,
        onTokenChanged: (token) => upsertFcmDevice(
          userId: cleanUserId,
          fcmToken: token,
        ),
        onNotificationTap: onNotificationTap,
      );
      debugPrint('[FCM] initialized for authenticated user');
    } catch (error, stack) {
      debugPrint('[FCM] initialization skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> initializeFcmForCurrentUser({
    String? webVapidKey,
    FutureOr<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) return;

    await initializeFcmForUser(
      userId,
      webVapidKey: webVapidKey,
      onNotificationTap: onNotificationTap,
    );
  }

  String _currentDevicePlatform() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  Future<void> upsertFcmDevice({
    required String userId,
    required String fcmToken,
    String? deviceName,
    String? appVersion,
  }) async {
    final cleanUserId = userId.trim();
    final cleanToken = fcmToken.trim();
    if (cleanUserId.isEmpty || cleanToken.isEmpty) return;

    try {
      await client.from('user_devices').upsert(
        {
          'user_id': cleanUserId,
          'fcm_token': cleanToken,
          'platform': _currentDevicePlatform(),
          if (deviceName != null && deviceName.trim().isNotEmpty)
            'device_name': deviceName.trim(),
          if (appVersion != null && appVersion.trim().isNotEmpty)
            'app_version': appVersion.trim(),
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,fcm_token',
      );
      debugPrint('[FCM] device upserted for user=$cleanUserId');
    } catch (error, stack) {
      debugPrint('[FCM] device upsert failed: $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> deactivateCurrentFcmDevice(String userId) async {
    final token = await _readCurrentFcmTokenSafely();
    if (token == null || token.isEmpty) return;

    await client
        .from('user_devices')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId.trim())
        .eq('fcm_token', token);
  }

  Future<String?> _readCurrentFcmTokenSafely() async {
    try {
      return await _fcmNotifications.currentToken();
    } catch (error) {
      debugPrint('[FCM] current token unavailable: $error');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════
  Future<UserModel> createUser(Map<String, dynamic> data) async {
    try {
      final cleanData = Map<String, dynamic>.from(data);
      debugPrint('📌 Creating user');

      final response =
          await adminClient.from('users').insert(cleanData).select().single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      debugPrint('📌 Looking for user with id: $id');

      final response =
          await adminClient.from('users').select().eq('id', id).maybeSingle();

      if (response == null) {
        debugPrint('📌 No user found with id: $id');
        return null;
      }

      var user = UserModel.fromJson(response);
      final role = user.type.value.toLowerCase();

      if (role == 'provider') {
        try {
          final provider = await adminClient
              .from('service_providers')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

          if (provider != null) {
            user = user.copyWith(
              serviceProviderId: provider['id'] as String?,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Provider enrichment skipped: $e');
        }
      }

      if (role == 'institution') {
        try {
          final inst = await adminClient
              .from('institutions')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

          if (inst != null) {
            user = user.copyWith(
              institutionId: inst['id'] as String?,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Institution enrichment skipped: $e');
        }
      }

      return user;
    } catch (e) {
      debugPrint('❌ Error getting user by id: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    try {
      var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleaned.startsWith('0')) {
        cleaned = '20${cleaned.substring(1)}';
      } else if (cleaned.length == 10) {
        cleaned = '20$cleaned';
      }

      final response = await adminClient
          .from('users')
          .select()
          .eq('phone', cleaned)
          .maybeSingle();

      if (response == null) return null;

      return await getUserById(response['id'] as String);
    } catch (e) {
      debugPrint('❌ Error getting user by phone: $e');
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

      debugPrint('📌 User updated');
      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating user: $e');
      rethrow;
    }
  }

  Future<bool> userExistsByPhone(String phone) async {
    try {
      var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleaned.startsWith('0')) {
        cleaned = '20${cleaned.substring(1)}';
      } else if (cleaned.length == 10) {
        cleaned = '20$cleaned';
      }

      final response =
          await adminClient.from('users').select('id').eq('phone', cleaned);
      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUSINESS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getBusinessByUserId(String userId) async {
    try {
      return await adminClient
          .from('businesses')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting business: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBusinessById(String businessId) async {
    try {
      return await adminClient
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting business by id: $e');
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
      debugPrint('❌ Error getting businesses by type: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createBusiness(Map<String, dynamic> data) async {
    try {
      return await adminClient
          .from('businesses')
          .insert(data)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ Error creating business: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateBusiness(
    String businessId,
    Map<String, dynamic> data,
  ) async {
    try {
      return await adminClient
          .from('businesses')
          .update(data)
          .eq('id', businessId)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ Error updating business: $e');
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
      debugPrint('❌ Error getting business capabilities: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // USER STATS
  // ═══════════════════════════════════════════════════════════
  Future<int> getUserTotalPoints(String userId) async {
    try {
      final response = await adminClient
          .from('users')
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      return response?['points'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting user points: $e');
      return 0;
    }
  }

  Future<int> getUserLevel(String userId) async {
    try {
      final response = await adminClient
          .from('users')
          .select('level')
          .eq('id', userId)
          .maybeSingle();

      return response?['level'] as int? ?? 1;
    } catch (e) {
      debugPrint('❌ Error getting user level: $e');
      return 1;
    }
  }

  Future<int> getUserDeliveriesCount(String userId) async {
    try {
      final response = await adminClient
          .from('deliveries')
          .select('id')
          .eq('volunteer_id', userId)
          .eq('status', 'completed');

      return response.length;
    } catch (e) {
      debugPrint('❌ Error getting deliveries count: $e');
      return 0;
    }
  }

  Future<int> getUserMealsSaved(String userId) async {
    try {
      final response = await adminClient
          .from('donations')
          .select('id')
          .eq('donor_id', userId)
          .eq('status', 'completed');

      return response.length;
    } catch (e) {
      try {
        final response = await adminClient
            .from('rescued_meals')
            .select('id')
            .eq('user_id', userId);

        return response.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<int> getUserCompletedTasks(String userId) async {
    try {
      final response = await adminClient
          .from('deliveries')
          .select('id')
          .eq('volunteer_id', userId)
          .eq('status', 'completed');

      return response.length;
    } catch (e) {
      debugPrint('❌ Error getting completed tasks: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final userResponse = await adminClient
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userResponse == null) {
        return {
          'points': 0,
          'level': 1,
          'deliveriesCount': 0,
          'mealsSaved': 0,
          'tasksCompleted': 0,
        };
      }

      final points = userResponse['points'] as int? ?? 0;
      final level = userResponse['level'] as int? ?? 1;

      final deliveries = await getUserDeliveriesCount(userId);
      final mealsSaved = await getUserMealsSaved(userId);
      final tasksCompleted = await getUserCompletedTasks(userId);

      return {
        'points': points,
        'level': level,
        'deliveriesCount': deliveries,
        'mealsSaved': mealsSaved,
        'tasksCompleted': tasksCompleted,
      };
    } catch (e) {
      debugPrint('❌ Error getting user stats: $e');
      return {
        'points': 0,
        'level': 1,
        'deliveriesCount': 0,
        'mealsSaved': 0,
        'tasksCompleted': 0,
      };
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
      debugPrint('❌ Error getting user rewards: $e');
      return [];
    }
  }

  Future<void> addPoints({
    required String userId,
    required int points,
    required String reason,
    String? deliveryId,
  }) async {
    try {
      final current = await adminClient
          .from('users')
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      final currentPoints = current?['points'] as int? ?? 0;
      final newPoints = currentPoints + points;

      await adminClient.from('users').update({
        'points': newPoints,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      int newLevel = 1;
      if (newPoints >= 1000) {
        newLevel = 5;
      } else if (newPoints >= 500) {
        newLevel = 4;
      } else if (newPoints >= 200) {
        newLevel = 3;
      } else if (newPoints >= 50) {
        newLevel = 2;
      }

      await adminClient
          .from('users')
          .update({'level': newLevel}).eq('id', userId);

      debugPrint(
          '✅ Added $points points (total: $newPoints, level: $newLevel)');
    } catch (e) {
      debugPrint('❌ Error adding points: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FOOD OFFERS
  // ═══════════════════════════════════════════════════════════
  Future<void> _expireOverdueFoodOffers() async {
    try {
      await client.rpc('expire_overdue_food_offers');
    } catch (e) {
      debugPrint('⚠️ Expiry cleanup skipped: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFoodOffers() async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client.from('food_offers').select('''
          *,
          businesses:business_id (
            id, name, logo, address, phone, rating, latitude, longitude
          )
        ''').eq('status', 'available').order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('❌ getFoodOffers ERROR: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFoodOfferById(String id) async {
    await _expireOverdueFoodOffers();
    try {
      return await client.from('food_offers').select('''
            *,
            businesses:business_id (
              id, name, logo, address, phone, rating, description,
              latitude, longitude, business_type
            )
          ''').eq('id', id).maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting food offer: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getFoodOfferWithDetails(
    String offerId,
    String userId,
  ) async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client.from('food_offers').select('''
            *,
            businesses:business_id (
              id, name, logo, address, phone, rating, description,
              latitude, longitude, business_type
            )
          ''').eq('id', offerId).maybeSingle();

      if (response == null) return null;

      final requestCountResponse = await client
          .from('offer_requests')
          .select('id')
          .eq('offer_id', offerId)
          .filter('status', 'in', '("pending","accepted","ready_for_pickup")');

      response['request_count'] = requestCountResponse.length;
      response['interested_count'] = requestCountResponse.length;

      final userRequest = await client
          .from('offer_requests')
          .select('id, status')
          .eq('offer_id', offerId)
          .eq('user_id', userId)
          .maybeSingle();

      response['is_requested_by_user'] = userRequest != null;
      response['is_accepted'] =
          userRequest != null && userRequest['status'] == 'accepted';
      response['user_request_status'] = userRequest?['status'];

      return response;
    } catch (e) {
      debugPrint('❌ Error getting food offer with details: $e');
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
              id, name, logo, address, latitude, longitude, business_type
            )
          ''')
          .eq('status', 'available')
          .gt('expiry_time', now.toIso8601String())
          .lt('expiry_time', twoHoursLater.toIso8601String())
          .order('expiry_time', ascending: true)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting urgent food offers: $e');
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
      debugPrint('❌ Error getting nearby food offers: $e');
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
              id, name, logo, address, phone, rating, latitude, longitude, business_type
            )
          ''')
          .eq('status', 'available')
          .gt('expiry_time', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting offers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableOffersWithRequests(
      String userId) async {
    await _expireOverdueFoodOffers();
    try {
      final response = await client
          .from('food_offers')
          .select('''
            *,
            businesses:business_id (
              id, name, logo, address, phone, rating, latitude, longitude, business_type
            )
          ''')
          .eq('status', 'available')
          .gt('expiry_time', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> offers = [];

      for (var offer in response) {
        final offerId = offer['id'] as String;

        final requestCountResponse = await client
            .from('offer_requests')
            .select('id')
            .eq('offer_id', offerId)
            .filter(
                'status', 'in', '("pending","accepted","ready_for_pickup")');

        offer['request_count'] = requestCountResponse.length;
        offer['interested_count'] = requestCountResponse.length;

        final userRequest = await client
            .from('offer_requests')
            .select('id, status')
            .eq('offer_id', offerId)
            .eq('user_id', userId)
            .maybeSingle();

        offer['is_requested_by_user'] = userRequest != null;
        offer['is_accepted'] =
            userRequest != null && userRequest['status'] == 'accepted';
        offer['user_request_status'] = userRequest?['status'];

        offers.add(offer);
      }

      return offers;
    } catch (e) {
      debugPrint('❌ Error getting offers with requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOfferById(String id) async {
    await _expireOverdueFoodOffers();
    try {
      return await client.from('food_offers').select('''
            *,
            businesses:business_id (
              id, name, logo, address, phone, rating, latitude, longitude, business_type
            )
          ''').eq('id', id).maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting offer: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // OFFER REQUESTS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> acceptOfferRequest(String requestId) async {
    try {
      final request = await client
          .from('offer_requests')
          .select('offer_id, user_id, status')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null) throw Exception('الطلب غير موجود');
      if (request['status'] != 'pending') {
        throw Exception('لا يمكن قبول طلب غير معلق');
      }

      final offerId = request['offer_id'] as String;

      final updatedRequest = await client
          .from('offer_requests')
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
            'notified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();

      await client.from('food_offers').update({
        'status': 'reserved',
        'reserved_by': request['user_id'],
        'reserved_at': DateTime.now().toIso8601String(),
        'is_paused': true,
        'paused_at': DateTime.now().toIso8601String(),
        'paused_reason': 'تم قبول طلب استلام',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', offerId);

      return updatedRequest;
    } catch (e) {
      debugPrint('❌ acceptOfferRequest error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rejectOfferRequest(String requestId) async {
    try {
      final request = await client
          .from('offer_requests')
          .select('offer_id, user_id')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null) throw Exception('الطلب غير موجود');

      return await client
          .from('offer_requests')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ rejectOfferRequest error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelOfferRequest(String requestId) async {
    try {
      final request = await client
          .from('offer_requests')
          .select('offer_id, status')
          .eq('id', requestId)
          .maybeSingle();

      if (request == null) throw Exception('الطلب غير موجود');

      final offerId = request['offer_id'] as String;
      final wasAccepted = request['status'] == 'accepted';

      final cancelledRequest = await client
          .from('offer_requests')
          .update({
            'status': 'cancelled',
            'cancellation_reason': 'تم الإلغاء من قبل العميل',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();

      if (wasAccepted) {
        await client.from('food_offers').update({
          'status': 'available',
          'reserved_by': null,
          'reserved_at': null,
          'is_paused': false,
          'paused_at': null,
          'paused_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', offerId);
      }

      return cancelledRequest;
    } catch (e) {
      debugPrint('❌ cancelOfferRequest error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getOfferRequestsForBusiness(
    String businessId,
    String offerId,
  ) async {
    try {
      final response = await client
          .from('offer_requests')
          .select('''
            *,
            users (id, name, phone, avatar_url)
          ''')
          .eq('offer_id', offerId)
          .eq('food_offers.business_id', businessId)
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ getOfferRequestsForBusiness error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserOfferRequest(
    String offerId,
    String userId,
  ) async {
    try {
      return await client
          .from('offer_requests')
          .select()
          .eq('offer_id', offerId)
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ getUserOfferRequest error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBusinessAllOfferRequests(
      String businessId) async {
    try {
      final response = await client
          .from('offer_requests')
          .select('''
            *,
            users (id, name, phone, avatar_url),
            food_offers!inner (
              id, title, quantity, pickup_location, expiry_time, business_id,
              businesses:business_id (id, name, logo, address, phone)
            )
          ''')
          .eq('food_offers.business_id', businessId)
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ getBusinessAllOfferRequests error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COMMUNITY STATS
  // ═══════════════════════════════════════════════════════════
  Future<CommunityStats> getCommunityStats() async {
    try {
      int mealsSaved = 0;
      try {
        final donationsResponse = await client
            .from('donations')
            .select('quantity')
            .eq('status', 'completed');
        for (var donation in donationsResponse) {
          mealsSaved += donation['quantity'] as int? ?? 1;
        }
      } catch (_) {
        mealsSaved = 0;
      }

      int activeVolunteers = 0;
      try {
        final volunteersResponse = await client
            .from('users')
            .select('id')
            .eq('role', 'user')
            .eq('is_active', true);
        activeVolunteers = volunteersResponse.length;
      } catch (_) {
        activeVolunteers = 0;
      }

      int participatingRestaurants = 0;
      try {
        final restaurantsResponse = await client
            .from('restaurants')
            .select('id')
            .eq('status', 'active');
        participatingRestaurants = restaurantsResponse.length;
      } catch (_) {
        participatingRestaurants = 0;
      }

      int beneficiaryCharities = 0;
      try {
        final charitiesResponse =
            await client.from('charities').select('id').eq('status', 'active');
        beneficiaryCharities = charitiesResponse.length;
      } catch (_) {
        beneficiaryCharities = 0;
      }

      return CommunityStats(
        mealsSaved: mealsSaved,
        activeVolunteers: activeVolunteers,
        participatingRestaurants: participatingRestaurants,
        beneficiaryCharities: beneficiaryCharities,
      );
    } catch (e) {
      debugPrint('❌ Error getting community stats: $e');
      return const CommunityStats();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DELIVERIES
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> createDelivery(Map<String, dynamic> data) async {
    return await client.from('deliveries').insert(data).select().single();
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
      debugPrint('❌ Error getting deliveries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> updateDeliveryStatus(
    String id,
    String status,
  ) async {
    try {
      return await client
          .from('deliveries')
          .update({'status': status})
          .eq('id', id)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ Error updating delivery: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
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
      debugPrint('❌ Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      await client.from('notifications').update({'is_read': true}).eq('id', id);
    } catch (e) {
      debugPrint('❌ Error marking notification: $e');
    }
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'is_read': false,
        'data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final response = await client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> registerCurrentDevice() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return;

      final fcmToken = await _fcmNotifications.currentToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final deviceName = await _getDeviceName();
      final appVersion = await _getAppVersion();

      await upsertFcmDevice(
        userId: user.id,
        fcmToken: fcmToken,
        deviceName: deviceName,
        appVersion: appVersion,
      );
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (kIsWeb) return 'Web Browser';
      return Platform.localHostname;
    } catch (e) {
      return Platform.operatingSystem;
    }
  }

  Future<String> _getAppVersion() async {
    return '1.0.0';
  }

  // ═══════════════════════════════════════════════════════════
  // CHARITIES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getCharities() async {
    try {
      final response = await adminClient
          .from('charities')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('❌ Error getting charities: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCharityById(String id) async {
    try {
      return await adminClient
          .from('charities')
          .select()
          .eq('id', id)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting charity: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // RESTAURANTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getRestaurants() async {
    try {
      final response =
          await adminClient.from('restaurants').select().eq('status', 'active');
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('❌ Error getting restaurants: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRestaurantById(String id) async {
    try {
      return await adminClient
          .from('restaurants')
          .select()
          .eq('id', id)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting restaurant: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════
  Future<UserModel> updateProfile({
    required String userId,
    required String name,
    String? phone,
    String? city,
    String? address,
    String? avatarUrl,
    double? lat, // ✅
    double? lng, // ✅
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
      // ✅ بنحفظ في latitude/longitude (الأعمدة الموجودة أصلاً)
      if (lat != null) data['latitude'] = lat;
      if (lng != null) data['longitude'] = lng;

      final response = await adminClient
          .from('users')
          .update(data)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
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

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // OFFER REQUESTS (create / update)
  // ═══════════════════════════════════════════════════════════
  Future<String?> _resolveRestaurantIdFromBusinessId(String businessId) async {
    final normalized = businessId.trim();
    if (normalized.isEmpty) return null;

    final business = await client
        .from('businesses')
        .select('user_id')
        .eq('id', normalized)
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

      return await client
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
    } catch (e) {
      debugPrint('❌ Error creating offer request: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getOfferRequestByUser({
    required String offerId,
    required String userId,
  }) async {
    try {
      return await client
          .from('offer_requests')
          .select()
          .eq('offer_id', offerId)
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error getting offer request: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserOfferRequests(String userId) async {
    try {
      final response = await client.from('offer_requests').select('''
            *,
            restaurants:restaurant_id (id, name, logo, address, phone),
            food_offers:offer_id (
              id, title, description, quantity, food_type, expiry_time,
              pickup_before, pickup_location, image, images, status, business_id,
              businesses:business_id (id, name, logo, address, phone)
            )
          ''').eq('user_id', userId).order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting user requests: $e');
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
            users (id, name, phone, avatar_url),
            food_offers!inner (
              id, title, quantity, pickup_location, expiry_time, business_id,
              businesses:business_id (id, name, logo, address, phone)
            )
          ''')
          .eq('food_offers.business_id', businessId)
          .eq('status', 'pending')
          .order('requested_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting business requests: $e');
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
            users (id, name, phone, avatar_url),
            food_offers!inner (
              id, title, quantity, pickup_location, expiry_time, business_id,
              businesses:business_id (id, name, logo, address, phone)
            )
          ''')
          .eq('food_offers.business_id', businessId)
          .order('requested_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting business requests: $e');
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
      debugPrint('❌ Error updating offer request status: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // OFFERS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> createOffer(Map<String, dynamic> data) async {
    try {
      return await adminClient
          .from('food_offers')
          .insert(data)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ createOffer error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> updateOffer(
    String offerId,
    Map<String, dynamic> data,
  ) async {
    try {
      return await adminClient
          .from('food_offers')
          .update(data)
          .eq('id', offerId)
          .select()
          .single();
    } catch (e) {
      debugPrint('❌ updateOffer error: $e');
      rethrow;
    }
  }

  Future<void> deleteOffer(String offerId) async {
    try {
      await adminClient.from('food_offers').delete().eq('id', offerId);
    } catch (e) {
      debugPrint('❌ deleteOffer error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION
  // ═══════════════════════════════════════════════════════════
  Future<Session?> getCurrentSession() async {
    try {
      return client.auth.currentSession;
    } catch (e) {
      debugPrint('❌ getCurrentSession error: $e');
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

  // ═══════════════════════════════════════════════════════════
  // FILTERED OFFERS
  // ═══════════════════════════════════════════════════════════
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
      debugPrint('❌ getAvailableOffersFiltered error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COMMUNITY OFFERS (images)
  // ═══════════════════════════════════════════════════════════
  Future<String?> getCommunityOfferImage(String offerId) async {
    try {
      final response = await client
          .from('community_offers')
          .select('image')
          .eq('id', offerId)
          .maybeSingle();

      return response?['image']?.toString();
    } catch (e) {
      debugPrint('❌ Error getting community offer image: $e');
      return null;
    }
  }

  Future<List<String>> getCommunityOfferImages(String offerId) async {
    try {
      final response = await client
          .from('community_offers')
          .select('images')
          .eq('id', offerId)
          .maybeSingle();

      if (response == null) return [];

      final images = response['images'] as List? ?? [];
      return images
          .map((url) => url.toString())
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting community offer images: $e');
      return [];
    }
  }

  Future<String?> getCommunityOfferPrimaryImageUrl(String offerId) async {
    try {
      final image = await getCommunityOfferImage(offerId);
      if (image == null || image.isEmpty) return null;
      return _buildCommunityImageUrl(image);
    } catch (e) {
      debugPrint('❌ Error getting community offer primary image URL: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCommunityOfferWithImages(
      String offerId) async {
    try {
      final response = await client
          .from('community_offers')
          .select()
          .eq('id', offerId)
          .maybeSingle();

      if (response == null) return null;

      final images = await getCommunityOfferImages(offerId);
      final primaryImage = await getCommunityOfferImage(offerId);

      response['images_list'] = images;
      response['primary_image'] = primaryImage;
      response['image_url'] = _buildCommunityImageUrl(primaryImage ?? '');

      return response;
    } catch (e) {
      debugPrint('❌ Error getting community offer with images: $e');
      return null;
    }
  }

  String _buildCommunityImageUrl(String imagePath) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (imagePath.startsWith('file:///')) {
      return '';
    }

    const baseUrl =
        'https://gsrhoqdtcyfdmvgahqvl.supabase.co/storage/v1/object/public/community-offers/';
    return '$baseUrl$imagePath';
  }

  Future<List<Map<String, dynamic>>> getOfferMedia(String offerId) async {
    try {
      final response = await adminClient
          .from('institution_offer_media')
          .select()
          .eq('offer_id', offerId)
          .order('sort_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting offer media: $e');
      return [];
    }
  }

  Future<String?> getOfferPrimaryImage(String offerId) async {
    try {
      final response = await adminClient
          .from('institution_offer_media')
          .select('public_url')
          .eq('offer_id', offerId)
          .eq('is_primary', true)
          .maybeSingle();

      return response?['public_url']?.toString();
    } catch (e) {
      debugPrint('❌ Error getting primary image: $e');
      return null;
    }
  }

  Future<List<String>> getOfferImages(String offerId) async {
    try {
      final response = await adminClient
          .from('institution_offer_media')
          .select('public_url')
          .eq('offer_id', offerId)
          .order('sort_order', ascending: true);

      return response
          .map((item) => item['public_url'].toString())
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting offer images: $e');
      return [];
    }
  }
}
