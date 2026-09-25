// lib/features/provider/presentation/pages/provider_otp_verify_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/routes/app_router.dart';

class ProviderOtpVerifyPage extends StatefulWidget {
  final String phone;
  final String displayName;
  final String categoryId;
  final String providerType;
  final String? email;

  const ProviderOtpVerifyPage({
    super.key,
    required this.phone,
    required this.displayName,
    required this.categoryId,
    required this.providerType,
    this.email,
  });

  @override
  State<ProviderOtpVerifyPage> createState() => _ProviderOtpVerifyPageState();
}

class _ProviderOtpVerifyPageState extends State<ProviderOtpVerifyPage> {
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _error = Color(0xFFD64545);

  final _repo = ServiceProviderRepository();
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  bool _sending = false;
  int _timer = 60;
  Timer? _timerFn;
  String? _errorMessage;

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

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _errorMessage = 'ادخل الكود كامل (6 أرقام)');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _errorMessage = null;
    });

    final result = await _repo.verifyAndCreateProvider(
      phone: widget.phone,
      code: _code,
      displayName: widget.displayName,
      categoryId: widget.categoryId,
      providerType: widget.providerType,
      email: widget.email,
    );

    if (!mounted) return;

    result.fold(
      (err) {
        setState(() {
          _verifying = false;
          _errorMessage = err;
        });
      },
      (data) {
        final provider = data['provider'] as Map<String, dynamic>;
        final status = data['status']?.toString() ??
            provider['verification_status']?.toString() ??
            'pending';
        final isActive = provider['is_active'] as bool? ?? true;
        final needsApproval = data['needsApproval'] == true;

        debugPrint(
          '✅ [Provider OTP] verified → status=$status, active=$isActive, '
          'needsApproval=$needsApproval',
        );

        // ══════════════════════════════════════════════════════
        // ✅ تحديث AuthStateNotifier — يخلي الـ router يعرف الحالة
        // ══════════════════════════════════════════════════════
        AuthStateNotifier.instance.setLoggedIn(
          isLoggedIn: true,
          role: 'provider',
          providerStatus: status,
          isActive: isActive,
        );

        // ✅ التوجيه
        if (needsApproval || status != 'approved') {
          context.go(AppRouter.providerPending, extra: provider);
        } else {
          context.go(AppRouter.providerHome);
        }
      },
    );
  }

  Future<void> _resend() async {
    if (_timer > 0 || _sending) return;
    setState(() => _sending = true);

    final result = await _repo.sendProviderOtp(phone: widget.phone);

    if (!mounted) return;

    result.fold(
      (err) {
        setState(() {
          _sending = false;
          _errorMessage = err;
        });
      },
      (_) {
        setState(() {
          _sending = false;
          _errorMessage = null;
        });
        _startTimer();
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bg, _bgDark],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight - 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed:
                                  _verifying ? null : () => context.pop(),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  color: _ink),
                            ),
                          ),

                          // Icon
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF25D366)
                                        .withValues(alpha: 0.08),
                                  ),
                                ),
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF25D366),
                                        Color(0xFF128C7E)
                                      ],
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomLeft,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF25D366)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.chat_rounded,
                                      color: Colors.white, size: 40),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          const Text(
                            'تحقق من رقمك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'بعتنالك كود مكوّن من 6 أرقام على واتساب',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _inkSoft.withValues(alpha: 0.75),
                              fontSize: 13.5,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Phone chip
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: _blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _blue.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_rounded,
                                      color: _blue, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.phone,
                                    style: const TextStyle(
                                      color: _ink,
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

                          // Error
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: _error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: _error,
                                        fontSize: 12.5,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (i) => _otpBox(i)),
                          ),
                          const SizedBox(height: 28),

                          // Verify button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _verifying ? null : _verify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                disabledBackgroundColor:
                                    _blue.withValues(alpha: 0.5),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'تحقق وكمّل',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Resend
                          Center(
                            child: _timer > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          color:
                                              _inkSoft.withValues(alpha: 0.5),
                                          size: 15),
                                      const SizedBox(width: 6),
                                      Text(
                                        'إعادة الإرسال خلال $_timer ثانية',
                                        style: TextStyle(
                                          color:
                                              _inkSoft.withValues(alpha: 0.6),
                                          fontSize: 12.5,
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
                                              color: _blue,
                                            ),
                                          )
                                        : const Icon(Icons.refresh_rounded,
                                            color: _blue, size: 18),
                                    label: const Text(
                                      'ابعت الكود تاني',
                                      style: TextStyle(
                                        color: _blue,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
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
          color: _ink,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _cardBg,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2ECE7), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasValue ? _blue : const Color(0xFFE2ECE7),
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _blue, width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (v.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
          if (_code.length == 6) _verify();
        },
      ),
    );
  }
}
