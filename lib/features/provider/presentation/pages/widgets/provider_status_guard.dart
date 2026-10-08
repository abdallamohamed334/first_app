// lib/features/provider/presentation/widgets/provider_status_guard.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wasla/core/services/supabase_service.dart';
import 'package:wasla/routes/app_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يراقب حالة مزود الخدمة أثناء استخدام التطبيق.
/// عند الرفض أو الإيقاف يعرض رسالة واضحة، يفتح الدعم عند الطلب، ثم يسجل الخروج.
class ProviderStatusGuard extends StatefulWidget {
  final Widget child;
  final Duration interval;

  const ProviderStatusGuard({
    super.key,
    required this.child,
    this.interval = const Duration(seconds: 20),
  });

  @override
  State<ProviderStatusGuard> createState() => _ProviderStatusGuardState();
}

class _ProviderStatusGuardState extends State<ProviderStatusGuard>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF0B7650);
  static const _greenLight = Color(0xFFEAF7F0);
  static const _red = Color(0xFFD64545);
  static const _orange = Color(0xFFE08A00);
  static const _ink = Color(0xFF163D30);
  static const _supportPhoneLocal = '01040652783';
  static const _supportPhoneIntl = '201040652783';

  Timer? _timer;
  bool _checking = false;
  bool _handlingBlockedState = false;
  String? _providerId;

  SupabaseClient get _client => SupabaseService().client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProviderIdAndCheck();
    _timer = Timer.periodic(widget.interval, (_) => _checkStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _loadProviderIdAndCheck() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final provider = await _client
          .from('service_providers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      _providerId = provider?['id']?.toString();
      await _checkStatus();
    } catch (error) {
      debugPrint('⚠️ [Provider Guard] initial check skipped: $error');
    }
  }

  Future<void> _checkStatus() async {
    if (_checking || _handlingBlockedState || !mounted) return;
    final providerId = _providerId;
    if (providerId == null || providerId.isEmpty) return;

    _checking = true;
    try {
      final provider = await _client
          .from('service_providers')
          .select('verification_status, is_active, verification_notes')
          .eq('id', providerId)
          .maybeSingle();

      if (!mounted || provider == null) return;

      final status =
          provider['verification_status']?.toString().trim().toLowerCase();
      final isActive = provider['is_active'] != false;

      if (status == 'rejected' || status == 'suspended' || !isActive) {
        await _handleBlockedState(
          status: status,
          notes: provider['verification_notes']?.toString(),
        );
      }
    } catch (error) {
      // فشل اتصال مؤقت لا يخرج المستخدم بلا سبب.
      debugPrint('⚠️ [Provider Guard] status check skipped: $error');
    } finally {
      _checking = false;
    }
  }

  Future<void> _openSupportWhatsApp({
    required String status,
  }) async {
    final reason = status == 'rejected' ? 'مرفوض' : 'موقوف';
    final message = 'مرحبًا فريق وِصلة،\n\n'
        'أنا مزود خدمة وحسابي $reason.\n'
        'أحتاج معرفة السبب والمساعدة في حل المشكلة.';
    final uri = Uri.parse(
      'https://wa.me/$_supportPhoneIntl?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) _showSupportNumberFallback();
    } catch (error) {
      debugPrint('⚠️ [Provider Guard] WhatsApp launch failed: $error');
      if (mounted) _showSupportNumberFallback();
    }
  }

  void _showSupportNumberFallback() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('تواصل مع الدعم على 01040652783'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _handleBlockedState({
    required String? status,
    required String? notes,
  }) async {
    if (_handlingBlockedState || !mounted) return;
    _handlingBlockedState = true;

    final rejected = status == 'rejected';
    final normalizedStatus = rejected ? 'rejected' : 'suspended';
    final accent = rejected ? _red : _orange;
    final title = rejected ? 'تم رفض حسابك' : 'تم إيقاف حسابك';
    final subtitle = rejected
        ? 'حساب مزود الخدمة الخاص بك تم رفضه من الإدارة.'
        : 'حساب مزود الخدمة الخاص بك متوقف حاليًا.';
    final details = rejected && notes != null && notes.trim().isNotEmpty
        ? notes.trim()
        : 'تواصل مع الدعم لمراجعة الحالة ومساعدتك.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rejected ? Icons.gpp_bad_rounded : Icons.lock_clock_rounded,
                  color: accent,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  details,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_in_talk_rounded, color: _green, size: 17),
                    SizedBox(width: 7),
                    Text(
                      _supportPhoneLocal,
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _openSupportWhatsApp(
                    status: normalizedStatus,
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 21),
                  label: const Text(
                    'تواصل مع الدعم واتساب',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'تسجيل الخروج والمتابعة لاحقًا',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await SupabaseService().signOut();
    } catch (error) {
      debugPrint('⚠️ [Provider Guard] sign out failed: $error');
    }

    if (!mounted) return;
    context.go(AppRouter.userTypeSelection);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
