import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/data/repositories/booking_repository.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQRPage extends StatefulWidget {
  final String businessId;

  const ScanQRPage({super.key, required this.businessId});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final MobileScannerController _controller = MobileScannerController();
  final BookingRepository _repository = BookingRepository(SupabaseService());

  bool _processing = false;
  Map<String, dynamic>? _result;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    String? token;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        token = value;
        break;
      }
    }
    if (token == null) return;

    setState(() {
      _processing = true;
      _result = null;
    });
    try {
      await _controller.stop();
      final verification = await _repository.verifyPickupToken(
        token: token,
        restaurantId: widget.businessId,
      );
      if (!mounted) return;
      setState(() => _result = verification);
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = {
            'success': false,
            'message': 'تعذر التحقق من رمز الاستلام حاليًا',
          });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _scanAgain() async {
    if (!mounted) return;
    setState(() => _result = null);
    try {
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = {
            'success': false,
            'message': 'تعذر تشغيل الكاميرا. تحقق من صلاحية استخدامها.',
          });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final success = result?['success'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح رمز الاستلام'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                IgnorePointer(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_processing)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Text(
                  result == null
                      ? 'ضع رمز الاستلام في وسط الإطار للتحقق منه'
                      : (result['message']?.toString() ??
                          (success ? 'تم تأكيد الاستلام' : 'تعذر التحقق من الرمز')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: result == null
                        ? Theme.of(context).colorScheme.onSurface
                        : success
                            ? Colors.green.shade800
                            : Colors.red.shade700,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _processing ? null : _scanAgain,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('مسح رمز آخر'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
