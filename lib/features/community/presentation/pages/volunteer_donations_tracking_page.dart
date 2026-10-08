// lib/features/community/presentation/pages/volunteer_donations_tracking_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/volunteer_donation_detail_page.dart';

// ثوابت الألوان - نفس ألوان صفحة التفاصيل بالظبط عشان يبقوا متطابقين بصريًا
const _green = Color(0xFF0B7650);
const _darkGreen = Color(0xFF123F31);
const _mint = Color(0xFFDDF3E8);
const _orange = Color(0xFFE28B00);
const _blue = Color(0xFF2F6DA5);
const _purple = Color(0xFF6651B5);
const _muted = Color(0xFF71837C);

const _stages = [
  'volunteer_assigned',
  'picked_up_from_donor',
  'in_transit',
  'completed',
];

// نفس تعريف الألوان والتسميات الموجود في صفحة التفاصيل بالظبط
(String, Color) _statusData(String status) {
  switch (status) {
    case 'volunteer_assigned':
      return ('معك أنت', _purple);
    case 'picked_up_from_donor':
      return ('استلمت من المتبرع', _blue);
    case 'in_transit':
      return ('في الطريق للجمعية', _orange);
    case 'completed':
      return ('تم التوصيل', _green);
    case 'cancelled':
      return ('تم الإلغاء', const Color(0xFFD64545));
    default:
      return ('قيد المتابعة', Colors.grey);
  }
}

class VolunteerDonationsTrackingPage extends StatefulWidget {
  const VolunteerDonationsTrackingPage({super.key});

  @override
  State<VolunteerDonationsTrackingPage> createState() =>
      _VolunteerDonationsTrackingPageState();
}

class _VolunteerDonationsTrackingPageState
    extends State<VolunteerDonationsTrackingPage> {
  final _repository = SeparateCharityDonationRepository();

  List<Map<String, dynamic>> _donations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = SupabaseService().client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'يجب تسجيل الدخول أولاً';
        });
        return;
      }

      final response = await SupabaseService()
          .client
          .from('charity_donation_requests')
          .select('''
            *,
            charities:charity_id (id, name, logo),
            users:donor_id (id, name, phone)
          ''')
          .eq('volunteer_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> donations = [];
      for (var item in response) {
        final charity = item['charities'] as Map<String, dynamic>?;
        final donor = item['users'] as Map<String, dynamic>?;

        // ✅ نفس فلترة الروابط الصالحة الموجودة في صفحة التفاصيل بالظبط
        final rawImages = item['images'];
        final images = rawImages is List
            ? rawImages
                .map((v) => v.toString())
                .where((url) => url.startsWith('http'))
                .toList()
            : <String>[];

        donations.add({
          'id': item['id'],
          'title': item['title'] ?? 'تبرع',
          'description': item['description'] ?? '',
          'quantity': item['quantity'] ?? 1,
          'images': images,
          'pickup_address': item['pickup_address'] ?? '',
          'pickup_city': item['pickup_city'] ?? '',
          'charity_name': charity?['name'] ?? 'جمعية خيرية',
          'charity_logo': charity?['logo'],
          'donor_name': donor?['name'] ?? 'متبرع',
          'donor_phone': donor?['phone'],
          'status': item['status']?.toString() ?? 'volunteer_assigned',
          'created_at': item['created_at'],
          'updated_at': item['updated_at'],
          'volunteer_accepted_at': item['volunteer_accepted_at'],
          'donor_pickup_confirmed_at': item['donor_pickup_confirmed_at'],
          'charity_received_at': item['charity_received_at'],
          'completed_at': item['completed_at'],
          'charity_pickup_code': item['charity_pickup_code'],
          // نمرر الـ map الأصلي كامل زي ما هو عشان صفحة التفاصيل تحتاجه
          'charities': item['charities'],
          'users': item['users'],
        });
      }

      setState(() {
        _donations = donations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل التبرعات: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text('تبرعاتي كمتطوع'),
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          foregroundColor: colors.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _loadDonations,
              icon: Icon(Icons.refresh_rounded, color: colors.primary),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'جاري تحميل تبرعاتك...',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurface, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDonations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_donations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volunteer_activism_rounded,
                size: 64,
                color: colors.outline.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'مفيش تبرعات متطوع فيها حالياً',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'روح قسم "تبرعات محتاجاك توصلها" واختار تبرع توصلّه',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _loadDonations,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _donations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final donation = _donations[index];
          return _VolunteerDonationCard(
            key: ValueKey(donation['id']),
            donation: donation,
            repository: _repository,
            onChanged: _loadDonations,
          );
        },
      ),
    );
  }
}

// ============================================================
// كارت التبرع - فيه نفس المعلومات والأزرار الموجودة في التفاصيل
// ============================================================

class _VolunteerDonationCard extends StatefulWidget {
  final Map<String, dynamic> donation;
  final SeparateCharityDonationRepository repository;
  final VoidCallback onChanged;

