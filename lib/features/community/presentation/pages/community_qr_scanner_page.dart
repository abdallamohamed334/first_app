import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:loqma/features/community/data/repositories/community_requests_repository.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';

class CommunityQrScannerPage extends StatefulWidget {
  const CommunityQrScannerPage({super.key});

  @override
  State<CommunityQrScannerPage> createState() => _CommunityQrScannerPageState();
}

class _CommunityQrScannerPageState extends State<CommunityQrScannerPage> {
  final _repository = CommunityRequestsRepository();
  final _controller = MobileScannerController();
  final _manualCodeController = TextEditingController();
  bool _busy = false;
  bool _handled = false;

  Future<void> _complete(String token) async {
    if (_busy || _handled || token.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _handled = true;
    });
    await _controller.stop();
    try {
      await _repository.completeByPickupToken(token);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الاستلام وإكمال الطلب')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _handled = false;
      });
      await _controller.start();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.message(
              error,
              fallback: 'تعذر إتمام التسليم. تحقق من الكود وحاول مرة أخرى.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _enterCodeManually() async {
    if (_busy) return;
    _manualCodeController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 280,
              maxWidth: 430,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إدخال كود الاستلام',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualCodeController,
                    autofocus: true,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'الكود',
                      hintText: 'اكتب الكود كما يظهر للمستخدم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          final value = _manualCodeController.text.trim();
                          if (value.isNotEmpty) {
                            Navigator.pop(dialogContext, value);
                          }
                        },
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('تحقق وتسليم'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (code != null && code.trim().isNotEmpty) {
      await _complete(code);
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('مسح كود الاستلام'),
          foregroundColor: Colors.white,
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'إدخال الكود يدويًا',
              onPressed: _busy ? null : _enterCodeManually,
              icon: const Icon(Icons.keyboard_alt_outlined),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.isNotEmpty) {
                    _complete(value);
                    break;
                  }
                }
              },
            ),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF66D49C), width: 4),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 104,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _enterCodeManually,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('أو أدخل الكود يدويًا'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF66D49C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 34,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(190),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _busy
                      ? 'جارٍ التحقق من الكود...'
                      : 'وجّه الكاميرا إلى QR المعروض على هاتف صاحب الطلب',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
