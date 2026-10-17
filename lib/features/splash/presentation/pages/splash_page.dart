import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/routes/app_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _splashBackground = Color(0xFF111111);
  Timer? _retryTimer;
  bool _isNavigating = false;
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutCubic,
    );
    _logoController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        unawaited(_navigateToNext());
      }
    });
    _logoController.forward();
  }

  Future<void> _navigateToNext() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    final client = Supabase.instance.client;
    Session? session = client.auth.currentSession;
    if (session == null) {
      try {
        final restored = await client.auth.onAuthStateChange.first
            .timeout(const Duration(seconds: 8));
        session = restored.session ?? client.auth.currentSession;
      } catch (_) {
        session = client.auth.currentSession;
      }
    }

    if (session != null) {
      // AuthStateNotifier is the single source of truth after the database
      // account record and role have been synchronized.
      final auth = AuthStateNotifier.instance;
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (mounted &&
          (!auth.isLoggedIn || auth.isSyncing || !auth.isResolved) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      if (!mounted) return;
      if (auth.isLoggedIn && auth.isResolved && !auth.isSyncing) {
        _isNavigating = false;
        context.go(auth.homeRoute ?? AppRouter.userTypeSelection);
        return;
      }

      // Fail closed: keep the simple branded splash visible and retry instead
      // of sending an unresolved session to the wrong workspace.
      debugPrint('Auth session is not resolved yet; retrying splash routing.');
      _isNavigating = false;
      _retryTimer = Timer(const Duration(seconds: 2), _navigateToNext);
      return;
    }

    var onboardingSeen = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      onboardingSeen = preferences.getBool('onboarding_seen') ??
          preferences.getBool('onboarding_completed') ??
          preferences.getBool('has_seen_onboarding') ??
          false;
    } catch (error) {
      debugPrint('Could not read onboarding preference: ${error.runtimeType}');
    }

    if (!mounted) return;
    _isNavigating = false;
    context.go(onboardingSeen ? AppRouter.userTypeSelection : AppRouter.onboarding);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = MediaQuery.sizeOf(context).shortestSide * 0.78;
    return Scaffold(
      backgroundColor: _splashBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: _splashBackground,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: _splashBackground,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: _splashBackground,
          alignment: Alignment.center,
          child: FadeTransition(
            opacity: _logoOpacity,
            child: ScaleTransition(
              scale: _logoScale,
              child: Semantics(
                label: 'شعار التطبيق',
                child: Image.asset(
                  'assets/images/khedma_splash_logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
