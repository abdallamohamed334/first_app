import 'package:flutter/material.dart';

import 'package:wasla/core/models/user_model.dart';
import 'package:wasla/features/userhome/presentation/pages/user_home_page.dart'
    as user_home;

import 'complete_profile_page.dart';

class UserProfileSetupFlow {
  const UserProfileSetupFlow._();

  static bool needsProfile(UserModel user) {
    final name = user.name.trim();
    final hasName = name.length >= 3 && name != 'مستخدم وِصلة';
    final hasEmail = user.email?.trim().isNotEmpty == true;
    final hasPhone = user.phone?.trim().isNotEmpty == true;
    final hasGovernorate = user.governorate?.trim().isNotEmpty == true;
    final hasCity = user.city?.trim().isNotEmpty == true;
    final hasAddress = user.address?.trim().isNotEmpty == true;
    final hasGender = user.gender?.trim().isNotEmpty == true;
    return !hasName ||
        !hasEmail ||
        !hasPhone ||
        !hasGovernorate ||
        !hasCity ||
        !hasAddress ||
        !hasGender ||
        !user.hasCoordinates;
  }

  static Future<void> open(
    BuildContext context,
    UserModel user, {
    String role = 'user',
  }) async {
    if (role.toLowerCase() != 'user') return;

    // The database-backed profile is the single source of truth. Complete
    // users go Home; every incomplete user must finish setup, regardless of
    // whether the flow came from auto-login, OTP login, or registration.
    if (needsProfile(user)) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(
            user: user,
            role: role,
            initialLat: user.lat,
            initialLng: user.lng,
          ),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const user_home.UserHomePage()),
      (_) => false,
    );
  }
}
