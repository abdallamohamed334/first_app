// lib/features/profile/presentation/bloc/profile_bloc.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/crashlytics_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SupabaseService _supabaseService;
  final StorageService _storageService;
  final AuthService _authService;
  final loqmaCrashlytics _crashlytics;

  ProfileBloc({
    SupabaseService? supabaseService,
    StorageService? storageService,
    AuthService? authService,
    loqmaCrashlytics? crashlytics,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _storageService = storageService ?? StorageService.instance,
        _authService = authService ?? AuthService(),
        _crashlytics = crashlytics ?? loqmaCrashlytics(),
        super(const ProfileInitial()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileUpdateUser>(_onUpdateUser);
    on<ProfileSignOut>(_onSignOut);
    on<ProfileUploadAvatar>(_onUploadAvatar);
    // ✅ اتشال _onUpdatePassword — مفيش password في النظام الجديد
  }

  // ═══════════════════════════════════════════════════════════
  // Load Profile
  // ═══════════════════════════════════════════════════════════
  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    await _crashlytics.setCurrentScreen('profile');

    try {
      // ✅ نجيب المستخدم الحالي من Auth
      final authUser = await _supabaseService.getCurrentUser();
      if (authUser == null) {
        emit(const ProfileError('المستخدم غير موجود'));
        return;
      }

      // ✅ نجيب بيانات المستخدم من جدول users بالـ ID
      final user = await _supabaseService.getUserById(authUser.id);
      if (user == null) {
        emit(const ProfileError('المستخدم غير موجود في قاعدة البيانات'));
        return;
      }

      final results = await Future.wait<Object?>([
        _supabaseService.getUserTotalPoints(user.id),
        _supabaseService.getUserDeliveriesCount(user.id),
        _supabaseService.getUserMealsSaved(user.id),
        _supabaseService.getUserRewards(user.id),
        _supabaseService.getUserCompletedTasks(user.id),
      ]);

      final points = _asInt(results[0]);
      final deliveries = _asInt(results[1]);
      final meals = _asInt(results[2]);
      final rewards = results[3] is List<RewardData>
          ? results[3] as List<RewardData>
          : const <RewardData>[];
      final tasks = _asInt(results[4]);

      emit(ProfileLoaded(
        user: user.copyWith(
          points: points,
          mealsSaved: meals,
          tasksCompleted: tasks,
        ),
        points: points,
        deliveriesCount: deliveries,
        mealsSaved: meals,
        rewards: rewards,
        completedTasks: tasks,
      ));
    } catch (error, stackTrace) {
      await _log('profile_load_failed', error, stackTrace);
      emit(const ProfileError('تعذر تحميل بيانات الملف الشخصي حاليًا'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Update User
  // ═══════════════════════════════════════════════════════════
  Future<void> _onUpdateUser(
    ProfileUpdateUser event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final user = await _currentUser();
      if (user == null) {
        emit(const ProfileError('المستخدم غير موجود'));
        return;
      }

      final updatedUser = await _supabaseService.updateProfile(
        userId: user.id,
        name: event.name?.trim().isNotEmpty == true
            ? event.name!.trim()
            : user.name,
        phone: _optional(event.phone),
        city: _optional(event.city),
        address: _optional(event.address),
        avatarUrl: _optional(event.avatarUrl),
      );
      emit(ProfileUpdated(user: updatedUser));
    } catch (error, stackTrace) {
      await _log('profile_update_failed', error, stackTrace);
      emit(const ProfileError('تعذر تحديث البيانات حاليًا'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Sign Out
  // ═══════════════════════════════════════════════════════════
  Future<void> _onSignOut(
    ProfileSignOut event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      await _authService.signOut();
      if (!isClosed) emit(const ProfileSignedOut());
    } catch (error, stackTrace) {
      await _log('profile_sign_out_failed', error, stackTrace);
      if (!isClosed) {
        emit(const ProfileError('تعذر تسجيل الخروج حاليًا. حاول مرة أخرى'));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Upload Avatar
  // ═══════════════════════════════════════════════════════════
  Future<void> _onUploadAvatar(
    ProfileUploadAvatar event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final user = await _currentUser();
      if (user == null) {
        emit(const ProfileError('المستخدم غير موجود'));
        return;
      }

      final avatarUrl = await _storageService.uploadAvatar(
        userId: user.id,
        imageFile: event.imageFile,
      );
      if (avatarUrl == null || avatarUrl.isEmpty) {
        emit(const ProfileError('تعذر رفع الصورة'));
        return;
      }

      emit(ProfileUpdated(user: user.copyWith(avatarUrl: avatarUrl)));
    } catch (error, stackTrace) {
      await _log('profile_avatar_upload_failed', error, stackTrace);
      emit(const ProfileError('تعذر رفع الصورة حاليًا'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  Future<UserModel?> _currentUser() async {
    final authUser = await _supabaseService.getCurrentUser();
    if (authUser == null) return null;
    return _supabaseService.getUserById(authUser.id);
  }

  static String? _optional(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _log(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) async {
    if (kDebugMode) debugPrint('$operation failed: ${error.runtimeType}');

    await _crashlytics.recordNonFatal(
      StateError(operation),
      stackTrace,
      reason: operation,
      information: const <Object>['profile_bloc'],
    );
  }
}
