// lib/routes/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/auth_state_notifier.dart';
import '../features/splash/presentation/pages/splash_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/user_type_selection_page.dart';
import '../features/auth/presentation/pages/institution_login_page.dart';

// ✅ Provider (مزود الخدمة)
import '../features/provider/presentation/pages/provider_auth_page.dart';
import '../features/provider/presentation/pages/provider_pending_page.dart';
import '../features/provider/presentation/pages/provider_main_shell.dart';
import '../features/provider/presentation/pages/provider_otp_verify_page.dart';
import '../features/provider/presentation/pages/provider_reviews_page.dart';
import '../features/provider/presentation/pages/provider_edit_profile_page.dart';
import '../features/provider/presentation/pages/provider_public_profile_page.dart';

// ✅ UserHome
import '../features/userhome/presentation/pages/user_home_page.dart'
    as user_home;
import '../features/userhome/presentation/pages/user_all_offers_page.dart';

// ✅ الصفحات الأساسية
import '../features/map/presentation/pages/map_page.dart';
import '../features/tasks/presentation/pages/tasks_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/volunteer/presentation/pages/volunteer_leaderboard_page.dart';
import '../features/donation/presentation/pages/offer_details_page.dart';
import '../features/charity/presentation/pages/charities_page.dart';

// ⚠️ للتوافق مع الأدوار القديمة
import '../features/business/restaurant/presentation/pages/business_restaurant_page.dart';
import '../features/charity/presentation/pages/charity_workspace_page.dart';

import '../features/institutions/presentation/pages/institutions_home_page.dart';

class AppRouter {
  // ═══════════════════════════════════════════════════════════
  // 🔗 Routes
  // ═══════════════════════════════════════════════════════════
  static const String splash = '/';
  static const String onboarding = '/onboarding';

  // ── Auth
  static const String userTypeSelection = '/user-type-selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String institutionLogin = '/institution-login';

  // ✅ Provider (مزود الخدمة)
  static const String providerAuth = '/provider/auth';
  static const String providerOtpVerify = '/provider/otp-verify';
  static const String providerPending = '/provider/pending';
  static const String providerReviews = '/provider/reviews';
  static const String providerEditProfile = '/provider/edit-profile';
  static const String providerPublicProfile = '/provider/public-profile';

  // ── Main
  static const String home = '/home';
  static const String providerHome = '/provider-home';
  static const String institutionsHome = '/institutions-home';

  // ── Secondary
  static const String map = '/map';
  static const String tasks = '/tasks';
  static const String profile = '/profile';
  static const String volunteer = '/volunteer';
  static const String allOffers = '/all-offers';
  static const String charities = '/charities';
  static const String offerDetails = '/offer/:id';
  static const String placeholder = '/placeholder';

  // ⚠️ Legacy
  static const String restaurantHome = '/restaurant-home';
  static const String charityHome = '/charity-home';

  // ═══════════════════════════════════════════════════════════
  // 🚦 GoRouter
  // ═══════════════════════════════════════════════════════════
  static final GoRouter router = GoRouter(
    initialLocation: splash,

    // ✅ يسمع لتغيّر حالة الـ Auth ويعيد التوجيه تلقائياً
    refreshListenable: AuthStateNotifier.instance,

    // ✅ Redirect ذكي
    redirect: (context, state) {
      final auth = AuthStateNotifier.instance;
      final loc = state.matchedLocation;

      // ── الصفحات العامة (مش محتاجة login)
      const publicRoutes = {
        '/',
        '/onboarding',
        '/user-type-selection',
        '/login',
        '/register',
        '/institution-login',
        '/provider/auth',
        '/provider/otp-verify',
      };

      final isPublic = publicRoutes.contains(loc);

      // ❌ مش مسجل دخول
      if (!auth.isLoggedIn) {
        if (isPublic) return null;
        return userTypeSelection;
      }

      // ══════════════════════════════════════════════════════════
      // ✅ Provider restrictions — منع المزود الموقوف من الوصول
      // ══════════════════════════════════════════════════════════
      if (auth.role == 'provider') {
        final status = auth.providerStatus ?? 'pending';
        final isActive = auth.isActive;

        final isBlocked = !isActive ||
            status == 'suspended' ||
            status == 'rejected' ||
            status == 'pending';

        // المسارات المسموح بيها للمزود المحظور
        const allowedForBlocked = {
          '/provider/pending',
          '/provider/auth',
          '/provider/otp-verify',
        };

        // ✅ لو محظور، نمنعه من أي مسار provider غير المسموح
        if (isBlocked) {
          final isProviderRoute =
              loc == '/provider-home' || loc.startsWith('/provider/');

          if (isProviderRoute && !allowedForBlocked.contains(loc)) {
            return providerPending;
          }

          // ✅ نمنع كذلك أي محاولة للوصول لـ Home العادي
          if (loc == '/home') {
            return providerPending;
          }
        }
      }

      // ✅ مسجل دخول → لو على صفحة auth/شاشة ترحيب → نروح للـ home
      const authPagesToRedirect = {
        '/',
        '/user-type-selection',
        '/login',
        '/register',
        '/institution-login',
        '/provider/auth',
        '/provider/otp-verify',
      };

      if (authPagesToRedirect.contains(loc)) {
        return auth.homeRoute ?? home;
      }

      return null;
    },

    routes: [
      // ─────────────────────────────────────────────
      // 1. Splash
      // ─────────────────────────────────────────────
      GoRoute(
        path: splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // ─────────────────────────────────────────────
      // 2. Onboarding
      // ─────────────────────────────────────────────
      GoRoute(
        path: onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // ─────────────────────────────────────────────
      // 3. User Type Selection
      // ─────────────────────────────────────────────
      GoRoute(
        path: userTypeSelection,
        name: 'user-type-selection',
        builder: (context, state) => const UserTypeSelectionPage(),
      ),

      // ─────────────────────────────────────────────
      // 4. Login
      // ─────────────────────────────────────────────
      GoRoute(
        path: login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // ─────────────────────────────────────────────
      // 4.b Institution Login
      // ─────────────────────────────────────────────
      GoRoute(
        path: institutionLogin,
        name: 'institution-login',
        builder: (context, state) => const InstitutionLoginPage(),
      ),

      // ─────────────────────────────────────────────
      // 4.c Provider Auth
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerAuth,
        name: 'provider-auth',
        builder: (context, state) => const ProviderAuthPage(),
      ),

      // ─────────────────────────────────────────────
      // 4.d Provider OTP Verify
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerOtpVerify,
        name: 'provider-otp-verify',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return ProviderOtpVerifyPage(
            phone: q['phone'] ?? '',
            displayName: q['name'] ?? '',
            categoryId: q['categoryId'] ?? '',
            providerType: q['providerType'] ?? 'individual',
            email: q['email'],
          );
        },
      ),

      // ─────────────────────────────────────────────
      // 4.e Provider Pending
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerPending,
        name: 'provider-pending',
        builder: (context, state) {
          final provider = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null;
          return ProviderPendingPage(provider: provider);
        },
      ),

      // ─────────────────────────────────────────────
      // 4.f Provider Reviews
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerReviews,
        name: 'provider-reviews',
        builder: (context, state) => const ProviderReviewsPage(),
      ),

