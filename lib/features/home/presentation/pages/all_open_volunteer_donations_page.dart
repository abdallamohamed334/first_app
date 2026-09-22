// lib/features/volunteer/presentation/pages/all_open_volunteer_donations_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/volunteer_donation_detail_page.dart';

class AllOpenVolunteerDonationsPage extends StatefulWidget {
  const AllOpenVolunteerDonationsPage({super.key});

  @override
  State<AllOpenVolunteerDonationsPage> createState() =>
      _AllOpenVolunteerDonationsPageState();
}

class _AllOpenVolunteerDonationsPageState
    extends State<AllOpenVolunteerDonationsPage> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _mint = Color(0xFFDDF3E8);

  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getOpenDonationsForVolunteers();
  }

  Future<void> _reload() async {
    final nextFuture = _repository.getOpenDonationsForVolunteers();
    if (!mounted) {
      await nextFuture.catchError((_) => <Map<String, dynamic>>[]);
      return;
    }
    setState(() {
      _future = nextFuture;
    });
    try {
      await nextFuture;
    } catch (_) {
      // يعرض FutureBuilder الخطأ للمستخدم برسالة آمنة.
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('row-level') ||
        text.contains('42501')) {
      return 'ليس لديك صلاحية لعرض هذه التبرعات حاليًا';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('timeout')) {
      return 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى';
    }
    return 'تعذر تحميل التبرعات المتاحة الآن';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('تبرعات محتاجاك توصلها',
              style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
          actions: [
            IconButton(
                onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _green));
            }
            if (snapshot.hasError) {
              return _emptyState(
                  _friendlyError(snapshot.error!), Icons.cloud_off_rounded,
                  retry: true);
            }
            final donations = snapshot.data ?? const <Map<String, dynamic>>[];
            if (donations.isEmpty) {
              return _emptyState(
                'مفيش تبرعات محتاجة متطوعين حاليًا',
                Icons.volunteer_activism_rounded,
                subtitle: 'حافظ على متابعة التطبيق عشان تعرف بأي تبرع جديد',
                retry: true,
              );
            }
            return RefreshIndicator(
              color: _green,
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: donations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) => _DonationCard(
                  donation: donations[index],
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VolunteerDonationDetailPage(
                            donation: donations[index]),
                      ),
                    );
                    if (changed == true) await _reload();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState(String title, IconData icon,
      {String? subtitle, bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
            if (retry) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Hero-image card matching the design language used across the app.
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final VoidCallback onTap;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);

  const _DonationCard({required this.donation, required this.onTap});

  // ✅ دالة للحصول على رابط الصورة
  String? _getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty || imagePath == 'null') {
      return null;
    }

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    String path = imagePath.trim();
    path = path.replaceFirst(RegExp(r'^/+'), '');

    if (path.contains('/legacy/')) {
      path = path.replaceAll('/legacy/', '/');
    }

    const bucket = 'community-offers';

    try {
      return 'https://gsrhoqdtcyfdmvgahqvl.supabase.co/storage/v1/object/public/$bucket/$path';
    } catch (error) {
      debugPrint('❌ Volunteer image URL error: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = donation['images'] is List
        ? List<String>.from(donation['images'] as List)
        : const <String>[];
    final heroImage = images.isNotEmpty ? images.first : null;
    final imageUrl = _getImageUrl(heroImage);

    final title = donation['title']?.toString().trim().isNotEmpty == true
        ? donation['title'].toString()
        : 'تبرع';
    final quantity = donation['quantity']?.toString() ?? '1';
    final charity = donation['charities'] is Map
        ? Map<String, dynamic>.from(donation['charities'] as Map)
        : const {};
    final charityName = charity['name']?.toString() ?? 'جمعية خيرية';
    final city = donation['pickup_city']?.toString() ?? '';
    final donor = donation['users'] is Map
        ? Map<String, dynamic>.from(donation['users'] as Map)
        : const {};
    final donorName = donor['name']?.toString() ?? 'متبرع';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2EEE8), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: _darkGreen.withAlpha(18),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ صورة التبرع (مع تحميل أفضل)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFE8F5EE),
                              child: const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _green,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),

                  // ✅ تدرج شفاف للأسفل
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1],
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(190)
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ✅ اسم الجمعية في أسفل الصورة
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(charityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  // ✅ عدد الوحدات (في الأعلى)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE28B00),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('$quantity وحدة',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ التفاصيل
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الموقع والمتبرع
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF6EF),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: _green),
                            const SizedBox(width: 4),
                            Text(city.isNotEmpty ? city : 'عنوان متاح',
                                style: const TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 13, color: Color(0xFF71837C)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(donorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF71837C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 14, color: _green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ مكان الصورة الافتراضي
  Widget _buildImagePlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFFE8F5EE),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_rounded,
            color: _green.withAlpha(100),
            size: 44,
          ),
          const SizedBox(height: 4),
          Text(
            'تبرع',
            style: TextStyle(
              color: _green.withAlpha(80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
