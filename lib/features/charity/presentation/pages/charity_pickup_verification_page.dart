import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CharityPickupVerificationPage extends StatefulWidget {
  final String requestId;
  final Future<Map<String, dynamic>> Function({
    required String requestId,
    required String code,
  }) onVerify;

  const CharityPickupVerificationPage({
    super.key,
    required this.requestId,
    required this.onVerify,
  });

  @override
  State<CharityPickupVerificationPage> createState() =>
      _CharityPickupVerificationPageState();
}

class _CharityPickupVerificationPageState
    extends State<CharityPickupVerificationPage> {
  static const Color primary = Color(0xFF001E15);
  static const Color green = Color(0xFF006C48);
  static const Color mint = Color(0xFF97F2C3);
  static const Color background = Color(0xFFF8FAFA);

  final MobileScannerController _scannerController = MobileScannerController();
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _busy = false;
  bool _scannerPaused = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _manualCode =>
      _codeControllers.map((controller) => controller.text.trim()).join();

  Future<void> _verify(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      _showError('أدخل كود الاستلام أو امسح رمز QR أولاً');
      return;
    }

    if (_busy) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onVerify(
        requestId: widget.requestId,
        code: normalized,
      );
      if (!mounted) return;

      final success = result['success'] == true ||
          result['verified'] == true ||
          result['status']?.toString() == 'completed';

      if (!success) {
        _showError(
          result['message']?.toString() ?? 'الكود غير صالح أو منتهي الصلاحية',
        );
        return;
      }

      await _showSuccess(
        result['message']?.toString() ?? 'تم تأكيد استلام التبرع بنجاح',
      );
    } catch (error) {
      if (mounted) {
        _showError(_friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _scannerPaused) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _scannerPaused = true;
        _scannerController.stop();
        _verify(value).whenComplete(() {
          if (!mounted) return;
          if (!_busy) {
            _scannerPaused = false;
            _scannerController.start();
          }
        });
        break;
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.length > 1) {
      _codeControllers[index].text = value.substring(0, 1);
      _codeControllers[index].selection = const TextSelection.collapsed(
        offset: 1,
      );
    }

    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_manualCode.length == 6) {
      _verify(_manualCode);
    }
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('PostgrestException(message: ', '')
        .replaceFirst(RegExp(r', code:.*'), '');
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showSuccess(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFFE3F7EC),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: green,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تم التحقق بنجاح!',
                  style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF53645D),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('متابعة'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const Text(
            'تحقق من الاستلام',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              const Text(
                'تحقق من الكود بعد استلام التبرع فعلياً لضمان وصوله بأمان.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF53645D), height: 1.5),
              ),
              const SizedBox(height: 24),
              _scannerBox(),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFC0C8C3))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو إدخال الكود يدوياً',
                      style: TextStyle(
                        color: Color(0xFF53645D),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFC0C8C3))),
                ],
              ),
              const SizedBox(height: 20),
              _manualInput(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                _errorBox(_errorMessage!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _verify(_manualCode),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_busy ? 'جارٍ التحقق...' : 'تحقق الآن'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scannerBox() {
    return Container(
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF17241F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC0C8C3)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Container(color: Colors.black.withAlpha(80)),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                children: [
                  _corner(top: 0, right: 0, topBorder: true, rightBorder: true),
                  _corner(top: 0, left: 0, topBorder: true, leftBorder: true),
                  _corner(
                      bottom: 0,
                      right: 0,
                      bottomBorder: true,
                      rightBorder: true),
                  _corner(
                      bottom: 0, left: 0, bottomBorder: true, leftBorder: true),
                  Center(
                    child: Container(
                      height: 2,
                      color: mint,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const Center(
              child: CircularProgressIndicator(color: mint),
            ),
          const Positioned(
            bottom: 18,
            left: 16,
            right: 16,
            child: Text(
              'وجّه الكاميرا إلى QR المعروض على هاتف صاحب الطلب',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? right,
    double? bottom,
    double? left,
    bool topBorder = false,
    bool rightBorder = false,
    bool bottomBorder = false,
    bool leftBorder = false,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: SizedBox(
        width: 34,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: topBorder
                  ? const BorderSide(color: mint, width: 4)
                  : BorderSide.none,
              right: rightBorder
                  ? const BorderSide(color: mint, width: 4)
                  : BorderSide.none,
              bottom: bottomBorder
                  ? const BorderSide(color: mint, width: 4)
                  : BorderSide.none,
              left: leftBorder
                  ? const BorderSide(color: mint, width: 4)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'رمز التحقق',
            style: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: List.generate(6, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 5),
                    child: TextField(
                      controller: _codeControllers[index],
                      focusNode: _focusNodes[index],
                      enabled: !_busy,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      onChanged: (value) => _onCodeChanged(index, value),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '-',
                        filled: true,
                        fillColor: const Color(0xFFF6FAF7),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFC0C8C3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: green, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE4E4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7B8B8)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
