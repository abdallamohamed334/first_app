// lib/features/institutions/presentation/pages/institutions_home_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

import '../../data/repositories/institutions_repository.dart';
import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution.dart';
import 'institution_add_donation_page.dart';
import 'institution_add_offer_page.dart';
import 'institution_donation_details_page.dart';
import 'institution_notifications_page.dart';
import 'institution_offer_details_page.dart';
import 'institution_offer_requests_management_page.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_profile_page.dart';
import 'institution_edit_offer_dialog.dart';
import 'institution_booking_search_page.dart';

// ✅ تعريف الألوان خارج الكلاس
const Color _primary = Color(0xFF0B7650);
const Color _primaryDark = Color(0xFF123F31);
const Color _background = Color(0xFFF6FAF8);
const Color _surface = Color(0xFFFFFFFF);
const Color _surfaceVariant = Color(0xFFE8F0EC);
const Color _muted = Color(0xFF71837C);
const Color _accent = Color(0xFFE28B00);
const Color _errorColor = Color(0xFFD64545); // ✅ غيرنا اسم اللون

class InstitutionsHomePage extends StatefulWidget {
  const InstitutionsHomePage({super.key});

  @override
  State<InstitutionsHomePage> createState() => _InstitutionsHomePageState();
}

class _InstitutionsHomePageState extends State<InstitutionsHomePage> {
  final _repository = InstitutionsRepository();
  final _offersRepository = InstitutionOffersRepository();
  Institution? _institution;
  List<Map<String, dynamic>> _offers = const [];
  List<Map<String, dynamic>> _donations = const [];
  bool _loading = true;
  String? _error; // ✅ ده للرسالة
  int _tab = 0;
  String _offerFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final institution = await _repository.getMine();
      final offers = await _repository.listMyOffers(institution.id);
      final donations =
          await _repository.listMyCharityDonations(institution.id);

