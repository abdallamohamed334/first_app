import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/repositories/auth_repository.dart';

import '../widgets/auth_button.dart';

class EmailOtpVerificationPage extends StatefulWidget {
  final String email;
  final AuthRepository authRepo;
  final Future<void> Function(UserModel user) onVerified;

  const EmailOtpVerificationPage({
    super.key,
    required this.email,
    required this.authRepo,
    required this.onVerified,
  });

  @override
  State<EmailOtpVerificationPage> createState() =>
      _EmailOtpVerificationPageState();
}

class _EmailOtpVerificationPageState extends State<EmailOtpVerificationPage> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading || _resending) return;

    final code = _normalizeDigits(_codeController.text);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('أدخل كود التحقق المكوّن من 6 أرقام');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await widget.authRepo.verifySignupEmailOtp(
        email: widget.email.trim().toLowerCase(),
        token: code,
      );

      if (!mounted) return;

      UserModel? verifiedUser;
      String? errorMessage;
      result.fold(
        (error) => errorMessage = error,
        (user) => verifiedUser = user,
      );

      if (errorMessage != null) {
        _showError(errorMessage!);
        return;
      }

      if (verifiedUser != null) {
        await widget.onVerified(verifiedUser!);
      } else if (mounted) {
        _showError('تعذر تحميل بيانات الحساب بعد التحقق');
      }
    } catch (error) {
      debugPrint('EMAIL OTP UI ERROR: ${error.runtimeType}');
      if (mounted) _showError('تعذر التحقق من الكود. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading || _resending) return;

    setState(() => _resending = true);
    try {
      final result = await widget.authRepo.resendSignupEmailOtp(
        email: widget.email.trim().toLowerCase(),
      );
      if (!mounted) return;

      String? errorMessage;
      var sent = false;
      result.fold(
        (error) => errorMessage = error,
        (_) => sent = true,
      );

      if (sent) {
        _showSuccess('تم إرسال كود جديد إلى بريدك الإلكتروني');
      } else {
        _showError(errorMessage ?? 'تعذر إعادة إرسال الكود');
      }
    } catch (error) {
      debugPrint('EMAIL OTP RESEND ERROR: ${error.runtimeType}');
      if (mounted) _showError('تعذر إعادة إرسال الكود حاليًا');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF159666),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  static String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    return value.split('').map((character) {
      final index = arabic.indexOf(character);
      return index >= 0 ? western[index] : character;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F6),
        appBar: AppBar(
          title: const Text('تأكيد البريد الإلكتروني'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF123F31),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 78,
                  color: Color(0xFF0B7650),
                ),
                const SizedBox(height: 20),
                const Text(
                  'أدخل كود البريد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                Text(
                  'أرسلنا كود التحقق إلى\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  autofocus: true,
                  enabled: !_loading,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText: 'كود التحقق',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AuthButton(
                  text: 'تحقق ودخول',
                  isLoading: _loading,
                  onPressed: () {
                    if (_loading || _resending) return;
                    _verify();
                  },
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _loading || _resending
                      ? null
                      : () {
                          _resend();
                        },
                  icon: _resending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة إرسال الكود'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'إذا كان الكود خاطئًا سيظل الحساب غير مؤكد ولن يتم السماح بالدخول.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
