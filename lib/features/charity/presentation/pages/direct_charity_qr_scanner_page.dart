import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DirectCharityQrScannerPage extends StatefulWidget {
  final String requestId;
  const DirectCharityQrScannerPage({super.key, required this.requestId});

  @override
  State<DirectCharityQrScannerPage> createState() =>
      _DirectCharityQrScannerPageState();
}

class _DirectCharityQrScannerPageState
    extends State<DirectCharityQrScannerPage> {
  final _repo = SeparateCharityDonationRepository();
  final _manual = TextEditingController();
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _confirm(String code) async {
    if (_busy || _done || code.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _repo.confirmPickup(requestId: widget.requestId, token: code);
      if (!mounted) return;
      setState(() {
        _done = true;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تأكيد استلام التبرع من المتبرع')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _manualEntry() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إدخال كود الاستلام'),
        content: TextField(
            controller: _manual,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'LD-XXXXXXXXXXXXXXX')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _confirm(_manual.text);
              },
              child: const Text('تحقق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تأكيد استلام التبرع'), actions: [
          IconButton(
              onPressed: _manualEntry,
              icon: const Icon(Icons.keyboard_alt_outlined),
              tooltip: 'إدخال يدوي')
        ]),
        body: Stack(children: [
          MobileScanner(onDetect: (capture) {
            final value = capture.barcodes.isEmpty
                ? null
                : capture.barcodes.first.rawValue;
            if (value != null) _confirm(value);
          }),
          Center(
              child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20)))),
          Positioned(
              bottom: 35,
              left: 24,
              right: 24,
              child: FilledButton.icon(
                  onPressed: _busy ? null : _manualEntry,
                  icon: const Icon(Icons.keyboard),
                  label:
                      Text(_busy ? 'جارٍ التحقق...' : 'أو أدخل الكود يدويًا'))),
        ]),
      );
}
