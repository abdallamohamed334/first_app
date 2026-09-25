// lib/features/provider/data/repositories/service_provider_repository.dart

import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';

class ServiceProviderRepository {
  final SupabaseService _supabase;

  ServiceProviderRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService();

  SupabaseClient get _client => _supabase.client;

  // ═══════════════════════════════════════════════════════════
  // 🔧 Helpers
  // ═══════════════════════════════════════════════════════════
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email.trim());
  }

  /// للعرض المحلي (01012345678)
  String _cleanPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return cleaned;
    }
    if (cleaned.startsWith('20') && cleaned.length == 12) {
      return '0${cleaned.substring(2)}';
    }
    return cleaned;
  }

  /// للـ OTP API (201012345678)
  String _cleanPhoneIntl(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '20${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('20') && cleaned.length == 12) {
      return cleaned;
    }
    if (cleaned.length == 10 && cleaned.startsWith('1')) {
      return '20$cleaned';
    }
    return cleaned;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('already') ||
        raw.contains('exists') ||
        raw.contains('duplicate') ||
        raw.contains('23505')) {
      return 'الإيميل أو رقم الهاتف مسجل بالفعل.';
    }
    if (raw.contains('invalid login') || raw.contains('invalid credentials')) {
      return 'الإيميل أو كلمة السر غير صحيحة.';
    }
    if (raw.contains('weak password')) {
      return 'كلمة السر ضعيفة. استخدم 6 أحرف على الأقل.';
    }
    if (raw.contains('email not confirmed')) {
      return 'لازم تأكّد إيميلك الأول.';
    }
    if (raw.contains('rate') || raw.contains('too many')) {
      return 'محاولات كثيرة. استنى شوية وحاول تاني.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection')) {
      return 'تعذر الاتصال. تحقق من الإنترنت.';
    }
    if (raw.contains('permission') || raw.contains('42501')) {
      return 'ليس لديك صلاحية. تواصل مع الدعم.';
    }
    if (raw.contains('23502') || raw.contains('not-null')) {
      return 'بيانات ناقصة. تأكد من اكتمال الحقول.';
    }
    return 'تعذر إتمام العملية. حاول تاني.';
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فحص اكتمال البروفايل
  // ═══════════════════════════════════════════════════════════
  /// بترجع:
  /// - List فاضية → البروفايل كامل
  /// - List فيها عناصر → الحقول الناقصة (بالعربي)
  List<String> checkProfileCompletion(Map<String, dynamic> provider) {
    final missing = <String>[];

    // 1️⃣ صورة البروفايل
    final profileImage = provider['profile_image_url']?.toString().trim() ?? '';
    if (profileImage.isEmpty) {
      missing.add('صورة البروفايل');
    }

    // 2️⃣ نبذة
    final bio = provider['bio']?.toString().trim() ?? '';
    if (bio.length < 10) {
      missing.add('نبذة عنك (10 أحرف على الأقل)');
    }

    // 3️⃣ المدينة
    final city = provider['city']?.toString().trim() ?? '';
    if (city.isEmpty) {
      missing.add('المدينة');
    }

    // 4️⃣ مناطق الخدمة
    final areas = provider['service_areas'];
    if (areas is! List || areas.isEmpty) {
      missing.add('منطقة خدمة واحدة على الأقل');
    }

    // 5️⃣ الواتساب / الهاتف
    final whatsapp = provider['whatsapp']?.toString().trim() ?? '';
    final phone = provider['phone']?.toString().trim() ?? '';
    if (whatsapp.isEmpty && phone.isEmpty) {
      missing.add('رقم الواتساب أو الهاتف');
    }

    // 6️⃣ سنوات الخبرة
    final exp = provider['experience_years'];
    if (exp == null || (exp is int && exp < 1)) {
      missing.add('سنوات الخبرة');
    }

    // 7️⃣ المهارات
    final skills = provider['skills'];
    if (skills is! List || skills.isEmpty) {
      missing.add('مهارة واحدة على الأقل');
    }

    return missing;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 التحقق من وجود مزود برقم الموبايل
  // ═══════════════════════════════════════════════════════════
  /// بترجّع:
  /// - null → الرقم مش مسجل كمزود
  /// - Map → المزود موجود (مع بياناته)
  Future<Either<String, Map<String, dynamic>?>> checkProviderByPhone({
    required String phone,
  }) async {
    try {
      final intl = _cleanPhoneIntl(phone);
      final local = _cleanPhone(phone);

      final variants = <String>{
        intl,
        local,
        '+$intl',
        '+$local',
      }.where((v) => v.isNotEmpty).toList();

      debugPrint('🔍 [Provider] Checking phone variants: $variants');

      final orParts = <String>[];
      for (final v in variants) {
        orParts.add('phone.eq.$v');
        orParts.add('whatsapp.eq.$v');
      }
      final orQuery = orParts.join(',');

      final rows = await _client.from('service_providers').select('''
            *,
            categories:category_id (id, name_ar, slug, icon)
          ''').or(orQuery).limit(1);

      if (rows.isEmpty) {
        debugPrint('🔍 [Provider] No provider found for this phone');
        return const Right(null);
      }

      final row = rows.first;

      debugPrint(
        '🔍 [Provider] Found provider: '
        'status=${row['verification_status']}, '
        'active=${row['is_active']}',
      );

      return Right(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('❌ [Provider] checkByPhone error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📱 OTP — إرسال الكود
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, String>> sendProviderOtp({
    required String phone,
  }) async {
    try {
      final cleanPhone = _cleanPhoneIntl(phone);

      if (cleanPhone.length < 10 || cleanPhone.length > 15) {
        return const Left('رقم الهاتف غير صحيح');
      }

      debugPrint('📤 [Provider OTP] Sending to $cleanPhone');

      final response = await _client.functions.invoke(
        'send-otp',
        body: {'phone': cleanPhone},
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ [Provider OTP] error: $err');
        if (err.contains('rate') || err.contains('too many')) {
          return const Left('انتظر دقيقة قبل طلب كود جديد');
        }
        return Left(err.isNotEmpty ? err : 'تعذر إرسال الكود');
      }

      final returned = data['phone']?.toString() ?? cleanPhone;
      debugPrint('✅ [Provider OTP] Sent to $returned');
      return Right(returned);
    } catch (error) {
      debugPrint('❌ [Provider OTP] send exception: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ OTP — التحقق + إنشاء/دخول
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, Map<String, dynamic>>> verifyAndCreateProvider({
    required String phone,
    required String code,
    required String displayName,
    required String categoryId,
    required String providerType,
    String? email,
    String? city,
    String? address,
  }) async {
    try {
      final cleanPhone = _cleanPhoneIntl(phone);
      final cleanCode = code.trim();

      if (!RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
        return const Left('الكود يجب أن يكون 6 أرقام');
      }

      final isRegisterMode = categoryId.trim().isNotEmpty;

      debugPrint(
        '📥 [Provider OTP] Verifying: $cleanPhone (mode=${isRegisterMode ? "register" : "login"})',
      );

      final response = await _client.functions.invoke(
        'verify-and-create',
        body: {
          'phone': cleanPhone,
          'code': cleanCode,
          'profile': {
            'role': 'provider',
            'name': displayName.isEmpty ? 'مزود خدمة' : displayName,
            'phone': cleanPhone,
            if (city != null && city.isNotEmpty) 'city': city,
          },
        },
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ [Provider OTP] verify error: $err');
        return Left(err.isNotEmpty ? err : 'كود التحقق غير صحيح');
      }

      final refreshToken = data['refresh_token']?.toString();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _client.auth.setSession(refreshToken);
      }

      final userId =
          data['user']?['id']?.toString() ?? _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        return const Left('تعذر تحميل بيانات المستخدم');
      }

      debugPrint('✅ [Provider OTP] Auth OK: $userId');

      final existing = await _client.from('service_providers').select('''
            *,
            categories:category_id (id, name_ar, slug, icon)
          ''').eq('user_id', userId).maybeSingle();

      if (existing != null) {
        final status = existing['verification_status']?.toString() ?? 'pending';
        final isActive = existing['is_active'] as bool? ?? true;

        if (!isActive || status == 'rejected' || status == 'suspended') {
          await _client.auth.signOut();
          if (status == 'rejected') {
            final notes = existing['verification_notes']?.toString() ?? '';
            return Left(
              notes.isNotEmpty
                  ? 'حسابك مرفوض. السبب: $notes'
                  : 'حسابك مرفوض. تواصل مع الدعم.',
            );
          }
          return const Left('حسابك غير مفعّل. تواصل مع الدعم.');
        }

        debugPrint('✅ [Provider OTP] Existing provider status=$status');

        return Right({
          'user': _client.auth.currentUser,
          'provider': Map<String, dynamic>.from(existing),
          'isNewUser': false,
          'status': status,
          'needsApproval': status != 'approved',
        });
      }

      if (!isRegisterMode) {
        await _client.auth.signOut();
        return const Left(
          'الرقم ده مش مسجل كمزود خدمة. اعمل حساب جديد من تاب "حساب جديد".',
        );
      }

      debugPrint('📥 [Provider OTP] Creating new provider...');

      final insertData = <String, dynamic>{
        'user_id': userId,
        'category_id': categoryId,
        'provider_type': providerType,
        'display_name': displayName.trim(),
        'phone': _cleanPhone(phone),
        'whatsapp': _cleanPhone(phone),
        'email': email,
        'verification_status': 'pending',
        'is_active': true,
        'is_available': false,
        'price_currency': 'EGP',
        'accepts_installments': false,
        'skills': <String>[],
        'service_areas': <String>[],
        'branches': '[]',
      };

      if (city != null && city.trim().isNotEmpty) {
        insertData['city'] = city.trim();
      }
      if (address != null && address.trim().isNotEmpty) {
        insertData['address'] = address.trim();
      }

      final providerRow = await _client
          .from('service_providers')
          .insert(insertData)
          .select()
          .single();

      debugPrint('✅ [Provider OTP] Created: ${providerRow['id']}');

      return Right({
        'user': _client.auth.currentUser,
        'provider': Map<String, dynamic>.from(providerRow),
        'isNewUser': true,
        'status': 'pending',
        'needsApproval': true,
      });
    } catch (error, stack) {
      debugPrint('❌ [Provider OTP] verify error: $error');
      debugPrintStack(stackTrace: stack);
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 جلب بروفايل المزود الحالي
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, Map<String, dynamic>>> getCurrentProvider() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return const Left('مش مسجل دخول');
      }

      final row = await _client.from('service_providers').select('''
            *,
            categories:category_id (id, name_ar, slug, icon)
          ''').eq('user_id', user.id).maybeSingle();

      if (row == null) {
        return const Left('مفيش بروفايل مزود خدمة مرتبط بحسابك');
      }

      return Right(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('❌ [Provider] getCurrent error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ تحديث بروفايل المزود
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, Map<String, dynamic>>> updateProviderProfile({
    required String providerId,
    String? displayName,
    String? bio,
    int? experienceYears,
    List<String>? skills,
    String? city,
    String? address,
    List<String>? serviceAreas,
    double? latitude,
    double? longitude,
    double? maxDistanceKm,
    String? pricingType,
    double? priceFrom,
    bool? acceptsInstallments,
    String? profileImageUrl,
    List<String>? portfolioImages,
    String? coverImageUrl,
    String? whatsapp,
    String? website,
    bool? isAvailable,
    String? availabilityNote,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (displayName != null) data['display_name'] = displayName.trim();
      if (bio != null) data['bio'] = bio.trim();
      if (experienceYears != null) data['experience_years'] = experienceYears;
      if (skills != null) data['skills'] = skills;
      if (city != null) data['city'] = city.trim();
      if (address != null) data['address'] = address.trim();
      if (serviceAreas != null) data['service_areas'] = serviceAreas;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (maxDistanceKm != null) data['max_distance_km'] = maxDistanceKm;
      if (pricingType != null) data['pricing_type'] = pricingType;
      if (priceFrom != null) data['price_from'] = priceFrom;
      if (acceptsInstallments != null) {
        data['accepts_installments'] = acceptsInstallments;
      }
      if (profileImageUrl != null) {
        data['profile_image_url'] = profileImageUrl;
      }
      if (portfolioImages != null) {
        data['portfolio_images'] = portfolioImages;
      }
      if (coverImageUrl != null) data['cover_image_url'] = coverImageUrl;
      if (whatsapp != null) data['whatsapp'] = _cleanPhone(whatsapp);
      if (website != null) data['website'] = website.trim();
      if (isAvailable != null) data['is_available'] = isAvailable;
      if (availabilityNote != null) {
        data['availability_note'] = availabilityNote.trim();
      }

      final row = await _client
          .from('service_providers')
          .update(data)
          .eq('id', providerId)
          .select()
          .single();

      debugPrint('✅ [Provider] Profile updated');

      return Right(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('❌ [Provider] update error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 رفع صورة للمزود
  // ═══════════════════════════════════════════════════════════
  /// [type]: profile | cover | portfolio
  Future<Either<String, String>> uploadProviderImage({
    required String userId,
    required String imagePath,
    required String type,
  }) async {
    try {
      final ext = imagePath.split('.').last.toLowerCase();
      final fileName =
          '$userId/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      debugPrint('📤 [Provider] Uploading $type: $fileName');

      final file = File(imagePath);

      await _client.storage.from('provider-images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final url =
          _client.storage.from('provider-images').getPublicUrl(fileName);

      debugPrint('✅ [Provider] Uploaded: $url');

      return Right(url);
    } catch (error) {
      debugPrint('❌ [Provider] upload error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 تبديل حالة التوفر ✅ محدّثة
  // ═══════════════════════════════════════════════════════════
  /// ✅ بتتحقق من اكتمال البروفايل قبل تشغيل الظهور
  Future<Either<String, bool>> toggleAvailability({
    required String providerId,
    required bool isAvailable,
    String? note,
  }) async {
    try {
      // ══════════════════════════════════════════════════════════
      // ✅ لو بيفتح الظهور → نتأكد من اكتمال البروفايل
      // ══════════════════════════════════════════════════════════
      if (isAvailable) {
        final providerRow = await _client
            .from('service_providers')
            .select()
            .eq('id', providerId)
            .maybeSingle();

        if (providerRow == null) {
          return const Left('مفيش بيانات المزود');
        }

        // ✅ افحص البروفايل
        final missing = checkProfileCompletion(providerRow);

        if (missing.isNotEmpty) {
          return Left(
            'عشان تظهر للمستخدمين، لازم تكمّل:\n• ${missing.join('\n• ')}',
          );
        }
      }

      // ✅ حدّث الحالة
      await _client.from('service_providers').update({
        'is_available': isAvailable,
        'availability_note': note,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', providerId);

      debugPrint('✅ [Provider] availability=$isAvailable');

      return Right(isAvailable);
    } catch (error) {
      debugPrint('❌ [Provider] toggleAvailability error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 إحصائيات المزود
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, Map<String, dynamic>>> getProviderStats(
    String providerId,
  ) async {
    try {
      final row = await _client.from('service_providers').select('''
            total_jobs,
            completed_jobs,
            cancelled_jobs,
            volunteer_jobs,
            rating_avg,
            total_reviews,
            response_time_minutes
          ''').eq('id', providerId).maybeSingle();

      if (row == null) return const Left('مفيش بيانات');

      return Right(Map<String, dynamic>.from(row));
    } catch (error) {
      debugPrint('❌ [Provider] stats error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ جلب تقييمات المزود
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, List<Map<String, dynamic>>>> getProviderReviews(
    String providerId,
  ) async {
    try {
      debugPrint('📥 [Provider] Fetching reviews for: $providerId');

      final rows = await _client
          .from('service_reviews')
          .select('''
            id,
            rating,
            comment,
            images,
            tags,
            is_anonymous,
            created_at,
            from_user_id
          ''')
          .eq('to_provider_id', providerId)
          .order('created_at', ascending: false);

      final reviews = <Map<String, dynamic>>[];

      for (final row in rows) {
        final review = Map<String, dynamic>.from(row);
        final userId = review['from_user_id']?.toString();
        final isAnonymous = review['is_anonymous'] as bool? ?? false;

        if (isAnonymous) {
          review['users'] = {
            'name': 'مستخدم مجهول',
            'avatar_url': null,
          };
        } else if (userId != null && userId.isNotEmpty) {
          try {
            final userRow = await _client
                .from('users')
                .select('name, avatar_url')
                .eq('id', userId)
                .maybeSingle();

            if (userRow != null) {
              review['users'] = {
                'name': userRow['name']?.toString() ?? 'مستخدم',
                'avatar_url': userRow['avatar_url']?.toString(),
              };
            } else {
              review['users'] = {
                'name': 'مستخدم',
                'avatar_url': null,
              };
            }
          } catch (_) {
            review['users'] = {
              'name': 'مستخدم',
              'avatar_url': null,
            };
          }
        }

        reviews.add(review);
      }

      debugPrint('✅ [Provider] Got ${reviews.length} reviews');

      return Right(reviews);
    } catch (error) {
      debugPrint('❌ [Provider] reviews error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ جلب التصنيفات
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, List<Map<String, dynamic>>>> getCategories({
    String? providerType,
  }) async {
    try {
      var query = _client.from('service_categories').select('''
            id,
            slug,
            name_ar,
            name_en,
            icon,
            color,
            description,
            supports_individual,
            supports_company,
            default_pricing,
            sort_order
          ''').eq('is_active', true);

      if (providerType == 'individual') {
        query = query.eq('supports_individual', true);
      } else if (providerType == 'company') {
        query = query.eq('supports_company', true);
      }

      final rows = await query.order('sort_order', ascending: true);

      return Right(List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      debugPrint('❌ [Provider] categories error: $error');
      return Left(_friendlyError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 تسجيل خروج
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, void>> logout() async {
    try {
      await _supabase.signOut();
      return const Right(null);
    } catch (error) {
      debugPrint('❌ [Provider] logout error: $error');
      return const Left('تعذر تسجيل الخروج');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 التحقق من الحالة
  // ═══════════════════════════════════════════════════════════
  Future<bool> isCurrentUserProvider() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final row = await _client
          .from('service_providers')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      return row != null;
    } catch (error) {
      debugPrint('❌ [Provider] isProvider error: $error');
      return false;
    }
  }
}
