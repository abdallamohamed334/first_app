import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_charities_page.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

/// Home section for verified, active charities.
/// It intentionally renders at most three cards; the full list remains available
/// through the "عرض الكل" action.
class HomeCharitiesSection extends StatefulWidget {
  const HomeCharitiesSection({super.key});

  @override
  State<HomeCharitiesSection> createState() => _HomeCharitiesSectionState();
}

class _HomeCharitiesSectionState extends State<HomeCharitiesSection> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  final CommunityOfferRepository _repository = CommunityOfferRepository();
  late Future<List<CommunityCharityOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CommunityCharityOption>> _load() async {
    final rows = await _repository.getActiveCharities();
    return rows
        .map(CommunityCharityOption.fromMap)
        .where((charity) => charity.id.isNotEmpty)
        .toList();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openDetails(CommunityCharityOption charity) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCharityDetailsPage(charity: charity),
      ),
    );
  }

  Future<void> _openAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityCharitiesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<List<CommunityCharityOption>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading();
          }

          if (snapshot.hasError) {
            return _error();
          }

          final charities = snapshot.data ?? const <CommunityCharityOption>[];
          if (charities.isEmpty) return _empty();

          return _content(charities.take(3).toList(), charities.length);
        },
      ),
    );
  }

  Widget _content(List<CommunityCharityOption> charities, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جمعيات متاحة',
                      style: TextStyle(
                        color: _darkGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'اختار الجهة التي تحب أن يصل إليها أثرك',
                      style: TextStyle(color: Color(0xFF71837C), fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openAll,
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(color: _green, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 214,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth =
                  (constraints.maxWidth * .78).clamp(260.0, 340.0);
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: charities.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, index) => SizedBox(
                  width: cardWidth,
                  child: _card(charities[index]),
                ),
              );
            },
          ),
        ),
        if (total > 3)
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 20, left: 20),
            child: Text(
              'توجد ${total - 3} جمعيات أخرى متاحة',
              style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(CommunityCharityOption charity) {
    final image = charity.logo?.trim() ?? '';
    final address = charity.address?.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: () => _openDetails(charity),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDCEBE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A123F31),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 116,
                width: double.infinity,
                child: image.isEmpty
                    ? _fallbackImage()
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackImage(),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              charity.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _darkGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              address?.isNotEmpty == true
                                  ? address!
                                  : 'جمعية موثقة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF71837C),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: _green),
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

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFFDDF3E8),
      alignment: Alignment.center,
      child:
          const Icon(Icons.volunteer_activism_rounded, color: _green, size: 42),
    );
  }

  Widget _loading() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: _green)),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDCEBE3)),
        ),
        child: const Text(
          'لا توجد جمعيات متاحة حاليًا.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD7C8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFC85A35)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'تعذر تحميل الجمعيات. حاول مرة أخرى.',
                style: TextStyle(
                    color: Color(0xFF874029), fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              color: _green,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'إعادة المحاولة',
            ),
          ],
        ),
      ),
    );
  }
}
