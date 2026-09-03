import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'package:loqma/features/business/restaurant/data/repositories/session_aware_scope.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/routes/app_router.dart';

import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/splash/presentation/bloc/splash_bloc.dart';

import 'core/services/analytics_service.dart';
import 'core/services/app_check_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';

bool _firebaseCrashlyticsReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Install global error handlers before initializing services.
  _installGlobalErrorHandlers();

  // Initialize Firebase.
  // We keep the result so we don't try to use Firebase-dependent
  // services if Firebase initialization fails.
  final firebaseReady = await _initializeFirebaseSafely();

  // Load environment variables.
  try {
    await dotenv.load();
    debugPrint('Environment variables loaded successfully');
  } catch (error, stack) {
    debugPrint('Failed to load .env file: $error');
    debugPrintStack(stackTrace: stack);
  }

  // App Check requires a successfully initialized Firebase app.
  if (firebaseReady) {
    try {
      await LoqmaAppCheck().activate(
        webRecaptchaSiteKey: dotenv.env['FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY'],
      );

      debugPrint('Firebase App Check activated');
    } catch (error, stack) {
      debugPrint('Firebase App Check activation failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  } else {
    debugPrint(
      'Firebase is not ready. Skipping Firebase App Check activation.',
    );
  }

  // Initialize Supabase.
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ??
          'https://gsrhoqdtcyfdmvgahqvl.supabase.co',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ??
          'sb_publishable_dVIM-E6QaOFvZIgJfhgJVg_Dqj8OmbH',
    );

    debugPrint('Supabase initialized successfully');
  } catch (error, stack) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  // Reconnect notifications after a hot restart or an existing saved session.
  // The method is a no-op when there is no authenticated user.
  try {
    final supabaseService = SupabaseService();

    await supabaseService.initializeFcmForCurrentUser(
      onNotificationTap: (data) async {
        final notificationType = data['type']?.toString();

        if (notificationType != null && notificationType.trim().isNotEmpty) {
          try {
            await LoqmaAnalytics().notificationOpened(
              notificationType: notificationType,
            );
          } catch (error, stack) {
            debugPrint(
              'Notification analytics failed: $error',
            );
            debugPrintStack(stackTrace: stack);
          }
        }
      },
    );

    if (firebaseReady) {
      try {
        await LoqmaAnalytics().appOpen();
      } catch (error, stack) {
        debugPrint('Analytics appOpen failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
  } catch (error, stack) {
    debugPrint('Notification initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  // Initialize notification dependency injection.
  try {
    initNotificationInjection();
  } catch (error, stack) {
    debugPrint('Notification injection failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  // IMPORTANT:
  // Always start the Flutter application even if an optional
  // Firebase/notification service failed.
  runApp(const MyApp());
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    if (_firebaseCrashlyticsReady) {
      unawaited(
        FirebaseCrashlytics.instance.recordFlutterFatalError(details),
      );
    } else {
      debugPrint(
        'Flutter error before Crashlytics initialization: '
        '${details.exception}',
      );
    }
  };

  PlatformDispatcher.instance.onError = (
    Object error,
    StackTrace stack,
  ) {
    if (_firebaseCrashlyticsReady) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        ),
      );
    } else {
      debugPrint(
        'Async error before Crashlytics initialization: $error',
      );
      debugPrintStack(stackTrace: stack);
    }

    // Returning true marks the error as handled after it has been recorded.
    return true;
  };
}

Future<bool> _initializeFirebaseSafely() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully');

    // Configure Firebase services independently.
    // If one service fails, it should not prevent the others
    // or prevent the application from starting.
    await _configureAnalytics();
    await _configureCrashlytics();
    await _configurePerformance();
    await _configureRemoteConfig();

    return true;
  } catch (error, stack) {
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stack);

    return false;
  }
}

Future<void> _configureAnalytics() async {
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      true,
    );

    debugPrint('Firebase Analytics configured');
  } catch (error, stack) {
    debugPrint(
      'Firebase Analytics configuration failed: $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> _configureCrashlytics() async {
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    _firebaseCrashlyticsReady = true;

    debugPrint(
      'Firebase Crashlytics configured; '
      'collection=${!kDebugMode}',
    );
  } catch (error, stack) {
    debugPrint(
      'Firebase Crashlytics configuration failed: $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> _configurePerformance() async {
  try {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      !kDebugMode,
    );

    debugPrint(
      'Firebase Performance configured; '
      'collection=${!kDebugMode}',
    );
  } catch (error, stack) {
    debugPrint(
      'Firebase Performance configuration failed: $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> _configureRemoteConfig() async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;

    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 1),
      ),
    );

    await remoteConfig.setDefaults(
      const <String, dynamic>{
        'maintenance_mode': false,
        'show_new_donation_flow': false,
        'show_new_home_banner': false,
        'donation_expiry_warning_minutes': 30,
        'max_donation_images': 5,
        'enable_qr_pickup': true,
        'enable_charity_notifications': true,
        'enable_restaurant_features': true,
      },
    );

    await remoteConfig.fetchAndActivate();

    debugPrint(
      'Firebase Remote Config configured and activated',
    );
  } catch (error, stack) {
    // Safe defaults remain available when Firebase Console
    // or the network is unavailable.
    debugPrint(
      'Firebase Remote Config configuration failed; '
      'defaults retained: $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) {
        return;
      }

      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      });
    } catch (error, stack) {
      debugPrint(
        'Failed to load theme preference: $error',
      );
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _toggleTheme(bool isDark) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isDarkMode = isDark;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'isDarkMode',
        isDark,
      );
    } catch (error, stack) {
      debugPrint(
        'Failed to save theme preference: $error',
      );
      debugPrintStack(stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SplashBloc(),
        ),
        BlocProvider(
          create: (_) => OnboardingBloc(),
        ),
        BlocProvider(
          create: (_) => HomeBloc(),
        ),
        BlocProvider(
          create: (_) => ProfileBloc(),
        ),
      ],
      child: SessionAwareBlocScope(
        service: supabaseService,
        child: MaterialApp.router(
          title: 'Loqma | لقمة',
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter.router,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}