      if (!mounted) return;
      setState(() {
        _institution = institution;
        _offers = offers;
        _donations = donations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات المؤسسة. حاول مرة أخرى';
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. حاول مرة أخرى')),
      );
    }
  }

  Future<void> _openProfile() async {
    final institution = _institution;
    if (institution == null) return;
    final updated = await Navigator.of(context).push<Institution>(
      MaterialPageRoute(
        builder: (_) => InstitutionProfilePage(institution: institution),
      ),
    );
    if (mounted && updated != null) setState(() => _institution = updated);
  }

  Future<void> _openAdd(WidgetBuilder builder) async {
    if (_institution == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (mounted) await _load();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InstitutionNotificationsPage()),
    );
    if (mounted) await _load();
  }

  // ✅ فتح ديالوج تعديل العرض - مع منع العروض المنتهية
  Future<void> _openEditOfferDialog(Map<String, dynamic> offer) async {
    // ✅ التحقق من أن العرض مش منتهي
    final status = offer['status']?.toString() ?? '';
    final expiresAt = offer['expires_at'] != null
        ? DateTime.tryParse(offer['expires_at'].toString())
        : null;

    // ✅ العرض منتهي الصلاحية
    if (status == 'expired' ||
        (expiresAt != null && expiresAt.isBefore(DateTime.now()))) {
      _showMessage('⛔ هذا العرض منتهي الصلاحية ولا يمكن تعديله', error: true);
      return;
    }

    // ✅ العرض ملغي
    if (status == 'cancelled') {
      _showMessage('🚫 هذا العرض ملغي ولا يمكن تعديله', error: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => InstitutionEditOfferDialog(
        offer: offer,
        repository: _offersRepository,
      ),
    );

    if (result != null && mounted) {
      if (result['updated'] == true) {
        _showMessage('✅ تم تحديث العرض بنجاح');
        await _load();
      } else if (result['toggled'] == true) {
        final isActive = result['is_active'] == true;
        _showMessage(
            isActive ? '✅ تم تشغيل العرض' : '⏸️ تم إيقاف العرض مؤقتاً');
        await _load();
      } else if (result['cancelled'] == true) {
        _showMessage('🚫 تم إلغاء العرض');
        await _load();
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _errorColor : _primary, // ✅ _errorColor
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredOffers {
    if (_offerFilter == 'all') return _offers;
    if (_offerFilter == 'active') {
      return _offers.where((offer) {
        final status = offer['status']?.toString() ?? '';
        return status == 'active' || status == 'available';
      }).toList();
    }
    if (_offerFilter == 'inactive') {
      return _offers.where((offer) {
        final status = offer['status']?.toString() ?? '';
        return status != 'active' && status != 'available';
      }).toList();
    }
    return _offers;
  }

  // ✅ حساب حالة الصلاحية
  Map<String, dynamic> _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return {
        'label': 'صلاحية غير محددة',
        'color': _muted,
        'icon': Icons.help_outline_rounded,
        'days': null,
      };
    }

    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) {
      return {
        'label': 'منتهي الصلاحية',
        'color': _errorColor, // ✅ _errorColor
        'icon': Icons.warning_amber_rounded,
        'days': daysLeft,
      };
    } else if (daysLeft <= 3) {
      return {
        'label': 'ينتهي خلال $daysLeft أيام',
        'color': _accent,
        'icon': Icons.timer_outlined,
        'days': daysLeft,
      };
    } else if (daysLeft <= 7) {
      return {
        'label': 'طازج - $daysLeft يوم متبقي',
        'color': _primary,
        'icon': Icons.fiber_new_rounded,
        'days': daysLeft,
      };
    } else {
      return {
        'label': 'صلاحية متبقية $daysLeft يوم',
        'color': const Color(0xFF3679C8),
        'icon': Icons.inventory_2_rounded,
        'days': daysLeft,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: _mobileAppBar(),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
                ? _buildErrorView()
                : _buildBody(),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  PreferredSizeWidget _mobileAppBar() {
    final institution = _institution;
    return AppBar(
      elevation: 0,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          _Avatar(url: institution?.logoUrl, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'جُود للمؤسسات',
                  style: TextStyle(
                      color: _primaryDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  institution?.name ?? 'مساحة مؤسستك',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // ✅ زر البحث عن حجز
        IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InstitutionBookingSearchPage(),
              ),
            );
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'البحث عن حجز',
        ),
        IconButton(
          onPressed: _openNotifications,
          tooltip: 'الإشعارات',
          icon:
              const Icon(Icons.notifications_none_rounded, color: _primaryDark),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') _openProfile();
            if (value == 'logout') _logout();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
            PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
          ],
          icon: const Icon(Icons.more_vert_rounded, color: _primaryDark),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_tab == 0) return _buildHomeTab();
    if (_tab == 1) return _buildOffersTab();
    if (_tab == 2) return _buildDonationsTab();
    if (_tab == 3) {
      final institutionId = _institution?.id;
      if (institutionId == null || institutionId.isEmpty) {
        return const Center(child: Text('لا توجد مؤسسة مرتبطة بالحساب'));
      }
      return InstitutionOfferRequestsManagementPage(
        institutionId: institutionId,
        repository: _repository,
      );
    }
    return _buildHomeTab();
  }

  Widget _buildHomeTab() {
    final institution = _institution!;
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SizedBox(height: 8),
          _WelcomeHeader(
            institution: institution,
            onNotifications: _openNotifications,
          ),
          const SizedBox(height: 20),
          _ProfileHero(institution: institution, onTap: _openProfile),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'ساهم بطريقتك',
            subtitle: 'حوّل فائض مؤسستك إلى أثر حقيقي',
          ),
          const SizedBox(height: 14),
          _ActionGrid(
            onOffer: () => _openAdd(
              (_) => InstitutionAddOfferPage(institutionId: institution.id),
            ),
            onDonation: () => _openAdd(
              (_) => InstitutionAddDonationPage(institutionId: institution.id),
            ),
          ),
          const SizedBox(height: 28),
          _StatsGrid(offers: _offers, donations: _donations),
          const SizedBox(height: 28),
          _RecentSection(
            rows: [
              ..._offers.map((e) => {...e, '_kind': 'offer'}),
              ..._donations.map((e) => {...e, '_kind': 'donation'}),
            ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a))),
            onOpen: (row) async {
              final map = Map<String, dynamic>.from(row);
              final isOffer = map['_kind'] == 'offer';
              map.remove('_kind');
              // ✅ الضغط على الكارد يفتح صفحة التفاصيل
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => isOffer
                    ? InstitutionOfferDetailsPage(
                        offer: InstitutionOffer.fromJson(map),
                      )
                    : InstitutionDonationDetailsPage(donation: map),
              ));
              if (mounted) await _load();
            },
            onEdit: (row) async {
              // ✅ الضغط على تعديل يفتح الديالوج (مع منع العروض المنتهية)
              final map = Map<String, dynamic>.from(row);
              final isOffer = map['_kind'] == 'offer';
              map.remove('_kind');
              if (isOffer) {
                await _openEditOfferDialog(map);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOffersTab() {
    final filteredOffers = _filteredOffers;
    final activeCount = _offers.where((o) {
      final status = o['status']?.toString() ?? '';
      return status == 'active' || status == 'available';
    }).length;
    final inactiveCount = _offers.length - activeCount;

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إدارة العروض',
                  style: TextStyle(
                    color: _primaryDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_offers.length} عرض منشور',
                  style: const TextStyle(color: _muted, fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all', _offers.length),
                const SizedBox(width: 8),
                _buildFilterChip('✅ متاح', 'active', activeCount),
                const SizedBox(width: 8),
                _buildFilterChip('⛔ غير متاح', 'inactive', inactiveCount),
              ],
            ),
          ),
          Expanded(
            child: filteredOffers.isEmpty
                ? const _EmptyView(message: 'لا توجد عروض في هذا التصنيف')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filteredOffers.length,
                    itemBuilder: (context, index) {
                      final offer = filteredOffers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfferCard(
                          offer: offer,
                          // ✅ الضغط على الكارد يفتح صفحة التفاصيل
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InstitutionOfferDetailsPage(
                                  offer: InstitutionOffer.fromJson(offer),
                                ),
                              ),
                            );
                            if (mounted) await _load();
                          },
                          // ✅ الضغط على تعديل يفتح الديالوج (مع منع العروض المنتهية)
                          onEdit: () => _openEditOfferDialog(offer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsTab() {
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Text(
            'سجل التبرعات',
            style: TextStyle(
              color: _primaryDark,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'تابع تبرعاتك من لحظة الإرسال حتى الوصول.',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          if (_donations.isEmpty)
            const _EmptyView(message: 'لا توجد تبرعات حتى الآن')
          else
            ..._donations.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DonationCard(
                    donation: row,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InstitutionDonationDetailsPage(
                            donation: row,
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _offerFilter == value;
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _offerFilter = value),
      label: Text(
        '$label ($count)',
        style: TextStyle(
          color: isSelected ? Colors.white : _primaryDark,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: _surfaceVariant,
      selectedColor: _primary,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? _primary : const Color(0xFFDCEBE3),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Widget _buildBottomNavigation() {
    return NavigationBar(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      selectedIndex: _tab,
      onDestinationSelected: (value) => setState(() => _tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.sell_outlined),
          selectedIcon: Icon(Icons.sell),
          label: 'عروضي',
        ),
        NavigationDestination(
          icon: Icon(Icons.volunteer_activism_outlined),
          selectedIcon: Icon(Icons.volunteer_activism),
          label: 'تبرعاتي',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'طلبات العملاء',
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: _muted,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'حدث خطأ غير متوقع',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _dateOf(Map<String, dynamic> row) =>
      DateTime.tryParse(
          (row['created_at'] ?? row['updated_at'])?.toString() ?? '') ??
      DateTime(1970);
}

// ============================================================
// ✅ كارد العرض - الضغط على الكارد = تفاصيل، الضغط على التلات نقاط = تعديل
// ============================================================
class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _OfferCard({
    required this.offer,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final status = offer['status']?.toString() ?? 'pending';
    final title = offer['title']?.toString() ?? 'عرض بدون اسم';
    final price = (offer['symbolic_price'] as num?)?.toDouble() ?? 0;
    final quantity = offer['quantity'] ?? 0;
    final remaining = offer['remaining_quantity'] ?? quantity;
    final images = offer['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;
    final isActive = status == 'active' || status == 'available';
    final isExpired = status == 'expired';
    final isCancelled = status == 'cancelled';

    // ✅ العرض قابل للتعديل فقط إذا كان active أو paused
    final isEditable = !isExpired && !isCancelled;

    // ✅ حساب حالة الصلاحية
    final expiryDate = offer['expires_at'] != null
        ? DateTime.tryParse(offer['expires_at'].toString())
        : null;
    final expiryStatus = _getExpiryStatus(expiryDate);
    final expiryLabel = expiryStatus['label'] as String;
    final expiryColor = expiryStatus['color'] as Color;
    final expiryIcon = expiryStatus['icon'] as IconData;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isActive ? const Color(0xFFCBE4D5) : const Color(0xFFF0F0F0),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ الصف العلوي: الصورة + العنوان + زر التعديل
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFE8F5EE),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_outlined,
                                color: _primary,
                                size: 30,
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              color: _primary,
                              size: 30,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _primaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // ✅ حالة العرض + حالة الصلاحية
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _StatusChip(status: status),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: expiryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: expiryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    expiryIcon,
                                    size: 12,
                                    color: expiryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expiryLabel,
                                    style: TextStyle(
                                      color: expiryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
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
                  // ✅ زر التعديل (ثلاث نقاط) - يظهر فقط للعروض القابلة للتعديل
                  if (isEditable)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        }
                      },
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: _muted,
                        size: 20,
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('تعديل العرض'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFEEF2F0), height: 1),
              const SizedBox(height: 10),
              // ✅ معلومات العرض كاملة
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: '${price.toStringAsFixed(0)} ج.م',
                    color: _primary,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.layers_outlined,
                    label: '$remaining / $quantity',
                    color: _muted,
                  ),
                  const SizedBox(width: 8),
                  if (expiryDate != null)
                    _InfoChip(
                      icon: Icons.event_outlined,
                      label:
                          '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                      color: _muted,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // ✅ تاريخ الانتهاء بالتفصيل
              if (expiryDate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: expiryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: expiryColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        expiryIcon,
                        size: 14,
                        color: expiryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ينتهي العرض: ${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                        style: TextStyle(
                          color: expiryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // ✅ تنبيه إذا كان العرض منتهي أو ملغي
              if (isExpired || isCancelled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _errorColor.withValues(alpha: 0.1), // ✅ _errorColor
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: _errorColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpired
                              ? Icons.timer_off_rounded
                              : Icons.block_rounded,
                          size: 14,
                          color: _errorColor, // ✅ _errorColor
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isExpired
                              ? '⛔ هذا العرض منتهي الصلاحية'
                              : '🚫 هذا العرض ملغي',
                          style: const TextStyle(
                            color: _errorColor, // ✅ _errorColor
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ دالة حساب حالة الصلاحية
  Map<String, dynamic> _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return {
        'label': 'صلاحية غير محددة',
        'color': _muted,
        'icon': Icons.help_outline_rounded,
      };
    }

    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft < 0) {
      return {
        'label': 'منتهي الصلاحية',
        'color': _errorColor, // ✅ _errorColor
        'icon': Icons.warning_amber_rounded,
      };
    } else if (daysLeft <= 3) {
      return {
        'label': 'ينتهي خلال $daysLeft أيام',
        'color': _accent,
        'icon': Icons.timer_outlined,
      };
    } else if (daysLeft <= 7) {
      return {
        'label': 'طازج - $daysLeft يوم متبقي',
        'color': _primary,
        'icon': Icons.fiber_new_rounded,
      };
    } else {
      return {
        'label': 'صلاحية متبقية $daysLeft يوم',
        'color': const Color(0xFF3679C8),
        'icon': Icons.inventory_2_rounded,
      };
    }
  }
}

// ✅ Widget مساعد لعرض المعلومات
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ✅ كارد التبرع
// ============================================================
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final VoidCallback onTap;

  const _DonationCard({required this.donation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = donation['status']?.toString() ?? 'pending';
    final title = donation['item_title']?.toString() ??
        donation['title']?.toString() ??
        'تبرع';
    final charityName = donation['charities']?['name']?.toString() ?? 'جمعية';
    final quantity = donation['quantity'] ?? 0;
    final images = donation['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F0F0), width: 1.5),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 80,
                  height: 80,
                  color: const Color(0xFFE8F5EE),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.volunteer_activism_rounded,
                            color: _primary,
                            size: 30,
                          ),
                        )
                      : const Icon(
                          Icons.volunteer_activism_rounded,
                          color: _primary,
                          size: 30,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 14,
                          color: _muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            charityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(status: status),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_rounded,
                size: 14,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ✅ Status Chip
// ============================================================
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  String get _label {
    switch (status) {
      case 'active':
      case 'available':
        return '✅ متاح';
      case 'paused':
        return '⏸️ متوقف';
      case 'sold_out':
        return '❌ نفدت الكمية';
      case 'expired':
        return '⏰ منتهي';
      case 'cancelled':
        return '🚫 ملغي';
      case 'pending':
        return '⏳ قيد المراجعة';
      case 'accepted':
        return '✅ تم القبول';
      case 'rejected':
        return '❌ مرفوض';
      case 'volunteer_assigned':
        return '👤 تم تعيين المتطوع';
      case 'institution_ready':
        return '📦 جاهز للتسليم';
      case 'volunteer_departed':
        return '🚗 في الطريق';
      case 'picked_up':
        return '📋 تم الاستلام';
      case 'completed':
        return '🎉 تم التسليم';
      default:
        return '🔄 غير محدد';
    }
  }

  Color get _color {
    final active = {
      'active',
      'available',
      'accepted',
      'completed',
      'picked_up'
    };
    final warning = {
      'pending',
      'volunteer_assigned',
      'institution_ready',
      'volunteer_departed'
    };
    final inactive = {'paused', 'sold_out', 'expired', 'cancelled', 'rejected'};

    if (active.contains(status)) return const Color(0xFF0B7650);
    if (warning.contains(status)) return const Color(0xFFE28B00);
    if (inactive.contains(status)) return _errorColor; // ✅ _errorColor
    return const Color(0xFF71837C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================
// ✅ باقي الـ Widgets (نفس الكود السابق)
// ============================================================

class _WelcomeHeader extends StatelessWidget {
  final Institution institution;
  final VoidCallback onNotifications;

  const _WelcomeHeader({
    required this.institution,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لوحة التحكم',
                style: TextStyle(
                  color: _primaryDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مرحباً بك مجدداً في إدارة ${institution.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onNotifications,
          tooltip: 'الإشعارات',
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final Institution institution;
  final VoidCallback onTap;

  const _ProfileHero({
    required this.institution,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF064E3B),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _Avatar(url: institution.logoUrl, size: 60, light: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _typeName(institution.type),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (institution.isVerified)
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFB8E8C8),
                  size: 22,
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeName(String value) {
    const types = {
      'bakery': 'مخبز وحلويات',
      'grocery': 'بقالة',
      'game_store': 'محل ألعاب',
      'supermarket': 'سوبر ماركت',
      'cafe': 'كافيه',
      'hotel': 'فندق',
    };
    return types[value] ?? 'مؤسسة أخرى';
  }
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onOffer;
  final VoidCallback onDonation;

  const _ActionGrid({
    required this.onOffer,
    required this.onDonation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = [
          Flexible(
            fit: FlexFit.loose,
            child: _ActionCard(
              icon: Icons.sell_rounded,
              title: 'بيع بسعر رمزي',
              subtitle: 'اعرض المنتجات الصالحة بسعر مناسب',
              color: const Color(0xFF7D562D),
              onTap: onOffer,
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: _ActionCard(
              icon: Icons.volunteer_activism_rounded,
              title: 'تبرع لجمعية',
              subtitle: 'أرسل الفائض إلى جمعية موثوقة',
              color: const Color(0xFF0F3D2E),
              onTap: onDonation,
            ),
          ),
        ];

        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              children[0],
              const SizedBox(width: 12),
              children[1],
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            children[0],
            const SizedBox(height: 12),
            children[1],
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final List<Map<String, dynamic>> donations;

  const _StatsGrid({
    required this.offers,
    required this.donations,
  });

  @override
  Widget build(BuildContext context) {
    final completed = donations
        .where((row) => row['status']?.toString() == 'completed')
        .length;
    final active =
        offers.where((row) => row['status']?.toString() == 'active').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          ('العروض النشطة', '$active', Icons.local_offer_outlined),
          ('عدد التبرعات', '${donations.length}', Icons.loyalty_outlined),
          ('التبرعات المكتملة', '$completed', Icons.check_circle_outline),
          (
            'إجمالي النشاط',
            '${offers.length + donations.length}',
            Icons.insights_outlined
          ),
        ];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 100,
          ),
          itemBuilder: (_, index) {
            return _StatCard(
              title: items[index].$1,
              value: items[index].$2,
              icon: items[index].$3,
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ),
              Icon(icon, color: _primary, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: _primaryDark,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>)? onEdit;

  const _RecentSection({
    required this.rows,
    required this.onOpen,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'آخر النشاطات',
          subtitle: 'نظرة سريعة على أحدث ما تم داخل المؤسسة',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyView(message: 'لا توجد نشاطات بعد')
        else
          ...rows.take(4).map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActivityCard(
                    row: row,
                    isOffer: row['_kind'] == 'offer',
                    icon: row['_kind'] == 'offer'
                        ? Icons.sell_outlined
                        : Icons.volunteer_activism_outlined,
                    onTap: () => onOpen(row),
                    onEdit: onEdit != null ? () => onEdit!(row) : null,
                  ),
                ),
              ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _primaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final IconData icon;
  final bool isOffer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _ActivityCard({
    required this.row,
    required this.icon,
    required this.isOffer,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final title =
        (row['title'] ?? row['item_title'] ?? 'بدون عنوان').toString();
    final image = _imageUrl(row);
    final subtitle = isOffer
        ? '${row['symbolic_price'] ?? '—'} ج.م · ${row['remaining_quantity'] ?? row['quantity'] ?? '—'} قطعة'
        : '${row['charity_name'] ?? 'جمعية'} · ${row['quantity'] ?? '—'} قطعة';

    // ✅ العرض قابل للتعديل فقط إذا كان active أو paused
    final isExpired = status == 'expired';
    final isCancelled = status == 'cancelled';
    final isEditable = isOffer && !isExpired && !isCancelled;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == 'active' || status == 'available'
                  ? const Color(0xFF6EAE8D)
                  : const Color(0xFFE4E9E5),
            ),
          ),
          child: Row(
            children: [
              _ListImage(url: image, icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(status: status),
                  ],
                ),
              ),
              // ✅ زر التعديل (ثلاث نقاط) - يظهر فقط للعروض القابلة للتعديل
              if (isEditable && onEdit != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit!();
                    }
                  },
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _muted,
                    size: 18,
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('تعديل العرض', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              if (!isEditable || onEdit == null) const SizedBox(width: 36),
            ],
          ),
        ),
      ),
    );
  }

  static String? _imageUrl(Map<String, dynamic> row) {
    final images = row['images'];
    if (images is List && images.isNotEmpty) {
      final value = images.first?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

class _ListImage extends StatelessWidget {
  final String? url;
  final IconData icon;

  const _ListImage({required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null
            ? Container(
                color: const Color(0xFFDDEBE4),
                child: Icon(icon, color: _primary, size: 24),
              )
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFDDEBE4),
                  child: Icon(icon, color: _primary, size: 24),
                ),
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final bool light;

  const _Avatar({
    required this.url,
    required this.size,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light ? Colors.white24 : const Color(0xFFDDEBE4),
        image: url != null && url!.trim().isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url!.trim()),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url == null || url!.trim().isEmpty
          ? Icon(
              Icons.storefront_rounded,
              color: light ? Colors.white : _primary,
              size: size * 0.45,
            )
          : null,
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;

  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9E5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_rounded,
            size: 40,
            color: Color(0xFF8AA096),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}
