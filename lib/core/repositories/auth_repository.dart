import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/analytics_service.dart';
import '../services/fcm_notification_service.dart';
import '../services/supabase_service.dart';
import '../utils/validators.dart';

class AuthRepository {
  final SupabaseService _supabase;
  final FcmNotificationService _fcmNotifications;
  final LoqmaAnalytics _analytics;
  final String? _webVapidKey;

  AuthRepository(
    this._supabase, {
    FcmNotificationService? fcmNotifications,
    LoqmaAnalytics? analytics,
    String? webVapidKey,
  })  : _fcmNotifications = fcmNotifications ?? FcmNotificationService(),
        _analytics = analytics ?? LoqmaAnalytics(),
        _webVapidKey = webVapidKey;

  static const Set<String> _businessTypes = {
    'restaurant',
    'business',
    'hotel',
    'supermarket',
    'bakery',
    'cafe',
  };

  static const String _institutionType = 'institution';

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('already') ||
        raw.contains('exists') ||
        raw.contains('duplicate') ||
        raw.contains('23505')) {
      if (raw.contains('phone')) {
        return 'رقم الهاتف مسجل بالفعل. استخدم رقمًا آخر.';
      }
      return 'البريد الإلكتروني مسجل بالفعل. استخدم بريدًا آخر.';
    }
    if (raw.contains('invalid email')) return 'البريد الإلكتروني غير صحيح.';
    if (raw.contains('password') || raw.contains('كلمة المرور')) {
      return 'كلمة المرور ضعيفة أو غير صالحة.';
    }
    if (raw.contains('rate') ||
        raw.contains('too many') ||
        raw.contains('429')) {
      return 'تمت محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';
    }
    if (raw.contains('authretryablefetchexception') ||
        raw.contains('fetch') ||
        raw.contains('clientexception') ||
        raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection')) {
      return 'تعذر الاتصال بخدمة التسجيل. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    if (raw.contains('23502') || raw.contains('not-null')) {
      return 'تعذر حفظ بيانات الحساب. تأكد من اكتمال البيانات.';
    }
    if (raw.contains('42501') || raw.contains('permission denied')) {
      return 'ليس لديك صلاحية لإتمام العملية.';
    }
    return 'تعذر إتمام العملية حاليًا. حاول مرة أخرى.';
  }

  Future<void> _initializeFcmForUser(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return;

    try {
      // Rebind the callback when a different account logs in on the same
      // process. This prevents a refreshed token from being saved for the
      // previous account.
      await _fcmNotifications.dispose();
      await _fcmNotifications.initialize(
        webVapidKey: _webVapidKey,
        onTokenChanged: (token) => _supabase.upsertFcmDevice(
          userId: cleanUserId,
          fcmToken: token,
        ),
        onNotificationTap: (data) async {
          // Navigation remains in the presentation layer. The data is logged
          // only as keys/type; no email, phone, token, or private payload is
          // written to logs.
          debugPrint(
            '[FCM] notification tap type=${data['type']?.toString() ?? 'unknown'}',
          );
        },
      );
      debugPrint('[FCM] initialized for authenticated user');
    } catch (error, stack) {
      // A notification problem must never make a valid login fail.
      debugPrint('[FCM] initialization skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<Either<String, UserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final session = await _supabase.signIn(cleanEmail, password);
      if (session == null) {
        return const Left('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }

      final user = await _loadUserWithRelations(session.user.id);
      if (user == null) {
        return const Left('تم تسجيل الدخول لكن ملف المستخدم غير موجود');
      }

      final activeRow = await _supabase.client
          .from('users')
          .select('is_active, is_verified')
          .eq('id', user.id)
          .maybeSingle();
      final isActive = activeRow?['is_active'] == true;
      final isVerified = activeRow?['is_verified'] == true;
      if (!isActive || !isVerified) {
        return const Left('يرجى تأكيد البريد الإلكتروني أولًا');
      }

      await _initializeFcmForUser(user.id);
      await _analytics.userLogin(userRole: user.type.value);
      debugPrint('AUTH LOGIN: role=${user.type.value}');
      return Right(user);
    } on AuthApiException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      if (code == 'email_not_confirmed') {
        return const Left('يرجى تأكيد البريد الإلكتروني أولًا');
      }
      if (code == 'invalid_credentials') {
        return const Left('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      }
      if (code == 'user_banned') return const Left('الحساب محظور');
      debugPrint('AUTH LOGIN FAILURE: code=${error.code}');
      return Left(_friendlyAuthError(error));
    } catch (error) {
      debugPrint('AUTH LOGIN FAILURE: type=${error.runtimeType}');
      return Left(_friendlyAuthError(error));
    }
  }

  Future<Either<String, String>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? userType,
  }) async {
    String stage = 'register_started';
    try {
      debugPrint('[RegisterDebug] stage=$stage');
      final cleanName = name.trim();
      final cleanPhone = phone.trim();
      final cleanEmail = email.trim().toLowerCase();
      final cleanType = (userType ?? 'user').trim().toLowerCase();

      if (!Validators.isValidName(cleanName)) {
        return const Left('الاسم غير صالح (3 أحرف على الأقل)');
      }
      if (!Validators.isValidPhone(cleanPhone)) {
        return const Left('رقم الهاتف غير صالح');
      }
      if (!Validators.isValidEmail(cleanEmail)) {
        return const Left('البريد الإلكتروني غير صالح');
      }
      if (!Validators.isValidPassword(password)) {
        return const Left('كلمة المرور ضعيفة (6 أحرف على الأقل)');
      }

      stage = 'before_auth_sign_up';
      debugPrint(
          '[RegisterDebug] stage=$stage email=$cleanEmail passwordLength=${password.length} userType=$cleanType');
      final authResponse = await _supabase.client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': cleanName,
          'phone': cleanPhone,
          'user_type': cleanType,
        },
      );

      stage = 'after_auth_sign_up';
      debugPrint(
          '[RegisterDebug] stage=$stage hasAuthUser=${authResponse.user != null} hasSession=${authResponse.session != null}');
      final authUser = authResponse.user;
      if (authUser == null) {
        return const Left('فشل إنشاء الحساب في المصادقة');
      }

      // Do not create public.users before OTP verification.
      // verify_signup_email_code creates the profile atomically after success.
      stage = 'before_signup_otp_issue';
      debugPrint('[RegisterDebug] stage=$stage authUserId=${authUser.id}');
      final otpResult = await issueSignupEmailCode(
        userId: authUser.id,
        email: cleanEmail,
        name: cleanName,
        phone: cleanPhone,
      );
      String? otpError;
      otpResult.fold((error) => otpError = error, (_) {});
      if (otpError != null) {
        // الحساب اتعمل في auth بالفعل، لكن الكود فشل يوصل (مثلاً مشكلة
        // مؤقتة في خدمة الإرسال). نوضح ده للمستخدم بدل رسالة فشل عامة
        // موهمة إن التسجيل كله فشل.
        stage = 'signup_otp_issue_failed';
        debugPrint('[RegisterDebug] stage=$stage authUserId=${authUser.id}');
        return Left(
          '$otpError\nيمكنك طلب إعادة إرسال الكود من صفحة التحقق.',
        );
      }

      stage = 'register_waiting_for_otp';
      debugPrint('[RegisterDebug] stage=$stage userId=${authUser.id}');
      return Right(authUser.id);
    } on AuthApiException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      if (code.contains('already') ||
          code.contains('exists') ||
          message.contains('already registered') ||
          message.contains('already exists') ||
          message.contains('user already')) {
        return const Left('البريد الإلكتروني مسجل بالفعل في النظام');
      }
      if (code.contains('weak') || message.contains('password')) {
        return const Left('كلمة المرور ضعيفة أو غير صالحة');
      }
      if (code.contains('rate') || message.contains('too many')) {
        return const Left('تمت محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى');
      }
      debugPrint(
        '[RegisterDebug] stage=$stage AuthApiException '
        'code=${error.code} status=${error.statusCode} '
        'message=${error.message}',
      );
      return Left(_friendlyAuthError(error));
    } catch (error, stackTrace) {
      debugPrint('AUTH REGISTER FAILURE: stage=$stage');
      debugPrint('AUTH REGISTER FAILURE: type=${error.runtimeType}');
      debugPrint('AUTH REGISTER FAILURE: error=$error');
      debugPrint('AUTH REGISTER FAILURE: stack=$stackTrace');
      return Left(_friendlyAuthError(error));
    }
  }

  Future<Either<String, Map<String, dynamic>>> verifyOrganizationAccessOtp(
    String otp,
  ) async {
    try {
      final cleanOtp = otp.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(cleanOtp)) {
        return const Left('كود المؤسسة يجب أن يتكون من 6 أرقام');
      }

      final rawResponse = await _supabase.client.rpc(
        'verify_organization_access_otp',
        params: {'p_otp': cleanOtp},
      );
      final data = _asMap(rawResponse);
      if (data == null || data['success'] != true) {
        return const Left('تعذر التحقق من كود المؤسسة');
      }

      debugPrint('ORGANIZATION OTP: verified');
      return Right(data);
    } on PostgrestException catch (error) {
      debugPrint('ORGANIZATION OTP FAILURE: code=${error.code}');
      final message = error.message.toLowerCase();
      if (message.contains('wrong') || message.contains('غير صحيح')) {
        return const Left('كود المؤسسة غير صحيح');
      }
      if (message.contains('locked') || message.contains('مؤقت')) {
        return const Left('تم إيقاف المحاولات مؤقتًا. حاول بعد قليل');
      }
      return const Left('تعذر التحقق من كود المؤسسة');
    } catch (error) {
      debugPrint('ORGANIZATION OTP FAILURE: type=${error.runtimeType}');
      return const Left('تعذر التحقق من كود المؤسسة حاليًا');
    }
  }

  /// يبعت كود التحقق عبر Edge Function اللي بتكلم Resend.
  ///
  /// ملحوظة: ده بينادي Supabase Edge Function اسمها
  /// `issue-signup-email-code` (مش RPC). لازم تكون منشورة فعلاً:
  ///   supabase functions deploy issue-signup-email-code
  ///   supabase secrets set RESEND_API_KEY=...
  Future<Either<String, void>> issueSignupEmailCode({
    required String userId,
    required String email,
    String? name,
    String? phone,
  }) async {
    try {
      final body = <String, dynamic>{
        'p_user_id': userId,
        'p_email': email.trim().toLowerCase(),
      };
      if (name != null && phone != null) {
        body['p_name'] = name.trim();
        body['p_phone'] = phone.trim();
      }

      final response = await _supabase.client.functions.invoke(
        'issue-signup-email-code',
        body: body,
      );

      final data = _asMap(response.data);
      if (data == null || data['success'] != true) {
        final err = data?['error']?.toString() ?? '';
        debugPrint('SIGNUP CODE ISSUE FAILURE: server_error=$err');
        if (err == 'rate_limited') {
          return const Left('انتظر دقيقة قبل طلب كود جديد');
        }
        return const Left('تعذر إرسال كود التحقق');
      }
      return const Right(null);
    } catch (error) {
      debugPrint(
        'SIGNUP CODE ISSUE FAILURE: type=${error.runtimeType} error=$error',
      );
      return const Left('تعذر إرسال كود التحقق حاليًا');
    }
  }

  Future<Either<String, void>> resendSignupEmailOtp({
    required String email,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      if (!Validators.isValidEmail(cleanEmail)) {
        return const Left('البريد الإلكتروني غير صحيح');
      }
      final authUserId = _supabase.client.auth.currentUser?.id;
      if (authUserId == null || authUserId.trim().isEmpty) {
        return const Left('انتهت جلسة التسجيل. أعد التسجيل مرة أخرى');
      }

      final result = await issueSignupEmailCode(
        userId: authUserId,
        email: cleanEmail,
      );
      debugPrint('RESEND SIGNUP CODE: resend requested');
      return result;
    } on AuthApiException catch (error) {
      return Left(_friendlyAuthError(error));
    } catch (error) {
      debugPrint('EMAIL OTP RESEND FAILURE: type=${error.runtimeType}');
      return Left(_friendlyAuthError(error));
    }
  }

  Future<Either<String, UserModel>> verifySignupEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanToken = token.trim();
      if (!Validators.isValidEmail(cleanEmail)) {
        return const Left('البريد الإلكتروني غير صحيح');
      }
      if (!RegExp(r'^\d{6}$').hasMatch(cleanToken)) {
        return const Left('كود التحقق يجب أن يتكون من 6 أرقام');
      }

      final authUserId = _supabase.client.auth.currentUser?.id;
      if (authUserId == null || authUserId.trim().isEmpty) {
        return const Left('انتهت جلسة التسجيل. أعد التسجيل مرة أخرى');
      }

      final response = await _supabase.client.rpc(
        'verify_signup_email_code',
        params: {
          'p_user_id': authUserId,
          'p_email': cleanEmail,
          'p_code': cleanToken,
        },
      );
      final data = _asMap(response);
      if (data == null || data['success'] != true) {
        return const Left('كود التحقق غير صحيح أو منتهي');
      }

      final user = await _loadUserWithRelations(authUserId);
      if (user == null) {
        return const Left('تم تأكيد البريد لكن ملف المستخدم غير موجود');
      }
      await _initializeFcmForUser(user.id);
      await _analytics.userSignup(userRole: user.type.value);
      debugPrint('EMAIL OTP: verified and user activated');
      return Right(user);
    } on AuthApiException catch (error) {
      final code = (error.code ?? '').toLowerCase();
      if (code.contains('otp') ||
          code.contains('token') ||
          code.contains('expired')) {
        return const Left('كود التحقق غير صحيح أو منتهي');
      }
      return Left(_friendlyAuthError(error));
    } catch (error) {
      debugPrint('EMAIL OTP VERIFY FAILURE: type=${error.runtimeType}');
      return Left(_friendlyAuthError(error));
    }
  }

  /// `users.user_type` is the explicit role source. Organization rows only
  /// enrich the matching role with IDs; they never change a normal user into
  /// a restaurant or charity.
  Future<UserModel?> _loadUserWithRelations(String userId) async {
    final row = await _supabase.client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;

    final rawRole = row['user_type']?.toString().trim().toLowerCase();
    if (!_isSupportedRole(rawRole)) {
      debugPrint('AUTH ROLE INVALID: user_type=$rawRole');
      return null;
    }

    var user = UserModel.fromJson(Map<String, dynamic>.from(row));
    final type = user.type.value.toLowerCase();

    try {
      final organization = await _supabase.client
          .from('organizations')
          .select(
            'organization_type, status, is_verified, business_id, '
            'restaurant_id, charity_id',
          )
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (organization != null) {
        final organizationType =
            organization['organization_type']?.toString().trim().toLowerCase();
        final typeMatches = _organizationMatchesUserType(
          organizationType,
          type,
        );

        if (!typeMatches) {
          debugPrint(
            'AUTH ROLE CONFLICT: userType=$type organizationType=$organizationType',
          );
          return user;
        }

        user = user.copyWith(
          businessId: _id(organization['business_id']),
          restaurantId: _id(organization['restaurant_id']),
          charityId: _id(organization['charity_id']),
        );
        return user;
      }

      // Legacy enrichment is restricted to the already explicit role.
      if (type == _institutionType) {
        final institution = await _supabase.client
            .from('institutions')
            .select('id')
            .eq('user_id', user.id)
            .eq('status', 'active')
            .maybeSingle();
        user = user.copyWith(
          institutionId: _id(institution?['id']),
        );
      } else if (_businessTypes.contains(type)) {
        final business = await _supabase.client
            .from('businesses')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        final restaurant = await _supabase.client
            .from('restaurants')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        user = user.copyWith(
          businessId: _id(business?['id']),
          restaurantId: _id(restaurant?['id']),
        );
      } else if (type == 'charity') {
        final charity = await _supabase.client
            .from('charities')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();
        user = user.copyWith(charityId: _id(charity?['id']));
      }
    } catch (error) {
      debugPrint('AUTH RELATION ENRICHMENT SKIPPED: type=${error.runtimeType}');
    }

    return user;
  }

  static bool _isSupportedRole(String? value) {
    return value == 'user' ||
        value == 'charity' ||
        value == _institutionType ||
        _businessTypes.contains(value);
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

  Future<Either<String, UserModel>> getUserByEmail(String email) async {
    try {
      final row = await _supabase.client
          .from('users')
          .select('id')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      if (row == null) return const Left('المستخدم غير موجود');
      return getUser(_id(row['id']) ?? '');
    } catch (error) {
      debugPrint('GET USER BY EMAIL FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحميل المستخدم');
    }
  }

  Future<Either<String, UserModel>> updateUser({
    required String id,
    String? name,
    String? phone,
    String? avatarUrl,
    String? city,
    String? address,
    String? userType,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name.trim();
      if (phone != null) data['phone'] = phone.trim();
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (city != null) data['city'] = city.trim();
      if (address != null) data['address'] = address.trim();
      // userType is intentionally ignored: role changes must be admin-only.
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
      return const Left('تعذر تحديث بيانات المستخدم');
    }
  }

  Future<Either<String, void>> resetPassword(String email) async {
    try {
      await _supabase.client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
      );
      return const Right(null);
    } catch (error) {
      debugPrint('RESET PASSWORD FAILURE: type=${error.runtimeType}');
      return const Left('تعذر إرسال رابط استعادة كلمة المرور');
    }
  }

  Future<Either<String, void>> sendResetOtp(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final exists = await _supabase.userExistsByEmail(cleanEmail);
      if (!exists) return const Left('البريد الإلكتروني غير مسجل');
      final otp = _supabase.generateOtp();
      await _supabase.saveOtp(cleanEmail, otp);
      debugPrint('PASSWORD OTP: generated');
      return const Right(null);
    } catch (error) {
      debugPrint('SEND RESET OTP FAILURE: type=${error.runtimeType}');
      return const Left('تعذر إرسال كود استعادة كلمة المرور');
    }
  }

  Future<Either<String, bool>> verifyResetOtp({
    required String email,
    required String code,
  }) async {
    try {
      final valid =
          await _supabase.verifyOtp(email.trim().toLowerCase(), code.trim());
      if (!valid) return const Left('الكود غير صحيح أو منتهي الصلاحية');
      return const Right(true);
    } catch (error) {
      debugPrint('VERIFY RESET OTP FAILURE: type=${error.runtimeType}');
      return const Left('تعذر التحقق من كود الاستعادة');
    }
  }

  Future<Either<String, void>> updatePassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      if (!Validators.isValidPassword(newPassword)) {
        return const Left('كلمة المرور ضعيفة (6 أحرف على الأقل)');
      }
      await _supabase.updatePasswordInAuth(email, newPassword);
      return const Right(null);
    } catch (error) {
      debugPrint('UPDATE PASSWORD FAILURE: type=${error.runtimeType}');
      return const Left('تعذر تحديث كلمة المرور');
    }
  }

  Future<Either<String, String>> getUserType() async {
    final result = await getCurrentUserFromDb();
    return result.fold(
      (error) => Left(error),
      (user) => Right(user.type.value),
    );
  }

  Future<Either<String, String>> getBusinessId(String userId) async {
    return _getRelatedId(
      table: 'businesses',
      userId: userId,
      missingMessage: 'المؤسسة غير موجودة',
    );
  }

  Future<Either<String, String>> getRestaurantId(String userId) async {
    return _getRelatedId(
      table: 'restaurants',
      userId: userId,
      missingMessage: 'المطعم غير موجود',
    );
  }

  Future<Either<String, String>> getCharityId(String userId) async {
    return _getRelatedId(
      table: 'charities',
      userId: userId,
      missingMessage: 'الجمعية غير موجودة',
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
      return const Left('تعذر تحميل بيانات المؤسسة');
    }
  }

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

  Future<Either<String, UserModel>> getCurrentUserFromDb() async {
    try {
      final authUser = await _supabase.getCurrentUser();
      if (authUser == null) return const Left('المستخدم غير مسجل دخول');
      final user = await _loadUserWithRelations(authUser.id);
      if (user == null) return const Left('ملف المستخدم غير موجود');
      return Right(user);
    } catch (error) {
      debugPrint('CURRENT USER LOAD ERROR: type=${error.runtimeType}');
      return const Left('تعذر تحميل ملف الحساب. حاول تسجيل الدخول مرة أخرى.');
    }
  }

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
      'userType': user.type.value,
      'restaurantId': user.restaurantId,
      'businessId': user.businessId,
      'charityId': user.charityId,
      'session': session,
    });
  }

  /// Kept for API compatibility. Navigation belongs to the presentation layer.
  Future<void> navigateByUserType({
    required BuildContext context,
    required String userType,
    String? restaurantId,
    String? charityId,
  }) async {}

  static bool _organizationMatchesUserType(
    String? organizationType,
    String userType,
  ) {
    if (organizationType == null || organizationType.isEmpty) return true;
    if (userType == 'charity') return organizationType == 'charity';
    if (userType == _institutionType) {
      return organizationType == _institutionType ||
          organizationType == 'business';
    }
    if (userType == 'restaurant') {
      return organizationType == 'business' || organizationType == 'restaurant';
    }
    return false;
  }

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
