import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/core/services/auth_identity_resolver.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/routes/app_router.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_donation_requests_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_workspace_page.dart';
import 'package:loqma/features/home/presentation/bloc/home_bloc.dart';
import 'package:loqma/features/home/presentation/pages/home_page.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_restaurant_page.dart';

class CharityDetailsPage extends StatefulWidget {
  final Map<String, dynamic> charity;

  const CharityDetailsPage({super.key, required this.charity});

  @override
  State<CharityDetailsPage> createState() => _CharityDetailsPageState();
}

class _CharityDetailsPageState extends State<CharityDetailsPage> {
  static const _primary = Color(0xFF003527);
  static const _green = Color(0xFF006C48);
  static const _mint = Color(0xFFE9F7F0);
  static const _cream = Color(0xFFF8FAFA);
  static const _muted = Color(0xFF62786D);
  static const _line = Color(0xFFE2ECE5);

  late Future<List<Map<String, dynamic>>> _volunteersFuture;
  bool _isNavigatingBack = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _volunteersFuture = _loadVolunteers();
  }

  String _value(String key, [String fallback = '']) {
    final value = widget.charity[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  bool get _isVerified => widget.charity['is_verified'] == true;

  Future<List<Map<String, dynamic>>> _loadVolunteers() async {
    final charityId = _value('id');
    if (charityId.isEmpty) return const [];

    final rows = await SupabaseService()
        .client
        .from('charity_volunteers')
        .select('id, name, status, gender, avatar_url')
        .eq('charity_id', charityId)
        .eq('status', 'active')
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  void _retryVolunteers() {
    if (!mounted) return;
    setState(() => _volunteersFuture = _loadVolunteers());
  }

  Future<void> _goBack() async {
    if (_isNavigatingBack || !mounted) return;
    setState(() => _isNavigatingBack = true);
    try {
      final client = SupabaseService().client;
      final authId = client.auth.currentUser?.id;
      if (authId == null) {
        // If no auth, just pop.
        if (mounted) Navigator.of(context).pop();
        return;
      }

      final resolved = await AuthIdentityResolver.resolve(client, authId);

      if (!mounted) return;

      if (resolved == 'charity') {
        context.go(AppRouter.charityHome);
      } else if (resolved == 'restaurant') {
        context.go(AppRouter.restaurantHome);
      } else if (resolved == 'user') {
        context.go(AppRouter.home);
      } else {
        // Unknown: fallback to home route (no institution allowed)
        context.go(AppRouter.login);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('تعذر العودة للصفحة السابقة')));
      }
    } finally {
      if (mounted) setState(() => _isNavigatingBack = false);
    }
  }

  void _showUnavailable(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showUnavailable(
      _isFavorite
          ? 'تمت إضافة الجمعية للمفضلة'
          : 'تمت إزالة الجمعية من المفضلة',
    );
  }

  void _shareCharity() {
    _showUnavailable(
        'يمكنك مشاركة اسم الجمعية من خلال قائمة المشاركة في جهازك');
  }

  void _openDonation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCharityDonationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _value('name', 'جمعية موثقة');
    final description = _value(
      'description',
      'نعمل على إيصال الدعم إلى المستحقين بكرامة واهتمام، ونحوّل فائض اليوم إلى أثر يدوم.',
    );
    final address = _value('address', 'العنوان غير مضاف');
    final logoUrl = _value('logo_url');
    final coverImageUrl = _value('cover_image_url');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _circleButton(
              icon: Icons.arrow_forward_rounded,
              tooltip: 'رجوع',
              onPressed: _goBack,
            ),
          ),
          actions: [
            _circleButton(
              icon: Icons.share_rounded,
              tooltip: 'مشاركة',
              onPressed: _shareCharity,
            ),
            _circleButton(
              icon: _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: 'المفضلة',
              onPressed: _toggleFavorite,
            ),
          ],
          title: const Text(
            'تفاصيل الجمعية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHero(name, address, logoUrl, coverImageUrl),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 126),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsStrip(),
                  const SizedBox(height: 16),
                  _buildIdentityCard(name, description),
                  const SizedBox(height: 16),
                  _buildSectionTitle('عن الجمعية', Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  _buildSurface(
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.75,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                      'المتطوعون الحاليون', Icons.groups_rounded),
                  const SizedBox(height: 10),
                  _buildVolunteers(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('الموقع', Icons.location_on_outlined),
                  const SizedBox(height: 10),
                  _buildLocation(address),
                  const SizedBox(height: 16),
                  _buildPrivacyCard(),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomButton(),
      ),
    );
  }

  Widget _buildHero(
    String name,
    String address,
    String logoUrl,
    String coverImageUrl,
  ) {
    return SizedBox(
      height: 292,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF012D1D),
                  Color(0xFF1B4332),
                  Color(0xFF4C6452)
                ],
              ),
              image: coverImageUrl.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(coverImageUrl),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
            ),
            child: coverImageUrl.isEmpty
                ? const SizedBox.expand()
                : const ColoredBox(color: Color(0x66012D1D)),
          ),
          Positioned(
            top: 70,
            left: -46,
            child: _softCircle(180, const Color(0x22A5D0B9)),
          ),
          Positioned(
            right: -52,
            bottom: -62,
            child: _softCircle(220, const Color(0x18FFFFFF)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 104, 20, 22),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'جمعية موثوقة على لقمة',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(
                              _isVerified
                                  ? Icons.verified_rounded
                                  : Icons.favorite_rounded,
                              color: const Color(0xFFFFE6A5),
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _isVerified
                                    ? 'جمعية موثقة ونشطة'
                                    : 'جمعية نشطة لاستقبال التبرعات',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _brandMark(logoUrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip() {
    // No fabricated ratings, reviews, or impact totals are shown. The cards
    // communicate verified state and live participation only.
    final items = [
      (
        Icons.verified_rounded,
        _isVerified ? 'موثقة' : 'نشطة',
        _isVerified ? 'حالة الجمعية' : 'تستقبل التبرعات',
      ),
      (Icons.groups_rounded, 'فريق', 'متطوعو الجمعية'),
      (Icons.shield_outlined, 'آمن', 'متابعة واضحة'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: compact ? 82 : 92),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, color: _green, size: compact ? 19 : 22),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildIdentityCard(String name, String description) {
    return _buildSurface(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: _green,
              size: 31,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: _mint, shape: BoxShape.circle),
          child: Icon(icon, color: _green, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolunteers() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _volunteersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 126,
            child: Center(child: CircularProgressIndicator(color: _green)),
          );
        }

        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.cloud_off_rounded,
            message: 'تعذر تحميل المتطوعين حاليًا',
            action: _retryVolunteers,
          );
        }

        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return _messageCard(
            icon: Icons.groups_outlined,
            message: 'لا يوجد متطوعون مضافون حاليًا',
          );
        }

        return SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) => _volunteerCard(rows[index]),
          ),
        );
      },
    );
  }

  Widget _volunteerCard(Map<String, dynamic> row) {
    final rawName = row['name']?.toString().trim();
    final name = rawName == null || rawName.isEmpty ? 'متطوع الجمعية' : rawName;

    return SizedBox(
      width: 116,
      child: _buildSurface(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _VolunteerAvatar(row: row),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primary,
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocation(String address) {
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 108,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Icon(Icons.map_outlined, color: _green, size: 42),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: _green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showUnavailable(
                  'سيتم فتح الخرائط عند إضافة إحداثيات الجمعية'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('فتح في الخرائط'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _green, size: 25),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'نحافظ على خصوصيتك، وتتم متابعة التبرع من خلال خطوات واضحة وآمنة.',
              style: TextStyle(
                color: _primary,
                height: 1.55,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07123F31),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String message,
    VoidCallback? action,
  }) {
    return _buildSurface(
      child: Row(
        children: [
          Icon(icon, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          if (action != null)
            IconButton(
              onPressed: action,
              tooltip: 'إعادة المحاولة',
              icon: const Icon(Icons.refresh_rounded, color: _green),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: _openDonation,
          icon: const Icon(Icons.volunteer_activism_rounded),
          label: const Text('تبرع لهذه الجمعية'),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withAlpha(38),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }

  Widget _brandMark(String logoUrl) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(75)),
      ),
      child: logoUrl.isEmpty
          ? const Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 34,
            )
          : ClipOval(
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _VolunteerAvatar extends StatelessWidget {
  const _VolunteerAvatar({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final gender = row['gender']?.toString().toLowerCase().trim();
    final avatarUrl = row['avatar_url']?.toString().trim();
    final asset = gender == 'female'
        ? 'assets/images/default_female_volunteer.png'
        : 'assets/images/default_male_volunteer.png';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _assetOrIcon(asset, gender),
        ),
      );
    }

    return _assetOrIcon(asset, gender);
  }

  Widget _assetOrIcon(String asset, String? gender) {
    return ClipOval(
      child: Image.asset(
        asset,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF7EF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            gender == 'female' ? Icons.face_3_rounded : Icons.person_rounded,
            color: const Color(0xFF0B7650),
            size: 30,
          ),
        ),
      ),
    );
  }
}
