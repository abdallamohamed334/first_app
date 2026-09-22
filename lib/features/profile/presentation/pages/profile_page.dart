// lib/features/profile/presentation/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/theme/theme_notifier.dart';

import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/storage_service.dart';

import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/community/presentation/pages/my_community_needs_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/profile_achievements.dart';
import '../widgets/profile_info_card.dart';
import '../widgets/profile_settings_list.dart';
import '../widgets/profile_edit_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storage = StorageService.instance;

  bool _isUploading = false;
  bool _isLoggingOut = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasStarted) return;

      _hasStarted = true;

      context.read<ProfileBloc>().add(
            const ProfileStarted(),
          );
    });
  }

  Future<void> _refresh() async {
    context.read<ProfileBloc>().add(
          const ProfileStarted(),
        );

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text(
          'ملفي الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (!mounted) return;

          if (state is ProfileError) {
            if (_isLoggingOut) {
              setState(
                () => _isLoggingOut = false,
              );
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ProfileUpdated) {
            context.read<ProfileBloc>().add(
                  const ProfileStarted(),
                );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم تحديث بياناتك بنجاح',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ProfileSignedOut) {
            if (mounted) {
              setState(
                () => _isLoggingOut = false,
              );
            }

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const LoginPage(),
              ),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ProfileLoaded) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  36,
                ),
                children: [
                  ProfileHeader(
                    user: state.user,
                    points: state.points,
                    onEditPressed: () => _showEditDialog(
                      context,
                      state.user,
                    ),
                    onAvatarPressed: () => _pickAndUploadAvatar(
                      state.user.id,
                    ),
                    isUploading: _isUploading,
                  ),

                  const SizedBox(height: 22),

                  ProfileStats(
                    mealsReceived: state.mealsSaved,
                    points: state.points,
                    donations: state.deliveriesCount,
                    memberSince: state.user.createdAt.year.toString(),
                  ),

                  const SizedBox(height: 22),

                  ProfileInfoCard(
                    user: state.user,
                  ),

                  const SizedBox(height: 22),

                  ProfileAchievements(
                    achievements: _getAchievements(state),
                  ),

                  const SizedBox(height: 22),

                  _buildCommunityActions(
                    context,
                  ),

                  const SizedBox(height: 22),

                  // ==========================
                  // SETTINGS
                  // ==========================

                  ValueListenableBuilder<bool>(
                    valueListenable: themeNotifier,
                    builder: (
                      context,
                      isDarkMode,
                      _,
                    ) {
                      return ProfileSettingsList(
                        isDarkMode: isDarkMode,
                        onDarkModeChanged: (value) async {
                          themeNotifier.value = value;

                          try {
                            final prefs = await SharedPreferences.getInstance();

                            await prefs.setBool(
                              'isDarkMode',
                              value,
                            );
                          } catch (error) {
                            debugPrint(
                              'Failed to save theme: $error',
                            );
                          }
                        },
                        onEditProfile: () => _showEditDialog(
                          context,
                          state.user,
                        ),
                        onLogout: () {
                          _showLogoutDialog(
                            context,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'loqma • إنقاذ الطعام يبدأ بخطوة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ProfileError) {
            return _buildError(
              context,
              state.message,
            );
          }

          return _buildError(
            context,
            'تعذر تحميل بيانات الملف الشخصي',
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Community Actions (احتياجاتي بس)
  // ═══════════════════════════════════════════════════════════

  Widget _buildCommunityActions(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withAlpha(
          Theme.of(context).brightness == Brightness.dark ? 70 : 100,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primary.withAlpha(45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مجتمع loqma',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'تابع احتياجاتك اللي نشرتها وشوف مين تواصل معاك.',
            style: TextStyle(
              color: colors.onPrimaryContainer.withAlpha(190),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // ✅ زر احتياجاتي بس
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyCommunityNeedsPage(),
                ),
              ),
              icon: const Icon(
                Icons.volunteer_activism_rounded,
                size: 18,
              ),
              label: const Text(
                'احتياجاتي',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    String message,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 64,
              color: colors.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(
    String userId,
  ) async {
    try {
      final image = await _storage.pickImageFromGallery();

      if (image == null) return;

      setState(
        () => _isUploading = true,
      );

      final url = await _storage.uploadAvatar(
        userId: userId,
        imageFile: image,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        throw Exception(
          'تعذر رفع الصورة',
        );
      }

      context.read<ProfileBloc>().add(
            const ProfileStarted(),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديث الصورة بنجاح',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديث الصورة حاليًا',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isUploading = false,
        );
      }
    }
  }

  void _showEditDialog(
    BuildContext context,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (_) => ProfileEditDialog(
        user: user,
      ),
    );
  }

  Future<void> _showLogoutDialog(
    BuildContext context,
  ) async {
    if (_isLoggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || _isLoggingOut) {
      return;
    }

    setState(
      () => _isLoggingOut = true,
    );

    context.read<ProfileBloc>().add(
          const ProfileSignOut(),
        );
  }

  List<String> _getAchievements(
    ProfileLoaded state,
  ) {
    final result = <String>[];

    if (state.mealsSaved >= 1) {
      result.add('أول وجبة منقذة');
    }

    if (state.mealsSaved >= 10) {
      result.add('10 وجبات منقذة');
    }

    if (state.points >= 100) {
      result.add('100 نقطة');
    }

    if (state.deliveriesCount >= 1) {
      result.add('أول توصيل');
    }

    if (state.user.level >= 3) {
      result.add('متطوع محترف');
    }

    return result;
  }
}
