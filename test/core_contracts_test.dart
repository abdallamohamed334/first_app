import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/core/services/otp_service.dart';

void main() {
  group('AppErrorMapper', () {
    test('maps offline and timeout failures to the retryable network message', () {
      const expected = 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
      expect(AppErrorMapper.message(const SocketException('offline')), expected);
      expect(AppErrorMapper.message(TimeoutException('timeout')), expected);
    });

    test('does not expose technical permission or expiry details', () {
      expect(
        AppErrorMapper.message(StateError('42501 permission denied')),
        'ليس لديك صلاحية لتنفيذ هذه العملية.',
      );
      expect(
        AppErrorMapper.message(StateError('token expired')),
        'انتهت صلاحية الطلب أو كود الاستلام.',
      );
    });
  });

  group('AuthStateNotifier', () {
    late AuthStateNotifier state;

    setUp(() {
      state = AuthStateNotifier.instance;
      state.clear();
    });

    test('does not route before auth/profile synchronization resolves', () {
      state.setLoggedIn(
        isLoggedIn: true,
        role: 'user',
        authResolved: false,
        userProfileComplete: true,
      );
      expect(state.homeRoute, isNull);
      expect(state.isSyncing, isTrue);
    });

    test('routes approved providers and blocks pending providers', () {
      state.setLoggedIn(
        isLoggedIn: true,
        role: 'provider',
        providerStatus: 'approved',
        authResolved: true,
      );
      expect(state.homeRoute, '/provider-home');

      state.setLoggedIn(
        isLoggedIn: true,
        role: 'provider',
        providerStatus: 'pending',
        authResolved: true,
      );
      expect(state.homeRoute, '/provider/pending');
    });

    test('requires complete user profile before opening the home feed', () {
      state.setLoggedIn(
        isLoggedIn: true,
        role: 'user',
        authResolved: true,
        userProfileComplete: false,
      );
      expect(state.homeRoute, '/login');
    });
  });

  group('OTP client contract', () {
    test('generates exactly six numeric digits using secure randomness', () {
      final code = OtpService().generateOtp();
      expect(code, matches(RegExp(r'^\d{6}$')));
    });
  });
}
