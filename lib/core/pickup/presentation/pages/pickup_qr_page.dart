import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PickupQRPage extends StatefulWidget {
  final String requestId;
  final String businessId;
  final String? existingToken;

  const PickupQRPage({
    super.key,
    required this.requestId,
    required this.businessId,
    this.existingToken,
  });

  @override
  State<PickupQRPage> createState() => _PickupQRPageState();
}

class _PickupQRPageState extends State<PickupQRPage> {
  late final BookingRepository _repository;
  late final SupabaseService _supabase;
  Timer? _countdownTimer;

  String? _token;
  DateTime? _expiresAt;
  bool _isLoading = true;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _supabase = SupabaseService();
    _repository = BookingRepository(_supabase);
    _generateOrGetToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateOrGetToken() async {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isExpired = false;
      });
    }

    try {
      final authUser = await _supabase.getCurrentUser();
      if (!mounted) return;

      if (authUser == null) {
        _showMessage('يجب تسجيل الدخول أولًا', isError: true);
        Navigator.of(context).pop();
        return;
      }

      final existingToken = widget.existingToken?.trim();
      final token = existingToken == null || existingToken.isEmpty
          ? await _repository.generatePickupToken(
              bookingId: widget.requestId,
              userId: authUser.id,
              businessId: widget.businessId,
            )
          : existingToken;

      if (!mounted) return;
      if (token == null || token.trim().isEmpty) {
        _setLoading(false);
        _showMessage('تعذر إنشاء كود الاستلام', isError: true);
        return;
      }

      final expiry = await _loadExpiry();
      if (!mounted) return;

      setState(() {
        _token = token.trim();
        _expiresAt = expiry;
        _isExpired = expiry == null || !_isBeforeNow(expiry);
        _isLoading = false;
      });

      if (expiry != null && !_isExpired) {
        _startCountdown();
      }
    } catch (_) {
      if (!mounted) return;
      _setLoading(false);
      _showMessage('حدث خطأ أثناء تجهيز كود الاستلام', isError: true);
    }
  }

  Future<DateTime?> _loadExpiry() async {
    final response = await _supabase.client
        .from('offer_requests')
        .select('pickup_token_expires_at')
        .eq('id', widget.requestId)
        .maybeSingle();

    final value = response?['pickup_token_expires_at'];
    if (value is DateTime) return value.toUtc();
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _expiresAt == null) {
        _countdownTimer?.cancel();
        return;
      }

      final expired = !_isBeforeNow(_expiresAt!);
      if (expired) _countdownTimer?.cancel();
      setState(() => _isExpired = expired);
    });
  }

  bool _isBeforeNow(DateTime date) {
    return DateTime.now().toUtc().isBefore(date.toUtc());
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
  }

  String _getTimeRemaining() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return 'غير متاح';

    final remaining = expiresAt.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return 'انتهت الصلاحية';
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _copyToken() async {
    final token = _token;
    if (token == null || token.isEmpty || _isExpired) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (mounted) _showMessage('تم نسخ الكود', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('كود الاستلام'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isExpired
              ? _buildExpiredState(colorScheme)
              : _buildQRContent(colorScheme),
    );
  }

  Widget _buildQRContent(ColorScheme colorScheme) {
    final token = _token;
    if (token == null || token.isEmpty) {
      return _buildExpiredState(colorScheme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildExpiryBanner(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: QrImageView(
              data: token,
              version: QrVersions.auto,
              size: 250,
              gapless: false,
              errorStateBuilder: (context, error) => const Icon(
                Icons.error_outline,
                size: 50,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            token,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أظهر هذا الكود للمطعم لاستلام الوجبة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _copyToken,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ الكود'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoBanner(),
        ],
      ),
    );
  }

  Widget _buildExpiryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            'متبقي: ${_getTimeRemaining()}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الكود صالح حتى انتهاء الوقت الظاهر بالأعلى.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_rounded, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'انتهت صلاحية الكود',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط لإعادة إنشاء كود جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateOrGetToken,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إنشاء كود جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
