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
  bool _isActive = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isSyncing => _isSyncing;
  bool get isResolved => _isResolved;
  String? get role => _role;
  String? get providerStatus => _providerStatus;
  bool get isActive => _isActive;

  String? get homeRoute {
    if (!_isLoggedIn || !_isResolved || _isSyncing) return null;

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
        return '/restaurant-home';
      case 'user':
      case 'admin':
        return '/home';
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
    bool isActive = true,
    bool authResolved = false,
  }) {
    final normalizedRole = _normalize(role);
    final normalizedStatus = _normalize(providerStatus);
    final nextSyncing = isLoggedIn && !authResolved;
    final nextResolved = !isLoggedIn || authResolved;

    final changed = _isLoggedIn != isLoggedIn ||
        _role != normalizedRole ||
        _providerStatus != normalizedStatus ||
        _isActive != isActive ||
        _isSyncing != nextSyncing ||
        _isResolved != nextResolved;

    _isLoggedIn = isLoggedIn;
    _role = isLoggedIn ? normalizedRole : null;
    _providerStatus = isLoggedIn ? normalizedStatus : null;
    _isActive = isActive;
    _isSyncing = nextSyncing;
    _isResolved = nextResolved;

    if (changed) {
      debugPrint(
        '🔔 [AuthState] loggedIn=$_isLoggedIn role=$_role '
        'providerStatus=$_providerStatus active=$_isActive '
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
    _isActive = true;
    debugPrint('🔔 [AuthState] cleared');
    notifyListeners();
  }

  String? _normalize(String? value) {
    final text = value?.trim().toLowerCase();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
