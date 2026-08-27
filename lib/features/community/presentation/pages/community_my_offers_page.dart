import 'package:flutter/material.dart';
import '../../data/repositories/community_my_offers_repository.dart';

class CommunityMyOffersPage extends StatefulWidget {
  const CommunityMyOffersPage({super.key});

  @override
  State<CommunityMyOffersPage> createState() => _CommunityMyOffersPageState();
}

class _CommunityMyOffersPageState extends State<CommunityMyOffersPage> {
  final _repository = CommunityMyOffersRepository();
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];
  String _filter = 'all';
  String? _busyRequestId;

  static const _green = Color(0xFF0B7650);
  static const _dark = Color(0xFF123F31);
  static const _muted = Color(0xFF71837C);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await _repository.getMyOffersWithRequests();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل عروضك حاليًا. حاول مرة أخرى.';
      });
    }
  }

  List<Map<String, dynamic>> get _visibleOffers {
    final query = _searchController.text.trim().toLowerCase();
    return _offers.where((offer) {
      final requests = _requests(offer);
      final matchesFilter = _filter == 'all' ||
          requests.any((request) => request['status'] == _filter);
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final title = (offer['title'] ?? '').toString().toLowerCase();
      final description = (offer['description'] ?? '').toString().toLowerCase();
      final requestText = requests
          .map((request) => request['requester']?.toString() ?? '')
          .join(' ')
          .toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          requestText.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _requests(Map<String, dynamic> offer) {
    final raw = offer['requests'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _changeStatus(String requestId, String status) async {
    setState(() => _busyRequestId = requestId);
    try {
      await _repository.updateRequestStatus(
        requestId: requestId,
        status: status,
      );
      if (!mounted) return;
      _showMessage(
        status == 'accepted' ? 'تم قبول الطلب بنجاح' : 'تم رفض الطلب',
        success: status == 'accepted',
      );
      await _load();
    } catch (error) {
      if (mounted) _showMessage('تعذر تحديث الطلب، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _confirmReject(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: const Text('هل تريد رفض طلب هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB54747)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _changeStatus(requestId, 'rejected');
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _dark,
          elevation: 0,
          titleSpacing: 18,
          title: Row(children: [
            Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _dark, borderRadius: BorderRadius.circular(12)),
                child: const Text('ل',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            const Text('لقمة',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          ]),
          actions: [
            IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث'),
            IconButton(
                onPressed: () =>
                    _showMessage('ستظهر الإشعارات عند وصول طلب جديد'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'الإشعارات'),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return _MessageState(
          icon: Icons.cloud_off_rounded,
          title: 'تعذر تحميل عروضك',
          actionLabel: 'إعادة المحاولة',
          onAction: _load);
    }
    if (_offers.isEmpty) {
      return const _MessageState(
          icon: Icons.inventory_2_outlined,
          title: 'لم تضف أي عرض بعد',
          subtitle: 'عندما تضيف ملابس أو أثاثًا ستظهر طلباته هنا.');
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _summaryCard(),
          const SizedBox(height: 18),
          _searchAndFilters(),
          const SizedBox(height: 16),
          if (_visibleOffers.isEmpty)
            const _MessageState(
                icon: Icons.filter_alt_off_rounded,
                title: 'لا توجد نتائج بهذا الفلتر',
                subtitle: 'جرّب تعديل البحث أو اختيار كل العروض.')
          else
            ..._visibleOffers.map(_offerCard),
        ],
      ),
    );
  }

  Widget _searchAndFilters() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم العرض أو المتبرع...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close_rounded)),
            filled: true,
            fillColor: Colors.white,
            prefixIconColor: _green,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFC0C8C3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFC0C8C3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _green, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        _filterBar(),
      ]);

  Widget _summaryCard() {
    final pending = _offers
        .expand((offer) => _requests(offer))
        .where((request) => request['status'] == 'pending')
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF14523D)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.volunteer_activism_rounded,
              color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('متابعة عروضي',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  pending == 0
                      ? 'لا توجد طلبات جديدة الآن'
                      : 'لديك $pending طلبات جديدة تحتاج قرارك',
                  style: const TextStyle(
                      color: Color(0xFFDDF3E8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          _stat('${_offers.length}', 'عرض'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Color(0xFFDDF3E8), fontSize: 10)),
      ]),
    );
  }

  Widget _filterBar() {
    final filters = <String, String>{
      'all': 'كل العروض',
      'pending': 'طلبات جديدة',
      'accepted': 'مقبولة',
      'completed': 'مكتملة'
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => setState(() => _filter = entry.key),
              selectedColor: const Color(0xFFDDF3E8),
              labelStyle: TextStyle(
                  color: selected ? _green : _muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final requests = _requests(offer);
    final pending =
        requests.where((request) => request['status'] == 'pending').length;
    final image = (offer['image'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE1ECE6),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A003527), blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE8F5EE),
                          child: Icon(Icons.checkroom_rounded,
                              color: _green, size: 32))
                      : Image.network(image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFE8F5EE),
                              child: Icon(Icons.checkroom_rounded,
                                  color: _green, size: 32))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((offer['title'] ?? 'عرض مجتمعي').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _dark,
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                          '${requests.length} طلب • ${pending > 0 ? '$pending جديد' : 'لا توجد طلبات جديدة'}',
                          style: TextStyle(
                              color: pending > 0 ? _green : _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              _statusPill((offer['status'] ?? 'available').toString()),
            ],
          ),
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...requests.map(_requestTile),
          ],
        ],
      ),
    );
  }

  Widget _requestTile(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final requester = request['requester'];
    final name = requester is Map ? (requester['name'] ?? 'مستخدم') : 'مستخدم';
    final requestId = request['id'].toString();
    final busy = _busyRequestId == requestId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE8F5EE),
                child: Icon(Icons.person_outline_rounded,
                    color: _green, size: 19)),
            const SizedBox(width: 9),
            Expanded(
                child: Text(name.toString(),
                    style: const TextStyle(
                        color: _dark, fontWeight: FontWeight.w900))),
            _statusPill(status),
          ]),
          if ((request['message'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('"${request['message']}"',
                style:
                    const TextStyle(color: _muted, fontSize: 12, height: 1.4)),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: busy ? null : () => _confirmReject(requestId),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB54747),
                          side: const BorderSide(color: Color(0xFFE7B9B9)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('رفض'))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton(
                      onPressed: busy
                          ? null
                          : () => _changeStatus(requestId, 'accepted'),
                      style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('قبول'))),
            ]),
          ],
        ],
      ),
    );
  }

  Color _statusBorder(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFB36B12);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'completed':
        return _green;
      case 'rejected':
        return const Color(0xFFB54747);
      default:
        return _green;
    }
  }

  Widget _statusPill(String status) {
    final data = <String, (String, Color, Color)>{
      'available': ('متاح', _green, const Color(0xFFE8F5EE)),
      'pending': ('جديد', const Color(0xFFB36B12), const Color(0xFFFFF0DA)),
      'accepted': ('مقبول', const Color(0xFF3679C8), const Color(0xFFEAF2FF)),
      'completed': ('مكتمل', _green, const Color(0xFFE8F5EE)),
      'rejected': ('مرفوض', const Color(0xFFB54747), const Color(0xFFFFEEEE)),
    };
    final item = data[status] ?? ('متاح', _green, const Color(0xFFE8F5EE));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: item.$3, borderRadius: BorderRadius.circular(9)),
        child: Text(item.$1,
            style: TextStyle(
                color: item.$2, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState(
      {required this.icon,
      required this.title,
      this.subtitle,
      this.actionLabel,
      this.onAction});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFF0B7650), size: 54),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF123F31),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Color(0xFF71837C), fontSize: 13))
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!))
              ]
            ])));
  }
}
