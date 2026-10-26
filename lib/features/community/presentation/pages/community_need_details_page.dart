// lib/features/community/presentation/pages/community_need_details_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';
import 'package:loqma/features/community/presentation/pages/add_community_need_page.dart';

class CommunityNeedDetailsPage extends StatefulWidget {
  final String needId;

  const CommunityNeedDetailsPage({
    super.key,
    required this.needId,
  });

  @override
  State<CommunityNeedDetailsPage> createState() =>
      _CommunityNeedDetailsPageState();
}

class _CommunityNeedDetailsPageState extends State<CommunityNeedDetailsPage> {
  final _repository = CommunityNeedsRepository();

  // ─────────────── هوية بصرية جديدة للصفحة ───────────────
  static const _primary = Color(0xFF191919);
  static const _primaryDark = Color(0xFF050505);
  static const _primarySoft = Color(0xFFF0ECF7);
  static const _bg = Color(0xFFF8F7FA);
  static const _ink = Color(0xFF171717);
  static const _muted = Color(0xFF77727D);
  static const _border = Color(0xFFE9E6ED);
  static const _amber = Color(0xFFDC9A34);
  static const _blue = Color(0xFF6C4DB3);
  static const _green = Color(0xFF2E9B68);
  static const _whatsapp = Color(0xFF25D366);
  static const _danger = Color(0xFFC1503F);

  // ─────────────── الحالة ───────────────
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _need;
  bool _contacting = false;
  bool _isOwner = false;

