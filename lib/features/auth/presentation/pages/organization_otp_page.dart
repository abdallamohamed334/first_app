import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/repositories/auth_repository.dart';

class OrganizationOtpPage extends StatefulWidget {
  final UserModel user;
  final AuthRepository authRepo;
  final Future<void> Function() onVerified;

  const OrganizationOtpPage({
    super.key,
    required this.user,
    required this.authRepo,
    required this.onVerified,
  });

  @override
  State<OrganizationOtpPage> createState() => _OrganizationOtpPageState();
}

class _OrganizationOtpPageState extends State<OrganizationOtpPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String get _organizationLabel {
    final type = widget.user.type.value.toLowerCase();
    return type == 'charity' ? 'الجمعية' : 'المطعم';
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'أدخل كودًا مكوّنًا من 6 أرقام');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await widget.authRepo.verifyOrganizationAccessOtp(otp);
    if (!mounted) return;

    await result.fold(
      (error) async {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      },
      (_) async {
        setState(() => _isLoading = false);
        await widget.onVerified();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F6),
        appBar: AppBar(
          title: Text('تحقق من دخول $_organizationLabel'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: const Color(0xFF12372A),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: Color(0xFF0B7650),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'أدخل كود المؤسسة',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF12372A),
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'تم التحقق من البريد وكلمة المرور. أدخل الكود الإداري المكوّن من 6 أرقام للمتابعة.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              height: 1.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _otpController,
                        autofocus: true,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                          filled: true,
                          fillColor: const Color(0xFFF4F8F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0B7650),
                              width: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _isLoading ? null : _verify(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFC0392B),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B7650),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'تحقق وادخل',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('العودة لتسجيل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
