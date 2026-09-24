// lib/features/auth/presentation/pages/otp_verify_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'complete_profile_page.dart';

// ✅ Import صفحات الـ Home للأدوار المختلفة
import 'package:loqma/features/userhome/presentation/pages/user_home_page.dart'
    as user_home;
import 'package:loqma/features/institutions/presentation/pages/institutions_home_page.dart';

class OtpVerifyPage extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> profile;

  const OtpVerifyPage({
    super.key,
    required this.phone,
    required this.profile,
  });

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _authRepo = AuthRepository(SupabaseService());
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  bool _sending = false;
  int _timer = 60;
  Timer? _timerFn;

  static const _bg = Color(0xFFF5F8F6);
  static const _primary = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _red = Color(0xFFD64545);
  static const _green = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _timerFn?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = 60;
    _timerFn?.cancel();
    _timerFn = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timer > 0) {
          _timer--;
        } else {
          _timerFn?.cancel();
        }
      });
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  // ═══════════════════════════════════════════════════════════
  // ✅ الحل: بنستخدم Navigator.pushAndRemoveUntil
  //    (نفس الـ API اللي فتح OtpVerifyPage من LoginPage)
  //    علشان نتجنب التعارض مع GoRouter
  // ═══════════════════════════════════════════════════════════

  /// ✅ بيرجّع الـ Home Page المناسبة حسب الـ role
  Widget _homePageForRole(String role) {
    switch (role.toLowerCase()) {
      case 'provider':
        // TODO: لما يكون فيه ProviderHomePage مخصصة، نغيّرها هنا
        return const user_home.UserHomePage();
      case 'institution':
      case 'charity':
        return const InstitutionsHomePage();
      case 'admin':
      case 'user':
      default:
        return const user_home.UserHomePage();
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      _snack('ادخل الكود كامل (6 أرقام)', error: true);
      return;
    }

    setState(() => _verifying = true);

    try {
      final result = await _authRepo.verifyAndCreate(
        phone: widget.phone,
        code: _code,
        profile: widget.profile,
      );

      if (!mounted) return;

      await result.fold(
        (error) async {
          setState(() => _verifying = false);
          _snack(error, error: true);
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        },
        (data) async {
          final user = data['user'] as UserModel;
          final isNewUser = data['isNewUser'] == true;

          final hasName = (user.name ?? '').trim().isNotEmpty;
          final hasCity = (user.city ?? '').trim().isNotEmpty;
          final needsProfile = isNewUser || !hasName || !hasCity;

          debugPrint(
            '✅ Verified. isNewUser=$isNewUser, '
            'hasName=$hasName, hasCity=$hasCity',
          );

          if (!mounted) return;

          if (needsProfile) {
            // 🆕 محتاج يكمّل بياناته
            _snack('✅ تم التحقق، كمّل بياناتك');
            await Future.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;

            // ✅ pushReplacement لأنها جزء من نفس الفلو
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CompleteProfilePage(
                  user: user,
                  role: widget.profile['role']?.toString() ?? 'user',
                ),
              ),
            );
          } else {
            // ✅ مستخدم قديم ببيانات كاملة → Home مباشرة
            _snack('✅ تم تسجيل الدخول');

            final role = user.type.value.toLowerCase();
            debugPrint('🔴 [OTP] navigating to home for role: $role');

            await Future.delayed(const Duration(milliseconds: 400));
            if (!mounted) return;

            // ═══════════════════════════════════════════════════
            // ✅ الحل السحري:
            //    pushAndRemoveUntil بيمسح كل الـ Navigator stack
            //    (بما فيهم OtpVerifyPage + LoginPage)
            //    ويفتح الـ Home مباشرة
            //    → مفيش لوب، مفيش رجوع للـ Login
            // ═══════════════════════════════════════════════════
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => _homePageForRole(role),
              ),
              (route) => false, // ← يمسح كل الـ routes القديمة
            );
          }
        },
      );
    } catch (e) {
      debugPrint('❌ verify error: $e');
      if (!mounted) return;
      setState(() => _verifying = false);
      _snack('تعذر التحقق، حاول تاني', error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Resend
  // ═══════════════════════════════════════════════════════════
  Future<void> _resend() async {
    if (_timer > 0 || _sending) return;

    setState(() => _sending = true);

    try {
      final result = await _authRepo.sendOtp(phone: widget.phone);
      if (!mounted) return;

      result.fold(
        (error) {
          setState(() => _sending = false);
          _snack(error, error: true);
        },
        (_) {
          setState(() => _sending = false);
          _startTimer();
          _snack('تم إرسال كود جديد ✅');
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        },
      );
    } catch (e) {
      debugPrint('❌ resend error: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      _snack('تعذر إعادة الإرسال', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: error ? _red : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 24),
                        _buildIcon(),
                        const SizedBox(height: 22),
                        const Text(
                          'تحقق من رقمك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _darkGreen,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'بعتنالك كود مكوّن من 6 أرقام على واتساب',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_rounded,
                                    color: _primary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  widget.phone,
                                  style: const TextStyle(
                                    color: _darkGreen,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) => _otpBox(i)),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _verifying ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              disabledBackgroundColor:
                                  _primary.withValues(alpha: 0.5),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _verifying
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'تحقق وكمّل',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: _timer > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
                                        size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'إعادة الإرسال خلال $_timer ثانية',
                                      style: TextStyle(
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                )
                              : TextButton.icon(
                                  onPressed: _sending ? null : _resend,
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _primary,
                                          ),
                                        )
                                      : const Icon(Icons.refresh_rounded,
                                          color: _primary, size: 18),
                                  label: const Text(
                                    'ابعت الكود تاني',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'مش وصلك الكود؟ تأكد من رقمك وحاول تاني',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.4),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _verifying ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _darkGreen,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const Text(
          'جُود',
          style: TextStyle(
            color: _primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 46),
      ],
    );
  }

  Widget _buildIcon() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_green, Color(0xFF128C7E)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child:
                const Icon(Icons.chat_rounded, color: Colors.white, size: 44),
          ),
        ],
      ),
    );
  }

  Widget _otpBox(int index) {
    final hasValue = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !_verifying,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: _darkGreen,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2ECE7), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasValue ? _primary : const Color(0xFFE2ECE7),
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (v.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_code.length == 6) {
            _verify();
          }
          setState(() {});
        },
      ),
    );
  }
}
