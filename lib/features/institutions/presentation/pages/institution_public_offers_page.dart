import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_offer_details_page.dart';

class InstitutionPublicOffersPage extends StatefulWidget {
  final String institutionId;
  final String institutionName;
  final String? institutionType;
  final String? institutionLogoUrl;
  final String? institutionPhone;
  final String? institutionCity;
  final String? institutionGovernorate;
  final InstitutionOffersRepository? repository;

  const InstitutionPublicOffersPage({
    super.key,
    required this.institutionId,
    required this.institutionName,
    this.institutionType,
    this.institutionLogoUrl,
    this.institutionPhone,
    this.institutionCity,
    this.institutionGovernorate,
    this.repository,
  });

  @override
  State<InstitutionPublicOffersPage> createState() =>
      _InstitutionPublicOffersPageState();
}

class _InstitutionPublicOffersPageState
    extends State<InstitutionPublicOffersPage> {
  static const Color _red = Color(0xFFFF2E3B);
  static const Color _redDark = Color(0xFFD8202C);
  static const Color _ink = Color(0xFF1B1D22);
  static const Color _muted = Color(0xFF68707C);
  static const Color _background = Color(0xFFF7F8FA);

  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOffer>> _offersFuture;
  String? _institutionPhone;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _institutionPhone = widget.institutionPhone;
    _offersFuture = _loadOffers();
    _loadInstitutionPhone();
  }

  Future<List<InstitutionOffer>> _loadOffers() =>
      _repository.listAvailableOffersByInstitution(widget.institutionId);

  Future<void> _refresh() async {
    final future = _loadOffers();
    if (mounted) {
      setState(() {
        _offersFuture = future;
      });
    }
    await future;
    await _loadInstitutionPhone();
  }

  Future<void> _loadInstitutionPhone() async {
    final phone = await _repository.getInstitutionPhone(widget.institutionId);
    if (!mounted || phone == null || phone.isEmpty) return;
    setState(() => _institutionPhone = phone);
  }

  String get _location {
    final parts = [widget.institutionCity, widget.institutionGovernorate]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return parts.join('، ');
  }

  Future<void> _callInstitution(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s()\-]'), '');
    if (normalized.isEmpty) return;

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: normalized),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'المؤسسة',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<List<InstitutionOffer>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _red),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refresh);
          }

          final offers = snapshot.data ?? const <InstitutionOffer>[];
          return RefreshIndicator(
            color: _red,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildInstitutionHeader(offers)),
                SliverToBoxAdapter(
                  child: _buildOffersSectionHeader(offers.length),
                ),
                if (offers.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 14);
                          }
                          final offer = offers[index ~/ 2];
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
                        childCount: offers.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstitutionHeader(List<InstitutionOffer> offers) {
    final firstOffer = offers.isEmpty ? null : offers.first;
    final passedPhone = _institutionPhone?.trim();
    final offerPhone = firstOffer?.institutionPhone?.trim();
    final phone = passedPhone != null && passedPhone.isNotEmpty
        ? passedPhone
        : offerPhone != null && offerPhone.isNotEmpty
            ? offerPhone
            : null;
    final passedLogo = widget.institutionLogoUrl?.trim();
    final offerLogo = firstOffer?.institutionLogoUrl?.trim();
    final logoUrl = passedLogo != null && passedLogo.isNotEmpty
        ? passedLogo
        : offerLogo != null && offerLogo.isNotEmpty
            ? offerLogo
            : null;
    final institutionName = widget.institutionName.trim().isNotEmpty
        ? widget.institutionName.trim()
        : firstOffer?.institutionName ?? 'مؤسسة';
    final type = (widget.institutionType ?? '').trim().isNotEmpty
        ? widget.institutionType!.trim()
        : firstOffer?.institutionType?.trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E8ED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1B1D22),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_red, _redDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(27),
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(17),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 52,
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 15,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'ملف المؤسسة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: -36,
                child: Container(
                  width: 86,
                  height: 86,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A1B1D22),
                        blurRadius: 13,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoUrl == null
                      ? _buildInstitutionLogoFallback()
                      : Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildInstitutionLogoFallback(),
                        ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 49, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  institutionName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (type != null && type.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type,
                      style: const TextStyle(
                        color: _redDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (_location.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: _muted, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 13, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8EBF0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 39,
                        height: 39,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFE7E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_outlined,
                          color: _red,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'هاتف المؤسسة',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              phone ?? 'رقم الهاتف غير متاح',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: phone == null ? _muted : _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (phone != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _callInstitution(phone),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: const Text('اتصال'),
                          style: TextButton.styleFrom(
                            foregroundColor: _redDark,
                            backgroundColor: const Color(0xFFFFE7E9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 9,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionLogoFallback() => Container(
        color: const Color(0xFFFFF0F1),
        child: const Icon(Icons.storefront_rounded, color: _red, size: 36),
      );

  Widget _buildOffersSectionHeader(int offerCount) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 13),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عروض المؤسسة',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'تصفح العروض المتاحة واختر ما يناسبك',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$offerCount عرض',
                style: const TextStyle(
                  color: _redDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _OfferCard extends StatelessWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  static const Color _red = Color(0xFFFF2E3B);
  static const Color _ink = Color(0xFF1B1D22);
  static const Color _muted = Color(0xFF68707C);

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.firstImage;
    final price = offer.symbolicPrice == 0
        ? 'مجانًا'
        : '${offer.symbolicPrice.toStringAsFixed(offer.symbolicPrice % 1 == 0 ? 0 : 2)} جنيه';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E6EC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A1B1D22),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 154,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    else
                      _imageFallback(),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: _red, size: 14),
                            SizedBox(width: 4),
                            Text(
                              offer.isBookable ? 'قابل للحجز' : 'عرض عادي',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.sell_outlined, color: _red, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          price,
                          style: const TextStyle(
                            color: _red,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.inventory_2_outlined,
                            color: _muted, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'متبقي ${offer.remainingQuantity}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if ((offer.pickupLocation ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: _muted, size: 15),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              offer.pickupLocation!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        color: const Color(0xFFFFF0F1),
        child: const Center(
          child: Icon(Icons.shopping_bag_outlined, color: _red, size: 44),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE6E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFFD8202C),
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد عروض متاحة حاليًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1B1D22),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'ارجع لاحقًا لمشاهدة العروض الجديدة من المؤسسة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF68707C),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFD8202C), size: 44),
            const SizedBox(height: 12),
            const Text(
              'تعذر تحميل عروض المؤسسة',
              style: TextStyle(
                color: Color(0xFF1B1D22),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تحقق من اتصال الإنترنت ثم أعد المحاولة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF68707C)),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _InstitutionPublicOffersPageState._red),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
