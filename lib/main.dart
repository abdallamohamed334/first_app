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
// ✅ AuthStateNotifier — لمزامنة حالة الدخول مع Supabase
import 'core/services/auth_state_notifier.dart';
import 'core/theme/app_theme.dart';
import 'features/institutions/domain/entities/institution.dart';

// ✅ ThemeNotifier
import 'core/theme/theme_notifier.dart';

bool _firebaseCrashlyticsReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _installGlobalErrorHandlers();

  final envLoaded = await _loadEnvSafely();

  final firebaseReady = await _initializeFirebaseSafely().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      debugPrint('Firebase startup timed out; continuing without blocking UI');
      return false;
    },
  );

  if (firebaseReady) {
    try {
      await loqmaAppCheck().activate(
        webRecaptchaSiteKey: dotenv.env['FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY'],
      ).timeout(const Duration(seconds: 3));

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
    ).timeout(const Duration(seconds: 5));

    debugPrint('Supabase initialized successfully');

    // ═══════════════════════════════════════════════════════════
    // ✅ Auth Listener موحّد — يزامن AuthStateNotifier مع Supabase
    // ═══════════════════════════════════════════════════════════
    _attachAuthStateSync();
  } catch (error, stack) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  final isDarkMode = await _loadThemePreferenceSafely();

  // ✅ تهيئة الـ ThemeNotifier قبل بدء التطبيق
  ThemeNotifier.isDarkMode.value = isDarkMode;

  runApp(MyApp(initialIsDarkMode: isDarkMode));
  unawaited(_initializePostLaunchServices(firebaseReady));
}

Future<void> _initializePostLaunchServices(bool firebaseReady) async {
  try {
    final supabaseService = SupabaseService();
    await supabaseService
        .initializeFcmForCurrentUser(
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
        )
        .timeout(const Duration(seconds: 8));
    if (firebaseReady) {
      await loqmaAnalytics().appOpen().timeout(const Duration(seconds: 3));
    }
  } catch (error, stack) {
    debugPrint('Post-launch notification initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }
  try {
    initNotificationInjection();
  } catch (error, stack) {
    debugPrint('Notification injection failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}

// ═══════════════════════════════════════════════════════════════
// ✅ مزامنة AuthStateNotifier مع أحداث Supabase Auth
// - عند الخروج: ننضف الحالة فورًا
// - عند الدخول/التحديث/الجلسة الأولية: نحمّل user_type ونضبط الحالة
// ═══════════════════════════════════════════════════════════════
int _authSyncGeneration = 0;

/// مزامنة الجلسة مع users و service_providers و institutions قبل السماح للـ router بالتوجيه.
/// لا نحدد الدور من users.user_type وحده، لأن الحساب قد يكون مستخدمًا ومزود خدمة.
void _attachAuthStateSync() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    final session = data.session;

    if (event == AuthChangeEvent.signedOut || session == null) {
      _authSyncGeneration++;
      AuthStateNotifier.instance.clear();
      debugPrint('🔔 [AuthState] signed out → cleared');
      return;
    }

    if (event != AuthChangeEvent.signedIn &&
        event != AuthChangeEvent.tokenRefreshed &&
        event != AuthChangeEvent.initialSession) {
      return;
    }

    final generation = ++_authSyncGeneration;
    final userId = session.user.id;
    final authState = AuthStateNotifier.instance;

    // مهم: لا نضع role=user هنا. ننتظر نتيجة الجدولين أولًا.
    authState.beginSync();
    debugPrint('🔄 [AuthState] resolving session for $userId');

    try {
      final client = Supabase.instance.client;

      final results = await Future.wait<dynamic>([
        client
            .from('users')
            .select('user_type, role, is_active')
            .eq('id', userId)
            .maybeSingle(),
        client
            .from('service_providers')
            .select('id, verification_status, is_active')
            .eq('user_id', userId)
            .maybeSingle(),
      ]);

      // تجاهل نتيجة Listener قديمة لو وصل حدث أحدث أثناء الاستعلام.
      if (generation != _authSyncGeneration) return;

      final profile = results[0] as Map<String, dynamic>?;
      final provider = results[1] as Map<String, dynamic>?;
      Map<String, dynamic>? institution;
      try {
        institution = await client
            .from('institutions')
            .select('id, institution_type, status, is_verified')
            .eq('user_id', userId)
            .maybeSingle();
      } catch (error) {
        // Institutions may have stricter RLS than the users table. Do not
        // break ordinary-user/provider session recovery when that query is
        // unavailable; the institution login flow still validates ownership.
        debugPrint('⚠️ [AuthState] institution lookup skipped: $error');
      }

      if (profile == null) {
        debugPrint('⚠️ [AuthState] no user row for $userId');
        authState.clear();
        return;
      }

      final profileRole = (profile['user_type'] ?? profile['role'] ?? 'user')
          .toString()
          .trim()
          .toLowerCase();
      final institutionType = institution?['institution_type']
          ?.toString()
          .trim()
          .toLowerCase();
      final resolvedRole = provider != null
          ? 'provider'
          : (institutionType == null || institutionType.isEmpty
              ? profileRole
              : institutionType);
      final providerStatus =
          provider?['verification_status']?.toString().trim().toLowerCase();
      final institutionStatus =
          institution?['status']?.toString().trim().toLowerCase();
      final isActive = profile['is_active'] != false &&
          (provider == null || provider['is_active'] != false) &&
          (institution == null ||
              Institution.isAllowedStatus(institutionStatus));

      debugPrint(
        '✅ [AuthState] resolved role=$resolvedRole '
        'providerStatus=$providerStatus active=$isActive '
        'providerFound=${provider != null} '
        'institutionStatus=$institutionStatus '
        'institutionFound=${institution != null}',
      );

      authState.setLoggedIn(
        isLoggedIn: true,
        role: resolvedRole,
        providerStatus: providerStatus,
        institutionStatus: institutionStatus,
        isActive: isActive,
        authResolved: true,
      );

      debugPrint(
        '🔔 [AuthState] synced from auth event: $resolvedRole '
        'status=$providerStatus active=$isActive',
      );
    } catch (error, stack) {
      if (generation != _authSyncGeneration) return;
      debugPrint('⚠️ Failed to sync AuthState: $error');
      debugPrintStack(stackTrace: stack);
      authState.clear();
    }
  });
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
              title: 'وِصلة',
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