  // ═══════════════════════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadNeed();
  }

  Future<void> _loadNeed() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final need = await _repository.getNeedById(widget.needId);
      if (!mounted) return;

      if (need == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'الاحتياج غير موجود';
        });
        return;
      }

      final currentUserId = SupabaseService().client.auth.currentUser?.id;
      final requesterId = need['requester_id']?.toString();

      setState(() {
        _need = need;
        _isOwner = requesterId != null && requesterId == currentUserId;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ loadNeed error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'تعذر تحميل الاحتياج';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ EDIT NEED (جديد)
  // ═══════════════════════════════════════════════════════════

  Future<void> _editNeed() async {
    final need = _need;
    if (need == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCommunityNeedPage(
          needId: need['id']?.toString(),
          initialData: need,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadNeed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم تحديث الاحتياج بنجاح',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CONTACT
  // ═══════════════════════════════════════════════════════════

  Future<void> _contact(String type) async {
    final need = _need;
    if (need == null || _contacting) return;

    final phone =
        type == 'phone' ? _extractPhone(need) : _extractWhatsapp(need);

    if (phone == null || phone.isEmpty) {
      _message('رقم التواصل غير متاح');
      return;
    }

    setState(() => _contacting = true);

    try {
      final result = await _repository.trackContact(
        needId: widget.needId,
        contactType: type,
      );

      final cleanPhone = _cleanPhoneForContact(phone);

      if (type == 'phone') {
        final uri = Uri(scheme: 'tel', path: cleanPhone);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _message('تعذر فتح تطبيق الاتصال');
        }
      } else {
        final message = Uri.encodeComponent(
          'السلام عليكم، شفت احتياجك على Khedma وحابب أساعد',
        );

        final whatsappAppUri = Uri.parse(
          'whatsapp://send?phone=$cleanPhone&text=$message',
        );

        final webUri = Uri.parse(
          'https://wa.me/$cleanPhone?text=$message',
        );

        bool launched = false;

        try {
          if (await canLaunchUrl(whatsappAppUri)) {
            await launchUrl(
              whatsappAppUri,
              mode: LaunchMode.externalApplication,
            );
            launched = true;
          }
        } catch (_) {}

        if (!launched) {
          try {
            if (await canLaunchUrl(webUri)) {
              await launchUrl(
                webUri,
                mode: LaunchMode.externalApplication,
              );
              launched = true;
            }
          } catch (_) {}
        }

        if (!launched) {
          _message('تعذر فتح واتساب — تأكد إن التطبيق مثبت');
        }
      }

      if (!mounted) return;

      final wasNew = result['was_new'] == true;

      if (wasNew) {
        setState(() {
          _need = {
            ...need,
            'contact_count': (need['contact_count'] as num? ?? 0) + 1,
            if (type == 'phone')
              'phone_count': (need['phone_count'] as num? ?? 0) + 1,
            if (type == 'whatsapp')
              'whatsapp_count': (need['whatsapp_count'] as num? ?? 0) + 1,
          };
        });
      }
    } catch (e) {
      debugPrint('❌ contact error: $e');
      _message('تعذر تسجيل التواصل');
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  String _cleanPhoneForContact(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (clean.isEmpty) return '';

    if (clean.startsWith('01') && clean.length == 11) {
      clean = '20${clean.substring(1)}';
    } else if (clean.startsWith('1') && clean.length == 10) {
      clean = '20$clean';
    } else if (!clean.startsWith('20') &&
        clean.length >= 10 &&
        clean.length <= 12) {
      clean = '20$clean';
    }

    return clean;
  }

  String? _extractPhone(Map<String, dynamic> need) {
    final contactPhone = need['contact_phone']?.toString();
    if (contactPhone != null && contactPhone.trim().isNotEmpty) {
      return contactPhone.trim();
    }

    final users = need['users'];
    if (users is Map) {
      final phone = users['phone']?.toString();
      if (phone != null && phone.isNotEmpty) return phone;
    }

    return null;
  }

  String? _extractWhatsapp(Map<String, dynamic> need) {
    final contactWhatsapp = need['contact_whatsapp']?.toString();
    if (contactWhatsapp != null && contactWhatsapp.trim().isNotEmpty) {
      return contactWhatsapp.trim();
    }

    return _extractPhone(need);
  }

  // ═══════════════════════════════════════════════════════════
  // CANCEL NEED
  // ═══════════════════════════════════════════════════════════

  Future<void> _cancelNeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _danger),
            SizedBox(width: 8),
            Text('إلغاء الاحتياج'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد؟ الاحتياج مش هيتعرض تاني.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _contacting = true);

    try {
      await _repository.cancelNeed(widget.needId);
      if (!mounted) return;
      _message('✅ تم إلغاء الاحتياج');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ cancelNeed error: $e');
      _message('تعذر إلغاء الاحتياج');
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MARK FULFILLED
  // ═══════════════════════════════════════════════════════════

  Future<void> _markFulfilled() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: _primary,
            size: 32,
          ),
        ),
        title: const Text(
          'تم توفير الحاجة؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'هل حد ساعدك ووفّرلك اللي كنت محتاجه؟ الاحتياج هيتقفل.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لسه'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تم'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _contacting = true);

    try {
      await _repository.markAsFulfilled(widget.needId);
      if (!mounted) return;
      _message('🎉 مبروك! تم توفير الحاجة');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ markFulfilled error: $e');
      _message('تعذر تحديث الحالة');
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && _errorMessage == null && _need != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 18,
          title: const Text(
            'تفاصيل الاحتياج',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _loadNeed,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : (_errorMessage != null || _need == null)
                ? _buildErrorState()
                : _buildContent(),
        bottomNavigationBar: ready ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: _blue,
      onRefresh: _loadNeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          _buildNeedHero(),
          const SizedBox(height: 14),
          _buildRequesterCard(),
          const SizedBox(height: 14),
          _buildDetailsCard(),
          const SizedBox(height: 14),
          _buildStatsCard(),
          if (!_isOwner) ...[
            const SizedBox(height: 14),
            _buildAvailabilityNotice(),
          ],
          const SizedBox(height: 14),
          _buildSafetyNote(),
        ],
      ),
    );
  }

  void _showNeedImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('صورة الاحتياج'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 52,
                ),
              ),
            ),
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildNeedHero() {
    final need = _need!;
    final title = need['title']?.toString() ?? 'احتياج';
    final categoryName = (need['category_name_ar'] ?? need['need_category'])
            ?.toString() ??
        'احتياج آخر';
    final imageUrl = need['image_url']?.toString();
    final urgencyData = _urgencyData(need['urgency']?.toString() ?? 'normal');
    final status = need['status']?.toString() ?? 'active';
    final statusData = _statusData(status);
    final expiresAt = _parseDate(need['expires_at']);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _primaryDark,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl.trim().isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showNeedImage(imageUrl),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _primaryDark.withValues(alpha: 0.30),
                      _primaryDark.withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _heroIcon(Icons.volunteer_activism_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _statusPill(statusData.$1, statusData.$2),
                  ],
                ),
                const SizedBox(height: 92),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroInfoPill(urgencyData.$1, urgencyData.$2),
                    _heroInfoPill(
                      Icons.schedule_rounded,
                      _remainingText(expiresAt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _statusPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _green.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequesterCard() {
    final need = _need!;
    final users = need['users'];
    final userMap = users is Map
        ? Map<String, dynamic>.from(users)
        : <String, dynamic>{};
    final name = userMap['name']?.toString() ?? 'مستخدم';
    final avatar = userMap['avatar_url']?.toString();
    final city = userMap['city']?.toString() ?? need['city']?.toString() ?? '';

    return _surfaceCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: avatar != null && avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: _blue,
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: _blue,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'صاحب الاحتياج',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (city.isNotEmpty)
            _softTag(Icons.location_on_rounded, city, _blue),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final need = _need!;
    final description = need['description']?.toString().trim() ?? '';
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;
    final address = need['address']?.toString().trim() ?? '';

    return _surfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Text(
              'عن الاحتياج',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: _highlightValue(
                    Icons.inventory_2_rounded,
                    'الكمية المطلوبة',
                    '$quantity',
                    'قطعة',
                    _blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _highlightValue(
                    Icons.handshake_rounded,
                    'نوع الطلب',
                    'مساعدة',
                    'مجتمعية',
                    _amber,
                  ),
                ),
              ],
            ),
          ),
          if (description.isNotEmpty || address.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: _border),
            if (description.isNotEmpty)
              _detailBlock(Icons.notes_rounded, 'الوصف', description),
            if (address.isNotEmpty)
              _detailBlock(Icons.place_rounded, 'مكان التسليم', address),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _highlightValue(
    IconData icon,
    String label,
    String value,
    String suffix,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: color,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' $suffix',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blue, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final need = _need!;
    final contactCount = (need['contact_count'] as num?)?.toInt() ?? 0;
    final phoneCount = (need['phone_count'] as num?)?.toInt() ?? 0;
    final whatsappCount = (need['whatsapp_count'] as num?)?.toInt() ?? 0;

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: _blue, size: 21),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'التفاعل على الاحتياج',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$contactCount تواصل',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  Icons.phone_rounded,
                  'اتصالات',
                  phoneCount,
                  _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniMetric(
                  Icons.chat_rounded,
                  'واتساب',
                  whatsappCount,
                  _whatsapp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityNotice() {
    final need = _need!;
    final status = need['status']?.toString() ?? 'active';
    final expiresAt = _parseDate(need['expires_at']);
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isInactive = status != 'active' || isExpired;
    if (!isInactive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _danger.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          _softIcon(Icons.timer_off_rounded, _danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExpired && status == 'active'
                  ? 'الاحتياج انتهى ولم يعد متاحًا للتواصل.'
                  : 'الاحتياج غير متاح حاليًا للتواصل.',
              style: const TextStyle(
                color: _danger,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _amber.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _softIcon(Icons.shield_outlined, _amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'خليك حريص في التعاملات: اتفقوا في مكان عام، ومتشاركش بياناتك البنكية أو كلمات المرور.',
              style: TextStyle(
                color: _ink,
                fontSize: 11.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _softIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _softTag(IconData icon, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 115),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ شريط الأزرار السفلي الثابت (Sticky Bottom Bar)
  // ═══════════════════════════════════════════════════════════

  Widget? _buildBottomBar() {
    final need = _need!;
    final status = need['status']?.toString() ?? 'active';
    final expiresAt = _parseDate(need['expires_at']);
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isInactive = status != 'active' || isExpired;

    // ✅ لو مش صاحب الاحتياج والعرض مش نشط → مفيش شريط سفلي، البانر
    // في المحتوى كفاية
    if (!_isOwner && isInactive) return null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: _primaryDark.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _isOwner
            ? _buildOwnerBottomActions(status)
            : Row(
                children: [
                  Expanded(
                    child: _buildContactButton(
                      icon: Icons.phone_rounded,
                      label: 'اتصال',
                      color: _primary,
                      onTap: () => _contact('phone'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildContactButton(
                      icon: Icons.chat_rounded,
                      label: 'واتساب',
                      color: _whatsapp,
                      onTap: () => _contact('whatsapp'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ✅ أزرار صاحب الاحتياج — الفعل الأهم بعرض كامل، والباقي جنب بعض
  Widget _buildOwnerBottomActions(String status) {
    final isActive = status == 'active';

    if (!isActive) {
      return Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ده احتياجك — الاحتياج ده مقفول دلوقتي.',
              style: TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _contacting ? null : _markFulfilled,
            icon: _contacting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: const Text(
              'تم توفير الحاجة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _contacting ? null : _editNeed,
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text(
                    'تعديل',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _contacting ? null : _cancelNeed,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text(
                    'إلغاء',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _danger,
                    side: const BorderSide(color: _danger, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _contacting ? null : onTap,
        icon: _contacting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR
  // ═══════════════════════════════════════════════════════════

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _danger,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'تعذر التحميل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadNeed,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  String _remainingText(DateTime? expiresAt) {
    if (expiresAt == null) return '--';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'منتهي';
    if (diff.inDays > 0) return 'متبقي ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'متبقي ${diff.inHours} ساعة';
    return 'متبقي ${diff.inMinutes} دقيقة';
  }

  (IconData, String, Color) _urgencyData(String urgency) {
    switch (urgency) {
      case 'urgent':
        return (Icons.warning_amber_rounded, 'عاجل جدًا', _danger);
      case 'high':
        return (Icons.priority_high_rounded, 'مهم', _amber);
      case 'low':
        return (Icons.sentiment_satisfied_rounded, 'عادي', _primary);
      case 'normal':
      default:
        return (Icons.sentiment_neutral_rounded, 'متوسط', _blue);
    }
  }

  (String, IconData) _statusData(String status) {
    switch (status) {
      case 'active':
        return ('نشط', Icons.check_circle_rounded);
      case 'matched':
        return ('تم التواصل', Icons.people_alt_rounded);
      case 'fulfilled':
        return ('اتوفر', Icons.verified_rounded);
      case 'cancelled':
        return ('ملغي', Icons.cancel_rounded);
      case 'expired':
        return ('منتهي', Icons.timer_off_rounded);
      default:
        return ('نشط', Icons.check_circle_rounded);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textDirection: TextDirection.rtl),
        backgroundColor: _primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(String categoryName) {
    return Container(
      height: 178,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 52),
          const SizedBox(height: 10),
          Text(
            categoryName,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

}
