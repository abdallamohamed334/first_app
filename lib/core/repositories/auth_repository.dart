// lib/features/auth/data/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/fcm_notification_service.dart';
import '../../../../core/utils/validators.dart';

class AuthRepository {
  final SupabaseService _supabase;
  final FcmNotificationService _fcmNotifications;
  final loqmaAnalytics _analytics;
  final String? _webVapidKey;

  AuthRepository(
    this._supabase, {
    FcmNotificationService? fcmNotifications,
    loqmaAnalytics? analytics,
    String? webVapidKey,
  })  : _fcmNotifications = fcmNotifications ?? FcmNotificationService(),
        _analytics = analytics ?? loqmaAnalytics(),
        _webVapidKey = webVapidKey;

  // ═══════════════════════════════════════════════════════════
  // 🎯 الأدوار المدعومة (3 بس)
  // ═══════════════════════════════════════════════════════════
  static const Set<String> _supportedRoles = {
    'user',
    'provider',
    'institution',
  };

  // ═══════════════════════════════════════════════════════════
  // 🔧 Helpers
  // ═══════════════════════════════════════════════════════════
  String _cleanPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (cleaned.length == 10) {
      cleaned = '20$cleaned';
    }
    return cleaned;
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('already') ||
        raw.contains('exists') ||
        raw.contains('duplicate') ||
        raw.contains('23505')) {
      if (raw.contains('phone')) {
        return 'رقم الهاتف مسجل بالفعل. استخدم رقمًا آخر.';
      }
      return 'الحساب مسجل بالفعل.';
    }
    if (raw.contains('invalid phone') || raw.contains('رقم غير صحيح')) {
      return 'رقم الهاتف غير صحيح.';
    }
    if (raw.contains('rate') ||
        raw.contains('too many') ||
        raw.contains('429')) {
      return 'تمت محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';
    }
    if (raw.contains('otp') || raw.contains('code')) {
      return 'كود التحقق غير صحيح أو منتهي.';
    }
    if (raw.contains('expired')) {
      return 'انتهت صلاحية الكود. اطلب كود جديد.';
    }
    if (raw.contains('authretryablefetchexception') ||
        raw.contains('fetch') ||
        raw.contains('clientexception') ||
        raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection')) {
      return 'تعذر الاتصال بالخدمة. تحقق من الإنترنت وحاول تاني.';
    }
    if (raw.contains('23502') || raw.contains('not-null')) {
      return 'تعذر حفظ البيانات. تأكد من اكتمال البيانات.';
    }
    if (raw.contains('42501') || raw.contains('permission denied')) {
      return 'ليس لديك صلاحية لإتمام العملية.';
    }
    return 'تعذر إتمام العملية حاليًا. حاول تاني.';
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 FCM
  // ═══════════════════════════════════════════════════════════
  Future<void> _initializeFcmForUser(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;

    try {
      await _fcmNotifications.dispose();
      await _fcmNotifications.initialize(
        webVapidKey: _webVapidKey,
        onTokenChanged: (token) => _supabase.upsertFcmDevice(
          userId: cleanUserId,
          fcmToken: token,
        ),
        onNotificationTap: (data) async {
          debugPrint(
            '[FCM] notification tap type=${data['type']?.toString() ?? 'unknown'}',
          );
        },
      );
      debugPrint('[FCM] initialized');
    } catch (error, stack) {
      debugPrint('[FCM] initialization skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 إرسال كود التحقق على واتساب
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, String>> sendOtp({required String phone}) async {
    try {
      final cleanPhone = _cleanPhone(phone);

      if (cleanPhone.length < 10 || cleanPhone.length > 15) {
        return const Left('رقم الهاتف غير صحيح');
      }

      debugPrint('📤 Sending OTP to $cleanPhone');

      final response = await _supabase.client.functions.invoke(
        'send-otp',
        body: {'phone': cleanPhone},
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ sendOtp error: $err');
        if (err.contains('rate') || err.contains('too many')) {
          return const Left('انتظر دقيقة قبل طلب كود جديد');
        }
        return Left(err.isNotEmpty ? err : 'تعذر إرسال الكود');
      }

      final returnedPhone = data['phone']?.toString() ?? cleanPhone;
      debugPrint('✅ OTP sent to $returnedPhone');
      return Right(returnedPhone);
    } catch (error) {
      debugPrint('❌ sendOtp exception: ${error.runtimeType}');
      return Left(_friendlyAuthError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ التحقق + إنشاء/دخول الحساب
  // بترجّع Map فيه {user, isNewUser}
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, Map<String, dynamic>>> verifyAndCreate({
    required String phone,
    required String code,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);
      final cleanCode = code.trim();

      if (!RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
        return const Left('الكود يجب أن يكون 6 أرقام');
      }

      // ✅ التحقق من الدور
      final role = (profile['role'] ?? 'user').toString().toLowerCase();
      if (!_supportedRoles.contains(role)) {
        return const Left('نوع الحساب غير مدعوم');
      }

      debugPrint('📥 Verifying OTP for $cleanPhone (role=$role)');

      final response = await _supabase.client.functions.invoke(
        'verify-and-create',
        body: {
          'phone': cleanPhone,
          'code': cleanCode,
          'profile': profile,
        },
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('❌ verifyAndCreate error: $err');
        return Left(err.isNotEmpty ? err : 'كود التحقق غير صحيح');
      }

      // ✅ نثبّت الجلسة
      final refreshToken = data['refresh_token']?.toString();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _supabase.client.auth.setSession(refreshToken);
      }

      // ✅ نحمّل بيانات المستخدم كاملة
      final userId = data['user']?['id']?.toString() ?? '';
      if (userId.isEmpty) {
        return const Left('تعذر تحميل بيانات المستخدم');
      }

      final user = await _loadUserWithRelations(userId);
      if (user == null) {
        return const Left('ملف المستخدم غير موجود');
      }

      // ✅ FCM + Analytics
      await _initializeFcmForUser(user.id);

      final isNewUser = data['isNewUser'] == true;
      if (isNewUser) {
        await _analytics.userSignup(userRole: user.type.value);
      } else {
        await _analytics.userLogin(userRole: user.type.value);
      }

      debugPrint('✅ Auth success: ${isNewUser ? "new" : "existing"} user');

      // ✅ نرجّع Map فيه user + isNewUser
      return Right({
        'user': user,
        'isNewUser': isNewUser,
      });
    } on AuthApiException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      if (code.contains('otp') || code.contains('token')) {
        return const Left('كود التحقق غير صحيح أو منتهي');
      }
      debugPrint('❌ verifyAndCreate AuthApiException: ${error.code}');
      return Left(_friendlyAuthError(error));
    } catch (error, stack) {
      debugPrint('❌ verifyAndCreate exception: ${error.runtimeType}');
      debugPrintStack(stackTrace: stack);
      return Left(_friendlyAuthError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 التسجيل (يُستخدم مع verifyAndCreate)
  // ═══════════════════════════════════════════════════════════
  /// بياخد بيانات التسجيل + يبعت OTP
  /// (ملاحظة: الحساب نفسه بيتعمل في verify-and-create)
  Future<Either<String, String>> register({
    required String name,
    required String phone,
    required String role,
    String? city,
    // حقول مقدم الخدمة (اختيارية)
    String? categoryId,
    String? providerType,
    String? address,
    String? bio,
    int? experienceYears,
    List<String>? skills,
    List<String>? serviceAreas,
    String? pricingType,
    double? priceFrom,
    // حقول المؤسسة (اختيارية)
    String? institutionType,
    String? commercialRegister,
    String? taxId,
  }) async {
    try {
      // ✅ 1. التحقق من البيانات
      final cleanName = name.trim();
      final cleanPhone = _cleanPhone(phone);
      final cleanRole = role.trim().toLowerCase();

      if (!Validators.isValidName(cleanName)) {
        return const Left('الاسم غير صالح (3 أحرف على الأقل)');
      }
      if (cleanPhone.length < 10) {
        return const Left('رقم الهاتف غير صحيح');
      }
      if (!_supportedRoles.contains(cleanRole)) {
        return const Left('نوع الحساب غير مدعوم');
      }

      // ✅ 2. التحقق من إضافي حسب الدور
      if (cleanRole == 'provider') {
        if (categoryId == null || categoryId.isEmpty) {
          return const Left('اختار نوع الخدمة');
        }
      }
      if (cleanRole == 'institution') {
        if (institutionType == null || institutionType.isEmpty) {
          return const Left('اختار نوع المؤسسة');
        }
      }

      // ✅ 3. نبعت OTP
      debugPrint('📤 Register: sending OTP to $cleanPhone (role=$cleanRole)');
      final otpResult = await sendOtp(phone: cleanPhone);

      return otpResult.fold(
        (err) => Left(err),
        (returnedPhone) => Right(returnedPhone),
      );
    } catch (error, stack) {
      debugPrint('❌ register exception: ${error.runtimeType}');
      debugPrintStack(stackTrace: stack);
      return Left(_friendlyAuthError(error));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 إعادة إرسال OTP
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, String>> resendOtp({required String phone}) async {
    return sendOtp(phone: phone);
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 تسجيل خروج
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, void>> logout() async {
    try {
      await _fcmNotifications.dispose();
      await _supabase.signOut();
      return const Right(null);
    } catch (error) {
      debugPrint('LOGOUT FAILURE: type=${error.runtimeType}');
      return const Left('حدث خطأ أثناء تسجيل الخروج');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 تحميل بيانات المستخدم
  // ═══════════════════════════════════════════════════════════
  Future<UserModel?> _loadUserWithRelations(String userId) async {
    try {
      final row = await _supabase.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (row == null) return null;

      final rawRole = row['role']?.toString().trim().toLowerCase() ??
          row['user_type']?.toString().trim().toLowerCase();

      if (!_supportedRoles.contains(rawRole)) {
        debugPrint('AUTH ROLE INVALID: role=$rawRole');
        return null;
      }

      var user = UserModel.fromJson(Map<String, dynamic>.from(row));
      final type = user.type.value.toLowerCase();

      // ✅ مقدم خدمة → نجيب service_provider_id
      if (type == 'provider') {
        try {
          final provider = await _supabase.client
              .from('service_providers')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();
          if (provider != null) {
            user = user.copyWith(
              serviceProviderId: _id(provider['id']),
            );
          }
        } catch (e) {
          debugPrint('PROVIDER ENRICHMENT SKIPPED: $e');
        }
      }

      // ✅ مؤسسة → نجيب institution_id
      if (type == 'institution') {
        try {
          final inst = await _supabase.client
              .from('institutions')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();
          if (inst != null) {
            user = user.copyWith(
              institutionId: _id(inst['id']),
            );
          }
        } catch (e) {
          debugPrint('INSTITUTION ENRICHMENT SKIPPED: $e');
        }
      }

      return user;
    } catch (error) {
      debugPrint('LOAD USER FAILURE: type=${error.runtimeType}');
      return null;
    }
  }

  Future<Either<String, UserModel>> getUser(String id) async {
    try {
      final user = await _loadUserWithRelations(id);
      if (user == null) return const Left('المستخدم غير موجود');
      return Right(user);
    } catch (error) {
      debugPrint('GET USER FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحميل المستخدم');
    }
  }

  Future<Either<String, UserModel>> getCurrentUserFromDb() async {
    try {
      final authUser = await _supabase.getCurrentUser();
      if (authUser == null) return const Left('المستخدم غير مسجل دخول');
      final user = await _loadUserWithRelations(authUser.id);
      if (user == null) return const Left('ملف المستخدم غير موجود');
      return Right(user);
    } catch (error) {
      debugPrint('CURRENT USER LOAD ERROR: type=${error.runtimeType}');
      return const Left('تعذر تحميل ملف الحساب. حاول تسجيل الدخول تاني.');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 تحديث بيانات المستخدم
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, UserModel>> updateUser({
    required String id,
    String? name,
    String? phone,
    String? avatarUrl,
    String? city,
    String? address,
    String? role,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name.trim();
      if (phone != null) data['phone'] = phone.trim();
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (city != null) data['city'] = city.trim();
      if (address != null) data['address'] = address.trim();
      // role change is admin-only → بنتجاهله
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase.client
          .from('users')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return Right(UserModel.fromJson(Map<String, dynamic>.from(response)));
    } catch (error) {
      debugPrint('UPDATE USER FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحديث البيانات');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔐 الجلسة
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, bool>> isLoggedIn() async {
    try {
      return Right(await _supabase.getCurrentSession() != null);
    } catch (_) {
      return const Right(false);
    }
  }

  Future<Either<String, dynamic>> getCurrentSession() async {
    try {
      final session = await _supabase.getCurrentSession();
      if (session == null) return const Left('لا توجد جلسة نشطة');
      return Right(session);
    } catch (error) {
      debugPrint('GET SESSION FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحميل الجلسة');
    }
  }

  Future<Either<String, dynamic>> getCurrentAuthUser() async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return const Left('المستخدم غير مسجل دخول');
      return Right(user);
    } catch (error) {
      debugPrint('GET AUTH USER FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحميل المستخدم الحالي');
    }
  }

  Future<Either<String, Map<String, dynamic>>> getSessionWithUserType() async {
    final sessionResult = await getCurrentSession();
    if (sessionResult.isLeft()) {
      return Left(sessionResult.swap().getOrElse(() => 'لا توجد جلسة'));
    }

    final session = sessionResult.getOrElse(() => null);
    final userResult = await getCurrentUserFromDb();
    if (userResult.isLeft()) {
      return Left(userResult.swap().getOrElse(() => 'المستخدم غير موجود'));
    }

    final user = userResult.getOrElse(() => throw StateError('missing user'));

    return Right({
      'user': user,
      'role': user.type.value,
      'serviceProviderId': user.serviceProviderId,
      'institutionId': user.institutionId,
      'session': session,
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🆔 Relations
  // ═══════════════════════════════════════════════════════════
  Future<Either<String, String>> getProviderId(String userId) async {
    return _getRelatedId(
      table: 'service_providers',
      userId: userId,
      missingMessage: 'بروفايل مقدم الخدمة غير موجود',
    );
  }

  Future<Either<String, String>> getInstitutionId(String userId) async {
    return _getRelatedId(
      table: 'institutions',
      userId: userId,
      missingMessage: 'المؤسسة غير موجودة',
    );
  }

  Future<Either<String, String>> _getRelatedId({
    required String table,
    required String userId,
    required String missingMessage,
  }) async {
    try {
      final row = await _supabase.client
          .from(table)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      final id = _id(row?['id']);
      return id == null ? Left(missingMessage) : Right(id);
    } catch (error) {
      debugPrint('GET RELATED ID FAILURE: table=$table');
      return const Left('تعذر تحميل البيانات');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 Helpers
  // ═══════════════════════════════════════════════════════════
  static String? _id(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }
}
