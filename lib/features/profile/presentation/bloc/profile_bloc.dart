import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final SupabaseService _supabaseService;
  final StorageService _storageService;
  final AuthService _authService;

  ProfileBloc({
    SupabaseService? supabaseService,
    StorageService? storageService,
    AuthService? authService,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _storageService = storageService ?? StorageService.instance,
        _authService = authService ?? AuthService(),
        super(const ProfileInitial()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileUpdateUser>(_onUpdateUser);
    on<ProfileUpdatePassword>(_onUpdatePassword);
    on<ProfileSignOut>(_onSignOut);
    on<ProfileUploadAvatar>(_onUploadAvatar);
  }

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final authUser = await _supabaseService.getCurrentUser();
      final email = authUser?.email?.trim();
      if (email == null || email.isEmpty) {
        emit(const ProfileError('المستخدم غير موجود'));
        return;
      }

      final user = await _supabaseService.getUserByEmail(email);
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
    } catch (error) {
      _log('profile load', error);
      emit(const ProfileError('تعذر تحميل بيانات الملف الشخصي حاليًا'));
    }
  }

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
    } catch (error) {
      _log('profile update', error);
      emit(const ProfileError('تعذر تحديث البيانات حاليًا'));
    }
  }

  Future<void> _onUpdatePassword(
    ProfileUpdatePassword event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      final authUser = await _supabaseService.getCurrentUser();
      final email = authUser?.email?.trim();
      if (email == null || email.isEmpty) {
        emit(const ProfileError('المستخدم غير موجود'));
        return;
      }
      await _supabaseService.updatePasswordInAuth(email, event.newPassword);
      emit(const ProfilePasswordUpdated());
    } catch (error) {
      _log('profile password update', error);
      emit(const ProfileError('تعذر تحديث كلمة المرور حاليًا'));
    }
  }

  Future<void> _onSignOut(
    ProfileSignOut event,
    Emitter<ProfileState> emit,
  ) async {
    try {
      // AuthService signs out from Supabase and always clears all local
      // identity/business cache values in its finally block.
      await _authService.signOut();
      if (!isClosed) emit(const ProfileSignedOut());
    } catch (error) {
      _log('profile sign out', error);
      if (!isClosed) {
        emit(const ProfileError('تعذر تسجيل الخروج حاليًا. حاول مرة أخرى'));
      }
    }
  }

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

      // StorageService already persists avatar_url and verifies the updated row.
      // Do not issue a second update here; it can race with the first request.
      emit(ProfileUpdated(user: user.copyWith(avatarUrl: avatarUrl)));
    } catch (error) {
      _log('profile avatar upload', error);
      emit(const ProfileError('تعذر رفع الصورة حاليًا'));
    }
  }

  Future<UserModel?> _currentUser() async {
    final authUser = await _supabaseService.getCurrentUser();
    final email = authUser?.email?.trim();
    if (email == null || email.isEmpty) return null;
    return _supabaseService.getUserByEmail(email);
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

  void _log(String operation, Object error) {
    if (kDebugMode) debugPrint('$operation failed: ${error.runtimeType}');
  }
}
