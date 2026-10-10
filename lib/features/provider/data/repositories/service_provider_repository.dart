// lib/features/provider/data/repositories/service_provider_repository.dart

import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_error_mapper.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/auth_state_notifier.dart';
import '../../../../core/services/image_upload_codec.dart';

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

  String _maskPhone(String phone) {
    if (phone.length < 6) return '******';
    return '${phone.substring(0, 4)}******${phone.substring(phone.length - 2)}';
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static const _profileCompletionColumns =
      'profile_image_url,bio,governorate,city,service_areas,available_days,id_card_front_url,id_card_back_url,whatsapp,phone,experience_years,skills';

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('provider_phone_immutable')) {
      return 'رقم الهاتف مرتبط بحساب تسجيل الدخول ولا يمكن تغييره من البروفايل.';
    }
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
    if (raw.contains('cannot send code') ||
        raw.contains('لا يمكن إرسال كود') ||
        raw.contains('account type') ||
        raw.contains('نوع الحساب') ||
        raw.contains('provider phone')) {
      return 'لا يمكن إرسال كود لهذا الرقم. تأكد أن الرقم مرتبط بحساب مزود خدمة أو سجّل حسابًا جديدًا.';
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
    return AppErrorMapper.message(
      error,
      fallback: 'تعذر إتمام العملية حاليًا. حاول تاني.',
    );
  }

  /// يحوّل رسائل الـEdge Function القادمة في response.data إلى رسائل آمنة.
  /// لا نعرض نص الخطأ القادم من Supabase مباشرة لأنه قد يحتوي على تفاصيل
  /// داخلية من قاعدة البيانات أو أسماء دوال وسياسات RLS.
  String _friendlyProviderOtpResponseError(
    String error, {
    required bool isSending,
  }) {
    final raw = error.trim().toLowerCase();
    if (raw.isEmpty) {
      return isSending
          ? 'تعذر إرسال كود التحقق. حاول تاني.'
          : 'كود التحقق غير صحيح أو منتهي.';
    }

    if (raw.contains('rate') ||
        raw.contains('too many') ||
        raw.contains('انتظر') ||
        raw.contains('429')) {
      return 'تم تجاوز عدد المحاولات. انتظر دقيقة ثم حاول مرة أخرى.';
    }
    if (isSending &&
        (raw.contains('cannot send') ||
            raw.contains('لا يمكن إرسال') ||
            raw.contains('account type') ||
            raw.contains('نوع الحساب') ||
            raw.contains('provider'))) {
      return 'لا يمكن إرسال كود لهذا الرقم. تأكد أن الرقم مرتبط بحساب مزود خدمة أو سجّل حسابًا جديدًا.';
    }
    if (!isSending &&
        (raw.contains('otp') ||
            raw.contains('code') ||
            raw.contains('كود') ||
            raw.contains('رمز') ||
            raw.contains('expired') ||
            raw.contains('منتهي'))) {
      return 'كود التحقق غير صحيح أو منتهي. اطلب كودًا جديدًا وحاول مرة أخرى.';
    }
    if (raw.contains('phone') || raw.contains('رقم')) {
      return 'رقم الهاتف غير صحيح أو غير مرتبط بالحساب المطلوب.';
    }
    return isSending
        ? 'تعذر إرسال كود التحقق حاليًا. حاول تاني.'
        : 'تعذر التحقق من الكود حاليًا. حاول تاني.';
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

    final governorate = provider['governorate']?.toString().trim() ?? '';
    if (governorate.isEmpty) {
      missing.add('المحافظة');
    }

    final availableDays = provider['available_days'];
    if (availableDays is! List || availableDays.isEmpty) {
      missing.add('يوم متاح واحد على الأقل');
    }

    if ((provider['id_card_front_url']?.toString().trim() ?? '').isEmpty) {
      missing.add('صورة البطاقة الأمامية');
    }
    if ((provider['id_card_back_url']?.toString().trim() ?? '').isEmpty) {
      missing.add('صورة البطاقة الخلفية');
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
    final experienceYears =
        exp is num ? exp.toInt() : int.tryParse(exp?.toString().trim() ?? '');
    if (experienceYears == null || experienceYears < 1) {
      missing.add('سنوات الخبرة');
    }

    // 7️⃣ المهارات
    final skills = provider['skills'];
    if (skills is! List || skills.isEmpty) {
      missing.add('مهارة واحدة على الأقل');
    }

    return missing;
  }

  // ══════════════════════════════════════════════════════════
  // 📱 OTP — إرسال الكود
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, String>> sendProviderOtp({
    required String phone,
    String loginMode = 'provider',
  }) async {
    try {
      final cleanPhone = _cleanPhoneIntl(phone);

      if (cleanPhone.length < 10 || cleanPhone.length > 15) {
        return const Left('رقم الهاتف غير صحيح');
      }

      debugPrint(
        '📤 [Provider OTP] Sending to ${_maskPhone(cleanPhone)} '
        '(loginMode=$loginMode)',
      );

      final response = await _client.functions.invoke(
        'send-otp',
        body: {
          'phone': cleanPhone,
          'loginMode': loginMode,
        },
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ [Provider OTP] error response received');
        return Left(_friendlyProviderOtpResponseError(err, isSending: true));
      }

      final returned = data['phone']?.toString() ?? cleanPhone;
      debugPrint('✅ [Provider OTP] Sent to ${_maskPhone(returned)}');
      return Right(returned);
    } catch (error, stack) {
      debugPrint('❌ [Provider OTP] send exception: ${error.runtimeType}');
      debugPrintStack(stackTrace: stack);
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
            // Required for a new service_providers row. Omit it for login so
            // an existing provider profile is not overwritten accidentally.
            if (categoryId.trim().isNotEmpty) 'categoryId': categoryId.trim(),
            if (providerType.trim().isNotEmpty)
              'providerType': providerType.trim(),
            if (city != null && city.isNotEmpty) 'city': city,
          },
        },
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ [Provider OTP] verify error response received');
        return Left(_friendlyProviderOtpResponseError(err, isSending: false));
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

      // امنع الـ router من اتخاذ قرار قبل تحميل حالة مزود الخدمة.
      AuthStateNotifier.instance.beginSync();

      // The edge function has just completed OTP and created the session.
      // Use the narrow auth-state RPC here to avoid a transient RLS failure
      // while the client session event is still propagating.
      final accountRow = await _client
          .from('users')
          .select('account_status, suspension_until')
          .eq('id', userId)
          .maybeSingle();
      final accountStatus =
          accountRow?['account_status']?.toString().trim().toLowerCase() ??
              'active';
      if (accountStatus != 'active') {
        await _client.auth.signOut();
        return const Left('حسابك موقوف أو قيد المراجعة. تواصل مع الدعم.');
      }

      final existingRows = await _client.rpc(
        'get_provider_auth_state',
      );
      final existing = existingRows is List && existingRows.isNotEmpty
          ? Map<String, dynamic>.from(existingRows.first as Map)
          : null;

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

        await _publishProviderAuthState(
          provider: {...existing, 'account_status': accountStatus},
          userId: userId,
        );

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
      providerRow['account_status'] = accountStatus;

      debugPrint('✅ [Provider OTP] Created: ${providerRow['id']}');

      await _publishProviderAuthState(
        provider: providerRow,
        userId: userId,
      );

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
  /// يثبت الدور النهائي بعد نجاح OTP.
  /// لا نعدل users.user_type؛ وجود service_providers هو مصدر الدور هنا.
  Future<void> _publishProviderAuthState({
    required Map<String, dynamic> provider,
    required String userId,
  }) async {
    final status =
        provider['verification_status']?.toString().trim().toLowerCase();
    final providerActive = provider['is_active'] != false;

    debugPrint(
      '✅ [Provider Auth] resolved role=provider '
      'providerStatus=$status active=$providerActive '
      'userId=$userId',
    );

    AuthStateNotifier.instance.setLoggedIn(
      isLoggedIn: true,
      role: 'provider',
      providerStatus: status,
      isActive: providerActive,
      accountStatus: provider['account_status']?.toString(),
      suspensionUntil: provider['suspension_until'] is String
          ? DateTime.tryParse(provider['suspension_until'] as String)
          : null,
      authResolved: true,
    );
  }

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
    String? governorate,
    String? address,
    List<String>? serviceAreas,
    List<String>? availableDays,
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
    String? idCardFrontUrl,
    String? idCardBackUrl,
    bool profileLocked = false,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (!profileLocked && displayName != null) {
        data['display_name'] = displayName.trim();
      }
      if (!profileLocked && bio != null) data['bio'] = bio.trim();
      if (!profileLocked && experienceYears != null) {
        data['experience_years'] = experienceYears;
      }
      if (!profileLocked && skills != null) data['skills'] = skills;
      if (city != null) data['city'] = city.trim();
      if (governorate != null) data['governorate'] = governorate.trim();
      if (!profileLocked && address != null) data['address'] = address.trim();
      if (serviceAreas != null) data['service_areas'] = serviceAreas;
      if (availableDays != null) data['available_days'] = availableDays;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (maxDistanceKm != null) data['max_distance_km'] = maxDistanceKm;
      if (!profileLocked && pricingType != null)
        data['pricing_type'] = pricingType;
      if (!profileLocked && priceFrom != null) data['price_from'] = priceFrom;
      if (!profileLocked && acceptsInstallments != null) {
        data['accepts_installments'] = acceptsInstallments;
      }
      if (profileImageUrl != null) {
        data['profile_image_url'] = profileImageUrl;
      }
      if (portfolioImages != null) {
        data['portfolio_images'] = portfolioImages;
      }
      if (!profileLocked && coverImageUrl != null)
        data['cover_image_url'] = coverImageUrl;
      if (!profileLocked && whatsapp != null)
        data['whatsapp'] = _cleanPhone(whatsapp);
      if (!profileLocked && website != null) data['website'] = website.trim();
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

      if (!profileLocked &&
          (idCardFrontUrl != null || idCardBackUrl != null)) {
        final linked = await _client.rpc(
          'link_my_provider_identity_documents',
          params: {
            'p_provider_id': providerId,
            'p_front_path': idCardFrontUrl,
            'p_back_path': idCardBackUrl,
          },
        );
        if (linked is! Map || linked['success'] != true) {
          final message = linked is Map
              ? linked['message']?.toString()
              : null;
          return Left(message?.isNotEmpty == true
              ? message!
              : 'تعذر حفظ مستندات الهوية');
        }

        final refreshed = await _client
            .from('service_providers')
            .select()
            .eq('id', providerId)
            .single();
        debugPrint('✅ [Provider] Profile and KYC references updated');
        return Right(Map<String, dynamic>.from(refreshed));
      }

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
      const allowedTypes = {'profile', 'cover', 'portfolio'};
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
      if (!allowedTypes.contains(type)) {
        return const Left('نوع الصورة غير صحيح');
      }
      final ext = imagePath.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        return const Left('يسمح برفع صور JPG أو PNG أو WEBP فقط');
      }
      final fileName =
          '$userId/${type}_${DateTime.now().millisecondsSinceEpoch}.webp';

      debugPrint('📤 [Provider] Uploading $type: $fileName');

      final file = File(imagePath);
      if (!await file.exists()) {
        return const Left('ملف الصورة غير موجود');
      }
      if (await file.length() > 10 * 1024 * 1024) {
        return const Left('حجم الصورة يجب ألا يتجاوز 10 ميجابايت');
      }

      final encoded = await ImageUploadCodec.fromBytes(await file.readAsBytes());
      const contentType = 'image/webp';
      await _client.storage.from('provider-images').uploadBinary(
            fileName,
            encoded,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: contentType,
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

  Future<Either<String, String>> uploadProviderIdentityDocument({
    required String userId,
    required String imagePath,
    required String side,
  }) async {
    try {
      const allowedSides = {'front', 'back'};
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
      if (!allowedSides.contains(side)) {
        return const Left('نوع البطاقة غير صحيح');
      }
      final ext = imagePath.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        return const Left('يسمح برفع صور JPG أو PNG أو WEBP فقط');
      }
      final file = File(imagePath);
      if (!await file.exists()) return const Left('ملف الصورة غير موجود');
      if (await file.length() > 10 * 1024 * 1024) {
        return const Left('حجم صورة البطاقة يجب ألا يتجاوز 10 ميجابايت');
      }
      final path =
          '$userId/id_card_${side}_${DateTime.now().millisecondsSinceEpoch}.webp';
      final encoded = await ImageUploadCodec.fromBytes(await file.readAsBytes());
      const contentType = 'image/webp';
      await _client.storage.from('provider-documents').uploadBinary(
            path,
            encoded,
            fileOptions: FileOptions(contentType: contentType),
          );
      return Right(path);
    } catch (error) {
      debugPrint('❌ [Provider] identity upload error: $error');
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
            .select(_profileCompletionColumns)
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
