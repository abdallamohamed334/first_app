// lib/features/auth/presentation/pages/register_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/auth/presentation/pages/otp_verify_page.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  /// نوع الحساب: user | provider | institution
  final String role;

  const RegisterPage({
    super.key,
    this.role = 'user',
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final AuthRepository _authRepo = AuthRepository(SupabaseService());

  bool _isLoading = false;
  bool _agreeTerms = false;

  // ── ألوان
  static const _bg = Color(0xFFF5F8F6);
  static const _primary = Color(0xFF0B7650);
  static const _primaryLight = Color(0xFF25B77C);
  static const _darkGreen = Color(0xFF123F31);
  static const _red = Color(0xFFD64545);

  // ✅ هل ده تسجيل مؤسسة/مقدم؟
  bool get _isProvider => widget.role == 'provider';
  bool get _isInstitution => widget.role == 'institution';

  String get _roleTitle {
    if (_isProvider) return 'مقدم خدمة';
    if (_isInstitution) return 'مؤسسة';
    return 'مستخدم';
  }

  IconData get _roleIcon {
    if (_isProvider) return Icons.handyman_rounded;
    if (_isInstitution) return Icons.business_rounded;
    return Icons.person_rounded;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
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

  // ═══════════════════════════════════════════════════════════
  // Top Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildTopBar(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _darkGreen,
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
        const SizedBox(width: 44),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Hero
  // ═══════════════════════════════════════════════════════════
  Widget _buildHero(ColorScheme colors) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _primaryLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            _roleIcon,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 17),
        Text(
          'انضم إلى جُود',
          style: const TextStyle(
            color: _darkGreen,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'سجّل بياناتك وهيوصلك كود على واتساب',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Form Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildFormCard(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حساب $_roleTitle جديد',
            style: const TextStyle(
              color: Color(0xFF153F31),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'ادخل بياناتك وهنراجع الحساب',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 17),

          // ── تنبيه واتساب
          _buildWhatsAppNotice(),
          const SizedBox(height: 18),

          // ── الاسم
          AuthTextField(
            controller: _nameController,
            label: _isInstitution ? 'اسم المؤسسة' : 'الاسم الكامل',
            hint: _isInstitution ? 'مثال: مؤسسة الخير' : 'أدخل اسمك بالكامل',
            prefixIcon: _isInstitution
                ? Icons.business_rounded
                : Icons.person_outline_rounded,
          ),
          const SizedBox(height: 13),

          // ── الهاتف
          AuthTextField(
            controller: _phoneController,
            label: 'رقم الهاتف (واتساب)',
            hint: '01012345678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')),
              LengthLimitingTextInputFormatter(16),
            ],
          ),
          const SizedBox(height: 14),

          // ── الشروط
          _buildTermsRow(colors),
          const SizedBox(height: 15),

          // ── زر الإرسال
          AuthButton(
            text: 'إرسال كود التحقق',
            isLoading: _isLoading,
            onPressed: _handleRegister,
            icon: Icons.send_rounded,
          ),

          const SizedBox(height: 10),
          const Center(
            child: Text(
              'هيوصلك كود مكوّن من 6 أرقام على واتساب 📲',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Notice
  // ═══════════════════════════════════════════════════════════
  Widget _buildWhatsAppNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7EADF)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF128C7E)],
              ),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'هنبعتلك كود تحقق على واتساب. تأكد إن الرقم متاح على واتساب.',
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

  // ═══════════════════════════════════════════════════════════
  // Terms
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // Login Link
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // Register Handler — بيسجل + يروح لصفحة OTP
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final phone = _normalizeEgyptianPhone(_phoneController.text);

    // ── Validation
    if (name.length < 3) {
      _showError('يرجى إدخال الاسم، 3 أحرف على الأقل');
      return;
    }
    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
      _showError('أدخل رقم هاتف مصري صحيح (11 رقم يبدأ بـ 010/011/012/015)');
      return;
    }
    if (!_agreeTerms) {
      _showError('يجب الموافقة على الشروط وسياسة الخصوصية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('📌 [Register] name=$name phone=$phone role=${widget.role}');

      // ── نبني البروفايل كامل (للأدوار)
      final profile = <String, dynamic>{
        'name': name,
        'role': widget.role,
        'city': 'طنطا',
      };

      // ✅ نبعت OTP عبر AuthRepository
      final result = await _authRepo.sendOtp(phone: phone);

      if (!mounted) return;

      await result.fold(
        (error) async {
          _showError(error);
        },
        (returnedPhone) async {
          // ✅ نروح لصفحة التحقق
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyPage(
                phone: returnedPhone,
                profile: profile,
              ),
            ),
          );

          if (!mounted) return;

          if (verified == true) {
            // ✅ التسجيل تم بنجاح
            // OtpVerifyPage هيتعامل مع التوجيه حسب الـ role
            debugPrint('✅ [Register] verification success');
          }
        },
      );
    } catch (error, stackTrace) {
      debugPrint('❌ [Register] type=${error.runtimeType}');
      debugPrint('❌ [Register] error=$error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showError('تعذر إتمام التسجيل، حاول تاني');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Normalize Egyptian Phone
  // ═══════════════════════════════════════════════════════════
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
    if (phone.startsWith('20') && phone.length == 12) {
      phone = phone.substring(2);
    }
    if (phone.length == 10) phone = '0$phone';
    return phone;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
