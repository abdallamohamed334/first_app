// lib/routes/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/features/map/presentation/pages/location_picker_page.dart';

import '../features/splash/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
// ✅ استخدم UserHomePage
import '../features/userhome/presentation/pages/user_home_page.dart'
    as user_home;
// ✅ استخدم UserAllOffersPage
import '../features/userhome/presentation/pages/user_all_offers_page.dart';

import '../features/map/presentation/pages/map_page.dart';
// ✅ صفحة تحديد الموقع قبل تسجيل الدخول
import '../features/tasks/presentation/pages/tasks_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/volunteer/presentation/pages/volunteer_leaderboard_page.dart';
import '../features/donation/presentation/pages/offer_details_page.dart';
import '../features/charity/presentation/pages/charities_page.dart';
import '../features/business/restaurant/presentation/pages/business_restaurant_page.dart';
import '../features/charity/presentation/pages/charity_workspace_page.dart';
import '../features/institutions/presentation/pages/institutions_home_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String selectLocation = '/select-location';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String map = '/map';
  static const String tasks = '/tasks';
  static const String profile = '/profile';
  static const String volunteer = '/volunteer';
  static const String restaurantHome = '/restaurant-home';
  static const String charityHome = '/charity-home';
  static const String institutionsHome = '/institutions-home';
  static const String allOffers = '/all-offers';

  static const String offerDetails = '/offer/:id';
  static const String charities = '/charities';
  static const String placeholder = '/placeholder';

  static final GoRouter router = GoRouter(
    // ✅ الصفحة الافتتاحية هي Splash
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: selectLocation,
        name: 'select-location',
        builder: (context, state) => const LocationPickerPage(),
      ),
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const user_home.UserHomePage(),
      ),
      GoRoute(
        path: allOffers,
        name: 'all-offers',
        builder: (context, state) {
          final offers = state.extra as List? ?? [];
          return UserAllOffersPage(offers: offers.cast());
        },
      ),
      GoRoute(
        path: map,
        name: 'map',
        builder: (context, state) => const MapPage(),
      ),
      GoRoute(
        path: tasks,
        name: 'tasks',
        builder: (context, state) => const TasksPage(),
      ),
      GoRoute(
        path: profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: volunteer,
        name: 'volunteer',
        builder: (context, state) => const VolunteerLeaderboardPage(),
      ),
      GoRoute(
        path: charities,
        name: 'charities',
        builder: (context, state) => const CharitiesPage(),
      ),
      GoRoute(
        path: restaurantHome,
        name: 'restaurant-home',
        builder: (context, state) => const BusinessRestaurantPage(),
      ),
      GoRoute(
        path: charityHome,
        name: 'charity-home',
        builder: (context, state) => const CharityWorkspacePage(),
      ),
      GoRoute(
        path: institutionsHome,
        name: 'institutions-home',
        builder: (context, state) => const InstitutionsHomePage(),
      ),
      GoRoute(
        path: offerDetails,
        name: 'offer-details',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OfferDetailsPage(offer: {'id': id});
        },
      ),
      GoRoute(
        path: placeholder,
        name: 'placeholder',
        builder: (context, state) {
          final title =
              state.uri.queryParameters['title'] ?? 'صفحة قيد التطوير';
          return _PlaceholderPage(title: title);
        },
      ),
    ],
    // ❌ إزالة الـ Redirect بالكامل
    // redirect: (context, state) {
    //   if (state.matchedLocation == splash || state.matchedLocation == '/') {
    //     return map;
    //   }
    //   return null;
    // },
    errorBuilder: (context, state) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'الصفحة غير موجودة',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'عذرًا، الصفحة التي تبحث عنها غير متوفرة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(login),
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: 'رجوع',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.construction,
                  size: 80,
                  color: colorScheme.outline.withAlpha(128),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'هذه الصفحة قيد التطوير',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'قريبًا',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
