import 'package:flutter/material.dart';

import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/features/userhome/presentation/pages/user_home_page.dart'
    as user_home;

import 'complete_profile_page.dart';
import 'user_location_setup_page.dart';

class UserProfileSetupFlow {
  const UserProfileSetupFlow._();

  static bool needsProfile(UserModel user) {
    final name = user.name.trim();
    final hasName = name.length >= 3 && name != 'مستخدم وِصلة';
    final hasEmail = user.email?.trim().isNotEmpty == true;
    final hasCity = user.city?.trim().isNotEmpty == true;
    final hasAddress = user.address?.trim().isNotEmpty == true;
    return !hasName ||
        !hasEmail ||
        !hasCity ||
        !hasAddress ||
        !user.hasCoordinates;
  }

  static Future<void> open(
    BuildContext context,
    UserModel user, {
    String role = 'user',
  }) async {
    if (role.toLowerCase() != 'user') return;

    if (!user.hasCoordinates) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => UserLocationSetupPage(user: user),
        ),
        (_) => false,
      );
      return;
    }

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
