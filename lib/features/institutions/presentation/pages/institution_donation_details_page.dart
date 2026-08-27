import 'package:flutter/material.dart';
import '../../data/repositories/institutions_repository.dart';

class InstitutionDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;
  const InstitutionDonationDetailsPage({super.key, required this.donation});

  @override
  State<InstitutionDonationDetailsPage> createState() =>
      _InstitutionDonationDetailsPageState();
}

class _InstitutionDonationDetailsPageState
    extends State<InstitutionDonationDetailsPage> {
  final _repository = InstitutionsRepository();
  late Map<String, dynamic> _donation;
  String? _pickupCode;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _donation = Map<String, dynamic>.from(widget.donation);
  }

  String get _status => (_donation['status'] ?? 'pending').toString();

  Future<void> _run(Future<Map<String, dynamic>> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (!mounted) return;
      setState(() {
        _donation = {..._donation, ...result};
        _busy = false;
        final code = result['pickup_code']?.toString();
        if (code != null && code.length == 6) _pickupCode = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنفيذ العملية بنجاح')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تنفيذ العملية. تحقق من الحالة وحاول مرة أخرى')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_donation['item_title'] ?? 'تبرع بدون اسم').toString();
    final institution = _donation['institutions'];
    final charity = _donation['charities'];
    final images = _imageUrls(_donation['images']);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F9F7),
        appBar: AppBar(title: const Text('تفاصيل التبرع'), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1.5,
                  child: Image.network(
                    images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _DonationImageFallback(),
                  ),
                ),
              )
            else
              const _DonationImageFallback(),
            const SizedBox(height: 12),
            _Header(title: title, status: _status),
            const SizedBox(height: 12),
            _InfoCard(rows: {
              'الجمعية': _nestedName(charity) ??
                  (_donation['charity_name']?.toString() ?? 'غير محدد'),
              'المؤسسة': _nestedName(institution) ??
                  (_donation['institution_name']?.toString() ?? 'مؤسسة'),
              'الكمية': (_donation['quantity'] ?? '—').toString(),
              'الحالة': _statusLabel(_status),
            }),
            if ((_donation['description']?.toString() ?? '')
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 12),
              _TextCard(
                  title: 'الوصف', text: _donation['description'].toString()),
            ],
            const SizedBox(height: 12),
            _Timeline(status: _status),
            const SizedBox(height: 16),
            if (_pickupCode != null) _CodeCard(code: _pickupCode!),
            if (_pickupCode != null) const SizedBox(height: 12),
            ..._actions(),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions() {
    final id = _donation['id']?.toString();
    if (id == null || id.isEmpty) return const [];
    if (_status == 'volunteer_assigned') {
      return [
        _ActionButton(
            label: 'أنا جاهز للتسليم',
            icon: Icons.check_circle_outline,
            onPressed:
                _busy ? null : () => _run(() => _repository.markReady(id)))
      ];
    }
    if (_status == 'institution_ready' || _status == 'volunteer_departed') {
      return [
        _ActionButton(
            label: 'إظهار كود الاستلام',
            icon: Icons.password_rounded,
            onPressed: _busy
                ? null
                : () => _run(() => _repository.generatePickupCode(id)))
      ];
    }
    if (_status == 'picked_up') {
      return [
        const _Notice(
            text: 'تم استلام التبرع من المتطوع. في انتظار تأكيد وصوله للجمعية.')
      ];
    }
    if (_status == 'completed') {
      return [const _Notice(text: 'تم تسليم التبرع للجمعية بنجاح.')];
    }
    return const [];
  }

  static List<String> _imageUrls(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _nestedName(dynamic value) =>
      value is Map ? value['name']?.toString() : null;

  static String _statusLabel(String status) {
    const labels = {
      'pending': 'في انتظار المراجعة',
      'accepted': 'تم القبول',
      'rejected': 'مرفوض',
      'volunteer_assigned': 'تم تعيين المتطوع',
      'institution_ready': 'المؤسسة جاهزة للتسليم',
      'volunteer_departed': 'المتطوع في الطريق',
      'picked_up': 'تم استلام المتطوع للتبرع',
      'completed': 'تم التسليم للجمعية',
      'cancelled': 'ملغي',
      'expired': 'منتهي',
    };
    return labels[status] ?? 'حالة غير معروفة';
  }
}

