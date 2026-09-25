// lib/core/services/auth_state_notifier.dart

import 'package:flutter/foundation.dart';

/// ✅ بيحفظ حالة المستخدم الحالي (role + provider status)
/// عشان الـ router يعرف يوجّهه فين
class AuthStateNotifier extends ChangeNotifier {
  static final AuthStateNotifier instance = AuthStateNotifier._();
  AuthStateNotifier._();

  bool _isLoggedIn = false;
  String? _role; // user | provider | institution | admin
  String? _providerStatus; // pending | approved | rejected | suspended
  bool _isActive = true;

  bool get isLoggedIn => _isLoggedIn;
  String? get role => _role;
  String? get providerStatus => _providerStatus;
  bool get isActive => _isActive;

  /// ✅ الصفحة الرئيسية حسب الحالة
  String? get homeRoute {
    if (!_isLoggedIn) return null;

    switch (_role) {
      case 'provider':
        if (!_isActive) return '/provider/pending';
        switch (_providerStatus) {
          case 'approved':
            return '/provider-home';
          case 'rejected':
          case 'suspended':
          case 'pending':
          default:
            return '/provider/pending';
        }

      case 'institution':
      case 'charity':
        return '/institutions-home';

      case 'admin':
      case 'user':
      default:
        return '/home';
    }
  }

  void setLoggedIn({
    required bool isLoggedIn,
    String? role,
    String? providerStatus,
    bool isActive = true,
  }) {
    final changed = _isLoggedIn != isLoggedIn ||
        _role != role ||
        _providerStatus != providerStatus ||
        _isActive != isActive;

    _isLoggedIn = isLoggedIn;
    _role = role;
    _providerStatus = providerStatus;
    _isActive = isActive;

    if (changed) {
      debugPrint(
        '🔔 [AuthState] loggedIn=$_isLoggedIn role=$_role '
        'providerStatus=$_providerStatus active=$_isActive',
      );
      notifyListeners();
    }
  }

  void clear() {
    setLoggedIn(isLoggedIn: false);
  }
}
