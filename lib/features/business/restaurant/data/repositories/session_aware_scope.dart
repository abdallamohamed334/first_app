import 'dart:async';

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
import 'package:loqma/features/map/presentation/bloc/map_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/notification_injection.dart';
import 'package:loqma/features/volunteer/presentation/bloc/volunteer_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the provider tree mounted while the auth session changes.
///
/// Do not conditionally replace the widget that contains [child]. Flutter
/// inherited elements must be disposed only after all descendants have been
/// detached; replacing nested BlocProviders from a StreamBuilder/FutureBuilder
/// was the source of the `_dependents.isEmpty` assertion.
class SessionAwareBlocScope extends StatefulWidget {
  final Widget child;
  final SupabaseService service;

  const SessionAwareBlocScope({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  State<SessionAwareBlocScope> createState() => _SessionAwareBlocScopeState();
}

class _SessionAwareBlocScopeState extends State<SessionAwareBlocScope> {
  late final SupabaseClient _client;
  StreamSubscription<AuthState>? _authSubscription;
  Future<String?>? _identityFuture;
  String? _identityUserId;
  String? _identityType;
  bool _identityLoading = false;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    FirebaseMessagingService.instance.initialize();

    _authSubscription = _client.auth.onAuthStateChange.listen((authState) {
      final userId = authState.session?.user.id;
      if (userId == _identityUserId &&
          authState.event != AuthChangeEvent.signedOut) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _startIdentityLookup(userId);
      });
    });

    final userId = _client.auth.currentUser?.id;
    _identityUserId = userId;
    _identityLoading = userId != null;
    _identityFuture = userId == null ? null : _resolveIdentityType(userId);
    _identityFuture?.then(_onIdentityResolved);
  }

  void _startIdentityLookup(String? userId) {
    _identityUserId = userId;
    _identityType = null;
    _identityLoading = userId != null;
    _identityFuture = userId == null ? null : _resolveIdentityType(userId);
    _identityFuture?.then(_onIdentityResolved);
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  Future<String?> _resolveIdentityType(String authUserId) async {
    try {
      final row = await _client
          .from('users')
          .select('user_type')
          .eq('id', authUserId)
          .maybeSingle();
      final rawRole = row?['user_type']?.toString().trim().toLowerCase();
      if (rawRole == 'institution') return 'institution';

      final value = await AuthIdentityResolver.resolve(_client, authUserId);
      return value.trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }

  void _onIdentityResolved(String? type) {
    if (!mounted || _identityType == type) return;
    setState(() {
      _identityType = type;
      _identityLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Every provider remains at the same position for the entire app life.
    // HomeBloc and ProfileBloc are intentionally not repeated here because
    // main.dart already owns those two providers.
    final providers = MultiBlocProvider(
      providers: [
        BlocProvider<BusinessDashboardBloc>(
          create: (_) => BusinessDashboardBloc(
            BusinessRepository(widget.service),
            widget.service,
          ),
        ),
        BlocProvider<CharityBloc>(
          create: (_) => CharityBloc(),
        ),
        BlocProvider<MapBloc>(
          create: (_) => MapBloc(widget.service),
        ),
        BlocProvider<VolunteerBloc>(
          create: (_) => VolunteerBloc(widget.service),
        ),
        BlocProvider<NotificationBloc>(
          create: (_) => sl<NotificationBloc>(),
        ),
        BlocProvider<BookingBloc>(
          create: (_) => BookingBloc(
            BookingRepository(widget.service),
          ),
        ),
      ],
      child: widget.child,
    );

    final isUnknownAccount =
        _identityUserId != null && !_identityLoading && _identityType == null;

    // Keep the provider subtree in the same position even when showing the
    // account warning. Only the overlay changes; providers are never moved or
    // disposed because of an auth-state callback.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        fit: StackFit.expand,
        children: [
          providers,
          if (isUnknownAccount) const _UnknownAccountOverlay(),
        ],
      ),
    );
  }
}

class _UnknownAccountOverlay extends StatefulWidget {
  const _UnknownAccountOverlay();

  @override
  State<_UnknownAccountOverlay> createState() => _UnknownAccountOverlayState();
}

class _UnknownAccountOverlayState extends State<_UnknownAccountOverlay> {
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
