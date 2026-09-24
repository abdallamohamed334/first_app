// lib/main.dart

import 'dart:async';

import 'package:loqma/features/business/restaurant/data/repositories/session_aware_scope.dart';
import 'features/map/data/repositories/map_repository_impl.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/features/userhome/data/repositories/userhome_repository.dart';
import 'package:loqma/routes/app_router.dart';
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

import 'features/userhome/presentation/bloc/userhome_bloc.dart';

import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';
import 'features/splash/presentation/bloc/splash_bloc.dart';

import 'core/services/analytics_service.dart';
import 'core/services/app_check_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';

// ✅ ThemeNotifier
import 'core/theme/theme_notifier.dart';

bool _firebaseCrashlyticsReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installGlobalErrorHandlers();

  final envLoaded = await _loadEnvSafely();

  final firebaseReady = await _initializeFirebaseSafely();

  if (firebaseReady) {
    try {
      await loqmaAppCheck().activate(
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

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (!envLoaded || supabaseUrl == null || supabaseAnonKey == null) {
    debugPrint(
      '⚠️ SUPABASE_URL / SUPABASE_ANON_KEY missing from environment. '
      'Check that .env was bundled correctly for this build.',
    );
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl ?? '',
      anonKey: supabaseAnonKey ?? '',
    );

    debugPrint('Supabase initialized successfully');
  } catch (error, stack) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  final isDarkMode = await _loadThemePreferenceSafely();

  // ✅ تهيئة الـ ThemeNotifier قبل بدء التطبيق
  ThemeNotifier.isDarkMode.value = isDarkMode;

  try {
    final supabaseService = SupabaseService();

    await supabaseService.initializeFcmForCurrentUser(
      onNotificationTap: (data) async {
        final notificationType = data['type']?.toString();

        if (notificationType != null && notificationType.trim().isNotEmpty) {
          try {
            await loqmaAnalytics().notificationOpened(
              notificationType: notificationType,
            );
          } catch (error, stack) {
            debugPrint('Notification analytics failed: $error');
            debugPrintStack(stackTrace: stack);
          }
        }
      },
    );

    if (firebaseReady) {
      try {
        await loqmaAnalytics().appOpen();
      } catch (error, stack) {
        debugPrint('Analytics appOpen failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
  } catch (error, stack) {
    debugPrint('Notification initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  try {
    initNotificationInjection();
  } catch (error, stack) {
    debugPrint('Notification injection failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  runApp(MyApp(initialIsDarkMode: isDarkMode));
}

Future<bool> _loadEnvSafely() async {
  try {
    await dotenv.load();
    debugPrint('Environment variables loaded successfully');
    return true;
  } catch (error, stack) {
    debugPrint('Failed to load .env file: $error');
    debugPrintStack(stackTrace: stack);
    return false;
  }
}

Future<bool> _loadThemePreferenceSafely() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkMode') ?? false;
  } catch (error, stack) {
    debugPrint('Failed to load theme preference: $error');
    debugPrintStack(stackTrace: stack);
    return false;
  }
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
      debugPrint('Async error before Crashlytics initialization: $error');
      debugPrintStack(stackTrace: stack);
    }

    return true;
  };
}

Future<bool> _initializeFirebaseSafely() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully');

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
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    debugPrint('Firebase Analytics configured');
  } catch (error, stack) {
    debugPrint('Firebase Analytics configuration failed: $error');
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
      'Firebase Crashlytics configured; collection=${!kDebugMode}',
    );
  } catch (error, stack) {
    debugPrint('Firebase Crashlytics configuration failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> _configurePerformance() async {
  try {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(
      !kDebugMode,
    );

    debugPrint(
      'Firebase Performance configured; collection=${!kDebugMode}',
    );
  } catch (error, stack) {
    debugPrint('Firebase Performance configuration failed: $error');
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

    // ✅ تحديث الـ defaults للأدوار الجديدة
    await remoteConfig.setDefaults(
      const <String, dynamic>{
        'maintenance_mode': false,
        'show_new_home_banner': false,
        'donation_expiry_warning_minutes': 30,
        'max_donation_images': 5,
        'enable_whatsapp_otp': true,
        'enable_provider_features': true,
        'enable_institution_features': true,
        'enable_urgent_calls': false,
      },
    );

    await remoteConfig.fetchAndActivate();

    debugPrint('Firebase Remote Config configured and activated');
  } catch (error, stack) {
    debugPrint(
      'Firebase Remote Config configuration failed; '
      'defaults retained: $error',
    );
    debugPrintStack(stackTrace: stack);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialIsDarkMode});

  /// Loaded once in main() before runApp(), so the very first frame
  /// already renders with the correct theme — no flash.
  final bool initialIsDarkMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    ThemeNotifier.isDarkMode.value = widget.initialIsDarkMode;
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
          create: (_) => UserHomeBloc(
            repository: UserHomeRepository(
              supabaseService: supabaseService,
            ),
            mapRepository: MapRepositoryImpl(),
          ),
        ),
        BlocProvider(
          create: (_) => ProfileBloc(
            supabaseService: supabaseService,
          ),
        ),
      ],
      child: SessionAwareBlocScope(
        service: supabaseService,
        child: ValueListenableBuilder<bool>(
          valueListenable: ThemeNotifier.isDarkMode,
          builder: (context, isDarkMode, _) {
            return MaterialApp.router(
              // ✅ الاسم الجديد
              title: 'جُود',
              debugShowCheckedModeBanner: false,
              routerConfig: AppRouter.router,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            );
          },
        ),
      ),
    );
  }
}
