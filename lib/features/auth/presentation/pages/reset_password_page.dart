import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/core/utils/validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _authRepo = AuthRepository(SupabaseService());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Stack(
          children: [
            _buildBackground(colorScheme),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildAppBar(colorScheme),
                    const SizedBox(height: 40),
                    _buildHeader(colorScheme),
                    const SizedBox(height: 32),
                    _buildForm(colorScheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(ColorScheme colorScheme) {
    return Stack(
      children: [
        Positioned(
          top: -MediaQuery.of(context).size.height * 0.1,
          right: -MediaQuery.of(context).size.width * 0.1,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.width * 0.4,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 100,
                  spreadRadius: 50,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -MediaQuery.of(context).size.height * 0.05,
          left: -MediaQuery.of(context).size.width * 0.05,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.3,
            height: MediaQuery.of(context).size.width * 0.3,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.2),
                  blurRadius: 80,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Text(
          'loqma',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isOtpVerified
                ? Icons.check_circle_rounded
                : Icons.lock_reset_rounded,
            size: 40,
            color: _isOtpVerified ? Colors.green : colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isOtpVerified ? 'تغيير كلمة المرور' : 'إعادة تعيين كلمة المرور',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isOtpVerified
              ? 'أدخل كلمة المرور الجديدة'
              : 'سنرسل لك كوداً إلى بريدك الإلكتروني',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Email Field
          if (!_isOtpVerified) ...[
            AuthTextField(
              controller: _emailController,
              label: 'البريد الإلكتروني',
              hint: 'example@domain.com',
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
          ],
          // OTP Field
          if (_isOtpSent && !_isOtpVerified) ...[
            AuthTextField(
              controller: _otpController,
              label: 'رمز التحقق',
              hint: 'أدخل الرمز المكون من 6 أرقام',
              prefixIcon: Icons.pin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // New Password
          if (_isOtpVerified) ...[
            AuthTextField(
              controller: _newPasswordController,
              label: 'كلمة المرور الجديدة',
              hint: '********',
              prefixIcon: Icons.lock,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'تأكيد كلمة المرور',
              hint: '********',
              prefixIcon: Icons.lock_reset,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Buttons
          if (!_isOtpSent && !_isOtpVerified)
            AuthButton(
              text: 'إرسال الكود',
              isLoading: _isLoading,
              onPressed: () {
                _sendOtp();
              },
              icon: Icons.send,
            ),
          if (_isOtpSent && !_isOtpVerified)
            Row(
              children: [
                Expanded(
                  child: AuthButton(
                    text: 'تحقق',
                    isLoading: _isLoading,
                    onPressed: () {
                      _verifyOtp();
                    },
                    icon: Icons.check,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _sendOtp();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      'إعادة الإرسال',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_isOtpVerified)
            AuthButton(
              text: 'تغيير كلمة المرور',
              isLoading: _isLoading,
              onPressed: _updatePassword,
              icon: Icons.save,
            ),
        ],
      ),
    );
  }

  // ============ SEND OTP ============

  Future<void> _sendOtp() async {
    if (_isLoading) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!Validators.isValidEmail(email)) {
      _showError('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authRepo.sendResetOtp(email);
      if (!mounted) return;

      String? errorMessage;
      var sent = false;
      result.fold(
        (error) => errorMessage = error,
        (_) => sent = true,
      );

      if (sent) {
        setState(() => _isOtpSent = true);
        _showSuccess('تم إرسال كود الاستعادة إلى بريدك الإلكتروني');
      } else {
        _showError(errorMessage ?? 'تعذر إرسال كود الاستعادة');
      }
    } catch (error) {
      debugPrint('RESET OTP SEND FAILURE: ${error.runtimeType}');
      if (mounted) _showError('تعذر إرسال كود الاستعادة حاليًا');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ VERIFY OTP ============

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    final code = _normalizeDigits(_otpController.text);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('يرجى إدخال الرمز المكون من 6 أرقام');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authRepo.verifyResetOtp(
        email: _emailController.text.trim().toLowerCase(),
        code: code,
      );
      if (!mounted) return;

      String? errorMessage;
      var verified = false;
      result.fold(
        (error) => errorMessage = error,
        (value) => verified = value,
      );

      if (verified) {
        setState(() => _isOtpVerified = true);
        _showSuccess('تم التحقق من الكود بنجاح');
      } else {
        _showError(errorMessage ?? 'الكود غير صحيح أو منتهي');
      }
    } catch (error) {
      debugPrint('RESET OTP VERIFY FAILURE: ${error.runtimeType}');
      if (mounted) _showError('تعذر التحقق من كود الاستعادة');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============ UPDATE PASSWORD ============

  Future<void> _updatePassword() async {
    if (_isLoading) return;
    final password = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;

    if (!Validators.isValidPassword(password)) {
      _showError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password != confirmation) {
      _showError('كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authRepo.updatePassword(
        email: _emailController.text.trim().toLowerCase(),
        newPassword: password,
      );
      if (!mounted) return;

      String? errorMessage;
      var updated = false;
      result.fold(
        (error) => errorMessage = error,
        (_) => updated = true,
      );

      if (!updated) {
        _showError(errorMessage ?? 'تعذر تحديث كلمة المرور');
        return;
      }

      _showSuccess('تم تغيير كلمة المرور بنجاح');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint('RESET PASSWORD UPDATE FAILURE: ${error.runtimeType}');
      if (mounted) _showError('تعذر تحديث كلمة المرور حاليًا');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    return value.split('').map((character) {
      final index = arabic.indexOf(character);
      return index >= 0 ? western[index] : character;
    }).join();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
