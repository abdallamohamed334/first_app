import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/auth_identity_resolver.dart';
import 'package:loqma/core/services/firebase_messaging_service.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:loqma/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:loqma/features/business/data/repositories/business_repository.dart';
import 'package:loqma/features/business/presentation/bloc/business_dashboard_bloc.dart';
import 'package:loqma/features/charity/presentation/bloc/charity_bloc.dart';
import 'package:loqma/features/home/presentation/bloc/home_bloc.dart';
import 'package:loqma/features/map/presentation/bloc/map_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:loqma/features/volunteer/presentation/bloc/volunteer_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionAwareBlocScope extends StatelessWidget {
  final Widget child;
  final SupabaseService service;

  const SessionAwareBlocScope({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data?.session;
        if (session == null) return child;

        return FutureBuilder<String?>(
          future: _resolveIdentityType(client, session.user.id),
          builder: (context, identitySnapshot) {
            if (identitySnapshot.connectionState != ConnectionState.done) {
              return const Directionality(
                textDirection: TextDirection.rtl,
                child: Material(
                  color: Colors.transparent,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final type = identitySnapshot.data;

            // Institutions use their isolated module and must not be wrapped
            // with the legacy restaurant/business dashboard scope.
            if (type == 'institution') {
              return child;
            }

            if (_isInstitution(type)) {
              return BlocProvider<BusinessDashboardBloc>(
                create: (_) => BusinessDashboardBloc(
                  BusinessRepository(service),
                  service,
                ),
                child: child,
              );
            }

            if (type == 'charity') {
              return BlocProvider<CharityBloc>(
                create: (_) => CharityBloc(),
                child: child,
              );
            }

            if (type == 'user') {
              return _UserOnlyScope(service: service, child: child);
            }

            // لا نرجع صفحة جديدة ولا نعرض شاشة خطأ كاملة.
            // نُبقي التطبيق في مكانه ونظهر تنبيهًا فوقه فقط.
            return _UnknownAccountDialogScope(
              key: const ValueKey<String>('unknown-account-dialog-scope'),
              child: child,
            );
          },
        );
      },
    );
  }

  Future<String?> _resolveIdentityType(
    SupabaseClient client,
    String authUserId,
  ) async {
    try {
      // Read the explicit role first. This keeps the new institution role
      // independent from the legacy organization resolver.
      final row = await client
          .from('users')
          .select('user_type')
          .eq('id', authUserId)
          .maybeSingle();
      final rawRole = row?['user_type']?.toString().trim().toLowerCase();
      if (rawRole == 'institution') return 'institution';

      final value = await AuthIdentityResolver.resolve(client, authUserId);
      return value.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  bool _isInstitution(String? type) => const {
        'restaurant',
        'business',
        'hotel',
        'supermarket',
        'bakery',
        'cafe',
      }.contains(type);
}

class _UnknownAccountDialogScope extends StatefulWidget {
  final Widget child;

  const _UnknownAccountDialogScope({
    super.key,
    required this.child,
  });

  @override
  State<_UnknownAccountDialogScope> createState() =>
      _UnknownAccountDialogScopeState();
}

class _UnknownAccountDialogScopeState
    extends State<_UnknownAccountDialogScope> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          const ModalBarrier(
            dismissible: false,
            color: Color(0x66000000),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 42,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'تعذر تحديد نوع الحساب',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'لم نتمكن من ربط الحساب بنوع مستخدم صحيح. '
                          'سيتم تسجيل الخروج لحماية بيانات الحساب.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _signingOut ? null : _signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(
                            _signingOut
                                ? 'جارٍ تسجيل الخروج...'
                                : 'العودة لتسجيل الدخول',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserOnlyScope extends StatefulWidget {
  final SupabaseService service;
  final Widget child;

  const _UserOnlyScope({required this.service, required this.child});

  @override
  State<_UserOnlyScope> createState() => _UserOnlyScopeState();
}

class _UserOnlyScopeState extends State<_UserOnlyScope> {
  @override
  void initState() {
    super.initState();
    FirebaseMessagingService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
        BlocProvider<ProfileBloc>(create: (_) => ProfileBloc()),
        BlocProvider<MapBloc>(create: (_) => MapBloc(widget.service)),
        BlocProvider<VolunteerBloc>(
          create: (_) => VolunteerBloc(widget.service),
        ),
        BlocProvider<NotificationBloc>(create: (_) => sl<NotificationBloc>()),
        BlocProvider<BookingBloc>(
          create: (_) => BookingBloc(BookingRepository(widget.service)),
        ),
      ],
      child: widget.child,
    );
  }
}
