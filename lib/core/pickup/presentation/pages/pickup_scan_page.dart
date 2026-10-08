import 'package:flutter/material.dart';
import 'package:loqma/core/pickup/data/repositories/pickup_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PickupScanPage extends StatefulWidget {
  final String restaurantId;

  const PickupScanPage({
    super.key,
    required this.restaurantId,
  });

  @override
  State<PickupScanPage> createState() => _PickupScanPageState();
}

class _PickupScanPageState extends State<PickupScanPage> {
  late final MobileScannerController _scannerController;
  late final PickupRepository _repository;

  bool _isScanning = true;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _repository = PickupRepository(SupabaseService());
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String rawToken) async {
    final token = rawToken.trim();
    if (!_isScanning || _isValidating || token.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isValidating = true;
    });

    try {
      final result = await _repository.verifyPickupToken(
        token: token,
        restaurantId: widget.restaurantId,
      );

      if (!mounted) return;

      final isSuccessful =
          result['success'] == true || result['isValid'] == true;
      if (isSuccessful) {
        await _showSuccessDialog(
          message: _asString(result['message']) ?? 'تم تسليم الوجبة بنجاح',
          userId: _asString(result['userId']),
          requestId: _asString(result['requestId']),
        );
      } else {
        await _showErrorDialog(
          _asString(result['message']) ?? 'كود الاستلام غير صحيح',
        );
      }
    } catch (_) {
      if (mounted) {
        await _showErrorDialog('تعذر التحقق من كود الاستلام');
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isScanning = true;
      });
    }
  }

  Future<void> _showSuccessDialog({
    required String message,
    String? userId,
    String? requestId,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text('نجاح'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(fontSize: 16)),
              if (userId != null || requestId != null) ...[
                const SizedBox(height: 12),
                Text(
                  'تم تسجيل عملية الاستلام بنجاح.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('تم'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text('تعذر التحقق'),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        );
      },
    );
  }

  static String? _asString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح كود الاستلام'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تشغيل الفلاش',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed:
                _isValidating ? null : () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (!_isScanning || _isValidating) return;

              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.trim().isNotEmpty) {
                  _handleScan(value);
                  break;
                }
              }
            },
          ),
          if (_isScanning) _buildScannerOverlay(),
          if (_isValidating) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'ضع الكود داخل الإطار',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withAlpha(150),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'جاري التحقق...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
