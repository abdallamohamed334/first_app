import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';

class BusinessRestaurantPickupPage extends StatefulWidget {
  const BusinessRestaurantPickupPage({super.key});

  @override
  State<BusinessRestaurantPickupPage> createState() =>
      _BusinessRestaurantPickupPageState();
}

class _BusinessRestaurantPickupPageState
    extends State<BusinessRestaurantPickupPage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);

  final _repository = BusinessRestaurantRepository();
  final _scannerController = MobileScannerController();
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());

  int _tab = 0;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _success;

  @override
  void dispose() {
    _scannerController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _manualCode =>
      _codeControllers.map((controller) => controller.text).join();

  String _normalizeCode(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    return value.trim().split('').map((char) {
      final index = arabicDigits.indexOf(char);
      return index >= 0 ? '$index' : char;
    }).join();
  }

  Future<void> _switchTab(int tab) async {
    if (_busy) return;
    setState(() {
      _tab = tab;
      _error = null;
      _success = null;
    });
    if (tab == 0) {
      await _scannerController.start();
    } else {
      await _scannerController.stop();
      if (mounted) _codeFocusNodes.first.requestFocus();
    }
  }

  Future<void> _verify(String rawCode) async {
    final code = _normalizeCode(rawCode);
    if (_busy || !RegExp(r'^\d{6}$').hasMatch(code)) {
      if (mounted && !_busy) {
        setState(() => _error = 'كود الاستلام يجب أن يتكون من 6 أرقام فقط.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    await _scannerController.stop();
    try {
      final result = await _repository.verifyPickupCode(code);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = result;
      });
      RestaurantOperationFeedback.success(context, 'تم تأكيد الاستلام بنجاح.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            AppErrorMapper.message(error, fallback: 'الكود غير صحيح أو منتهي.');
      });
      RestaurantOperationFeedback.error(context, error);
      if (_tab == 0) await _scannerController.start();
    }
  }

  Future<void> _verifyManual() async {
    final code = _normalizeCode(_manualCode);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'أدخل كود الاستلام المكون من 6 أرقام.');
      return;
    }
    await _verify(code);
  }

  void _handleDigitChanged(int index, String value) {
    if (value.length > 1) {
      _codeControllers[index].text = value.characters.last;
      _codeControllers[index].selection =
          const TextSelection.collapsed(offset: 1);
    }
    if (value.isNotEmpty && index < _codeFocusNodes.length - 1) {
      _codeFocusNodes[index + 1].requestFocus();
    }
    if (_manualCode.length == 6) _verifyManual();
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _codeControllers[index].text.isEmpty &&
        index > 0) {
      _codeFocusNodes[index - 1].requestFocus();
      _codeControllers[index - 1].clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
          elevation: 0,
          surfaceTintColor: Colors.white,
          titleSpacing: 16,
          leading: IconButton(
            tooltip: 'العودة',
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          title: const Text('تأكيد الاستلام',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                onPressed: _busy ? null : () => _switchTab(_tab),
                icon: const Icon(Icons.refresh_rounded)),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 34),
          children: [
            const Text('تأكيد الاستلام',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: primary, fontSize: 29, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('يرجى تأكيد استلام الطلب لضمان الجودة والتتبع.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 15)),
            const SizedBox(height: 22),
            _tabs(),
            const SizedBox(height: 20),
            if (_success != null)
              _successCard()
            else if (_tab == 0)
              _scannerView()
            else
              _manualView(),
            const SizedBox(height: 22),
            _securityWarning(),
          ],
        ),
      ),
    );
  }

  Widget _tabs() => Container(
        height: 54,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: const Color(0xFFE6EEFF),
            borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          Expanded(
              child: _tabButton(0, Icons.qr_code_scanner_rounded, 'سكان QR')),
          Expanded(
              child: _tabButton(1, Icons.keyboard_alt_rounded, 'إدخال الكود')),
        ]),
      );

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _tab == index;
    return InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x12000000), blurRadius: 4)]
                : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: selected ? primary : muted),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  color: selected ? primary : muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _scannerView() => Column(children: [
        _scannerFrame(),
        const SizedBox(height: 14),
        const Text(
            'ضع رمز الاستجابة السريعة الخاص بالطلب داخل الإطار للمسح الضوئي.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 14, height: 1.45)),
        if (_busy) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: green)
        ],
        if (_error != null) ...[const SizedBox(height: 16), _errorBox(_error!)],
      ]);

  Widget _scannerFrame() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(fit: StackFit.expand, children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        _verify(raw);
                        break;
                      }
                    }
                  },
                ),
                IgnorePointer(
                    child: CustomPaint(painter: _ScannerOverlayPainter())),
                if (_busy)
                  Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child:
                          const CircularProgressIndicator(color: Colors.white)),
              ]),
            ),
          ),
        ),
      );

  Widget _manualView() => Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0EAE5)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x080B7650),
                    blurRadius: 13,
                    offset: Offset(0, 5))
              ]),
          child: Column(children: [
            const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('أدخل كود الاستلام المكون من 6 أرقام',
                    style:
                        TextStyle(color: muted, fontWeight: FontWeight.w700))),
            const SizedBox(height: 18),
            Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    _digitField(i),
                    if (i == 2)
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('-',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)))
                  ]
                ]),
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                    onPressed: _busy ? null : _verifyManual,
                    style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11))),
                    child: Text(_busy ? 'جارٍ التحقق...' : 'تأكيد الكود',
                        style: const TextStyle(fontWeight: FontWeight.w800)))),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _errorBox(_error!)
            ],
          ]),
        ),
      ]);

  Widget _digitField(int index) => SizedBox(
        width: 43,
        height: 54,
        child: Focus(
          onKeyEvent: (_, event) => _handleKey(index, event),
          child: TextField(
            controller: _codeControllers[index],
            focusNode: _codeFocusNodes[index],
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            maxLength: 1,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _handleDigitChanged(index, value),
            decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Color(0xFFBFC9C3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: primary, width: 1.5))),
            style: const TextStyle(
                color: primary, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      );

  Widget _successCard() {
    final title =
        _success?['offer_title'] ?? _success?['title'] ?? 'تم تأكيد الاستلام';
    final reference = _success?['request_id'] ?? _success?['offer_id'];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF8F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF80BEA6))),
      child: Column(children: [
        Container(
            width: 68,
            height: 68,
            decoration:
                const BoxDecoration(color: green, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 42)),
        const SizedBox(height: 14),
        const Text('تم تأكيد الاستلام بنجاح',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: primary, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(title.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
        if (reference != null) ...[
          const SizedBox(height: 7),
          Text('مرجع العملية: $reference',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: muted, fontSize: 12))
        ],
        const SizedBox(height: 18),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: primary),
            child: const Text('العودة إلى مساحة المطعم')),
      ]),
    );
  }

  Widget _errorBox(String message) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFE5E1),
          borderRadius: BorderRadius.circular(11)),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFFBA1A1A), fontWeight: FontWeight.w700)));

  Widget _securityWarning() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFE5E1).withValues(alpha: .6),
          borderRadius: BorderRadius.circular(13),
          border:
              Border.all(color: const Color(0xFFBA1A1A).withValues(alpha: .2))),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.gpp_maybe_rounded, color: Color(0xFFBA1A1A)),
        SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تنبيه أمني',
              style: TextStyle(
                  color: Color(0xFFBA1A1A), fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
              'تحقق من الكود فقط عند حضور العميل أو المندوب فعليًا، ولا تشارك رمز الاستلام مع أي شخص آخر.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.4))
        ]))
      ]));
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: .48);
    final frame = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: size.center(Offset.zero),
            width: size.width * .72,
            height: size.width * .72),
        const Radius.circular(18));
    canvas.drawPath(
        Path.combine(PathOperation.difference,
            Path()..addRect(Offset.zero & size), Path()..addRRect(frame)),
        overlay);
    final corner = Paint()
      ..color = const Color(0xFF80BEA6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(frame, corner);
    final line = Paint()
      ..color = const Color(0xFF80BEA6)
      ..strokeWidth = 2;
    final y = size.height * .5;
    canvas.drawLine(
        Offset(size.width * .15, y), Offset(size.width * .85, y), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
