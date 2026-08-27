import 'package:flutter/material.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_offer_details_page.dart';

class InstitutionOffersPage extends StatefulWidget {
  final InstitutionOffersRepository? repository;
  final List<InstitutionOffer> initialOffers;

  const InstitutionOffersPage({
    super.key,
    this.repository,
    required this.initialOffers,
  });

  @override
  State<InstitutionOffersPage> createState() => _InstitutionOffersPageState();
}

class _InstitutionOffersPageState extends State<InstitutionOffersPage> {
  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOffer>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _future = _repository.listAvailableOffers();
  }

  Future<void> _reload() async {
    final future = _repository.listAvailableOffers();
    if (mounted) setState(() => _future = future);
    await future;
  }

  List<InstitutionOffer> _visibleOffers(List<InstitutionOffer> offers) {
    final query = _query.trim().toLowerCase();
    return offers.where((offer) {
      if (!offer.isActive || offer.remainingQuantity <= 0) return false;
      if (query.isEmpty) return true;
      return offer.title.toLowerCase().contains(query) ||
          offer.institutionName.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F5F0),
          foregroundColor: const Color(0xFF173C2D),
          elevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عروض المؤسسات',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 2),
              Text(
                'اختيارات مفيدة بسعر رمزي',
                style: TextStyle(
                  color: Color(0xFF72827A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث العروض',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<InstitutionOffer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading(colors);
            }
            if (snapshot.hasError) {
              return _buildError();
            }

            final allOffers = snapshot.data ?? const <InstitutionOffer>[];
            final offers = _visibleOffers(allOffers);

            return RefreshIndicator(
              color: const Color(0xFF0B7650),
              backgroundColor: Colors.white,
              onRefresh: _reload,
              child: offers.isEmpty
                  ? _buildEmpty(hasSearch: _query.trim().isNotEmpty)
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        _buildSummary(allOffers),
                        const SizedBox(height: 16),
                        _buildSearchField(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'متاح الآن',
                                style: TextStyle(
                                  color: Color(0xFF173C2D),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${offers.length} عرض',
                              style: const TextStyle(
                                color: Color(0xFF0B7650),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...offers.map(
                          (offer) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _InstitutionOfferCard(
                              offer: offer,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InstitutionOfferDetailsPage(
                                    offer: offer,
                                    repository: _repository,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme colors) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Container(
          height: 108,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => Container(
            height: 330,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFE7E1D8)),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<InstitutionOffer> allOffers) {
    final activeCount = allOffers
        .where((offer) => offer.isActive && offer.remainingQuantity > 0)
        .length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173C2D), Color(0xFF28614A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173C2D).withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Color(0xFFF4C982),
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اختيارك له أثر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount عروض متاحة من مؤسسات موثوقة',
                  style: TextStyle(
                    color: Colors.white.withAlpha(190),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFF4C982), size: 17),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث باسم العرض أو المؤسسة',
        hintStyle: const TextStyle(
          color: Color(0xFF9AA59F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0B7650)),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE7E1D8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE7E1D8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFF0B7650), width: 1.3),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 54, color: Color(0xFF7E9188)),
            const SizedBox(height: 14),
            const Text(
              'تعذر تحميل عروض المؤسسات حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF173C2D),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B7650),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({required bool hasSearch}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .62,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5F0E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF0B7650),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    hasSearch
                        ? 'لا توجد نتائج مطابقة'
                        : 'لا توجد عروض متاحة الآن',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF173C2D),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasSearch
                        ? 'جرّب البحث باسم مختلف أو امسح كلمة البحث.'
                        : 'اسحب لأسفل للتحديث والبحث عن عروض جديدة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF72827A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionOfferCard extends StatefulWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _InstitutionOfferCard({required this.offer, required this.onTap});

  @override
  State<_InstitutionOfferCard> createState() => _InstitutionOfferCardState();
}

class _InstitutionOfferCardState extends State<_InstitutionOfferCard> {
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

  List<String> get _images {
    final values = <String>[];
    for (final value in widget.offer.images) {
      final url = value.trim();
      if (url.isNotEmpty && !values.contains(url)) values.add(url);
    }
    final first = widget.offer.firstImage?.trim();
    if (values.isEmpty && first != null && first.isNotEmpty) values.add(first);
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final images = _images;
    final hasDiscount = offer.originalPrice != null &&
        offer.originalPrice! > offer.symbolicPrice;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(27),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: const Color(0xFFE8E1D7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173C2D).withAlpha(14),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 218,
                child: _OfferGallery(
                  images: images,
                  controller: _pageController,
                  currentIndex: _currentImage,
                  onChanged: (index) => setState(() => _currentImage = index),
                  remainingQuantity: offer.remainingQuantity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF173C2D),
                              fontSize: 19,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 8),
                          _Pill(
                            label: '${offer.discountPercent!.round()}% أقل',
                            color: const Color(0xFFFFF0D3),
                            textColor: const Color(0xFF98621D),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 17, color: Color(0xFF0B7650)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${offer.institutionName} • ${offer.institutionType ?? 'مؤسسة'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF71827A),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'السعر الرمزي',
                              style: TextStyle(
                                color: Color(0xFF8A9992),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${offer.symbolicPrice.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(
                                color: Color(0xFF0B7650),
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _Pill(
                          label: 'متبقي ${offer.remainingQuantity}',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFFEAF5EE),
                          textColor: const Color(0xFF0B7650),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('شاهد التفاصيل'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0B7650),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferGallery extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int remainingQuantity;

  const _OfferGallery({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onChanged,
    required this.remainingQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
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
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const _ImageLoading();
              },
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
                    Colors.black.withAlpha(55),
                    Colors.transparent,
                    Colors.black.withAlpha(105),
                  ],
                  stops: const [0, .48, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: _Pill(
            label: 'سعر رمزي',
            icon: Icons.auto_awesome_rounded,
            color: Colors.white.withAlpha(235),
            textColor: const Color(0xFF0B7650),
          ),
        ),
        Positioned(
          bottom: 13,
          right: 13,
          child: _Pill(
            label: 'متبقي $remainingQuantity',
            color: Colors.black.withAlpha(135),
            textColor: Colors.white,
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: currentIndex == index ? 22 : 7,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: currentIndex == index
                        ? Colors.white
                        : Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.label,
    this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5F0E9),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 23,
        height: 23,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Color(0xFF0B7650),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5F0E9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_rounded,
        color: Color(0xFF0B7650),
        size: 52,
      ),
    );
  }
}
