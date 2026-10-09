import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstitutionOtpVerifyPage extends StatefulWidget {
  final Future<bool> Function(String code) verifyCode;
  final Future<void> Function() onVerified;
  final Future<void> Function() onCancelled;

  const InstitutionOtpVerifyPage({
    super.key,
    required this.verifyCode,
    required this.onVerified,
    required this.onCancelled,
  });

  @override
  State<InstitutionOtpVerifyPage> createState() =>
      _InstitutionOtpVerifyPageState();
}

class _InstitutionOtpVerifyPageState extends State<InstitutionOtpVerifyPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;

  static const _primary = Color(0xFF315A45);
  static const _ink = Color(0xFF244536);
  static const _red = Color(0xFFB54747);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'اكتب كود التحقق المكوّن من 6 أرقام');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final allowed = await widget.verifyCode(code);
      if (!allowed) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'كود التحقق غير صحيح';
          _controller.clear();
        });
        _focusNode.requestFocus();
        return;
      }

      await widget.onVerified();
    } catch (error) {
      debugPrint('Institution OTP verification failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر التحقق حاليًا، حاول مرة أخرى';
      });
    }
  }

  Future<void> _cancel() async {
    await widget.onCancelled();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4EEE5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _loading ? null : _cancel,
            icon: const Icon(Icons.arrow_forward_rounded, color: _ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Icon(Icons.verified_user_rounded, color: _primary, size: 64),
              const SizedBox(height: 20),
              const Text(
                'تأكيد تسجيل الدخول',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink, fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                'أدخل الكود المكوّن من 6 أرقام الذي زوّدك به فريق وِصلة. يتم التحقق منه في قاعدة البيانات فقط؛ لا يُرسل برسالة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ink.withValues(alpha: 0.7), height: 1.6),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(letterSpacing: 8),
                  errorText: _error,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _loading ? null : _verify(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _loading ? null : _verify,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('تأكيد الدخول', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
