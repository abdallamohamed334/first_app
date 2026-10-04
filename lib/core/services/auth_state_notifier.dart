// lib/core/services/auth_state_notifier.dart

import 'package:flutter/foundation.dart';

class AuthStateNotifier extends ChangeNotifier {
  static final AuthStateNotifier instance = AuthStateNotifier._();
  AuthStateNotifier._();

  bool _isLoggedIn = false;
  bool _isSyncing = false;
  bool _isResolved = false;
  String? _role;
  String? _providerStatus;
  String? _institutionStatus;
  String _accountStatus = 'active';
  DateTime? _suspensionUntil;
  bool _isActive = true;
  bool _userProfileComplete = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isSyncing => _isSyncing;
  bool get isResolved => _isResolved;
  String? get role => _role;
  String? get providerStatus => _providerStatus;
  String? get institutionStatus => _institutionStatus;
  String get accountStatus => _accountStatus;
  DateTime? get suspensionUntil => _suspensionUntil;
  bool get isAccountRestricted => _accountStatus != 'active';
  bool get isActive => _isActive;
  bool get userProfileComplete => _userProfileComplete;

  /// Keeps startup, OTP, and auth-listener routing decisions consistent.
  /// A regular user must have identity, contact, address, city, and map
  /// coordinates before the router is allowed to open the home feed.
  static bool isCompleteUserProfile(
    Map<String, dynamic>? profile, {
    required String role,
  }) {
    if (role != 'user') return true;
    final row = profile ?? const <String, dynamic>{};
    final name = row['name']?.toString().trim() ?? '';
    final email = row['email']?.toString().trim() ?? '';
    final phone = row['phone']?.toString().trim() ?? '';
    final governorate = row['governorate']?.toString().trim() ?? '';
    final city = row['city']?.toString().trim() ?? '';
    final address = row['address']?.toString().trim() ?? '';
    final gender = row['gender']?.toString().trim() ?? '';
    final latitude = row['latitude'];
    final longitude = row['longitude'];

    return name.length >= 3 &&
        name != 'مستخدم وِصلة' &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        governorate.isNotEmpty &&
        city.isNotEmpty &&
        address.isNotEmpty &&
        gender.isNotEmpty &&
        latitude is num &&
        longitude is num;
  }

  String? get homeRoute {
    if (!_isLoggedIn || !_isResolved || _isSyncing) return null;
    if (isAccountRestricted) return '/account-restricted';

    switch (_role) {
      case 'provider':
        if (!_isActive) return '/provider/pending';
        switch (_providerStatus) {
          case 'approved':
            return '/provider-home';
          case 'pending':
          case 'rejected':
          case 'suspended':
          default:
            return '/provider/pending';
        }
      case 'charity':
        return '/charity-home';
      case 'restaurant':
        if (!_isActive ||
            !{'active', 'approved'}.contains(_institutionStatus)) {
          return '/user-type-selection';
        }
        return '/restaurant-home';
      case 'institution':
      case 'business':
      case 'grocery':
      case 'bakery':
      case 'pastry_shop':
      case 'sweets':
      case 'juice_shop':
      case 'butcher':
      case 'fish_market':
      case 'poultry_shop':
      case 'dairy_shop':
      case 'food_factory':
      case 'catering':
      case 'food_truck':
      case 'hotel':
      case 'resort':
      case 'wedding_hall':
      case 'company':
      case 'cafe':
      case 'game_store':
      case 'pharmacy':
      case 'clinic':
      case 'school':
      case 'university':
      case 'bookstore':
      case 'clothing_store':
      case 'electronics_store':
      case 'furniture_store':
      case 'market':
      case 'supermarket':
      case 'other':
        if (!_isActive ||
            !{'active', 'approved'}.contains(_institutionStatus)) {
          return '/user-type-selection';
        }
        return '/institutions-home';
      case 'user':
        return _userProfileComplete ? '/home' : '/login';
      case 'admin':
        return '/admin/account-cases';
      default:
        return '/institutions-home';
    }
  }

  void beginSync() {
    final changed = !_isSyncing || _isResolved;
    _isSyncing = true;
    _isResolved = false;

    if (changed) {
      debugPrint('🔄 [AuthState] waiting for profile/provider sync');
      notifyListeners();
    }
  }

  /// authResolved=false هو الافتراضي عمدًا.
  /// أي auth event مؤقت لا يحق له تشغيل Navigation قبل اكتمال المزامنة.
  void setLoggedIn({
    required bool isLoggedIn,
    String? role,
    String? providerStatus,
    String? institutionStatus,
    String? accountStatus,
    DateTime? suspensionUntil,
    bool isActive = true,
    bool userProfileComplete = true,
    bool authResolved = false,
  }) {
    final normalizedRole = _normalize(role);
    final normalizedStatus = _normalize(providerStatus);
    final normalizedInstitutionStatus = _normalize(institutionStatus);
    final normalizedAccountStatus = _normalize(accountStatus) ?? 'active';
    final nextSyncing = isLoggedIn && !authResolved;
    final nextResolved = !isLoggedIn || authResolved;

    final changed = _isLoggedIn != isLoggedIn ||
        _role != normalizedRole ||
        _providerStatus != normalizedStatus ||
        _institutionStatus != normalizedInstitutionStatus ||
        _accountStatus != normalizedAccountStatus ||
        _suspensionUntil != suspensionUntil ||
        _isActive != isActive ||
        _userProfileComplete != userProfileComplete ||
        _isSyncing != nextSyncing ||
        _isResolved != nextResolved;

    _isLoggedIn = isLoggedIn;
    _role = isLoggedIn ? normalizedRole : null;
    _providerStatus = isLoggedIn ? normalizedStatus : null;
    _institutionStatus = isLoggedIn ? normalizedInstitutionStatus : null;
    _accountStatus = isLoggedIn ? normalizedAccountStatus : 'active';
    _suspensionUntil = isLoggedIn ? suspensionUntil : null;
    _isActive = isActive;
    _userProfileComplete = userProfileComplete;
    _isSyncing = nextSyncing;
    _isResolved = nextResolved;

    if (changed) {
      debugPrint(
        '🔔 [AuthState] loggedIn=$_isLoggedIn role=$_role '
        'providerStatus=$_providerStatus active=$_isActive '
        'institutionStatus=$_institutionStatus '
        'accountStatus=$_accountStatus '
        'resolved=$_isResolved syncing=$_isSyncing',
      );
      notifyListeners();
    }
  }

  void clear() {
    _isLoggedIn = false;
    _isSyncing = false;
    _isResolved = true;
    _role = null;
    _providerStatus = null;
    _institutionStatus = null;
    _accountStatus = 'active';
    _suspensionUntil = null;
    _isActive = true;
    _userProfileComplete = true;
    debugPrint('🔔 [AuthState] cleared');
    notifyListeners();
  }

  String? _normalize(String? value) {
    final text = value?.trim().toLowerCase();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
