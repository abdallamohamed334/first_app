import 'package:flutter/material.dart';

import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';

class HomeCharitiesAndActionsSection extends StatefulWidget {
  const HomeCharitiesAndActionsSection({super.key});

  @override
  State<HomeCharitiesAndActionsSection> createState() =>
      _HomeCharitiesAndActionsSectionState();
}

class _HomeCharitiesAndActionsSectionState
    extends State<HomeCharitiesAndActionsSection> {
  static const green = Color(0xFF0B7650);
  static const darkGreen = Color(0xFF123F31);
  static const paleGreen = Color(0xFFF0F8F3);
  static const background = Color(0xFFF7FBF8);

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCharities();
  }

  Future<List<Map<String, dynamic>>> _loadCharities() async {
    final rows = await SupabaseService()
        .client
        .from('charities')
        .select(
            'id, name, address, description, status, is_verified, logo, logo_url, image_url')
        .eq('status', 'active')
        .order('name');

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refreshCharities() async {
    final nextFuture = _loadCharities();
    if (mounted) {
      setState(() {
        _future = nextFuture;
      });
    }
    await nextFuture;
  }

  void _openAllCharities() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AllAvailableCharitiesPage(),
      ),
    );
  }

  void _openDonation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddCharityDonationPage(),
      ),
    );
  }

  void _openSymbolicSale() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddCommunityOfferPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(),
          const SizedBox(height: 12),
          _buildActions(),
          const SizedBox(height: 18),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 142,
                  child: Center(
                    child: CircularProgressIndicator(color: green),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildMessage(
                  icon: Icons.cloud_off_rounded,
                  text: 'تعذر تحميل الجمعيات حاليًا',
                  onRetry: _refreshCharities,
                );
              }

              final charities = snapshot.data ?? const [];
              if (charities.isEmpty) {
                return _buildMessage(
                  icon: Icons.volunteer_activism_outlined,
                  text: 'لا توجد جمعيات متاحة حاليًا',
                );
              }

              final visible = charities.take(6).toList();
              return Column(
                children: [
                  SizedBox(
                    height: 154,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _CharityCard(
                        charity: visible[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CharityDetailsPage(
                              charity: visible[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (charities.length > visible.length) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _openAllCharities,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text('عرض كل الجمعيات (${charities.length})'),
                      style: TextButton.styleFrom(foregroundColor: green),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFDDF3E8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.volunteer_activism_rounded, color: green),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اصنع أثرًا اليوم',
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'جمعيات موثقة ومساهمات تصل لمستحقيها',
                style: TextStyle(color: Color(0xFF71837C), fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _openAllCharities,
          tooltip: 'كل الجمعيات',
          icon: const Icon(Icons.arrow_forward_ios_rounded,
              size: 17, color: green),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final cardWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: cardWidth,
              child: _ActionCard(
                icon: Icons.volunteer_activism_rounded,
                title: 'تبرع للجمعية',
                subtitle: 'أرسل تبرعك مباشرة لجمعية موثقة',
                color: green,
                onTap: _openDonation,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _ActionCard(
                icon: Icons.sell_rounded,
                title: 'بيع بسعر رمزي',
                subtitle: 'اعرض شيئًا مفيدًا بسعر مناسب',
                color: const Color(0xFFD67A18),
                onTap: _openSymbolicSale,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    VoidCallback? onRetry,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEBE3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: green),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: darkGreen))),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: green),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(35),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 25),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharityCard extends StatelessWidget {
  const _CharityCard({required this.charity, required this.onTap});

  final Map<String, dynamic> charity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = charity['name']?.toString().trim();
    final address = charity['address']?.toString().trim();
    final image = [
      charity['logo']?.toString(),
      charity['logo_url']?.toString(),
      charity['image_url']?.toString(),
    ].firstWhere(
      (value) => value != null && value.trim().isNotEmpty,
      orElse: () => null,
    );

    return SizedBox(
      width: 214,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _CharityAvatar(imageUrl: image, name: name ?? 'ج'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name?.isNotEmpty == true ? name! : 'جمعية موثقة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF123F31),
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: Color(0xFF0B7650)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address?.isNotEmpty == true
                                  ? address!
                                  : 'متاحة للتبرع',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF71837C), fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'عرض التفاصيل',
                        style: TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharityAvatar extends StatelessWidget {
  const _CharityAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF3E8),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(Icons.volunteer_activism_rounded,
          color: Color(0xFF0B7650), size: 28),
    );
  }
}

class AllAvailableCharitiesPage extends StatefulWidget {
  const AllAvailableCharitiesPage({super.key});

  @override
  State<AllAvailableCharitiesPage> createState() =>
      _AllAvailableCharitiesPageState();
}

class _AllAvailableCharitiesPageState extends State<AllAvailableCharitiesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService()
        .client
        .from('charities')
        .select(
            'id, name, address, description, status, is_verified, logo, logo_url, image_url')
        .eq('status', 'active')
        .order('name');
  }

  Future<void> _refreshAllCharities() async {
    final nextFuture = SupabaseService()
        .client
        .from('charities')
        .select(
            'id, name, address, description, status, is_verified, logo, logo_url, image_url')
        .eq('status', 'active')
        .order('name');

    if (mounted) {
      setState(() {
        _future = nextFuture;
      });
    }
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBF8),
        appBar: AppBar(
          title: const Text('الجمعيات المتاحة'),
          foregroundColor: const Color(0xFF123F31),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0B7650)));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('تعذر تحميل الجمعيات حاليًا'));
            }
            final charities =
                List<Map<String, dynamic>>.from(snapshot.data ?? const []);
            if (charities.isEmpty) {
              return const Center(child: Text('لا توجد جمعيات متاحة حاليًا'));
            }
            return RefreshIndicator(
              color: const Color(0xFF0B7650),
              onRefresh: _refreshAllCharities,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                itemCount: charities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) =>
                    _FullCharityTile(charity: charities[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FullCharityTile extends StatelessWidget {
  const _FullCharityTile({required this.charity});

  final Map<String, dynamic> charity;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _CharityAvatar(
          imageUrl: null,
          name: charity['name']?.toString() ?? 'ج',
        ),
        title: Text(
          charity['name']?.toString() ?? 'جمعية موثقة',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Color(0xFF123F31), fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          charity['address']?.toString().isNotEmpty == true
              ? charity['address'].toString()
              : 'اضغط لعرض التفاصيل',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            const Icon(Icons.chevron_left_rounded, color: Color(0xFF0B7650)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => CharityDetailsPage(charity: charity)),
        ),
      ),
    );
  }
}

