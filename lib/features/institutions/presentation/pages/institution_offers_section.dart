import 'package:flutter/material.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import '../pages/institution_offer_details_page.dart';
import '../pages/institution_offers_page.dart';

class InstitutionOffersSection extends StatefulWidget {
  final InstitutionOffersRepository? repository;

  const InstitutionOffersSection({super.key, this.repository});

  @override
  State<InstitutionOffersSection> createState() =>
      _InstitutionOffersSectionState();
}

class _InstitutionOffersSectionState extends State<InstitutionOffersSection> {
  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOffer>> _future;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _future = _repository.listAvailableOffers();
  }

  Future<void> _refresh() async {
    final future = _repository.listAvailableOffers();
    if (mounted) setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InstitutionOffer>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.cloud_off_rounded,
            text: 'تعذر تحميل عروض المؤسسات حاليًا',
            action: TextButton(
              onPressed: _refresh,
              child: const Text('إعادة المحاولة'),
            ),
          );
        }

        final offers = (snapshot.data ?? const <InstitutionOffer>[])
            .where((offer) => offer.isActive && offer.remainingQuantity > 0)
            .toList(growable: false);
        if (offers.isEmpty) return const SizedBox.shrink();

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
                          'عروض المؤسسات',
                          style: TextStyle(
                            color: Color(0xFF123F31),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'اختيارات مميزة بسعر رمزي من مؤسسات موثوقة',
                          style: TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InstitutionOffersPage(
                          initialOffers: offers,
                          repository: _repository,
                        ),
                      ),
                    ),
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 370,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: offers.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  return _OfferCard(
                    offer: offer,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InstitutionOfferDetailsPage(
                          offer: offer,
                          repository: _repository,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCEBE3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0B7650)),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  late final PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final images = offer.images;
    final hasDiscount = offer.originalPrice != null &&
        offer.originalPrice! > offer.symbolicPrice;

    return SizedBox(
      width: 304,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: const Color(0xFF0B7650).withAlpha(34),
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE0EEE7)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF123F31).withAlpha(12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardImageSlider(
                  images: images,
                  controller: _pageController,
                  currentIndex: _currentImage,
                  onChanged: (index) => setState(() => _currentImage = index),
                  remainingQuantity: offer.remainingQuantity,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                offer.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF123F31),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (hasDiscount)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1D6),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${offer.discountPercent!.round()}% أقل',
                                  style: const TextStyle(
                                    color: Color(0xFF9A6314),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: Color(0xFF0B7650),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${offer.institutionName} • ${offer.institutionType ?? 'مؤسسة'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF71837C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'السعر الرمزي',
                                  style: TextStyle(
                                    color: Color(0xFF8A9B94),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${offer.symbolicPrice.toStringAsFixed(0)} جنيه',
                                  style: const TextStyle(
                                    color: Color(0xFF0B7650),
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F8F3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 15,
                                    color: Color(0xFF0B7650),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'متبقي ${offer.remainingQuantity}',
                                    style: const TextStyle(
                                      color: Color(0xFF0B7650),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B7650),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'شاهد التفاصيل',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                            ],
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
      ),
    );
  }
}

class _CardImageSlider extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int remainingQuantity;

  const _CardImageSlider({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
    required this.remainingQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const _ImageFallback()
          else
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              onPageChanged: onChanged,
              itemBuilder: (_, index) => Image.network(
                images[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _ImageFallback(),
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
                      Colors.black.withAlpha(80),
                      Colors.transparent,
                      Colors.black.withAlpha(90),
                    ],
                    stops: const [0, .45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(232),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Color(0xFF0B7650)),
                  SizedBox(width: 4),
                  Text(
                    'سعر رمزي',
                    style: TextStyle(
                      color: Color(0xFF064E3B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 11,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: currentIndex == index ? 21 : 7,
                    height: 6,
                    decoration: BoxDecoration(
                      color: currentIndex == index
                          ? Colors.white
                          : Colors.white.withAlpha(140),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 11,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'متبقي $remainingQuantity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDDF3E8),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 48,
          color: Color(0xFF0B7650),
        ),
      ),
    );
  }
}
