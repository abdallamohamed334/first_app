// lib/features/institutions/data/repositories/institutions_repository.dart

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

import '../../domain/entities/institution.dart';
import '../../domain/entities/institution_offer.dart';

class InstitutionsRepository {
  final SupabaseClient _client;

  InstitutionsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  // ============================================================
  // ✅ حساب أيام الصلاحية المتبقية
  // ============================================================

  int _calculateDaysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return 999;

    final now = DateTime.now();
    final diff = expiryDate.difference(now).inDays;

    return diff.clamp(-1, 999);
  }

  // ============================================================
  // ✅ جلب العروض من institution_offers
  // ============================================================

  Future<List<Map<String, dynamic>>> getOffersWithStatus(
    String institutionId,
  ) async {
    try {
      final response = await _client
          .from('institution_offers')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''')
          .eq('institution_id', institutionId)
          .order('created_at', ascending: false);

      final offers = _maps(response);

      for (var offer in offers) {
        final expiryDate = offer['expires_at'] != null
            ? DateTime.tryParse(
                offer['expires_at'].toString(),
              )
            : null;

        final daysLeft = _calculateDaysUntilExpiry(expiryDate);

        offer['days_until_expiry'] = daysLeft;

        if (daysLeft < 0) {
          offer['expiry_status'] = 'expired';
          offer['status'] = 'expired';
        } else if (daysLeft <= 3) {
          offer['expiry_status'] = 'expiring_soon';
        } else {
          offer['expiry_status'] = 'fresh';
        }
      }

      return offers;
    } catch (e) {
      print('❌ Error getting offers with status: $e');
      return [];
    }
  }

  // ============================================================
  // ✅ جلب العروض العامة
  // ============================================================

  Future<List<Map<String, dynamic>>> listPublicOffers() async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        print('⚠️ listPublicOffers: no authenticated user');
        return [];
      }

      // ------------------------------------------------------------
      // 📍 موقع المستخدم من users
      // لا نستخدم موقع الجهاز مباشرة هنا؛ مصدر الحقيقة هو users.
      // ------------------------------------------------------------
      final userRow = await _client
          .from('users')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) {
        print('⚠️ listPublicOffers: users row not found');
        return [];
      }

      final userLatitude = _asDouble(userRow['latitude']);
      final userLongitude = _asDouble(userRow['longitude']);

      if (userLatitude == null || userLongitude == null) {
        print(
          '⚠️ listPublicOffers: user location is missing '
          '(latitude/longitude)',
        );
        return [];
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // ------------------------------------------------------------
      // 🏪 موقع العرض الحقيقي موجود في institutions
      // وليس institution_offers.latitude/longitude
      // ------------------------------------------------------------
      final rows = await _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone,
              latitude,
              longitude
            )
          ''').eq('status', 'active').gt('expires_at', now);

      final offers = _maps(rows);

      // ------------------------------------------------------------
      // 📏 عرض المؤسسات الموجودة داخل 10 كم فقط
      // ------------------------------------------------------------
      final nearbyOffers = <Map<String, dynamic>>[];

      for (final offer in offers) {
        if (offer['status']?.toString() != 'active') {
          continue;
        }

        if (_asInt(offer['remaining_quantity']) <= 0) {
          continue;
        }

        final institution = offer['institutions'];

        if (institution is! Map) {
          continue;
        }

        final institutionMap = Map<String, dynamic>.from(institution);

        final institutionLatitude = _asDouble(institutionMap['latitude']);
        final institutionLongitude = _asDouble(institutionMap['longitude']);

        // المؤسسة بدون موقع لا يمكن حساب بعدها بأمان.
        if (institutionLatitude == null || institutionLongitude == null) {
          continue;
        }

        final distanceMeters = _distanceInMeters(
          userLatitude,
          userLongitude,
          institutionLatitude,
          institutionLongitude,
        );

        // الحد الأقصى = 10 كم
        if (distanceMeters > 10000) {
          continue;
        }

        // إضافة المسافة للـ UI لو احتاجت تعرض "على بعد X كم".
        final result = Map<String, dynamic>.from(offer);
        result['distance_meters'] = distanceMeters;
        result['distance_km'] =
            double.parse((distanceMeters / 1000).toStringAsFixed(2));

        nearbyOffers.add(result);
      }

      // الأقرب أولًا، ثم الأحدث.
      nearbyOffers.sort((a, b) {
        final distanceA = _asDouble(a['distance_meters']) ?? double.infinity;
        final distanceB = _asDouble(b['distance_meters']) ?? double.infinity;

        final distanceCompare = distanceA.compareTo(distanceB);

        if (distanceCompare != 0) {
          return distanceCompare;
        }

        final createdA = DateTime.tryParse(
          a['created_at']?.toString() ?? '',
        );

        final createdB = DateTime.tryParse(
          b['created_at']?.toString() ?? '',
        );

        if (createdA == null && createdB == null) return 0;
        if (createdA == null) return 1;
        if (createdB == null) return -1;

        return createdB.compareTo(createdA);
      });

      print(
        '📍 listPublicOffers: '
        'user=($userLatitude,$userLongitude) '
        'all=${offers.length} '
        'nearby=${nearbyOffers.length} '
        'radius=10km',
      );

      return nearbyOffers;
    } on PostgrestException catch (error) {
      print(
        '❌ listPublicOffers Postgrest error: '
        '${error.code} ${error.message}',
      );
      return [];
    } catch (e) {
      print('❌ listPublicOffers error: $e');
      return [];
    }
  }

  // ============================================================
  // ✅ جلب عروض المؤسسة
  // ============================================================

  Future<List<Map<String, dynamic>>> listMyOffers(
    String institutionId,
  ) async {
    final cleanInstitutionId = institutionId.trim();

    if (cleanInstitutionId.isEmpty) {
      throw const FormatException(
        'معرف المؤسسة غير موجود',
      );
    }

    try {
      final rows = await _client
          .from('institution_offers')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''')
          .eq(
            'institution_id',
            cleanInstitutionId,
          )
          .order(
            'created_at',
            ascending: false,
          );

      return _maps(rows);
    } catch (e) {
      print('❌ listMyOffers error: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ جلب عرض معين
  // ============================================================

  Future<InstitutionOffer?> getOfferById(
    String offerId,
  ) async {
    try {
      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        return null;
      }

      final row = await _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('id', cleanOfferId).maybeSingle();

      if (row == null) {
        return null;
      }

      return InstitutionOffer.fromJson(
        Map<String, dynamic>.from(row),
      );
    } catch (e) {
      print('❌ getOfferById error: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ جلب طلبات المؤسسة
  // ============================================================

  Future<List<Map<String, dynamic>>> listOfferRequestsForInstitution(
    String institutionId,
  ) async {
    final cleanInstitutionId = institutionId.trim();

    if (cleanInstitutionId.isEmpty) {
      throw const FormatException(
        'معرف المؤسسة غير موجود',
      );
    }

    final offerRows = await _client
        .from('institution_offers')
        .select(
          'id, title, description, category, expires_at, status',
        )
        .eq(
          'institution_id',
          cleanInstitutionId,
        );

    final offers = _maps(offerRows);

    final offersById = <String, Map<String, dynamic>>{
      for (final offer in offers)
        if (offer['id'] != null) offer['id'].toString(): offer,
    };

    final offerIds = offersById.keys.toList(
      growable: false,
    );

    print(
      '[InstitutionDebug] request-list '
      'institutionId=$cleanInstitutionId '
      'ownedOffers=${offerIds.length}',
    );

    if (offerIds.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    List<Map<String, dynamic>> requestRows;

    try {
      final response = await _client
          .from('institution_offer_requests')
          .select('''
            *,
            users!requester_id (
              id,
              name,
              phone,
              avatar_url,
              city,
              points,
              level,
              email
            )
          ''')
          .inFilter(
            'offer_id',
            offerIds,
          )
          .order(
            'created_at',
            ascending: false,
          );

      requestRows = _maps(response);
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] users relation skipped: '
        '${error.code} ${error.message}',
      );

      final response = await _client
          .from('institution_offer_requests')
          .select('*')
          .inFilter(
            'offer_id',
            offerIds,
          )
          .order(
            'created_at',
            ascending: false,
          );

      requestRows = _maps(response);
    }

    print(
      '[InstitutionDebug] request-list '
      'rows=${requestRows.length}',
    );

    return requestRows.map((request) {
      final result = Map<String, dynamic>.from(
        request,
      );

      final offerId = result['offer_id']?.toString();

      final offer = offerId == null ? null : offersById[offerId];

      if (offer != null) {
        result['institution_offers'] = offer;
      }

      return result;
    }).toList(growable: false);
  }

  // ============================================================
  // ✅ إنشاء عرض (معدل مع صلاحية 12 ساعة وتحسينات)
  // ============================================================

  Future<Map<String, dynamic>> createOffer({
    required String institutionId,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required double symbolicPrice,
    double? originalPrice,
    required List<String> images,
    String? pickupLocation,
    required DateTime expiresAt,
    DateTime? pickupBefore,
    String foodType = 'وجبات',
    bool isHalal = true,
    bool isVegetarian = false,
    String foodCondition = 'good',
    bool requiresRefrigeration = false,
    String pickupNotes = '',
    String contactPhone = '',
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    if (institutionId.trim().isEmpty) {
      throw const FormatException(
        'معرف المؤسسة غير موجود. أعد فتح صفحة المؤسسة',
      );
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw const FormatException(
        'اكتب اسم العرض',
      );
    }

    if (quantity <= 0) {
      throw const FormatException(
        'الكمية يجب أن تكون أكبر من صفر',
      );
    }

    if (symbolicPrice < 0) {
      throw const FormatException(
        'السعر الرمزي يجب أن يكون أكبر من أو يساوي صفر',
      );
    }

    // ✅ التحقق من السعر الأصلي
    if (originalPrice != null && originalPrice < 0) {
      throw const FormatException(
        'السعر الأصلي يجب أن يكون أكبر من أو يساوي صفر',
      );
    }

    // ✅ التحقق من أن السعر الرمزي لا يتجاوز السعر الأصلي
    if (originalPrice != null && symbolicPrice > originalPrice) {
      throw FormatException(
        'السعر الرمزي ($symbolicPrice ج.م) لا يمكن أن يكون أكبر من السعر الأصلي ($originalPrice ج.م)',
      );
    }

    final ownedInstitution = await _client
        .from('institutions')
        .select('id, status')
        .eq(
          'id',
          institutionId.trim(),
        )
        .eq(
          'user_id',
          userId,
        )
        .maybeSingle();

    if (ownedInstitution == null) {
      throw const FormatException(
        'هذه المؤسسة غير مرتبطة بحساب الدخول الحالي',
      );
    }

    if (ownedInstitution['status']?.toString() != 'active') {
      throw const FormatException(
        'حساب المؤسسة غير نشط حاليًا',
      );
    }

    // ✅ استخدام RPC بدلاً من insert المباشر
    try {
      print(
        '[InstitutionDebug] CREATE OFFER '
        'institutionId=${institutionId.trim()} '
        'userId=$userId '
        'quantity=$quantity '
        'symbolicPrice=$symbolicPrice '
        'originalPrice=$originalPrice',
      );

      final result = await _client.rpc(
        'create_institution_offer',
        params: {
          'p_institution_id': institutionId.trim(),
          'p_title': cleanTitle,
          'p_description':
              description.trim().isEmpty ? null : description.trim(),
          'p_category': category.trim().isEmpty ? 'other' : category.trim(),
          'p_quantity': quantity,
          'p_original_price': originalPrice,
          'p_symbolic_price': symbolicPrice,
          'p_images': images,
          'p_pickup_location': pickupLocation?.trim().isEmpty == true
              ? null
              : pickupLocation?.trim(),
          'p_expires_at': expiresAt.toUtc().toIso8601String(),
          'p_pickup_start': null,
          'p_pickup_end': pickupBefore?.toUtc().toIso8601String(),
          'p_food_type': foodType,
          'p_is_halal': isHalal,
          'p_is_vegetarian': isVegetarian,
          'p_food_condition': foodCondition,
          'p_requires_refrigeration': requiresRefrigeration,
          'p_pickup_notes':
              pickupNotes.trim().isEmpty ? null : pickupNotes.trim(),
          'p_contact_phone':
              contactPhone.trim().isEmpty ? null : contactPhone.trim(),
          'p_pickup_time': null,
        },
      );

      print(
        '[InstitutionDebug] CREATE OFFER '
        'response=$result',
      );

      if (result == null) {
        throw const FormatException(
          'لم يتم إنشاء العرض',
        );
      }

      final offerId = result.toString().trim();

      if (offerId.isEmpty) {
        throw const FormatException(
          'لم يتم استلام معرف العرض من الخادم',
        );
      }

      print(
        '[InstitutionDebug] '
        '✅ OFFER CREATED '
        'offerId=$offerId',
      );

      // ✅ جلب العرض المنشأ بالكامل
      final createdOffer = await _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('id', offerId).single();

      return Map<String, dynamic>.from(createdOffer);
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] CREATE OFFER '
        'code=${error.code}',
      );

      print(
        '[InstitutionDebug] CREATE OFFER '
        'message=${error.message}',
      );

      print(
        '[InstitutionDebug] CREATE OFFER '
        'details=${error.details}',
      );

      // ✅ تحويل رسائل الخطأ من PostgreSQL إلى رسائل مفهومة
      final message = error.message.toLowerCase();
      if (message.contains('symbolic price cannot exceed original price')) {
        throw const FormatException(
          'السعر الرمزي لا يمكن أن يكون أكبر من السعر الأصلي\n'
          'يرجى تعديل السعر الأصلي أو السعر الرمزي',
        );
      }
      if (message.contains('expires_at')) {
        throw const FormatException(
          'صلاحية العرض لا تتجاوز 12 ساعة من الآن',
        );
      }
      if (message.contains('already reserved')) {
        throw const FormatException(
          'لا يمكن تعديل العرض لأنه تم حجز جزء منه بالفعل',
        );
      }
      if (message.contains('institution not found') ||
          message.contains('المؤسسة غير موجودة')) {
        throw const FormatException(
          'المؤسسة غير موجودة أو غير نشطة',
        );
      }

      rethrow;
    } catch (error) {
      print(
        '[InstitutionDebug] CREATE OFFER '
        'error=$error',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ تحديث العرض
  // ============================================================

  Future<void> updateOffer({
    required String offerId,
    String? title,
    String? description,
    String? category,
    int? quantity,
    int? remainingQuantity,
    double? symbolicPrice,
    double? originalPrice,
    List<String>? images,
    String? pickupLocation,
    DateTime? expiresAt,
    DateTime? pickupBefore,
    String? status,
    String? foodType,
    bool? isHalal,
    bool? isVegetarian,
    String? foodCondition,
    bool? requiresRefrigeration,
    String? pickupNotes,
    String? contactPhone,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (title != null) {
        data['title'] = title.trim();
      }

      if (description != null) {
        data['description'] = description.trim();
      }

      if (category != null) {
        data['category'] = category;
      }

      if (quantity != null) {
        data['quantity'] = quantity;
      }

      if (remainingQuantity != null) {
        data['remaining_quantity'] = remainingQuantity;
      }

      if (symbolicPrice != null) {
        data['symbolic_price'] = symbolicPrice;
      }

      if (originalPrice != null) {
        data['original_price'] = originalPrice;
      }

      if (images != null) {
        data['images'] = images;
      }

      if (pickupLocation != null) {
        data['pickup_location'] = pickupLocation.trim();
      }

      if (expiresAt != null) {
        data['expires_at'] = expiresAt.toUtc().toIso8601String();
      }

      if (pickupBefore != null) {
        data['pickup_before'] = pickupBefore.toUtc().toIso8601String();
      }

      if (status != null) {
        data['status'] = status;
      }

      if (foodType != null) {
        data['food_type'] = foodType;
      }

      if (isHalal != null) {
        data['is_halal'] = isHalal;
      }

      if (isVegetarian != null) {
        data['is_vegetarian'] = isVegetarian;
      }

      if (foodCondition != null) {
        data['food_condition'] = foodCondition;
      }

      if (requiresRefrigeration != null) {
        data['requires_refrigeration'] = requiresRefrigeration;
      }

      if (pickupNotes != null) {
        data['pickup_notes'] = pickupNotes.trim();
      }

      if (contactPhone != null) {
        data['contact_phone'] = contactPhone.trim();
      }

      data.removeWhere(
        (key, value) => value == null || (value is String && value.isEmpty),
      );

      await _client.from('institution_offers').update(data).eq('id', offerId);
    } catch (e) {
      throw Exception(
        'فشل تحديث العرض: $e',
      );
    }
  }

  // ============================================================
  // ✅ جلب المؤسسة الخاصة
  // ============================================================

  Future<Institution> getMine() async {
    final authUser = _client.auth.currentUser;
    final userId = authUser?.id;

    print(
      '[InstitutionDebug] auth.uid=${userId ?? 'null'}',
    );

    print(
      '[InstitutionDebug] auth.email=${authUser?.email ?? 'null'}',
    );

    if (userId == null || userId.isEmpty) {
      print(
        '[InstitutionDebug] STOP: no active auth session',
      );

      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    try {
      final userRow = await _client
          .from('users')
          .select(
            'id, user_type, is_active',
          )
          .eq(
            'id',
            userId,
          )
          .maybeSingle();

      print(
        '[InstitutionDebug] users row='
        '${userRow == null ? 'NULL' : 'FOUND'}',
      );

      if (userRow != null) {
        print(
          '[InstitutionDebug] '
          'users.user_type=${userRow['user_type']}',
        );

        print(
          '[InstitutionDebug] '
          'users.is_active=${userRow['is_active']}',
        );
      }

      final rows = await _client
          .from('institutions')
          .select()
          .eq(
            'user_id',
            userId,
          )
          .order(
            'created_at',
            ascending: true,
          )
          .limit(2);

      print(
        '[InstitutionDebug] '
        'institutions rows=${rows.length}',
      );

      if (rows.isNotEmpty) {
        final first = Map<String, dynamic>.from(
          rows.first as Map,
        );

        print(
          '[InstitutionDebug] '
          'institution.id=${first['id']}',
        );

        print(
          '[InstitutionDebug] '
          'institution.name=${first['name']}',
        );

        print(
          '[InstitutionDebug] '
          'institution_type=${first['institution_type']}',
        );

        print(
          '[InstitutionDebug] '
          'institution.status=${first['status']}',
        );
      }

      if (rows.isEmpty) {
        throw const FormatException(
          'لا توجد مؤسسة مرتبطة بهذا الحساب',
        );
      }

      return Institution.fromJson(
        Map<String, dynamic>.from(
          rows.first as Map,
        ),
      );
    } on FormatException {
      print(
        '[InstitutionDebug] FORMAT: '
        'no institution match or invalid session',
      );

      rethrow;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        'POSTGREST code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        'POSTGREST message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        'POSTGREST details=${error.details}',
      );

      throw FormatException(
        _friendlyInstitutionError(error),
      );
    } catch (error) {
      print(
        '[InstitutionDebug] UNKNOWN error=$error',
      );

      throw const FormatException(
        'تعذر الاتصال ببيانات المؤسسة حاليًا',
      );
    }
  }

  // ============================================================
  // ✅ تحديث المؤسسة
  // ============================================================

  Future<Institution> updateMine({
    String? name,
    String? institutionType,
    String? phone,
    String? city,
    String? address,
    String? description,
    String? logoUrl,
    String? coverImageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    final data = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    void put(
      String key,
      String? value,
    ) {
      if (value != null) {
        data[key] = value.trim();
      }
    }

    put('name', name);
    put('institution_type', institutionType);
    put('phone', phone);
    put('city', city);
    put('address', address);
    put('description', description);
    put('logo_url', logoUrl);
    put('cover_image_url', coverImageUrl);

    final row = await _client
        .from('institutions')
        .update(data)
        .eq(
          'user_id',
          userId,
        )
        .select()
        .single();

    return Institution.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  // ============================================================
  // ✅ رفع صورة المؤسسة
  // ============================================================

  Future<String> uploadInstitutionImage({
    required Uint8List bytes,
    required String fileExtension,
    bool cover = false,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    final safeExtension = fileExtension.replaceAll('.', '').toLowerCase();

    final path = '$userId/'
        '${cover ? 'cover' : 'logo'}_'
        '${DateTime.now().millisecondsSinceEpoch}'
        '.$safeExtension';

    await _client.storage.from('institution-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$safeExtension',
          ),
        );

    return _client.storage.from('institution-images').getPublicUrl(path);
  }

  // ============================================================
  // ✅ جلب عروض المؤسسة كـ Entities
  // ============================================================

  Future<List<InstitutionOffer>> listPublicOfferEntities() async {
    final rows = await listPublicOffers();

    return rows.map(InstitutionOffer.fromJson).toList(growable: false);
  }

  Future<List<InstitutionOffer>> listMyOfferEntities(
    String institutionId,
  ) async {
    final rows = await listMyOffers(
      institutionId,
    );

    return rows.map(InstitutionOffer.fromJson).toList(growable: false);
  }

  // ============================================================
  // ✅ إنشاء كود استلام طلب المؤسسة
  // ============================================================

  Future<Map<String, dynamic>> generateOfferRequestPickupCode(
    String requestId,
  ) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    try {
      final result = await _client.rpc(
        'institution_generate_offer_request_pickup_code',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      print(
        '[InstitutionDebug] '
        'generate pickup response=$result',
      );

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw FormatException(
          response['message']?.toString() ?? 'تعذر إنشاء كود الاستلام',
        );
      }

      return response;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        'generate pickup code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        'generate pickup message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        'generate pickup details=${error.details}',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ التحقق من كود الاستلام
  // ============================================================

  Future<Map<String, dynamic>> verifyOfferRequestPickupCode({
    required String requestId,
    required String code,
  }) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    // ----------------------------------------------------------
    // تنظيف الكود
    // ----------------------------------------------------------

    var cleanCode = code.trim();

    // تحويل الأرقام العربية إلى إنجليزية
    cleanCode = cleanCode
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');

    // إزالة أي شيء غير الأرقام
    cleanCode = cleanCode.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // ----------------------------------------------------------
    // لازم يكون 6 أرقام بالضبط
    // ----------------------------------------------------------

    if (cleanCode.length != 6) {
      throw const FormatException(
        'كود الاستلام يجب أن يتكون من 6 أرقام',
      );
    }

    try {
      print(
        '[InstitutionDebug] VERIFY PICKUP '
        'requestId=$cleanRequestId '
        'codeLength=${cleanCode.length}',
      );

      // --------------------------------------------------------
      // استدعاء RPC
      // --------------------------------------------------------

      final result = await _client.rpc(
        'institution_verify_offer_request_pickup_code',
        params: {
          'p_request_id': cleanRequestId,
          'p_code': cleanCode,
        },
      );

      print(
        '[InstitutionDebug] VERIFY PICKUP '
        'rawResponse=$result',
      );

      // --------------------------------------------------------
      // التأكد أن الاستجابة Map
      // --------------------------------------------------------

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      final success = response['success'] == true;

      final status = response['status']?.toString();

      print(
        '[InstitutionDebug] VERIFY PICKUP '
        'success=$success '
        'status=$status',
      );

      // --------------------------------------------------------
      // النجاح الحقيقي
      // --------------------------------------------------------

      if (!success) {
        throw FormatException(
          response['message']?.toString() ?? 'كود الاستلام غير صحيح',
        );
      }

      if (status != 'picked_up') {
        throw const FormatException(
          'تم التحقق من الكود ولكن لم يتم تحديث حالة الطلب',
        );
      }

      print(
        '[InstitutionDebug] '
        '✅ PICKUP VERIFIED '
        'requestId=$cleanRequestId '
        'status=picked_up',
      );

      return response;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        '❌ VERIFY PICKUP '
        'code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        '❌ VERIFY PICKUP '
        'message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        '❌ VERIFY PICKUP '
        'details=${error.details}',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ إكمال طلب المؤسسة
  // ============================================================

  Future<Map<String, dynamic>> completeOfferRequest(
    String requestId,
  ) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    try {
      final result = await _client.rpc(
        'institution_complete_offer_request',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      print(
        '[InstitutionDebug] '
        'complete request response=$result',
      );

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw FormatException(
          response['message']?.toString() ?? 'تعذر إكمال الطلب',
        );
      }

      return response;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        'complete request code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        'complete request message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        'complete request details=${error.details}',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ تجهيز الطلب للاستلام
  // ============================================================

  Future<Map<String, dynamic>> markOfferRequestReady(
    String requestId,
  ) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    try {
      final result = await _client.rpc(
        'institution_mark_offer_request_ready',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      print(
        '[InstitutionDebug] '
        'ready request response=$result',
      );

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw FormatException(
          response['message']?.toString() ?? 'تعذر تجهيز الطلب للاستلام',
        );
      }

      if (response['status'] != 'ready_for_pickup') {
        throw const FormatException(
          'لم يتم تحديث الطلب إلى جاهز للاستلام',
        );
      }

      return response;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        'ready request code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        'ready request message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        'ready request details=${error.details}',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ قبول / رفض طلب
  // ============================================================

  Future<Map<String, dynamic>> updateOfferRequest({
    required String requestId,
    required bool accept,
  }) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    try {
      print(
        '[InstitutionDebug] UPDATE REQUEST '
        'requestId=$cleanRequestId '
        'accept=$accept',
      );

      final result = await _client.rpc(
        'institution_update_offer_request',
        params: {
          'p_request_id': cleanRequestId,
          'p_accept': accept,
        },
      );

      print(
        '[InstitutionDebug] UPDATE REQUEST '
        'response=$result',
      );

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw FormatException(
          response['message']?.toString() ?? 'تعذر تحديث حالة الطلب',
        );
      }

      final expectedStatus = accept ? 'accepted' : 'rejected';

      if (response['status'] != expectedStatus) {
        throw FormatException(
          'لم يتم تحديث الطلب إلى الحالة المطلوبة: '
          '$expectedStatus',
        );
      }

      print(
        '[InstitutionDebug] '
        '✅ UPDATE REQUEST SUCCESS '
        'requestId=$cleanRequestId '
        'status=${response['status']}',
      );

      return response;
    } on PostgrestException catch (error) {
      print(
        '[InstitutionDebug] '
        '❌ UPDATE REQUEST '
        'code=${error.code}',
      );

      print(
        '[InstitutionDebug] '
        '❌ UPDATE REQUEST '
        'message=${error.message}',
      );

      print(
        '[InstitutionDebug] '
        '❌ UPDATE REQUEST '
        'details=${error.details}',
      );

      rethrow;
    }
  }

  // ============================================================
  // ✅ دوال الجمعيات الخيرية
  // ============================================================

  Future<List<Map<String, dynamic>>> listActiveCharities() async {
    final rows = await _client
        .from('charities')
        .select(
          'id, name, logo, image_url, logo_url, '
          'address, description',
        )
        .eq(
          'status',
          'active',
        )
        .eq(
          'is_verified',
          true,
        )
        .order('name');

    return _maps(rows);
  }

  Future<List<Map<String, dynamic>>> listMyCharityDonations(
    String institutionId,
  ) async {
    final rows = await _client
        .from('institution_charity_donations')
        .select(
          '*, charities(id, name, logo, image_url, logo_url)',
        )
        .eq(
          'institution_id',
          institutionId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return _maps(rows);
  }

  Future<Map<String, dynamic>> createCharityDonation({
    required String institutionId,
    required String charityId,
    required String itemTitle,
    required String description,
    required int quantity,
    required String itemCondition,
    required List<String> images,
  }) async {
    final cleanTitle = itemTitle.trim();

    if (cleanTitle.isEmpty) {
      throw const FormatException(
        'اكتب اسم التبرع',
      );
    }

    if (quantity <= 0) {
      throw const FormatException(
        'الكمية يجب أن تكون أكبر من صفر',
      );
    }

    final row = await _client
        .from('institution_charity_donations')
        .insert({
          'institution_id': institutionId,
          'charity_id': charityId,
          'item_title': cleanTitle,
          'description': description.trim(),
          'quantity': quantity,
          'item_condition': itemCondition.trim(),
          'images': images,
          'status': 'pending',
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> acceptDonation({
    required String donationId,
    required bool accept,
  }) async {
    return _rpcMap(
      'institution_accept_charity_donation',
      {
        'p_donation_id': donationId,
        'p_accept': accept,
      },
    );
  }

  Future<Map<String, dynamic>> assignVolunteer({
    required String donationId,
    required String volunteerId,
    required String volunteerName,
    required String volunteerPhone,
  }) async {
    return _rpcMap(
      'institution_assign_charity_volunteer',
      {
        'p_donation_id': donationId,
        'p_volunteer_id': volunteerId,
        'p_volunteer_name': volunteerName.trim(),
        'p_volunteer_phone': volunteerPhone.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> markReady(
    String donationId,
  ) async {
    return _rpcMap(
      'institution_mark_ready',
      {
        'p_donation_id': donationId,
      },
    );
  }

  Future<Map<String, dynamic>> markVolunteerDeparted(
    String donationId,
  ) async {
    return _rpcMap(
      'institution_mark_volunteer_departed',
      {
        'p_donation_id': donationId,
      },
    );
  }

  Future<Map<String, dynamic>> generatePickupCode(
    String donationId,
  ) async {
    return _rpcMap(
      'institution_generate_pickup_code',
      {
        'p_donation_id': donationId,
      },
    );
  }

  Future<Map<String, dynamic>> verifyPickupCode({
    required String donationId,
    required String code,
  }) async {
    return _rpcMap(
      'institution_verify_pickup_code',
      {
        'p_donation_id': donationId,
        'p_code': code.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> confirmArrival(
    String donationId,
  ) async {
    return _rpcMap(
      'institution_confirm_arrival',
      {
        'p_donation_id': donationId,
      },
    );
  }

  // ============================================================
  // ✅ دوال الإشعارات
  // ============================================================

  Future<List<Map<String, dynamic>>> listMyNotifications() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    final institution = await _client
        .from('institutions')
        .select('id')
        .eq(
          'user_id',
          userId,
        )
        .maybeSingle();

    final institutionId = institution?['id']?.toString();

    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException(
        'لا توجد مؤسسة مرتبطة بهذا الحساب',
      );
    }

    final rows = await _client
        .from('institution_notifications')
        .select()
        .eq(
          'institution_id',
          institutionId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return _maps(rows);
  }

  Future<int> countUnreadNotifications() async {
    final rows = await listMyNotifications();

    return rows
        .where(
          (row) => row['is_read'] != true,
        )
        .length;
  }

  Future<void> markNotificationAsRead(
    String notificationId,
  ) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    final institution = await _client
        .from('institutions')
        .select('id')
        .eq(
          'user_id',
          userId,
        )
        .maybeSingle();

    final institutionId = institution?['id']?.toString();

    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException(
        'لا توجد مؤسسة مرتبطة بهذا الحساب',
      );
    }

    await _client
        .from('institution_notifications')
        .update({
          'is_read': true,
        })
        .eq(
          'id',
          notificationId,
        )
        .eq(
          'institution_id',
          institutionId,
        );
  }

  Future<void> markAllNotificationsAsRead() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException(
        'يجب تسجيل الدخول أولًا',
      );
    }

    final institution = await _client
        .from('institutions')
        .select('id')
        .eq(
          'user_id',
          userId,
        )
        .maybeSingle();

    final institutionId = institution?['id']?.toString();

    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException(
        'لا توجد مؤسسة مرتبطة بهذا الحساب',
      );
    }

    await _client
        .from('institution_notifications')
        .update({
          'is_read': true,
        })
        .eq(
          'institution_id',
          institutionId,
        )
        .eq(
          'is_read',
          false,
        );
  }

  // ============================================================
  // ✅ دوال الشكاوى (Product Complaints)
  // ============================================================

  Future<void> addProductComplaint({
    required String offerId,
    required String complaintType,
    String? description,
    String? photoUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');

    final offer = await _client
        .from('institution_offers')
        .select('institution_id')
        .eq('id', offerId)
        .maybeSingle();

    if (offer == null) throw Exception('العرض غير موجود');

    await _client.from('product_complaints').insert({
      'offer_id': offerId,
      'user_id': user.id,
      'institution_id': offer['institution_id'],
      'complaint_type': complaintType,
      'description': description,
      'photo_url': photoUrl,
    });
  }

  Future<List<Map<String, dynamic>>> getMyComplaints() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('product_complaints')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getInstitutionComplaints(
    String institutionId,
  ) async {
    final rows = await _client
        .from('product_complaints')
        .select('*')
        .eq('institution_id', institutionId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
  }) async {
    if (!['resolved', 'rejected'].contains(status)) {
      throw Exception('حالة غير صحيحة');
    }

    await _client.from('product_complaints').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', complaintId);
  }

  // ============================================================
  // ✅ دوال مساعدة
  // ============================================================

  Future<Map<String, dynamic>> _rpcMap(
    String function,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(
      function,
      params: params,
    );

    if (result is Map) {
      return Map<String, dynamic>.from(
        result,
      );
    }

    throw const FormatException(
      'استجابة غير صالحة من الخادم',
    );
  }

  static List<Map<String, dynamic>> _maps(
    dynamic value,
  ) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (row) => Map<String, dynamic>.from(row),
        )
        .toList();
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed;
  }

  static double _distanceInMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;

    final lat1 = latitude1 * math.pi / 180.0;
    final lat2 = latitude2 * math.pi / 180.0;
    final deltaLat = (latitude2 - latitude1) * math.pi / 180.0;
    final deltaLon = (longitude2 - longitude1) * math.pi / 180.0;

    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);

    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;

    final clampedA = a.clamp(0.0, 1.0);

    final c = 2 *
        math.atan2(
          math.sqrt(clampedA),
          math.sqrt(1.0 - clampedA),
        );

    return earthRadiusMeters * c;
  }

  static int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _friendlyInstitutionError(
    PostgrestException error,
  ) {
    final text = '${error.code} ${error.message}'.toLowerCase();

    if (text.contains('permission') ||
        text.contains('row-level security') ||
        text.contains('rls')) {
      return 'لا توجد صلاحية لقراءة بيانات المؤسسة. '
          'راجع سياسة القراءة الخاصة بالمؤسسات.';
    }

    if (text.contains('column') || text.contains('does not exist')) {
      return 'بيانات المؤسسة غير متوافقة '
          'مع نسخة قاعدة البيانات الحالية.';
    }

    return 'تعذر تحميل بيانات المؤسسة حاليًا';
  }
}
