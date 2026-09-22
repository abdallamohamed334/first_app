// lib/features/home/presentation/widgets/open_volunteer_donations_home_section.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/volunteer_donation_detail_page.dart';
import 'package:loqma/features/home/presentation/pages/all_open_volunteer_donations_page.dart';

class OpenVolunteerDonationsHomeSection extends StatefulWidget {
  const OpenVolunteerDonationsHomeSection({super.key});

  @override
  State<OpenVolunteerDonationsHomeSection> createState() =>
      _OpenVolunteerDonationsHomeSectionState();
}

class _OpenVolunteerDonationsHomeSectionState
    extends State<OpenVolunteerDonationsHomeSection> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);

  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _claiming = {};
  final Set<String> _claimed = {};

  @override
  void initState() {
    super.initState();
    _future = _repository.getOpenDonationsForVolunteers();
  }

  Future<void> _reload() async {
    final future = _repository.getOpenDonationsForVolunteers();
    if (!mounted) return;
    setState(() => _future = future);
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('طرف آخر') || text.contains('تم قبول')) {
      return 'للأسف حد سبقك لهذا التبرع';
    }
    if (text.contains('يجب تسجيل الدخول')) {
      return 'سجّل الدخول أولًا عشان توصّل تبرع';
    }
    return 'تعذر تنفيذ الإجراء الآن، حاول مرة أخرى';
  }

  Future<void> _quickClaim(String id) async {
    setState(() => _claiming.add(id));
    try {
      await _repository.claimOpenDonation(id);
      if (!mounted) return;
      setState(() {
        _claimed.add(id);
        _claiming.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ تم حجز التبرع بنجاح، تحرك لاستلامه'),
          backgroundColor: _darkGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: const Color(0xFFD64545),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final donations = snapshot.data ?? const <Map<String, dynamic>>[];
        if (donations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.volunteer_activism_rounded,
                              color: Color(0xFFE28B00), size: 22),
                          SizedBox(width: 5),
                          Text('تبرعات محتاجة توصيل',
                              style: TextStyle(
                                  color: _darkGreen,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ]),
                        const SizedBox(height: 2),
                        Text('${donations.length} تبرع بانتظار متطوع يوصّله',
                            style: const TextStyle(
                                color: Color(0xFF71837C), fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const AllOpenVolunteerDonationsPage()),
                      );
                      await _reload();
                    },
                    child: const Text('عرض الكل',
                        style: TextStyle(
                            color: _green, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            SizedBox(
              height: 235, // ✅ تقليل الارتفاع من 236 إلى 235
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: donations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _card(donations[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(Map<String, dynamic> donation) {
    final id = donation['id']?.toString() ?? '';
    final images = donation['images'] is List
        ? List<String>.from(donation['images'] as List)
        : const <String>[];
    final heroImage = images.isNotEmpty ? images.first : null;
    final title = donation['title']?.toString().trim().isNotEmpty == true
        ? donation['title'].toString()
        : 'تبرع';
    final quantity = donation['quantity']?.toString() ?? '1';
    final charity = donation['charities'] is Map
        ? Map<String, dynamic>.from(donation['charities'] as Map)
        : const {};
    final charityName = charity['name']?.toString() ?? 'جمعية خيرية';
    final city = donation['pickup_city']?.toString() ?? '';
    final isClaiming = _claiming.contains(id);
    final isClaimed = _claimed.contains(id);

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => VolunteerDonationDetailPage(donation: donation)),
        );
        if (changed == true) await _reload();
      },
      child: Container(
        width: 216,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2EEE8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:
              MainAxisSize.min, // ✅ إضافة mainAxisSize: MainAxisSize.min
          children: [
            // ✅ صورة التبرع
            SizedBox(
              height: 118,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  heroImage == null
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [_darkGreen, _green],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft),
                          ),
                          child: Center(
                              child: Icon(Icons.volunteer_activism_rounded,
                                  color: Colors.white, size: 34)),
                        )
                      : Image.network(
                          heroImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  colors: [_darkGreen, _green],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft),
                            ),
                            child: Center(
                                child: Icon(Icons.image_not_supported_outlined,
                                    color: Colors.white, size: 28)),
                          ),
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE28B00),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 3),
                        Text('$quantity وحدة',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            // ✅ المحتوى
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    MainAxisSize.min, // ✅ إضافة mainAxisSize: MainAxisSize.min
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Color(0xFF71837C)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(city.isNotEmpty ? city : charityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF71837C), fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // ✅ زر "أقدر أوصّله"
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: isClaimed
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: const Color(0xFFE3F7EC),
                                borderRadius: BorderRadius.circular(11)),
                            child: const Text('تم الحجز ✓',
                                style: TextStyle(
                                    color: _green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900)),
                          )
                        : FilledButton(
                            onPressed:
                                isClaiming ? null : () => _quickClaim(id),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                            child: isClaiming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('أقدر أوصّله',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
