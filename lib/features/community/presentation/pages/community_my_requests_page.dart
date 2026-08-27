import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:loqma/features/community/data/repositories/community_requests_repository.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';

class CommunityMyRequestsPage extends StatefulWidget {
  const CommunityMyRequestsPage({super.key});

  @override
  State<CommunityMyRequestsPage> createState() =>
      _CommunityMyRequestsPageState();
}

class _CommunityMyRequestsPageState extends State<CommunityMyRequestsPage> {
  final _repository = CommunityRequestsRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyId;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  @override
  void initState() {
    super.initState();
    _future = _repository.getMyRequests();
  }

  Future<void> _refresh() async {
    final next = _repository.getMyRequests();
    setState(() => _future = next);
    await next;
  }

  Future<void> _cancel(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: const Text(
              'سيصبح العرض متاحًا مرة أخرى إذا وافق صاحب العرض على الإلغاء.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('رجوع')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB54747)),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('إلغاء الطلب')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = id);
    try {
      await _repository.updateRequestStatus(requestId: id, status: 'cancelled');
      if (!mounted) return;
      _showMessage('تم إلغاء الطلب', success: true);
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppErrorMapper.message(
            error,
            fallback: 'تعذر إلغاء الطلب. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showPickupQr(String requestId) async {
    try {
      final token = await _repository.getOrCreatePickupToken(requestId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'كود الاستلام',
                      textAlign: TextAlign.right,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اعرض QR أو الكود النصي لصاحب العرض عند الاستلام.',
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: QrImageView(
                        data: token,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F7F4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD7E9DF)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              token,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                                color: _darkGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'نسخ الكود',
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: token));
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext)
                                    .showSnackBar(
                                  const SnackBar(content: Text('تم نسخ الكود')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, color: _green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'لا تشارك الكود قبل وصولك واستلام العرض.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF71837C), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إغلاق'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          AppErrorMapper.message(
            error,
            fallback: 'تعذر إنشاء كود الاستلام. تأكد أن الطلب جاهز للاستلام.',
          ),
        );
      }
    }
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
            title: const Text('طلباتي من الملابس والأثاث'),
            centerTitle: true,
            backgroundColor: _background,
            foregroundColor: _darkGreen,
            elevation: 0,
            actions: [
              IconButton(
                  onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))
            ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _green));
            }
            if (snapshot.hasError) {
              return _MessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'تعذر تحميل طلباتك',
                  onRetry: _refresh);
            }
            final requests = (snapshot.data ?? const <Map<String, dynamic>>[])
                .where(_matchesFilter)
                .toList();
            return RefreshIndicator(
                color: _green,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _buildIntro(),
                    const SizedBox(height: 15),
                    _buildFilters(),
                    const SizedBox(height: 15),
                    if (requests.isEmpty)
                      _MessageState(
                          icon: Icons.inbox_rounded,
                          title: 'لا توجد طلبات بهذا الفلتر',
                          onRetry: _refresh)
                    else
                      ...requests.map(_buildCard),
                  ],
                ));
          },
        ),
      ),
    );
  }

  bool _matchesFilter(Map<String, dynamic> row) =>
      _filter == 'all' || row['status']?.toString() == _filter;

  Widget _buildIntro() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B7650), Color(0xFF2BAA76)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24)),
      child: const Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('تابع طلباتك بسهولة',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('اعرف هل تم قبول طلبك ومتى يمكنك استلام العرض.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 12, height: 1.4))
        ])),
        SizedBox(width: 12),
        Icon(Icons.track_changes_rounded, color: Colors.white, size: 40)
      ]));

  Widget _buildFilters() {
    final filters = {
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز للاستلام',
      'completed': 'مكتمل',
      'cancelled': 'ملغي'
    };
    return SizedBox(
        height: 40,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final key = filters.keys.elementAt(index);
              final active = _filter == key;
              return FilterChip(
                  selected: active,
                  onSelected: (_) => setState(() => _filter = key),
                  label: Text(filters[key]!),
                  selectedColor: const Color(0xFFDDF3E8),
                  backgroundColor: Colors.white,
                  checkmarkColor: _green,
                  labelStyle: TextStyle(
                      color: active ? _green : const Color(0xFF5F786C),
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                  side: BorderSide(
                      color: active ? _green : const Color(0xFFE0EBE5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)));
            }));
  }

  Widget _buildCard(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final status = request['status']?.toString() ?? 'pending';
    final offer = request['community_offers'] is Map
        ? Map<String, dynamic>.from(request['community_offers'] as Map)
        : <String, dynamic>{};
    final title = offer['title']?.toString() ?? 'عرض بدون عنوان';
    final image = offer['image']?.toString();
    final price = (request['price_snapshot'] as num?)?.toDouble() ?? 0;
    final listingType = offer['listing_type']?.toString() ?? 'donation';
    final canCancel = status == 'pending' || status == 'accepted';
    final busy = _busyId == id;

    return Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE1ECE6)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 13,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                    width: 72,
                    height: 72,
                    child: image == null || image.isEmpty
                        ? Container(
                            color: const Color(0xFFE8F5EE),
                            child: const Icon(Icons.volunteer_activism_rounded,
                                color: _green, size: 30))
                        : Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8F5EE),
                                child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: _green))))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  _statusPill(status)
                ]))
          ]),
          const SizedBox(height: 13),
          Row(children: [
            Icon(
                listingType == 'symbolic_sale'
                    ? Icons.sell_outlined
                    : Icons.favorite_border_rounded,
                color: _green,
                size: 17),
            const SizedBox(width: 6),
            Text(
                listingType == 'symbolic_sale'
                    ? '${price.toStringAsFixed(0)} جنيه'
                    : 'تبرع مجاني',
                style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            const Text('طلب عام',
                style: TextStyle(color: Color(0xFF71837C), fontSize: 11))
          ]),
          if (status == 'ready_for_pickup') ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => _showPickupQr(id),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('عرض كود الاستلام'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
          if (status == 'pending' || status == 'accepted') ...[
            const SizedBox(height: 13),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: busy ? null : () => _cancel(id),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB54747),
                        side: const BorderSide(color: Color(0xFFE7B9B9)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13))),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('إلغاء الطلب')))
          ],
        ]));
  }

  Widget _statusPill(String status) {
    final data = {
          'pending': (
            'في الانتظار',
            const Color(0xFFFFF0D6),
            const Color(0xFF946313)
          ),
          'accepted': ('مقبول', const Color(0xFFDDF3E8), _green),
          'completed': (
            'مكتمل',
            const Color(0xFFDCEBFA),
            const Color(0xFF2F6DA5)
          ),
          'cancelled': (
            'ملغي',
            const Color(0xFFFBE4E4),
            const Color(0xFFB54747)
          ),
          'rejected': (
            'مرفوض',
            const Color(0xFFFBE4E4),
            const Color(0xFFB54747)
          )
        }[status] ??
        ('حالة غير معروفة', const Color(0xFFF0F1F0), const Color(0xFF71837C));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: data.$2, borderRadius: BorderRadius.circular(20)),
        child: Text(data.$1,
            style: TextStyle(
                color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final Future<void> Function() onRetry;
  const _MessageState(
      {required this.icon, required this.title, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF0B7650), size: 48),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF123F31),
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onRetry, child: const Text('تحديث'))
      ]));
}
