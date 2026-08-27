import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:loqma/features/business/restaurant/data/repositories/session_aware_scope.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/routes/app_router.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/splash/presentation/bloc/splash_bloc.dart';
import 'features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/profile/presentation/bloc/profile_bloc.dart';

import 'core/theme/app_theme.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ??
        'https://gsrhoqdtcyfdmvgahqvl.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ??
        'sb_publishable_dVIM-E6QaOFvZIgJfhgJVg_Dqj8OmbH',
  );

  debugPrint('Supabase initialized successfully');
  initNotificationInjection();
  runApp(const MyApp());
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    if (!mounted) return;
    setState(() {
      _isDarkMode = isDark;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SplashBloc()),
        BlocProvider(create: (_) => OnboardingBloc()),
        BlocProvider(create: (_) => HomeBloc()),
        BlocProvider(create: (_) => ProfileBloc()),
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
