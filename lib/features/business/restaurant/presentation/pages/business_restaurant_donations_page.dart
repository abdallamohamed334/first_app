import 'package:flutter/material.dart';

import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_donation_details_page.dart';

class BusinessRestaurantDonationsPage extends StatefulWidget {
  const BusinessRestaurantDonationsPage({super.key});

  @override
  State<BusinessRestaurantDonationsPage> createState() =>
      _BusinessRestaurantDonationsPageState();
}

class _BusinessRestaurantDonationsPageState
    extends State<BusinessRestaurantDonationsPage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);

  final _repository = BusinessRestaurantRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _repository.listMyCharityDonations();
  }

  Future<void> _refresh() async {
    final next = _repository.listMyCharityDonations();
    if (mounted) {
      setState(() {
        _future = next;
      });
    }
    await next;
  }

  String _status(Map<String, dynamic> row) =>
      (row['status'] ?? 'pending').toString().toLowerCase().trim();

  // ✅ _statusLabel المعدلة
  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ قيد المراجعة';
      case 'accepted':
        return '✅ تم القبول';
      case 'institution_ready':
        return '📦 جاهز للتسليم';
      case 'volunteer_assigned':
        return '👤 تم تعيين مندوب';
      case 'volunteer_departed':
        return '🚗 المندوب في الطريق';
      case 'volunteer_arrived':
        return '📍 المندوب وصلني';
      case 'code_generated':
        return '🔑 تم إنشاء الكود';
      case 'picked_up':
        return '📋 تم الاستلام';
      case 'completed':
        return '✅ مكتمل';
      case 'rejected':
        return '❌ مرفوض';
      case 'cancelled':
      case 'expired':
        return '⏰ منتهي';
      default:
        return '⏳ قيد المراجعة';
    }
  }

  // ✅ _statusColor المعدلة
  Color _statusColor(String status) {
    if (status == 'completed') return green;
    if (status == 'rejected' || status == 'cancelled' || status == 'expired') {
      return const Color(0xFFBA1A1A);
    }
    if (status == 'pending') return Colors.orange;
    if (status == 'accepted') return Colors.blue;
    if (status == 'institution_ready') return Colors.purple;
    if (status == 'volunteer_assigned') return Colors.teal;
    if (status == 'volunteer_departed') return Colors.deepOrange;
    if (status == 'volunteer_arrived') return Colors.lightBlue;
    if (status == 'code_generated') return Colors.amber;
    if (status == 'picked_up') return Colors.indigo;
    return const Color(0xFF2B6954);
  }

  // ✅ _actionLabel المعدلة - مع التحقق من التواريخ
  String? _actionLabel(Map<String, dynamic> row) {
    final status = _status(row);
    final restaurantReadyAt = row['restaurant_ready_at']?.toString();
    final volunteerDepartedAt = row['volunteer_departed_at']?.toString();

    print('📌 Action label for status: $status');
    print('📌 restaurant_ready_at: $restaurantReadyAt');
    print('📌 volunteer_departed_at: $volunteerDepartedAt');

    final hasRestaurantReady = restaurantReadyAt != null &&
        restaurantReadyAt.isNotEmpty &&
        restaurantReadyAt != 'null';
    final hasVolunteerDeparted = volunteerDepartedAt != null &&
        volunteerDepartedAt.isNotEmpty &&
        volunteerDepartedAt != 'null';

    if (status == 'accepted') {
      return '📦 أنا جاهز للتسليم';
    }
    if (['volunteer_departed', 'volunteer_assigned'].contains(status)) {
      return '📍 تأكيد وصول المندوب';
    }
    if (status == 'volunteer_arrived') {
      if (!hasRestaurantReady) {
        return '⚠️ أنا جاهز للتسليم';
      }
      if (!hasVolunteerDeparted) {
        return '⚠️ انتظار تحرك المندوب';
      }
      final existingCode = row['pickup_code']?.toString();
      if (existingCode != null && existingCode.isNotEmpty) {
        return '🔑 عرض كود الاستلام';
      }
      return '🔑 إنشاء كود الاستلام';
    }
    if (status == 'code_generated') {
      return '🔑 عرض كود الاستلام';
    }
    return null;
  }

  // ✅ دالة عرض الكود
  Future<void> _showCodeDialog(String code) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔑 كود استلام التبرع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أعط هذا الكود للمندوب'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '📌 الكود صالح لمدة 24 ساعة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // ✅ دالة عرض تنبيه
  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ تنبيه'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  // ✅ _runAction المعدلة
  Future<void> _runAction(Map<String, dynamic> row) async {
    final donationId = row['id']?.toString();
    final label = _actionLabel(row);
    if (donationId == null || label == null) return;

    try {
      if (label == '📦 أنا جاهز للتسليم' || label == '⚠️ أنا جاهز للتسليم') {
        await _repository.updateDonationStatus(donationId, 'institution_ready');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📦 تم تأكيد جاهزية التبرع للتسليم')));
      } else if (label == '📍 تأكيد وصول المندوب') {
        await _repository.updateDonationStatus(donationId, 'volunteer_arrived');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📍 تم تأكيد وصول المندوب')));
      } else if (label == '⚠️ انتظار تحرك المندوب') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⏳ انتظر حتى يتحرك المندوب من الجمعية'),
          backgroundColor: Colors.orange,
        ));
      } else if (label == '🔑 إنشاء كود الاستلام') {
        final result = await _repository.generateDonationPickupCode(donationId);
        if (!mounted) return;
        final code = result['code']?.toString();
        if (code == null || code.isEmpty) {
          throw const FormatException('تعذر إنشاء كود الاستلام');
        }
        await _showCodeDialog(code);
      } else if (label == '🔑 عرض كود الاستلام') {
        final existingCode = row['pickup_code']?.toString();
        if (existingCode != null && existingCode.isNotEmpty) {
          await _showCodeDialog(existingCode);
        } else {
          final result =
              await _repository.generateDonationPickupCode(donationId);
          if (!mounted) return;
          final code = result['code']?.toString();
          if (code == null || code.isEmpty) {
            throw const FormatException('تعذر إنشاء كود الاستلام');
          }
          await _showCodeDialog(code);
        }
      }
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final errorMsg = error.toString();
      if (errorMsg
          .contains('لا يمكن إصدار الكود قبل جاهزية المطعم وتحرك المندوب')) {
        _showWarningDialog('⚠️ يجب أولاً:\n'
            '1. تأكيد جاهزية المطعم\n'
            '2. انتظار تحرك المندوب من الجمعية\n'
            'ثم حاول مرة أخرى');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppErrorMapper.message(error,
                fallback: 'تعذر تنفيذ الإجراء حاليًا.'))));
      }
    }
  }

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> rows) {
    if (_filter == 'all') return rows;
    return rows.where((row) {
      final status = _status(row);
      if (_filter == 'active') {
        return !['completed', 'rejected', 'cancelled', 'expired']
            .contains(status);
      }
      if (_filter == 'completed') return status == 'completed';
      if (_filter == 'rejected') {
        return ['rejected', 'cancelled', 'expired'].contains(status);
      }
      return status == _filter;
    }).toList();
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
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward_rounded)),
          title: const Text('تبرعاتي للجمعيات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                onPressed: () {
                  _refresh();
                },
                icon: const Icon(Icons.refresh_rounded)),
            const SizedBox(width: 8)
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _DonationsLoading();
            }
            if (snapshot.hasError) {
              return _DonationsError(
                message: AppErrorMapper.message(snapshot.error!,
                    fallback: 'تعذر تحميل تبرعات المطعم.'),
                onRetry: () async {
                  await _refresh();
                },
              );
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            final visible = _visible(rows);
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
                children: [
                  const Text('تبرعاتي للجمعيات',
                      style: TextStyle(
                          color: primary,
                          fontSize: 29,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('تابع حالة كل تبرع حتى وصوله للجمعية المستفيدة.',
                      style: TextStyle(color: muted, fontSize: 15)),
                  const SizedBox(height: 18),
                  _summary(rows),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const _DonationsEmpty()
                  else
                    ...visible.map(
                      (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 13),
                          child: _DonationCard(
                              row: row,
                              statusLabel: _statusLabel(_status(row)),
                              color: _statusColor(_status(row)),
                              actionLabel: _actionLabel(row),
                              onAction: () => _runAction(row),
                              onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          BusinessRestaurantDonationDetailsPage(
                                        donation: row,
                                      ),
                                    ),
                                  ))),
                    )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summary(List<Map<String, dynamic>> rows) {
    final active = rows
        .where((row) => !['completed', 'rejected', 'cancelled', 'expired']
            .contains(_status(row)))
        .length;
    final completed = rows.where((row) => _status(row) == 'completed').length;
    return Row(children: [
      Expanded(
          child: _SummaryCard(
              value: rows.length.toString(),
              label: 'إجمالي التبرعات',
              icon: Icons.volunteer_activism_rounded,
              color: primary)),
      const SizedBox(width: 10),
      Expanded(
          child: _SummaryCard(
              value: active.toString(),
              label: 'قيد المتابعة',
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFF8A5B13))),
      const SizedBox(width: 10),
      Expanded(
          child: _SummaryCard(
              value: completed.toString(),
              label: 'مكتملة',
              icon: Icons.check_circle_outline_rounded,
              color: green))
    ]);
  }

  Widget _filters() {
    final values = <String, String>{
      'all': 'الكل',
      'active': 'قيد المتابعة',
      'completed': 'مكتملة',
      'rejected': 'منتهية'
    };
    return SizedBox(
        height: 44,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final key = values.keys.elementAt(index);
              final selected = _filter == key;
              return ChoiceChip(
                  selected: selected,
                  label: Text(values[key]!),
                  onSelected: (_) => setState(() => _filter = key),
                  selectedColor: primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                      color: selected ? Colors.white : muted,
                      fontWeight: FontWeight.w700),
                  side: BorderSide(
                      color: selected ? primary : const Color(0xFFBFC9C3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)));
            }));
  }
}

