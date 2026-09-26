// lib/features/institutions/presentation/pages/institution_notifications_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/repositories/institutions_repository.dart';

class InstitutionNotificationsPage extends StatefulWidget {
  const InstitutionNotificationsPage({super.key});

  @override
  State<InstitutionNotificationsPage> createState() =>
      _InstitutionNotificationsPageState();
}

class _InstitutionNotificationsPageState
    extends State<InstitutionNotificationsPage> {
  final _repository = InstitutionsRepository();
  late Future<List<Map<String, dynamic>>> _future;

  // ─── ألوان جُود ───
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _primaryDark = Color(0xFF054D34);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF7B5EC7);
  static const Color _red = Color(0xFFDC4C4C);

  @override
  void initState() {
    super.initState();
    _future = _repository.listMyNotifications();
  }

  Future<void> _reload() async {
    setState(() => _future = _repository.listMyNotifications());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _markRead(String id) async {
    try {
      await _repository.markNotificationAsRead(id);
      await _reload();
    } catch (_) {
      if (mounted) _showError('تعذر تحديث الإشعار. حاول مرة أخرى');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _repository.markAllNotificationsAsRead();
      await _reload();
      if (mounted) {
        _showSuccess('✅ تم تحديد كل الإشعارات كمقروءة');
      }
    } catch (_) {
      if (mounted) _showError('تعذر تحديث الإشعارات. حاول مرة أخرى');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              stretch: true,
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              actions: [
                IconButton(
                  onPressed: _markAllRead,
                  tooltip: 'تحديد الكل كمقروء',
                  icon: const Icon(Icons.done_all_rounded),
                ),
                IconButton(
                  onPressed: _reload,
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildHeader(),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorState(),
                  );
                }

                final rows = snapshot.data ?? const <Map<String, dynamic>>[];

                if (rows.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, index) {
                      return _buildNotificationCard(rows[index], index);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إشعارات المؤسسة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'تابع كل التحديثات والطلبات',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> row, int index) {
    final read = row['is_read'] == true;
    final id = row['id']?.toString();
    final title = (row['title'] ?? 'إشعار جديد').toString();
    final body = (row['body'] ?? '').toString();
    final type = (row['type'] ?? 'general').toString();
    final createdAt = _parseDate(row['created_at']);

    final style = _notificationStyle(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: id == null ? null : () => _markRead(id),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: read ? Colors.white : style.color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: read
                    ? const Color(0xFFEEF3F0)
                    : style.color.withValues(alpha: 0.2),
                width: read ? 1 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: read
                      ? _ink.withValues(alpha: 0.03)
                      : style.color.withValues(alpha: 0.08),
                  blurRadius: read ? 12 : 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              style.color,
                              style.color.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: style.color.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          style.icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 14.5,
                                      fontWeight: read
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!read) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: style.color,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: style.color
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 58),
                      child: Text(
                        body,
                        style: const TextStyle(
                          color: _inkSoft,
                          fontSize: 13,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 58),
                    child: Row(
                      children: [
                        if (createdAt != null) ...[
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: _inkSoft.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _timeAgo(createdAt),
                            style: TextStyle(
                              color: _inkSoft.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            style.label,
                            style: TextStyle(
                              color: style.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!read)
                          Row(
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 12,
                                color: style.color,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'اضغط للقراءة',
                                style: TextStyle(
                                  color: style.color,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ({Color color, IconData icon, String label}) _notificationStyle(
    String type,
  ) {
    switch (type.toLowerCase()) {
      case 'offer_request':
        return (
          color: _primary,
          icon: Icons.shopping_bag_rounded,
          label: 'طلب جديد',
        );
      case 'request_accepted':
        return (
          color: _blue,
          icon: Icons.check_circle_rounded,
          label: 'تم القبول',
        );
      case 'request_rejected':
        return (
          color: _red,
          icon: Icons.cancel_rounded,
          label: 'مرفوض',
        );
      case 'delivery_assigned':
        return (
          color: _purple,
          icon: Icons.delivery_dining_rounded,
          label: 'في الطريق',
        );
      case 'delivery_completed':
        return (
          color: _primaryLight,
          icon: Icons.emoji_events_rounded,
          label: 'مكتمل',
        );
      case 'offer_request_status_changed':
        return (
          color: _orange,
          icon: Icons.swap_horiz_rounded,
          label: 'تحديث',
        );
      case 'system':
        return (
          color: _gold,
          icon: Icons.info_rounded,
          label: 'نظام',
        );
      default:
        return (
          color: _primary,
          icon: Icons.notifications_rounded,
          label: 'إشعار',
        );
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    if (diff.inDays < 30) {
      return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primary.withValues(alpha: 0.1),
                    _primaryLight.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 38,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'مفيش إشعارات دلوقتي',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لما يكون فيه طلب جديد أو تحديث\nهيظهر هنا على طول',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _inkSoft,
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _red,
                size: 40,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'تعذر تحميل الإشعارات',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصال الإنترنت وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
