// lib/features/community/data/repositories/community_offer_repository.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityOfferRepository {
  final SupabaseClient _client;

  CommunityOfferRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  // ============================================================
  // CHARITIES
  // ============================================================

  /// ✅ استخدام `status` بدل `is_active`
  Future<List<Map<String, dynamic>>> getActiveCharities() async {
    try {
      final response = await _client
          .from('charities')
          .select()
          .eq('status', 'active')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('⚠️ getActiveCharities error: $error');
      }

      return <Map<String, dynamic>>[];
    }
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Future<List<Map<String, dynamic>>> getActiveCategories() async {
    final response = await _client
        .from('community_categories')
        .select(
          'id, slug, name_ar, name_en, description, parent_id, is_active, sort_order',
        )
        .eq('is_active', true)
        .order('sort_order')
        .order('name_ar');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    return getActiveCategories();
  }

  // ============================================================
  // CREATE OFFER
  // ============================================================

  Future<Map<String, dynamic>> createOffer({
    required String title,
    required String description,
    required String categoryId,
    required String categorySlug,
    required String listingType,
    required String itemCondition,
    required int quantity,
    required double price,
    required String pickupLocation,
    required List<XFile> images,
    DateTime? expiresAt,
    String? charityId,
    String? marketplaceCategoryId,
    List<Map<String, dynamic>> marketplaceAttributes = const [],
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا لإنشاء عرض');
    }

    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanCategoryId = categoryId.trim();
    final cleanCategorySlug = categorySlug.trim();
    final cleanLocation = pickupLocation.trim();

    final cleanMarketplaceCategoryId = marketplaceCategoryId?.trim();

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (cleanTitle.length < 3) {
      throw Exception(
        'عنوان العرض يجب أن يحتوي على 3 أحرف على الأقل',
      );
    }

    if (cleanDescription.length < 10) {
      throw Exception(
        'وصف العرض يجب أن يحتوي على 10 أحرف على الأقل',
      );
    }

    if (cleanCategoryId.isEmpty || cleanCategorySlug.isEmpty) {
      throw Exception(
        'يجب اختيار تصنيف صحيح للعرض',
      );
    }

    // ==========================================================
    // MARKETPLACE CATEGORY
    // ==========================================================

    if (cleanMarketplaceCategoryId == null ||
        cleanMarketplaceCategoryId.isEmpty) {
      throw Exception(
        'يجب اختيار تصنيف Marketplace صحيح للعرض',
      );
    }

    // ==========================================================
    // COMMUNITY = SYMBOLIC SALE ONLY
    // ==========================================================

    if (listingType != 'symbolic_sale') {
      throw Exception(
        'نوع العرض المسموح به هو البيع بسعر رمزي فقط',
      );
    }

    // ✅ القيم المسموحة للـ condition
    const allowedConditions = {
      'new',
      'used',
      'very_good',
      'good',
      'needs_repair',
    };

    if (!allowedConditions.contains(itemCondition)) {
      throw Exception(
        'حالة المنتج غير صحيحة',
      );
    }

    if (quantity <= 0) {
      throw Exception(
        'الكمية يجب أن تكون أكبر من صفر',
      );
    }

    if (price <= 0) {
      throw Exception(
        'السعر الرمزي يجب أن يكون أكبر من صفر',
      );
    }

    if (cleanLocation.isEmpty) {
      throw Exception(
        'يجب إدخال مكان الاستلام',
      );
    }

    if (charityId != null && charityId.trim().isNotEmpty) {
      throw Exception(
        'العرض الرمزي لا يمكن ربطه بجمعية',
      );
    }

    // ==========================================================
    // EXPIRY VALIDATION
    // ==========================================================

    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      throw Exception(
        'تاريخ انتهاء العرض يجب أن يكون في المستقبل',
      );
    }

    // ==========================================================
    // CLEAN MARKETPLACE ATTRIBUTES
    // ==========================================================

    final cleanMarketplaceAttributes = <Map<String, dynamic>>[];

    for (final attribute in marketplaceAttributes) {
      final attributeId = attribute['attribute_id']?.toString().trim();

      final optionId = attribute['option_id']?.toString().trim();

      if (attributeId == null ||
          attributeId.isEmpty ||
          optionId == null ||
          optionId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Skipping incomplete marketplace attribute: '
            'attribute_id="$attributeId", '
            'option_id="$optionId"',
          );
        }

        continue;
      }

      cleanMarketplaceAttributes.add({
        'attribute_id': attributeId,
        'option_id': optionId,
      });
    }

    // ==========================================================
    // REMOVE DUPLICATE ATTRIBUTES
    // ==========================================================

    final uniqueMarketplaceAttributes = <Map<String, dynamic>>[];

    final usedAttributeIds = <String>{};

    for (final attribute in cleanMarketplaceAttributes) {
      final attributeId = attribute['attribute_id']?.toString();

      if (attributeId == null || attributeId.isEmpty) {
        continue;
      }

      if (usedAttributeIds.contains(attributeId)) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Duplicate marketplace attribute skipped: '
            '$attributeId',
          );
        }

        continue;
      }

      usedAttributeIds.add(attributeId);
      uniqueMarketplaceAttributes.add(attribute);
    }

    if (kDebugMode) {
      debugPrint(
        '✅ Clean marketplace attributes: '
        '${uniqueMarketplaceAttributes.length}',
      );
    }

    // ==========================================================
    // UPLOAD IMAGES
    // ==========================================================

    final uploadedPaths = <String>[];

    try {
      for (final image in images) {
        final path = await _uploadImage(
          userId: authUser.id,
          image: image,
        );

        uploadedPaths.add(path);
      }

      // SIGN UPLOADED IMAGES
      final uploadedUrls = <String>[];

      for (final path in uploadedPaths) {
        final signedUrl = await _signedImageUrl(path);

        if (signedUrl != null) {
          uploadedUrls.add(signedUrl);
        }
      }

      // ========================================================
      // PAYLOAD
      // ========================================================

      final payload = <String, dynamic>{
        'owner_id': authUser.id,
        'charity_id': null,
        'title': cleanTitle,
        'description': cleanDescription,
        'category': cleanCategorySlug,
        'category_id': cleanCategoryId,
        'marketplace_category_id': cleanMarketplaceCategoryId,
        'listing_type': 'symbolic_sale',
        'item_condition': itemCondition,
        'quantity': quantity,
        'price': price,
        'image': uploadedUrls.isEmpty ? null : uploadedUrls.first,
        'images': uploadedUrls,
        'pickup_location': cleanLocation,
        'status': 'available',
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      };

      if (kDebugMode) {
        debugPrint('═══════════════════════════════');
        debugPrint('📤 Community Offer Payload:');

        payload.forEach((key, value) {
          debugPrint('   $key: $value');
        });

        debugPrint('═══════════════════════════════');
      }

      // ========================================================
      // INSERT COMMUNITY OFFER
      // ========================================================

      final response = await _client
          .from('community_offers')
          .insert(payload)
          .select()
          .single();

      final result = Map<String, dynamic>.from(response);

      final communityOfferId = result['id']?.toString();

      if (communityOfferId == null || communityOfferId.isEmpty) {
        throw Exception(
          'تم إنشاء العرض ولكن تعذر الحصول على رقم العرض',
        );
      }

      if (kDebugMode) {
        debugPrint(
          '✅ Community offer created: '
          '$communityOfferId',
        );
      }

      // ========================================================
      // MARKETPLACE ATTRIBUTES
      // ========================================================

      if (uniqueMarketplaceAttributes.isNotEmpty) {
        Map<String, dynamic>? marketplaceOffer;

        for (var attempt = 0; attempt < 3; attempt++) {
          marketplaceOffer = await _getMarketplaceOfferForCommunityOffer(
            communityOfferId,
          );

          if (marketplaceOffer != null) {
            break;
          }

          if (kDebugMode) {
            debugPrint(
              '⏳ Marketplace offer not ready, '
              'retrying... '
              '(attempt ${attempt + 1}/3)',
            );
          }

          if (attempt < 2) {
            await Future<void>.delayed(
              const Duration(milliseconds: 300),
            );
          }
        }

        final marketplaceOfferId = marketplaceOffer?['id']?.toString();

        if (marketplaceOfferId == null || marketplaceOfferId.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '❌ Marketplace offer row not found for '
              'community offer: $communityOfferId',
            );
          }

          throw Exception(
            'تعذر تجهيز العرض للـ Marketplace. '
            'حاول مرة أخرى.',
          );
        }

        if (kDebugMode) {
          debugPrint(
            '✅ Marketplace offer found: '
            '$marketplaceOfferId',
          );

          debugPrint(
            '📤 Saving '
            '${uniqueMarketplaceAttributes.length} '
            'marketplace attributes...',
          );
        }

        try {
          await _client.rpc(
            'upsert_marketplace_offer_attributes',
            params: {
              'p_marketplace_offer_id': marketplaceOfferId,
              'p_attributes': uniqueMarketplaceAttributes,
            },
          );

          if (kDebugMode) {
            debugPrint('✅ Marketplace attributes saved');
          }
        } catch (rpcError) {
          if (kDebugMode) {
            debugPrint(
              '❌ Failed to save marketplace attributes: '
              '$rpcError',
            );
          }

          throw Exception(
            'تعذر حفظ مواصفات المنتج. '
            'لم يتم إنشاء العرض بشكل كامل.',
          );
        }
      }

      // ========================================================
      // NORMALIZE RESULT
      // ========================================================

      final normalized = await _withSignedImageUrls(result);

      return normalized;
    } catch (error) {
      // ========================================================
      // CLEANUP UPLOADED FILES
      // ========================================================

      if (uploadedPaths.isNotEmpty) {
        await _removeUploadedFiles(uploadedPaths);
      }

      if (kDebugMode) {
        debugPrint(
          '❌ Community offer creation failed: $error',
        );
      }

      rethrow;
    }
  }

  // ============================================================
  // UPDATE OFFER
  // ============================================================

  /// تعديل عرض موجود
  ///
  /// - [offerId] → رقم العرض
  /// - [newImages] → صور جديدة (XFile)
  /// - [keptImagePaths] → مسارات الصور القديمة اللي هتفضل
  /// - [removedImagePaths] → مسارات الصور القديمة اللي هتتشال
  ///
  /// ملاحظات:
  /// - الصور القديمة اللي مش في `keptImagePaths` هتتشال من الـ storage
  /// - الصور الجديدة هتترفع
  /// - الترتيب النهائي: kept + new
  Future<Map<String, dynamic>> updateOffer({
    required String offerId,
    required String title,
    required String description,
    required String categoryId,
    required String categorySlug,
    required String itemCondition,
    required int quantity,
    required double price,
    required String pickupLocation,
    // الصور:
    List<XFile> newImages = const [],
    List<String> keptImagePaths = const [],
    // اختياري:
    DateTime? expiresAt,
    String? marketplaceCategoryId,
    List<Map<String, dynamic>> marketplaceAttributes = const [],
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا لتعديل العرض');
    }

    if (offerId.trim().isEmpty) {
      throw Exception('رقم العرض غير صحيح');
    }

    final cleanOfferId = offerId.trim();
    final cleanTitle = title.trim();
    final cleanDescription = description.trim();
    final cleanCategoryId = categoryId.trim();
    final cleanCategorySlug = categorySlug.trim();
    final cleanLocation = pickupLocation.trim();

    final cleanMarketplaceCategoryId = marketplaceCategoryId?.trim();

    // ==========================================================
    // VALIDATION
    // ==========================================================

    if (cleanTitle.length < 3) {
      throw Exception(
        'عنوان العرض يجب أن يحتوي على 3 أحرف على الأقل',
      );
    }

    if (cleanDescription.length < 10) {
      throw Exception(
        'وصف العرض يجب أن يحتوي على 10 أحرف على الأقل',
      );
    }

    if (cleanCategoryId.isEmpty || cleanCategorySlug.isEmpty) {
      throw Exception(
        'يجب اختيار تصنيف صحيح للعرض',
      );
    }

    if (cleanMarketplaceCategoryId == null ||
        cleanMarketplaceCategoryId.isEmpty) {
      throw Exception(
        'يجب اختيار تصنيف Marketplace صحيح للعرض',
      );
    }

    const allowedConditions = {
      'new',
      'used',
      'very_good',
      'good',
      'needs_repair',
    };

    if (!allowedConditions.contains(itemCondition)) {
      throw Exception(
        'حالة المنتج غير صحيحة',
      );
    }

    if (quantity <= 0) {
      throw Exception(
        'الكمية يجب أن تكون أكبر من صفر',
      );
    }

    if (price <= 0) {
      throw Exception(
        'السعر الرمزي يجب أن يكون أكبر من صفر',
      );
    }

    if (cleanLocation.isEmpty) {
      throw Exception(
        'يجب إدخال مكان الاستلام',
      );
    }

    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      throw Exception(
        'تاريخ انتهاء العرض يجب أن يكون في المستقبل',
      );
    }

    // ==========================================================
    // OWNERSHIP CHECK
    // ==========================================================

    final existing = await _client
        .from('community_offers')
        .select('owner_id, images, image')
        .eq('id', cleanOfferId)
        .maybeSingle();

    if (existing == null) {
      throw Exception('العرض غير موجود');
    }

    final ownerId = existing['owner_id']?.toString();

    if (ownerId != authUser.id) {
      throw Exception('لا تملك صلاحية تعديل هذا العرض');
    }

    // ==========================================================
    // CLEAN MARKETPLACE ATTRIBUTES (نفس منطق create)
    // ==========================================================

    final cleanMarketplaceAttributes = <Map<String, dynamic>>[];

    for (final attribute in marketplaceAttributes) {
      final attributeId = attribute['attribute_id']?.toString().trim();

      final optionId = attribute['option_id']?.toString().trim();

      if (attributeId == null ||
          attributeId.isEmpty ||
          optionId == null ||
          optionId.isEmpty) {
        continue;
      }

      cleanMarketplaceAttributes.add({
        'attribute_id': attributeId,
        'option_id': optionId,
      });
    }

    final uniqueMarketplaceAttributes = <Map<String, dynamic>>[];

    final usedAttributeIds = <String>{};

    for (final attribute in cleanMarketplaceAttributes) {
      final attributeId = attribute['attribute_id']?.toString();

      if (attributeId == null || attributeId.isEmpty) {
        continue;
      }

      if (usedAttributeIds.contains(attributeId)) {
        continue;
      }

      usedAttributeIds.add(attributeId);
      uniqueMarketplaceAttributes.add(attribute);
    }

    // ==========================================================
    // 1) UPLOAD NEW IMAGES
    // ==========================================================

    final newlyUploadedPaths = <String>[];

    try {
      for (final image in newImages) {
        final path = await _uploadImage(
          userId: authUser.id,
          image: image,
        );

        newlyUploadedPaths.add(path);
      }

      // ========================================================
      // 2) BUILD FINAL IMAGES LIST (kept + newly uploaded)
      // ========================================================

      final cleanKeptPaths =
          keptImagePaths.map(_storagePath).where((p) => p.isNotEmpty).toList();

      final finalStoragePaths = <String>[
        ...cleanKeptPaths,
        ...newlyUploadedPaths,
      ];

      // ========================================================
      // 3) SIGN FINAL IMAGES
      // ========================================================

      final finalSignedUrls = <String>[];

      for (final path in finalStoragePaths) {
        final signed = await _signedImageUrl(path);

        if (signed != null) {
          finalSignedUrls.add(signed);
        }
      }

      // ========================================================
      // 4) BUILD PAYLOAD
      // ========================================================

      final payload = <String, dynamic>{
        'title': cleanTitle,
        'description': cleanDescription,
        'category': cleanCategorySlug,
        'category_id': cleanCategoryId,
        'marketplace_category_id': cleanMarketplaceCategoryId,
        'item_condition': itemCondition,
        'quantity': quantity,
        'price': price,
        'image': finalSignedUrls.isEmpty ? null : finalSignedUrls.first,
        'images': finalSignedUrls,
        'pickup_location': cleanLocation,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        // ⚠️ لا نغير status هنا
      };

      if (kDebugMode) {
        debugPrint('═══════════════════════════════');
        debugPrint('📤 Community Offer UPDATE Payload:');

        payload.forEach((key, value) {
          debugPrint('   $key: $value');
        });

        debugPrint('═══════════════════════════════');
      }

      // ========================================================
      // 5) UPDATE COMMUNITY OFFER
      // ========================================================

      final response = await _client
          .from('community_offers')
          .update(payload)
          .eq('id', cleanOfferId)
          .eq('owner_id', authUser.id) // حماية إضافية
          .select()
          .single();

      final result = Map<String, dynamic>.from(response);

      if (kDebugMode) {
        debugPrint(
          '✅ Community offer updated: '
          '$cleanOfferId',
        );
      }

      // ========================================================
      // 6) MARKETPLACE ATTRIBUTES
      // ========================================================

      if (uniqueMarketplaceAttributes.isNotEmpty) {
        Map<String, dynamic>? marketplaceOffer;

        for (var attempt = 0; attempt < 3; attempt++) {
          marketplaceOffer = await _getMarketplaceOfferForCommunityOffer(
            cleanOfferId,
          );

          if (marketplaceOffer != null) {
            break;
          }

          if (attempt < 2) {
            await Future<void>.delayed(
              const Duration(milliseconds: 300),
            );
          }
        }

        final marketplaceOfferId = marketplaceOffer?['id']?.toString();

        if (marketplaceOfferId != null && marketplaceOfferId.isNotEmpty) {
          try {
            await _client.rpc(
              'upsert_marketplace_offer_attributes',
              params: {
                'p_marketplace_offer_id': marketplaceOfferId,
                'p_attributes': uniqueMarketplaceAttributes,
              },
            );

            if (kDebugMode) {
              debugPrint('✅ Marketplace attributes updated');
            }
          } catch (rpcError) {
            if (kDebugMode) {
              debugPrint(
                '❌ Failed to update marketplace attributes: '
                '$rpcError',
              );
            }

            throw Exception(
              'تعذر حفظ مواصفات المنتج. '
              'لم يتم تعديل العرض بشكل كامل.',
            );
          }
        }
      }

      // ========================================================
      // 7) CLEANUP REMOVED IMAGES (من storage)
      // ========================================================

      // احسب الصور اللي اتشالت
      final oldStoragePaths = <String>[];

      final rawImages = existing['images'];

      if (rawImages is List) {
        for (final raw in rawImages) {
          final value = raw?.toString();

          if (value == null || value.isEmpty) {
            continue;
          }

          final path = _storagePath(value);

          if (path.isNotEmpty) {
            oldStoragePaths.add(path);
          }
        }
      }

      final removedPaths =
          oldStoragePaths.where((p) => !cleanKeptPaths.contains(p)).toList();

      if (removedPaths.isNotEmpty) {
        await _removeUploadedFiles(removedPaths);
      }

      // ========================================================
      // 8) NORMALIZE RESULT
      // ========================================================

      final normalized = await _withSignedImageUrls(result);

      return normalized;
    } catch (error) {
      // ========================================================
      // CLEANUP NEWLY UPLOADED FILES (في حالة الفشل)
      // ========================================================

      if (newlyUploadedPaths.isNotEmpty) {
        await _removeUploadedFiles(newlyUploadedPaths);
      }

      if (kDebugMode) {
        debugPrint(
          '❌ Community offer update failed: $error',
        );
      }

      rethrow;
    }
  }

  // ============================================================
  // GET OFFER BY ID
  // ============================================================

  /// جلب عرض واحد بالكامل (بالصور الموقعة)
  Future<Map<String, dynamic>?> getOfferById(String offerId) async {
    if (offerId.trim().isEmpty) {
      return null;
    }

    try {
      final response = await _client
          .from('community_offers')
          .select(
            '''
            *,
            community_categories(
              id,
              slug,
              name_ar,
              name_en
            )
            ''',
          )
          .eq('id', offerId.trim())
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final result = Map<String, dynamic>.from(response);

      return await _normalizeNumericValues(result);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('❌ getOfferById error: $error');
      }

      return null;
    }
  }

  // ============================================================
  // GET MARKETPLACE OFFER FOR COMMUNITY OFFER
  // ============================================================

  Future<Map<String, dynamic>?> _getMarketplaceOfferForCommunityOffer(
    String communityOfferId,
  ) async {
    final response = await _client
        .from('marketplace_offers')
        .select('id, source_type, source_id')
        .eq('source_type', 'community')
        .eq('source_id', communityOfferId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // NEARBY OFFERS
  // ============================================================

  Future<List<Map<String, dynamic>>> getNearbyOffers({
    required double latitude,
    required double longitude,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'get_nearby_community_offers',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    if (response is! List) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ get_nearby_community_offers '
          'returned unexpected response',
        );
      }

      return <Map<String, dynamic>>[];
    }

    final rows = response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      try {
        final normalized = await _normalizeNumericValues(
          Map<String, dynamic>.from(row),
        );

        result.add(normalized);
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Community offer normalization error: '
            '$error',
          );
        }
      }
    }

    return result;
  }

  // ============================================================
  // GET OFFERS
  // ============================================================

  Future<List<Map<String, dynamic>>> getOffers({
    String? categoryId,
  }) async {
    dynamic query = _client
        .from('community_offers')
        .select(
          '''
          *,
          community_categories!inner(
            id,
            slug,
            name_ar,
            name_en
          ),
          users:owner_id(
            id,
            name,
            email,
            avatar_url
          )
          ''',
        )
        .eq('status', 'available')
        .eq('listing_type', 'symbolic_sale')
        .filter('charity_id', 'is', null);

    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query = query.eq('category_id', categoryId.trim());
    }

    query = query.or(
      'expires_at.is.null,'
      'expires_at.gt.'
      '${DateTime.now().toUtc().toIso8601String()}',
    );

    final response = await query.order(
      'created_at',
      ascending: false,
    );

    final rows = List<Map<String, dynamic>>.from(response);

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      try {
        final normalized = await _normalizeNumericValues(
          Map<String, dynamic>.from(row),
        );

        result.add(normalized);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Community getOffers row error: $error');
        }
      }
    }

    return result;
  }

  // ============================================================
  // OFFER REVIEWS
  // ============================================================

  Future<List<Map<String, dynamic>>> getOfferReviews(String offerId) async {
    final response = await _client
        .from('offer_reviews')
        .select(
          '''
          *,
          users:reviewer_id(
            id,
            name,
            avatar_url
          )
          ''',
        )
        .eq('offer_id', offerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // ADD OFFER REVIEW
  // ============================================================

  Future<Map<String, dynamic>> addReview({
    required String offerId,
    required int rating,
    String? comment,
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('التقييم يجب أن يكون من 1 إلى 5');
    }

    final offer = await _client
        .from('community_offers')
        .select('owner_id')
        .eq('id', offerId)
        .maybeSingle();

    if (offer == null) {
      throw Exception('العرض غير موجود');
    }

    final ownerId = offer['owner_id']?.toString();

    if (ownerId == null) {
      throw Exception('تعذر تحديد صاحب العرض');
    }

    if (ownerId == authUser.id) {
      throw Exception('لا يمكنك تقييم عرضك بنفسك');
    }

    try {
      final response = await _client
          .from('offer_reviews')
          .insert({
            'offer_id': offerId,
            'reviewer_id': authUser.id,
            'owner_id': ownerId,
            'rating': rating,
            'comment': comment?.trim(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('لقد قمت بتقييم هذا العرض من قبل');
      }

      rethrow;
    }
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _client
        .from('users')
        .select(
          '''
          id,
          name,
          email,
          avatar_url,
          city,
          address,
          points,
          level,
          is_verified,
          created_at
          ''',
        )
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // USER OFFERS
  // ============================================================

  Future<List<Map<String, dynamic>>> getUserOffers(String userId) async {
    final response = await _client
        .from('community_offers')
        .select(
          '''
          *,
          community_categories(
            id,
            slug,
            name_ar,
            name_en
          )
          ''',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response);

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      result.add(
        await _normalizeNumericValues(
          Map<String, dynamic>.from(row),
        ),
      );
    }

    return result;
  }

  // ============================================================
  // CURRENT USER ID
  // ============================================================

  String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }

  // ============================================================
  // IS CURRENT USER OWNER
  // ============================================================

  Future<bool> isCurrentUserOwner(String offerId) async {
    final userId = getCurrentUserId();

    if (userId == null) {
      return false;
    }

    final response = await _client
        .from('community_offers')
        .select('owner_id')
        .eq('id', offerId)
        .maybeSingle();

    if (response == null) {
      return false;
    }

    return response['owner_id']?.toString() == userId;
  }

  // ============================================================
  // OFFER IMAGE
  // ============================================================

  Future<String?> getOfferImage(String offerId) async {
    final response = await _client
        .from('community_offers')
        .select('image, images')
        .eq('id', offerId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final images = response['images'];

    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString();

      if (first != null && first.isNotEmpty) {
        return await _signedImageUrl(first);
      }
    }

    final image = response['image']?.toString();

    if (image == null || image.isEmpty) {
      return null;
    }

    return await _signedImageUrl(image);
  }

  // ============================================================
  // USER REVIEWS
  // ============================================================

  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    final response = await _client
        .from('offer_reviews')
        .select(
          '''
          *,
          users:reviewer_id(
            id,
            name,
            avatar_url
          ),
          community_offers:offer_id(
            id,
            title
          )
          ''',
        )
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // USER AVERAGE RATING
  // ============================================================

  Future<double> getUserAverageRating(String userId) async {
    final response = await _client
        .from('offer_reviews')
        .select('rating')
        .eq('owner_id', userId);

    final rows = List<Map<String, dynamic>>.from(response);

    if (rows.isEmpty) {
      return 0.0;
    }

    double total = 0;
    int count = 0;

    for (final row in rows) {
      final value = _toDouble(row['rating']);

      if (value != null) {
        total += value;
        count++;
      }
    }

    if (count == 0) {
      return 0.0;
    }

    return total / count;
  }

  // ============================================================
  // ADD USER REVIEW
  // ============================================================

  Future<Map<String, dynamic>> addUserReview({
    required String ownerId,
    required int rating,
    String? comment,
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('التقييم يجب أن يكون من 1 إلى 5');
    }

    if (ownerId == authUser.id) {
      throw Exception('لا يمكنك تقييم نفسك');
    }

    try {
      final response = await _client
          .from('user_reviews')
          .insert({
            'owner_id': ownerId,
            'reviewer_id': authUser.id,
            'rating': rating,
            'comment': comment?.trim(),
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('لقد قمت بتقييم هذا المستخدم من قبل');
      }

      rethrow;
    }
  }

  // ============================================================
  // ✅ NEW: MARK AS COMPLETED (تم البيع)
  // ============================================================

  /// يحوّل حالة العرض إلى `completed` (تم البيع)
  /// - يستخدم RPC `mark_community_offer_completed` للأمان
  /// - بيرجع true لو نجح
  Future<bool> markOfferAsCompleted(String offerId) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    try {
      await _client.rpc(
        'mark_community_offer_completed',
        params: {
          'p_offer_id': offerId,
          'p_user_id': authUser.id,
        },
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ markOfferAsCompleted error: $e');
      }

      // ✅ Fallback: لو RPC مش موجود → update مباشر
      final text = e.toString().toLowerCase();

      if (text.contains('function') && text.contains('does not exist')) {
        await _client
            .from('community_offers')
            .update({
              'status': 'completed',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId)
            .eq('owner_id', authUser.id);

        return true;
      }

      rethrow;
    }
  }

  // ============================================================
  // ✅ NEW: RENEW OFFER (تجديد العرض)
  // ============================================================

  /// يجدّد عرض منتهي أو ملغي
  /// - [days] عدد الأيام الجديدة (افتراضي: 7)
  /// - يرجع تاريخ الانتهاء الجديد
  Future<DateTime?> renewOffer(
    String offerId, {
    int days = 7,
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    try {
      final response = await _client.rpc(
        'renew_community_offer',
        params: {
          'p_offer_id': offerId,
          'p_user_id': authUser.id,
          'p_days': days,
        },
      );

      if (response == null) return null;

      final text = response.toString().trim();
      if (text.isEmpty) return null;

      return DateTime.tryParse(text);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ renewOffer error: $e');
      }

      final text = e.toString().toLowerCase();

      if (text.contains('function') && text.contains('does not exist')) {
        final newExpiry = DateTime.now().add(Duration(days: days));

        await _client
            .from('community_offers')
            .update({
              'status': 'available',
              'expires_at': newExpiry.toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', offerId)
            .eq('owner_id', authUser.id);

        return newExpiry;
      }

      rethrow;
    }
  }

  // ============================================================
  // NORMALIZE NUMERIC VALUES
  // ============================================================

  Future<Map<String, dynamic>> _normalizeNumericValues(
    Map<String, dynamic> row,
  ) async {
    final result = Map<String, dynamic>.from(row);

    if (result.containsKey('price')) {
      result['price'] = _toDouble(result['price']) ?? 0.0;
    }

    if (result.containsKey('quantity')) {
      result['quantity'] = _toInt(result['quantity']) ?? 0;
    }

    if (result.containsKey('distance_meters')) {
      result['distance_meters'] = _toDouble(result['distance_meters']);
    }

    if (result.containsKey('distance_km')) {
      result['distance_km'] = _toDouble(result['distance_km']);
    }

    return _withSignedImageUrls(result);
  }

  // ============================================================
  // SIGN IMAGE URLS
  // ============================================================

  Future<Map<String, dynamic>> _withSignedImageUrls(
    Map<String, dynamic> row,
  ) async {
    final result = Map<String, dynamic>.from(row);

    final rawImages = result['images'];

    final signedImages = <String>[];

    if (rawImages is List) {
      for (final raw in rawImages) {
        final value = raw?.toString();

        if (value == null || value.isEmpty) {
          continue;
        }

        final signed = await _signedImageUrl(value);

        if (signed != null) {
          signedImages.add(signed);
        }
      }
    }

    if (signedImages.isNotEmpty) {
      result['images'] = signedImages;
      result['image'] = signedImages.first;
    } else {
      final rawImage = result['image']?.toString();

      if (rawImage != null && rawImage.isNotEmpty) {
        final signed = await _signedImageUrl(rawImage);

        if (signed != null) {
          result['image'] = signed;
          result['images'] = [signed];
        }
      }
    }

    return result;
  }

  // ============================================================
  // UPLOAD IMAGE
  // ============================================================

  Future<String> _uploadImage({
    required String userId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('الصورة المختارة فارغة');
    }

    final extension = _extension(image.name);

    final fileName = '${DateTime.now().microsecondsSinceEpoch}_'
        '${Object.hash(image.name, bytes.length).abs()}'
        '.$extension';

    final path = '$userId/$fileName';

    await _client.storage.from('community-offers').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(extension),
            upsert: false,
          ),
        );

    return path;
  }

  // ============================================================
  // STORAGE PATH
  // ============================================================

  String _storagePath(String value) {
    if (value.startsWith('community-offers/')) {
      return value.substring('community-offers/'.length);
    }

    return value;
  }

  // ============================================================
  // SIGNED IMAGE URL
  // ============================================================

  Future<String?> _signedImageUrl(String? value) async {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final clean = value.trim();

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    final path = _storagePath(clean);

    try {
      return await _client.storage.from('community-offers').createSignedUrl(
            path,
            60 * 60 * 24,
          );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to sign community image: $error');
      }

      return null;
    }
  }

  // ============================================================
  // REMOVE UPLOADED FILES
  // ============================================================

  Future<void> _removeUploadedFiles(List<String> paths) async {
    if (paths.isEmpty) {
      return;
    }

    try {
      await _client.storage.from('community-offers').remove(paths);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Failed to cleanup uploaded community images: $error',
        );
      }
    }
  }

  // ============================================================
  // EXTENSION
  // ============================================================

  String _extension(String fileName) {
    final clean = fileName.trim();

    final dotIndex = clean.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == clean.length - 1) {
      return 'jpg';
    }

    final extension = clean.substring(dotIndex + 1).toLowerCase();

    const allowed = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    };

    if (!allowed.contains(extension)) {
      return 'jpg';
    }

    return extension;
  }

  // ============================================================
  // CONTENT TYPE
  // ============================================================

  String _contentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'heic':
        return 'image/heic';

      case 'heif':
        return 'image/heif';

      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  // ============================================================
  // INT
  // ============================================================

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}