  const _VolunteerDonationCard({
    super.key,
    required this.donation,
    required this.repository,
    required this.onChanged,
  });

  @override
  State<_VolunteerDonationCard> createState() => _VolunteerDonationCardState();
}

class _VolunteerDonationCardState extends State<_VolunteerDonationCard> {
  bool _isLoading = false;
  String? _charityCode;
  final TextEditingController _codeController = TextEditingController();

  String get _donationId => widget.donation['id']?.toString() ?? '';
  String get _status =>
      widget.donation['status']?.toString() ?? 'volunteer_assigned';

  @override
  void initState() {
    super.initState();
    // ✅ لو الكود موجود أصلاً في الـ donation، استخدمه
    final existing = widget.donation['charity_pickup_code']?.toString();
    if (existing != null && existing.isNotEmpty) {
      _charityCode = existing;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFD64545) : _darkGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('كود') || text.contains('رمز')) {
      return 'الكود غير صحيح، تأكد من الرقم الذي أعطاك إياه المتبرع';
    }
    if (text.contains('انتهت صلاحية')) {
      return 'انتهت صلاحية الكود، اطلب كود جديد من المتبرع';
    }
    if (text.contains('لا يمكن تنفيذ') || text.contains('الحالة الحالية')) {
      return 'لا يمكن تنفيذ هذه الخطوة الآن';
    }
    return 'حدث خطأ، حاول مرة أخرى';
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerDonationDetailPage(donation: widget.donation),
      ),
    ).then((_) => widget.onChanged());
  }

  // ═══════════════════════════════════════════════════════════
  // 1️⃣ إدخال كود المتبرع
  // ═══════════════════════════════════════════════════════════

  void _showDonorCodeDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: _green),
              SizedBox(width: 10),
              Text(
                'تأكيد استلام التبرع',
                style:
                    TextStyle(color: _darkGreen, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اطلب من المتبرع إعطاءك كود الاستلام المكون من 6 أرقام، ثم أدخله هنا.',
                style: TextStyle(fontSize: 13, color: _muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: _darkGreen,
                ),
                decoration: InputDecoration(
                  labelText: 'أدخل كود الاستلام (6 أرقام)',
                  labelStyle: const TextStyle(color: _muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _green, width: 2),
                  ),
                  prefixIcon:
                      const Icon(Icons.lock_outline_rounded, color: _green),
                  counterText: '',
                ),
                onSubmitted: (_) =>
                    _confirmDonorPickup(dialogContext, setDialogState),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: _muted)),
            ),
            FilledButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _confirmDonorPickup(dialogContext, setDialogState),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('تأكيد الاستلام'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDonorPickup(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    final code = _codeController.text.trim();

    if (code.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _toast('الكود يجب أن يتكون من 6 أرقام', error: true);
      return;
    }

    setDialogState(() => _isLoading = true);
    setState(() => _isLoading = true);

    try {
      await widget.repository.confirmVolunteerPickupWithCode(_donationId, code);
      if (!mounted) return;
      Navigator.pop(dialogContext);
      _toast('✅ تم تأكيد استلام التبرع من المتبرع بنجاح');
      widget.onChanged();
    } catch (e) {
      setDialogState(() => _isLoading = false);
      setState(() => _isLoading = false);
      _toast(_friendlyError(e), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 2️⃣ "أنا في الطريق للجمعية" (بدل "إنشاء كود الجمعية")
  // ═══════════════════════════════════════════════════════════

  Future<void> _markInTransit() async {
    if (_isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: _orange),
            SizedBox(width: 10),
            Text(
              'أنا في الطريق للجمعية',
              style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد أنك بدأت التحرك نحو الجمعية؟\n'
          'سيتم إخطار الجمعية، وسيتولّد كود التسليم تلقائياً.',
          style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(color: _muted)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.local_shipping_rounded, size: 18),
            label: const Text('نعم، أنا في الطريق'),
            style: FilledButton.styleFrom(backgroundColor: _orange),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // 1) تحديث الحالة إلى in_transit
      await widget.repository.volunteerMarkInTransit(_donationId);
      if (!mounted) return;

      // 2) توليد كود الجمعية تلقائياً
      try {
        final code =
            await widget.repository.generateCharityPickupCode(_donationId);
        if (!mounted) return;
        setState(() {
          _charityCode = code;
          _isLoading = false;
        });
        _toast('✅ أنت الآن في الطريق — تم توليد كود التسليم');
      } catch (_) {
        // لو فشل توليد الكود، نكمل عادي — ممكن يكون اتولد قبل كده
        if (!mounted) return;
        setState(() => _isLoading = false);
        _toast('✅ أنت الآن في الطريق للجمعية');
      }

      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast(_friendlyError(e), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 3️⃣ عرض كود التسليم للجمعية
  // ═══════════════════════════════════════════════════════════

  Future<void> _showCharityCodeFlow() async {
    if (_charityCode != null && _charityCode!.isNotEmpty) {
      _showCharityCodeDialog(_charityCode!);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final code = await widget.repository.getCharityPickupCode(_donationId);
      if (!mounted) return;
      setState(() {
        _charityCode = code;
        _isLoading = false;
      });
      if (code.isNotEmpty) {
        _showCharityCodeDialog(code);
      } else {
        _toast('لم يتم توليد كود التسليم بعد', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _toast(_friendlyError(e), error: true);
      }
    }
  }

  void _showCharityCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.business_center_rounded, color: _orange),
            SizedBox(width: 10),
            Text(
              'كود التسليم للجمعية',
              style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أعط هذا الكود للجمعية عند وصولك لتأكيد استلام التبرع.',
              style: TextStyle(fontSize: 13, color: _muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withAlpha(50)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _orange,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              _toast('تم نسخ الكود 📋');
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: _green),
            label: const Text('نسخ', style: TextStyle(color: _green)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final donation = widget.donation;
    final title = donation['title']?.toString() ?? 'تبرع';
    final charityName = donation['charity_name']?.toString() ?? 'جمعية خيرية';
    final donorName = donation['donor_name']?.toString() ?? 'متبرع';
    final quantity = donation['quantity']?.toString() ?? '1';
    final images = (donation['images'] as List?)?.cast<String>() ?? [];
    final imageUrl = images.isNotEmpty ? images.first : null;
    final statusData = _statusData(_status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusData.$2.withAlpha(60), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withAlpha(6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openDetails,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: _green.withAlpha(20),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _green,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  color: _green.withAlpha(20),
                                  child: const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: _green,
                                    size: 26,
                                  ),
                                ),
                              )
                            : Container(
                                color: _green.withAlpha(20),
                                child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: _green,
                                  size: 26,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$charityName • $donorName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusData.$2.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: statusData.$2.withAlpha(50)),
                                ),
                                child: Text(
                                  statusData.$1,
                                  style: TextStyle(
                                    color: statusData.$2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$quantity وحدة',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_back_ios_rounded,
                        size: 14, color: colors.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                _SimpleTimeline(status: _status),
                const SizedBox(height: 12),
                // منطقة الأزرار - GestureDetector فاضي يمنع فتح صفحة التفاصيل
                GestureDetector(
                  onTap: () {},
                  child: _buildActionArea(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: LinearProgressIndicator(color: _green),
      );
    }

    switch (_status) {
      // 1️⃣ لسه محتاج يدخل كود المتبرع
      case 'volunteer_assigned':
        return _actionButton(
          '🔑 إدخال كود المتبرع',
          Icons.qr_code_scanner_rounded,
          _showDonorCodeDialog,
          color: _orange,
        );

      // 2️⃣ استلم من المتبرع → يدوس "أنا في الطريق للجمعية"
      case 'picked_up_from_donor':
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _blue.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'استلمت التبرع ✅ — دوس الزر لما تبدأ التحرك للجمعية',
                      style: TextStyle(
                        color: _blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _actionButton(
              '🚚 أنا في الطريق للجمعية',
              Icons.local_shipping_rounded,
              _markInTransit,
              color: _orange,
            ),
          ],
        );

      // 3️⃣ في الطريق → يعرض كود التسليم للجمعية
      case 'in_transit':
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _orange.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عند وصولك، اعرض كود التسليم للجمعية لتأكيد الاستلام',
                      style: TextStyle(
                        color: _orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _actionButton(
              '📋 عرض كود التسليم للجمعية',
              Icons.qr_code_rounded,
              _showCharityCodeFlow,
              color: _orange,
            ),
          ],
        );

      // 4️⃣ تم التوصيل
      case 'completed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F7EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: _green, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم التوصيل بنجاح - شكرًا لمجهودك 🎉',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _green,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'cancelled':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFCE9E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFD64545), size: 18),
              SizedBox(width: 8),
              Text(
                'تم إلغاء هذا التبرع',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF8A2E2E),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap,
      {required Color color}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ============================================================
// الخط الزمني المبسط - نفس مراحل صفحة التفاصيل
// ============================================================

class _SimpleTimeline extends StatelessWidget {
  final String status;
  const _SimpleTimeline({required this.status});

  static const _steps = [
    ('تم الحجز', Icons.handshake_rounded),
    ('استلمت التبرع', Icons.inventory_2_rounded),
    ('في الطريق', Icons.local_shipping_rounded),
    ('وصل للجمعية', Icons.verified_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentStep = _stages.indexOf(status);
    final activeIndex = currentStep >= 0 ? currentStep : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_steps.length, (index) {
        final isActive = index <= activeIndex;
        final isLast = index == _steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive ? _green : colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.check_rounded : _steps[index].$2,
                      size: 12,
                      color: isActive ? Colors.white : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _steps[index].$1,
                    style: TextStyle(
                      fontSize: 7,
                      color:
                          isActive ? colors.onSurface : colors.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: index < activeIndex ? _green : colors.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
