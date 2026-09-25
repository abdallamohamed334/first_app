// lib/features/provider/presentation/pages/provider_public_profile_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/features/provider/presentation/utils/service_category_icons.dart';

class ProviderPublicProfilePage extends StatefulWidget {
  const ProviderPublicProfilePage({super.key});

  @override
  State<ProviderPublicProfilePage> createState() =>
      _ProviderPublicProfilePageState();
}

class _ProviderPublicProfilePageState extends State<ProviderPublicProfilePage> {
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _orange = Color(0xFFE28B00);

  final _repo = ServiceProviderRepository();

  Map<String, dynamic>? _provider;
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _repo.getCurrentProvider();
    if (!mounted) return;

    await result.fold(
      (err) async {
        setState(() => _loading = false);
      },
      (provider) async {
        setState(() => _provider = provider);

        final statsResult =
            await _repo.getProviderStats(provider['id'].toString());

        if (!mounted) return;
        statsResult.fold(
          (err) => setState(() => _loading = false),
          (stats) => setState(() {
            _stats = stats;
            _loading = false;
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _cardBg,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_forward_rounded, color: _ink),
          ),
          title: const Text(
            'شكل بروفايلي',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, _bgDark],
            ),
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _blue),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNotice(),
                      const SizedBox(height: 14),
                      _buildPreviewCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ده شكل بروفايلك اللي المستخدمين هيشوفوه. كل البيانات اللي بتظهر هنا بتتعدل من "تعديل بروفايلي".',
              style: TextStyle(
                color: _inkSoft.withValues(alpha: 0.9),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final name = _provider?['display_name']?.toString() ?? 'مزود خدمة';
    final bio = _provider?['bio']?.toString() ?? '';
    final city = _provider?['city']?.toString() ?? '';
    final address = _provider?['address']?.toString() ?? '';
    final exp = _provider?['experience_years']?.toString() ?? '0';
    final avatar = _provider?['profile_image_url']?.toString();
    final cover = _provider?['cover_image_url']?.toString();
    final isVerified =
        _provider?['verification_status']?.toString() == 'approved';
    final isVisible = _provider?['is_available'] as bool? ?? false;

    final cat = _provider?['categories'];
    final catName = cat is Map ? cat['name_ar']?.toString() ?? '' : '';
    final catIcon = cat is Map ? cat['icon']?.toString() ?? '' : '';
    final iconData = ServiceCategoryIcons.getIcon(catIcon);

    final skills = (_provider?['skills'] as List?) ?? [];
    final areas = (_provider?['service_areas'] as List?) ?? [];
    final portfolio = (_provider?['portfolio_images'] as List?) ?? [];

    final rating = (_stats?['rating_avg'] as num?)?.toDouble() ?? 0;
    final reviews = (_stats?['total_reviews'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ═══════════════════════════════════════════════════
          // ✅ Cover + Profile Header
          // ═══════════════════════════════════════════════════
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Cover Image
              Container(
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BA3E8), _blue],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: (cover != null && cover.isNotEmpty)
                      ? Image.network(
                          cover,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        )
                      : const SizedBox(),
                ),
              ),

              // Profile avatar (overlapping cover)
              Positioned(
                bottom: -40,
                right: 20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _inkSoft.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (avatar != null && avatar.isNotEmpty)
                        ? Image.network(
                            avatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(),
                          )
                        : _fallback(),
                  ),
                ),
              ),

              // Verified badge
              if (isVerified)
                Positioned(
                  bottom: 4,
                  right: 85,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),

          // Spacing for avatar overlap
          const SizedBox(height: 50),

          // ═══════════════════════════════════════════════════
          // Name + Category
          // ═══════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                if (catName.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconData, color: _blue, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          catName,
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Visibility warning
          if (!isVisible)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: _orange.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_rounded,
                      color: _orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'أنت مخفي حالياً — المستخدمين مش هيشوفوا بروفايلك',
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ═══════════════════════════════════════════════════
          // Body
          // ═══════════════════════════════════════════════════
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating
                if (reviews > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: _orange, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($reviews تقييم)',
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Experience
                if (exp != '0') ...[
                  _infoRow(
                    Icons.workspace_premium_rounded,
                    'الخبرة',
                    '$exp سنة',
                  ),
                  const SizedBox(height: 8),
                ],

                // Location
                if (city.isNotEmpty || address.isNotEmpty) ...[
                  _infoRow(
                    Icons.location_on_rounded,
                    'الموقع',
                    [city, address].where((e) => e.isNotEmpty).join('، '),
                  ),
                  const SizedBox(height: 8),
                ],

                // Bio
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نبذة',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bio,
                          style: TextStyle(
                            color: _inkSoft.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ═══════════════════════════════════════════════
                // ✅ صور أعمالي (Portfolio)
                // ═══════════════════════════════════════════════
                if (portfolio.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.photo_library_rounded,
                          color: _blue,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'صور أعمالي',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${portfolio.length} صور',
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: portfolio.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final url = portfolio[index].toString();
                      return GestureDetector(
                        onTap: () => _openFullscreen(portfolio, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: _blue.withValues(alpha: 0.08),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _blue,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: _blue.withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: _blue,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Skills
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'المهارات',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.toString(),
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Service areas
                if (areas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'مناطق الخدمة',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: areas.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          a.toString(),
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // Fullscreen Gallery
  // ══════════════════════════════════════════════════════════
  void _openFullscreen(List<dynamic> images, int startIndex) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _FullscreenGallery(
            images: images.map((e) => e.toString()).toList(),
            initialIndex: startIndex,
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: _blue.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: _blue, size: 42),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _blue, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: _inkSoft.withValues(alpha: 0.7),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Fullscreen Gallery
// ═══════════════════════════════════════════════════════════
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // الصور
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Counter
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Thumbnails
            if (widget.images.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final selected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white24,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Opacity(
                              opacity: selected ? 1 : 0.5,
                              child: Image.network(
                                widget.images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white12,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
