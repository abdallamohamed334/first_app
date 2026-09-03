import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/auth/presentation/pages/email_otp_verification_page.dart';
import 'package:loqma/features/home/presentation/pages/home_page.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthRepository _authRepo = AuthRepository(SupabaseService());

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;
  // التسجيل العام مخصص للمستخدم العادي فقط.
  static const _ordinaryUserType = 'user';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8F6),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              child: Column(
                children: [
                  _buildTopBar(colors),
                  const SizedBox(height: 20),
                  _buildHero(colors),
                  const SizedBox(height: 22),
                  _buildFormCard(colors),
                  const SizedBox(height: 20),
                  _buildLoginLink(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF174C3B),
          ),
        ),
        const Text(
          'Loqma',
          style: TextStyle(
            color: Color(0xFF0B7650),
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildHero(ColorScheme colors) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B7650), Color(0xFF25B77C)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B7650).withAlpha(55),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'انضم إلى لقمة',
          style: TextStyle(
            color: Color(0xFF123F31),
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'شارك الطعام، قلّل الهدر، واصنع أثرًا حقيقيًا',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أنشئ حسابك الآن',
            style: TextStyle(
              color: Color(0xFF153F31),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'اختر نوع الحساب وأدخل بياناتك',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 17),
          _buildOrdinaryUserNotice(),
          const SizedBox(height: 18),
          AuthTextField(
            controller: _nameController,
            label: 'الاسم الكامل',
            hint: 'أدخل اسمك بالكامل',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 13),
          AuthTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            hint: '01012345678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')),
              LengthLimitingTextInputFormatter(16),
            ],
          ),
          const SizedBox(height: 13),
          AuthTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            hint: 'example@domain.com',
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 13),
          AuthTextField(
            controller: _passwordController,
            label: 'كلمة المرور',
            hint: '6 أحرف على الأقل',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 13),
          AuthTextField(
            controller: _confirmPasswordController,
            label: 'تأكيد كلمة المرور',
            hint: 'أعد كتابة كلمة المرور',
            prefixIcon: Icons.lock_reset_outlined,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildTermsRow(colors),
          const SizedBox(height: 15),
          AuthButton(
            text: 'إنشاء الحساب',
            isLoading: _isLoading,
            onPressed: _handleRegister,
            icon: Icons.person_add_alt_1_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOrdinaryUserNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7EADF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_outline_rounded, color: Color(0xFF0B7650)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'التسجيل هنا للمستخدمين العاديين فقط. حسابات المطاعم والمؤسسات يتم إنشاؤها وإدارتها من لوحة الإدارة.',
              style: TextStyle(
                color: Color(0xFF315A49),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow(ColorScheme colors) {
    return InkWell(
      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Checkbox(
            value: _agreeTerms,
            activeColor: const Color(0xFF159666),
            onChanged: (value) => setState(() => _agreeTerms = value ?? false),
          ),
          Expanded(
            child: Text(
              'أوافق على الشروط وسياسة الخصوصية',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
          child: const Text(
            'تسجيل الدخول',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final phone = _normalizeEgyptianPhone(_phoneController.text);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;

    if (name.length < 3) {
      _showError('يرجى إدخال الاسم، 3 أحرف على الأقل');
      return;
    }
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
      _showError(
          'أدخل رقم هاتف مصري صحيح مكونًا من 11 رقمًا ويبدأ بـ 010 أو 011 أو 012 أو 015');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    if (password.length < 6) {
      _showError('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (password != confirmation) {
      _showError('كلمتا المرور غير متطابقتين');
      return;
    }
    if (!_agreeTerms) {
      _showError('يجب الموافقة على الشروط وسياسة الخصوصية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('[RegisterPageDebug] PATCHED_REGISTER_PAGE_V2');
      debugPrint(
        '[RegisterPageDebug] before AuthRepository.register '
        'email=$email phone=$phone userType=$_ordinaryUserType',
      );
      final result = await _authRepo.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        userType: _ordinaryUserType,
      );

      debugPrint(
          '[RegisterPageDebug] after AuthRepository.register result=$result');
      if (!mounted) return;

      result.fold(
        _showRegistrationError,
        (userId) {
          _openEmailVerification(userId, email);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('[RegisterPageDebug] CATCH type=${error.runtimeType}');
      debugPrint('[RegisterPageDebug] CATCH error=$error');
      debugPrint('[RegisterPageDebug] CATCH stack=$stackTrace');
      if (mounted) _showRegistrationError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEmailVerification(String userId, String email) async {
    final result = await _authRepo.issueSignupEmailCode(
      userId: userId,
      email: email,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;

    String? errorMessage;
    result.fold((error) => errorMessage = error, (_) {});
    if (errorMessage != null) {
      _showRegistrationError(errorMessage!);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EmailOtpVerificationPage(
          email: email,
          authRepo: _authRepo,
          onVerified: (_) async {
            await _authRepo.logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  String _normalizeEgyptianPhone(String value) {
    var phone = value
        .trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(RegExp(r'[\s().-]'), '');

    if (phone.startsWith('+20')) phone = phone.substring(3);
    if (phone.startsWith('0020')) phone = phone.substring(4);
    if (phone.startsWith('20') && phone.length == 12)
      phone = phone.substring(2);
    if (phone.length == 10) phone = '0$phone';
    return phone;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD64545),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showRegistrationError(String error) {
    final normalized = error.toLowerCase();
    var message = error;

    if (normalized.contains('already') || normalized.contains('exists')) {
      message = 'البريد الإلكتروني مستخدم بالفعل. استخدم بريدًا آخر.';
    } else if (normalized.contains('phone')) {
      message = 'رقم الهاتف مستخدم بالفعل. استخدم رقمًا آخر.';
    } else if (normalized.contains('rate') || normalized.contains('too many')) {
      message = 'تمت محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.';
    } else if (normalized.contains('confirm') ||
        normalized.contains('تأكيد البريد')) {
      message = error;
    }

    _showError(message);
  }
}