class _DonationImageFallback extends StatelessWidget {
  const _DonationImageFallback();

  @override
  Widget build(BuildContext context) => Container(
        height: 170,
        decoration: BoxDecoration(
          color: const Color(0xFFDDEBE4),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 56, color: Color(0xFF0B7650)),
        ),
      );
}

class _Header extends StatelessWidget {
  final String title;
  final String status;
  const _Header({required this.title, required this.status});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      color: const Color(0xFF064E3B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.volunteer_activism, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(_statusLabel(status),
                      style: const TextStyle(color: Colors.white70))
                ]))
          ])));

  static String _statusLabel(String status) =>
      const {
        'pending': 'في انتظار المراجعة',
        'accepted': 'تم القبول',
        'rejected': 'مرفوض',
        'volunteer_assigned': 'تم تعيين المتطوع',
        'institution_ready': 'المؤسسة جاهزة للتسليم',
        'volunteer_departed': 'المتطوع في الطريق',
        'picked_up': 'تم الاستلام',
        'completed': 'تم التسليم للجمعية',
        'cancelled': 'ملغي',
        'expired': 'منتهي'
      }[status] ??
      'حالة غير معروفة';
}

class _InfoCard extends StatelessWidget {
  final Map<String, String> rows;
  const _InfoCard({required this.rows});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              children: rows.entries
                  .map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(
                            child: Text(entry.key,
                                style: const TextStyle(color: Colors.black54))),
                        Text(entry.value,
                            style: const TextStyle(fontWeight: FontWeight.w700))
                      ])))
                  .toList())));
}

class _TextCard extends StatelessWidget {
  final String title;
  final String text;
  const _TextCard({required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(text)
          ])));
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});
  @override
  Widget build(BuildContext context) {
    const steps = [
      'pending',
      'accepted',
      'volunteer_assigned',
      'institution_ready',
      'volunteer_departed',
      'picked_up',
      'completed'
    ];
    final current = steps.indexOf(status);
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('خط سير التبرع',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...steps.asMap().entries.map((entry) {
                final done = current >= entry.key && current >= 0;
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(
                          done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color:
                              done ? const Color(0xFF0B7650) : Colors.black26),
                      const SizedBox(width: 8),
                      Text(_statusLabel(entry.value),
                          style: TextStyle(
                              fontWeight:
                                  done ? FontWeight.w700 : FontWeight.w400))
                    ]));
              })
            ])));
  }

  static String _statusLabel(String status) =>
      const {
        'pending': 'في انتظار المراجعة',
        'accepted': 'تم القبول',
        'volunteer_assigned': 'تم تعيين المتطوع',
        'institution_ready': 'المؤسسة جاهزة للتسليم',
        'volunteer_departed': 'المتطوع في الطريق',
        'picked_up': 'تم استلام التبرع',
        'completed': 'تم التسليم للجمعية'
      }[status] ??
      status;
}

class _CodeCard extends StatelessWidget {
  final String code;
  const _CodeCard({required this.code});
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xFFFFF6E9),
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            const Text('كود الاستلام',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(code,
                style: const TextStyle(
                    fontSize: 32,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF9A5D18))),
            const SizedBox(height: 5),
            const Text('استخدمه مرة واحدة فقط وخلال 24 ساعة',
                style: TextStyle(color: Colors.black54))
          ])));
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ActionButton(
      {required this.label, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: FilledButton.icon(
          onPressed: onPressed, icon: Icon(icon), label: Text(label)));
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center)));
}