      // ─────────────────────────────────────────────
      // 4.g Provider Edit Profile
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerEditProfile,
        name: 'provider-edit-profile',
        builder: (context, state) => const ProviderEditProfilePage(),
      ),

      // ─────────────────────────────────────────────
      // 4.h Provider Public Profile
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerPublicProfile,
        name: 'provider-public-profile',
        builder: (context, state) => const ProviderPublicProfilePage(),
      ),

      // ─────────────────────────────────────────────
      // 5. Register
      // ─────────────────────────────────────────────
      GoRoute(
        path: register,
        name: 'register',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'user';
          return RegisterPage(role: role);
        },
      ),

      // ─────────────────────────────────────────────
      // 6. Home
      // ─────────────────────────────────────────────
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const user_home.UserHomePage(),
      ),

      // ─────────────────────────────────────────────
      // 7. Provider Home (Dashboard)
      // ─────────────────────────────────────────────
      GoRoute(
        path: providerHome,
        name: 'provider-home',
        builder: (context, state) => const ProviderMainShell(),
      ),

      // ─────────────────────────────────────────────
      // 8. Institutions Home
      // ─────────────────────────────────────────────
      GoRoute(
        path: institutionsHome,
        name: 'institutions-home',
        builder: (context, state) => const InstitutionsHomePage(),
      ),

      // ─────────────────────────────────────────────
      // 9. All Offers
      // ─────────────────────────────────────────────
      GoRoute(
        path: allOffers,
        name: 'all-offers',
        builder: (context, state) {
          final offers = state.extra as List? ?? [];
          return UserAllOffersPage(offers: offers.cast());
        },
      ),

      // ─────────────────────────────────────────────
      // 10. Map
      // ─────────────────────────────────────────────
      GoRoute(
        path: map,
        name: 'map',
        builder: (context, state) => const MapPage(),
      ),

      // ─────────────────────────────────────────────
      // 11. Tasks
      // ─────────────────────────────────────────────
      GoRoute(
        path: tasks,
        name: 'tasks',
        builder: (context, state) => const TasksPage(),
      ),

      // ─────────────────────────────────────────────
      // 12. Profile
      // ─────────────────────────────────────────────
      GoRoute(
        path: profile,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),

      // ─────────────────────────────────────────────
      // 13. Volunteer Leaderboard
      // ─────────────────────────────────────────────
      GoRoute(
        path: volunteer,
        name: 'volunteer',
        builder: (context, state) => const VolunteerLeaderboardPage(),
      ),

      // ─────────────────────────────────────────────
      // 14. Charities
      // ─────────────────────────────────────────────
      GoRoute(
        path: charities,
        name: 'charities',
        builder: (context, state) => const CharitiesPage(),
      ),

      // ─────────────────────────────────────────────
      // 15. Offer Details
      // ─────────────────────────────────────────────
      GoRoute(
        path: offerDetails,
        name: 'offer-details',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OfferDetailsPage(offer: {'id': id});
        },
      ),

      // ─────────────────────────────────────────────
      // 16. Placeholder
      // ─────────────────────────────────────────────
      GoRoute(
        path: placeholder,
        name: 'placeholder',
        builder: (context, state) {
          final title =
              state.uri.queryParameters['title'] ?? 'صفحة قيد التطوير';
          return _PlaceholderPage(title: title);
        },
      ),

      // ═══════════════════════════════════════════════════════
      // ⚠️ Legacy Routes
      // ═══════════════════════════════════════════════════════
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
    ],

    // ═══════════════════════════════════════════════════════════
    // ❌ Error Builder
    // ═══════════════════════════════════════════════════════════
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
                  onPressed: () => context.go(splash),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════
// Placeholder Page
// ═══════════════════════════════════════════════════════════
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
                  color: colorScheme.outline.withValues(alpha: 0.5),
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
                    color: colorScheme.primary.withValues(alpha: 0.1),
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