class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String statusLabel;
  final Color color;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _DonationCard({
    required this.row,
    required this.statusLabel,
    required this.color,
    required this.onTap,
    this.actionLabel,
    this.onAction,
  });

  String _value(List<String> keys, {String fallback = 'غير محدد'}) {
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'تاريخ غير محدد';
    return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _value(['item_title', 'title', 'name'], fallback: 'تبرع غذائي');
    final charity = _value(['charity_name', 'organization_name'],
        fallback: 'الجمعية المستفيدة');
    final quantity = _value(['quantity'], fallback: '—');
    final status = (row['status'] ?? 'pending').toString().toLowerCase().trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.7),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080B7650),
                  blurRadius: 13,
                  offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF003527),
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.volunteer_activism_rounded,
                    color: Color(0xFF0B7650), size: 18),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(charity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF5F6F68),
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(
                    child: _Meta(
                        icon: Icons.inventory_2_outlined,
                        label: 'الكمية',
                        value: quantity)),
                Expanded(
                    child: _Meta(
                        icon: Icons.calendar_today_outlined,
                        label: 'تاريخ الإرسال',
                        value: _date(row['created_at']))),
              ]),
              const SizedBox(height: 16),
              _Timeline(status: status, color: color),
              if (_value(['volunteer_name'], fallback: '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('المندوب: ${_value(['volunteer_name'])}',
                    style: const TextStyle(
                        color: Color(0xFF5F6F68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 10),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(actionLabel!),
                    style: FilledButton.styleFrom(
                        backgroundColor: color, foregroundColor: Colors.white),
                  ),
                ),
              ],
              const Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text('اضغط لعرض التفاصيل',
                      style: TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 11,
                          fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ _Timeline المعدلة
class _Timeline extends StatelessWidget {
  final String status;
  final Color color;
  const _Timeline({required this.status, required this.color});

  static const statuses = <String>[
    'pending',
    'accepted',
    'institution_ready',
    'volunteer_assigned',
    'volunteer_departed',
    'volunteer_arrived',
    'code_generated',
    'picked_up',
    'completed',
  ];

  static const labels = <String, String>{
    'pending': 'قيد المراجعة',
    'accepted': 'مقبول',
    'institution_ready': 'جاهز',
    'volunteer_assigned': 'مندوب',
    'volunteer_departed': 'في الطريق',
    'volunteer_arrived': 'وصل',
    'code_generated': 'كود',
    'picked_up': 'استلام',
    'completed': 'مكتمل',
  };

  static const terminalLabels = <String, String>{
    'rejected': 'مرفوض',
    'cancelled': 'ملغي',
    'expired': 'منتهي',
  };

  @override
  Widget build(BuildContext context) {
    final current = status;
    final currentIndex = statuses.indexOf(current);
    final terminalRejected = terminalLabels.containsKey(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < statuses.length; index++) ...[
                _TimelineStep(
                  label: labels[statuses[index]]!,
                  active: !terminalRejected && currentIndex >= index,
                  terminal: false,
                  color: color,
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 12,
                    height: 2,
                    color: !terminalRejected && currentIndex > index
                        ? color
                        : const Color(0xFFE6EEFF),
                  ),
              ],
            ],
          ),
        ),
        if (terminalRejected) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'نهاية المسار: ${terminalLabels[current]}',
                style: const TextStyle(
                  color: Color(0xFFBA1A1A),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool terminal;
  final Color color;
  const _TimelineStep(
      {required this.label,
      required this.active,
      required this.terminal,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final highlighted = active || terminal;
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: highlighted ? color : const Color(0xFFE6EEFF),
                shape: BoxShape.circle),
            child: Icon(terminal ? Icons.close_rounded : Icons.check_rounded,
                size: 15,
                color: highlighted ? Colors.white : const Color(0xFF8A9B94)),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: highlighted ? color : const Color(0xFF71837C),
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Meta({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: const Color(0xFF0B7650), size: 18),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF71837C), fontSize: 10)),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF121C2A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800))
        ]))
      ]);
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE0EAE5))),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 10,
                fontWeight: FontWeight.w700))
      ]));
}

class _DonationsLoading extends StatelessWidget {
  const _DonationsLoading();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: [
        for (var i = 0; i < 3; i++)
          Container(
              height: 220,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFE6EEFF),
                  borderRadius: BorderRadius.circular(16)))
      ]);
}

class _DonationsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _DonationsError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFF71837C), size: 48),
            const SizedBox(height: 13),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'))
          ])));
}

class _DonationsEmpty extends StatelessWidget {
  const _DonationsEmpty();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0EAE5))),
      child: const Column(children: [
        Icon(Icons.volunteer_activism_outlined,
            size: 52, color: Color(0xFF71837C)),
        SizedBox(height: 12),
        Text('لا توجد تبرعات مطابقة',
            style: TextStyle(
                color: Color(0xFF003527),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('ستظهر تبرعات المطعم للجمعيات هنا بعد إرسال أول طلب.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5F6F68)))
      ]));
}
