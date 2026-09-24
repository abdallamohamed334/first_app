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
  static const _primary = Color(0xFF1F7A5C);
  static const _primaryDark = Color(0xFF11402E);
  static const _primarySoft = Color(0xFFE6F3EC);
  static const _bg = Color(0xFFF7F5F1);
  static const _ink = Color(0xFF16241E);
  static const _muted = Color(0xFF74857D);
  static const _border = Color(0xFFEAE5DA);
  static const _amber = Color(0xFFDC9A34);
  static const _blue = Color(0xFF3E7FBF);
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
          'السلام عليكم، شفت احتياجك على لقمة وحابب أساعد',
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
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          title: const Text(
            'تفاصيل الاحتياج',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : (_errorMessage != null || _need == null)
                ? _buildErrorState()
                : _buildContent(),
        bottomNavigationBar: ready ? _buildBottomBar() : null,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // المحتوى — هيرو ثابت + كارت طافي (بمساحة محجوزة صح) + تفاصيل
  // ─────────────────────────────────────────────
  Widget _buildContent() {
    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadNeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeroWithOverlapCard(),
          const SizedBox(height: 14),
          _buildDetailsCard(),
          const SizedBox(height: 14),
          _buildStatsCard(),
          const SizedBox(height: 14),
          if (!_isOwner) ...[
            _buildAvailabilityNotice(),
            const SizedBox(height: 14),
          ],
          _buildSafetyNote(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ الهيرو + كارت "صاحب الاحتياج" الطافي
  // بيستخدموا Stack عادي (مش Sliver) والمساحة بتتحجز صح عن طريق
  // SizedBox في آخر الـ Stack، فمفيش أي تداخل مع اللي تحته.
  // ═══════════════════════════════════════════════════════════

  static const double _overlapAmount = 42;

  Widget _buildHeroWithOverlapCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            _buildHero(),
            // ✅ مساحة فاضية محجوزة تحت الهيرو بمقدار نص ارتفاع
            // الكارت الطافي، عشان اللي بعده ميتصدمش بيه
            const SizedBox(height: _overlapAmount),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildRequesterCard(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO (ثابت — من غير أي Sliver أو أنيميشن سكرول)
  // ═══════════════════════════════════════════════════════════

  Widget _buildHero() {
    final need = _need!;
    final title = need['title']?.toString() ?? 'احتياج';
    final categoryName = need['category_name_ar']?.toString() ?? 'عام';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final urgencyData = _urgencyData(urgency);
    final expiresAt = _parseDate(need['expires_at']);
    final status = need['status']?.toString() ?? 'active';
    final statusData = _statusData(status);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryDark, _primary],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroBadge(
                      icon: urgencyData.$1,
                      label: urgencyData.$2,
                    ),
                    _buildHeroBadge(
                      icon: Icons.access_time_rounded,
                      label: _remainingText(expiresAt),
                    ),
                    if (status != 'active')
                      _buildHeroBadge(
                        icon: statusData.$2,
                        label: statusData.$1,
                      ),
                  ],
                ),
                // ✅ مساحة إضافية تحت البادجز عشان الكارت الطافي
                // ميغطيش على البادجز نفسها
                const SizedBox(height: _overlapAmount + 6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
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

  // ═══════════════════════════════════════════════════════════
  // كارت صاحب الاحتياج — طافي فوق حافة الهيرو
  // ═══════════════════════════════════════════════════════════

  Widget _buildRequesterCard() {
    final need = _need!;
    final users = need['users'];
    final userMap =
        users is Map ? Map<String, dynamic>.from(users) : <String, dynamic>{};

    final name = userMap['name']?.toString() ?? 'مستخدم';
    final avatar = userMap['avatar_url']?.toString();
    final city = userMap['city']?.toString() ?? need['city']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _primarySoft,
              shape: BoxShape.circle,
            ),
            child: avatar != null && avatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatar,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person_rounded,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: _primary,
                    size: 24,
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (city.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: _primary, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    city,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DETAILS CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildDetailsCard() {
    final need = _need!;
    final description = need['description']?.toString() ?? '';
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;
    final address = need['address']?.toString() ?? '';

    final rows = <(IconData, String, String)>[
      (Icons.inventory_2_outlined, 'الكمية', '$quantity'),
      if (description.isNotEmpty)
        (Icons.description_outlined, 'الوصف', description),
      if (address.isNotEmpty) (Icons.place_outlined, 'العنوان', address),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: _primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'تفاصيل الاحتياج',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: _buildDetailRow(rows[i].$1, rows[i].$2, rows[i].$3),
            ),
            if (i != rows.length - 1) const Divider(height: 1, color: _border),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _primary, size: 15),
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
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsCard() {
    final need = _need!;
    final contactCount = (need['contact_count'] as num?)?.toInt() ?? 0;
    final phoneCount = (need['phone_count'] as num?)?.toInt() ?? 0;
    final whatsappCount = (need['whatsapp_count'] as num?)?.toInt() ?? 0;

    if (contactCount == 0 && !_isOwner) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _blue.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                color: _blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'كن أول واحد يساعد في الاحتياج ده 💙',
                style: TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: _blue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'عدد اللي تواصلوا',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$contactCount شخص',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.phone_rounded,
                  label: 'اتصال',
                  count: phoneCount,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.chat_rounded,
                  label: 'واتساب',
                  count: whatsappCount,
                  color: _whatsapp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // بانر "مش متاح حاليًا" (لغير صاحب الاحتياج)
  // ═══════════════════════════════════════════════════════════

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
        color: _danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.timer_off_rounded, color: _danger, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExpired && status == 'active'
                  ? 'الاحتياج انتهى خلاص.'
                  : 'الاحتياج مش متاح حاليًا.',
              style: const TextStyle(
                color: _danger,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SAFETY NOTE
  // ═══════════════════════════════════════════════════════════

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: _amber,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'خد حذرك في التعاملات. اتفقوا في مكان عام، ومتشاركش بياناتك البنكية.',
                style: TextStyle(
                  color: _amber.withValues(alpha: 0.95),
                  fontSize: 11.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
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
}