class CharityDetailsPage extends StatelessWidget {
  const CharityDetailsPage({super.key, required this.charity});

  final Map<String, dynamic> charity;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF7FBF8);

  @override
  Widget build(BuildContext context) {
    final name = _value('name', fallback: 'جمعية موثقة') ?? 'جمعية موثقة';
    final description = _value('description');
    final address = _value('address');
    final verified = charity['is_verified'] == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'رجوع',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          title: const Text(
            'ملف الجمعية',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(name, verified)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionTitle('عن الجمعية', Icons.info_outline_rounded),
                  const SizedBox(height: 10),
                  _buildDescription(description),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                      'معلومات الجمعية', Icons.fact_check_outlined),
                  const SizedBox(height: 10),
                  _buildInfoCard(address, verified),
                  const SizedBox(height: 20),
                  _buildVolunteersSection(),
                  const SizedBox(height: 20),
                  _buildTrustCard(),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: _buildDonationButton(context),
        ),
      ),
    );
  }

  String? _value(String key, {String? fallback}) {
    final value = charity[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  Widget _buildHero(String name, bool verified) {
    return Container(
      constraints: const BoxConstraints(minHeight: 310),
      padding: const EdgeInsets.fromLTRB(24, 112, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF063C2A), Color(0xFF0B7650), Color(0xFF27B47E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.volunteer_activism_rounded,
                color: _green, size: 40),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (verified) ...[
                const SizedBox(width: 10),
                const Icon(Icons.verified_rounded,
                    color: Color(0xFFF3C66B), size: 27),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verified
                ? 'جمعية موثقة على منصة لقمة'
                : 'جمعية متاحة لاستقبال التبرعات',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _green, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: _darkGreen, fontSize: 17, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildDescription(String? description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0EEE6)),
      ),
      child: Text(
        description?.isNotEmpty == true
            ? description!
            : 'تساهم هذه الجمعية في توصيل الدعم إلى المستحقين. يمكنك المشاركة بتبرع مباشر وآمن.',
        style: const TextStyle(
            color: Color(0xFF536C61), height: 1.65, fontSize: 13),
      ),
    );
  }

  Widget _buildInfoCard(String? address, bool verified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0EEE6)),
      ),
      child: Column(
        children: [
          _infoRow(Icons.location_on_outlined, 'العنوان',
              address?.isNotEmpty == true ? address! : 'العنوان غير مضاف'),
          const Divider(height: 24, color: Color(0xFFEAF2ED)),
          _infoRow(Icons.verified_user_outlined, 'الحالة',
              verified ? 'موثقة ونشطة' : 'نشطة'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
              color: Color(0xFFE4F4EA), shape: BoxShape.circle),
          child: Icon(icon, color: _green, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: Color(0xFF8A9B93), fontSize: 10)),
              const SizedBox(height: 3),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _loadVolunteers(String charityId) async {
    debugPrint('CHARITY_DETAILS volunteers START charity_id=$charityId');

    final rows = await SupabaseService()
        .client
        .from('charity_volunteers')
        // لا نطلب phone أو أي بيانات اتصال؛ الصفحة تحتاج الاسم فقط.
        .select('id, name, status')
        .eq('charity_id', charityId)
        .eq('status', 'active')
        .order('name');

    final result = List<Map<String, dynamic>>.from(rows);
    debugPrint(
        'CHARITY_DETAILS volunteers RESULT count=${result.length} charity_id=$charityId');
    return result;
  }

  Widget _buildVolunteersSection() {
    final charityId = charity['id']?.toString().trim();

    debugPrint(
        'CHARITY_DETAILS selected charity_id=$charityId name=${charity['name']}');

    if (charityId == null || charityId.isEmpty) {
      return _buildVolunteersMessage('بيانات الجمعية غير مكتملة');
    }

    final future = _loadVolunteers(charityId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('فريق الجمعية', Icons.groups_rounded),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 118,
                child: Center(
                  child: CircularProgressIndicator(color: _green),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildVolunteersMessage('تعذر تحميل فريق الجمعية حاليًا');
            }

            final rows =
                List<Map<String, dynamic>>.from(snapshot.data ?? const []);
            if (rows.isEmpty) {
              return _buildVolunteersMessage('لا يوجد متطوعون مضافون حاليًا');
            }

            return SizedBox(
              height: 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => _VolunteerCard(row: rows[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVolunteersMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0EEE6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF62786D), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.security_rounded, color: _green, size: 27),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تبرعك يصل من خلال إجراءات متابعة واضحة، ونحافظ على بياناتك أثناء العملية.',
              style: TextStyle(
                  color: _darkGreen,
                  height: 1.45,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddCharityDonationPage()),
        ),
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: const Text('ابدأ تبرعك لهذه الجمعية'),
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  const _VolunteerCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'متطوع الجمعية' : name;

    return Container(
      width: 124,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0EEE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08123F31),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF3E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF0B7650),
              size: 31,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF123F31),
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
