import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../data/repositories/institutions_repository.dart';

class InstitutionDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;
  const InstitutionDonationDetailsPage({super.key, required this.donation});

  @override
  State<InstitutionDonationDetailsPage> createState() =>
      _InstitutionDonationDetailsPageState();
}

class _InstitutionDonationDetailsPageState
    extends State<InstitutionDonationDetailsPage> {
  final _repository = InstitutionsRepository();
  late Map<String, dynamic> _donation;
  String? _pickupCode;
  bool _busy = false;
  int _currentImageIndex = 0;
  List<String> _images = [];

  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryDark = Color(0xFF064E3B);
  static const Color _primaryLight = Color(0xFFE8F5EE);
  static const Color _surface = Color(0xFFF6F9F7);
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textMuted = Color(0xFF7A8E87);
  static const Color _textDark = Color(0xFF123F31);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _error = Color(0xFFD64545);

  @override
  void initState() {
    super.initState();
    _donation = Map<String, dynamic>.from(widget.donation);
    _loadImages();
  }

  void _loadImages() {
    final images = _donation['images'];

    // ✅ جلب الصور من المصادر المختلفة
    List<String> allImages = [];

    // 1. من عمود images (قائمة)
    if (images is List) {
      for (var img in images) {
        if (img != null) {
          final url = img.toString().trim();
          if (url.isNotEmpty && !allImages.contains(url)) {
            allImages.add(url);
          }
        }
      }
    }

    // 2. من عمود image (صورة واحدة)
    final singleImage = _donation['image']?.toString().trim() ?? '';
    if (singleImage.isNotEmpty && !allImages.contains(singleImage)) {
      allImages.add(singleImage);
    }

    // 3. من عمود public_url
    final publicUrl = _donation['public_url']?.toString().trim() ?? '';
    if (publicUrl.isNotEmpty && !allImages.contains(publicUrl)) {
      allImages.add(publicUrl);
    }

    // 4. من nested data (لو الصور جوة objects)
    final media = _donation['media'] as List? ?? [];
    for (var item in media) {
      if (item is Map) {
        final url = item['url']?.toString().trim() ??
            item['public_url']?.toString().trim() ??
            '';
        if (url.isNotEmpty && !allImages.contains(url)) {
          allImages.add(url);
        }
      }
    }

    setState(() {
      _images = allImages;
    });

    print('✅ Found ${_images.length} images: $_images');
  }

  String get _status => (_donation['status'] ?? 'pending').toString();

  Future<void> _run(Future<Map<String, dynamic>> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (!mounted) return;
      setState(() {
        _donation = {..._donation, ...result};
        _busy = false;
        final code = result['pickup_code']?.toString();
        if (code != null && code.length == 6) _pickupCode = code;
        // ✅ إعادة تحميل الصور بعد التحديث
        _loadImages();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ تم تنفيذ العملية بنجاح'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ تعذر تنفيذ العملية. حاول مرة أخرى'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_donation['item_title'] ?? 'تبرع بدون اسم').toString();
    final charity = _donation['charities'];
    final charityName = _nestedName(charity) ??
        (_donation['charity_name']?.toString() ?? 'جمعية');
    final institutionName = _nestedName(_donation['institutions']) ??
        (_donation['institution_name']?.toString() ?? 'مؤسسة');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildImageSlider(title, institutionName),
            ),
            SliverToBoxAdapter(
              child: _buildContent(charityName, institutionName),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _textDark,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          padding: EdgeInsets.zero,
        ),
      ),
      title: const Text(
        'تفاصيل التبرع',
        style: TextStyle(
          color: _textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share_outlined, size: 20),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSlider(String title, String institutionName) {
    // ✅ استخدام _images بدل اللي جاي من بره
    final images = _images;

    return Stack(
      children: [
        if (images.isNotEmpty)
          Column(
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  height: 260,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: images.length > 1,
                  autoPlay: images.length > 1,
                  autoPlayInterval: const Duration(seconds: 4),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  onPageChanged: (index, reason) {
                    setState(() => _currentImageIndex = index);
                  },
                ),
                items: images.map((image) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _primaryDark.withValues(alpha: 0.4),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
              if (images.length > 1)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: images.asMap().entries.map((entry) {
                      return Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == entry.key
                              ? _primary
                              : Colors.white.withValues(alpha: 0.4),
                          border: Border.all(
                            color: _currentImageIndex == entry.key
                                ? _primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          )
        else
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        Positioned(
          top: 16,
          right: 16,
          child: _buildStatusBadge(_status),
        ),
        Positioned(
          bottom: images.isNotEmpty && images.length > 1 ? 40 : 20,
          right: 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          institutionName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(
                              _donation['created_at']?.toString() ?? ''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
      ],
    );
  }

  Widget _buildContent(String charityName, String institutionName) {
    final quantity = (_donation['quantity'] ?? '—').toString();
    final description = (_donation['description']?.toString() ?? '').trim();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(charityName, institutionName, quantity),
          const SizedBox(height: 16),
          if (description.isNotEmpty) _buildDescription(description),
          const SizedBox(height: 16),
          _buildTimeline(),
          const SizedBox(height: 16),
          if (_pickupCode != null) _buildCodeCard(_pickupCode!),
          if (_pickupCode != null) const SizedBox(height: 16),
          ..._buildActions(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String charityName, String institutionName, String quantity) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _primary, size: 22),
              SizedBox(width: 8),
              Text(
                'معلومات التبرع',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.volunteer_activism_rounded,
                  'الجمعية',
                  charityName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoItem(
                  Icons.inventory_2_rounded,
                  'الكمية',
                  '$quantity وحدة',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoItem(
                  Icons.storefront_rounded,
                  'المؤسسة',
                  institutionName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoItem(
                  Icons.check_circle_outline_rounded,
                  'الحالة',
                  _statusLabel(_status),
                  color: _getStatusColor(_status),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEE9)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color ?? _textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: _primary, size: 22),
              SizedBox(width: 8),
              Text(
                '📝 وصف التبرع',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    const steps = [
      ('pending', 'مراجعة الطلب', Icons.pending_actions_rounded),
      ('accepted', 'تم القبول', Icons.check_circle_outline_rounded),
      ('volunteer_assigned', 'تعيين متطوع', Icons.person_add_rounded),
      ('institution_ready', 'جاهز للتسليم', Icons.inventory_2_rounded),
      ('volunteer_departed', 'في الطريق', Icons.delivery_dining_rounded),
      ('picked_up', 'تم الاستلام', Icons.handshake_rounded),
      ('completed', 'تم التسليم', Icons.emoji_events_rounded),
    ];

    final currentIndex = steps.indexWhere((s) => s.$1 == _status);
    final isRejected =
        _status == 'rejected' || _status == 'cancelled' || _status == 'expired';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_outlined, color: _primary, size: 22),
              SizedBox(width: 8),
              Text(
                'خط سير التبرع',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isDone = !isRejected && currentIndex >= index;
            final isCurrent = index == currentIndex && !isRejected;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDone
                          ? _primary
                          : isRejected && isCurrent
                              ? _error
                              : const Color(0xFFE4EAE5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check_rounded
                          : isRejected && isCurrent
                              ? Icons.close_rounded
                              : step.$3,
                      color: isDone || (isRejected && isCurrent)
                          ? Colors.white
                          : const Color(0xFFA8B4AC),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: TextStyle(
                            color: isDone || (isRejected && isCurrent)
                                ? _textDark
                                : _textMuted,
                            fontWeight: isDone || (isRejected && isCurrent)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (isCurrent && !isRejected)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'المرحلة الحالية',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isDone && !isRejected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 20,
                    ),
                ],
              ),
            );
          }),
          if (isRejected)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: _error, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تم إلغاء هذا التبرع',
                      style: TextStyle(
                        color: _error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6E9), Color(0xFFFFEBC6)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.password_rounded, color: _gold, size: 24),
              ),
              const SizedBox(width: 10),
              const Text(
                'كود الاستلام',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.15)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                letterSpacing: 12,
                fontWeight: FontWeight.w900,
                color: _gold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '⏰ استخدمه مرة واحدة فقط خلال 24 ساعة',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    final id = _donation['id']?.toString();
    if (id == null || id.isEmpty) return [];

    if (_status == 'volunteer_assigned') {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _busy ? null : () => _run(() => _repository.markReady(id)),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_busy ? 'جاري التنفيذ...' : 'أنا جاهز للتسليم'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ];
    }

    if (_status == 'institution_ready' || _status == 'volunteer_departed') {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() => _repository.generatePickupCode(id)),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.password_rounded),
            label: Text(_busy ? 'جاري التنفيذ...' : 'إظهار كود الاستلام'),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ];
    }

    if (_status == 'picked_up') {
      return [
        const _DonationNoticeCard(
          icon: Icons.handshake_rounded,
          title: 'تم الاستلام بنجاح! 🎉',
          text: 'تم استلام التبرع من المتطوع. في انتظار تأكيد وصوله للجمعية.',
          color: _primary,
        ),
      ];
    }

    if (_status == 'completed') {
      return [
        const _DonationNoticeCard(
          icon: Icons.emoji_events_rounded,
          title: 'تم التسليم بنجاح! 🏆',
          text: 'تم تسليم التبرع للجمعية بنجاح. شكراً لك على مشاركتك!',
          color: _gold,
        ),
      ];
    }

    if (_status == 'rejected' ||
        _status == 'cancelled' ||
        _status == 'expired') {
      return [
        const _DonationNoticeCard(
          icon: Icons.cancel_rounded,
          title: 'تم إلغاء التبرع',
          text: 'هذا التبرع تم إلغاؤه ولا يمكن متابعته.',
          color: _error,
        ),
      ];
    }

    return [];
  }

  Widget _buildStatusBadge(String status) {
    final colors = {
      'pending': (const Color(0xFFB36B12), const Color(0xFFFFF0DA)),
      'accepted': (const Color(0xFF3679C8), const Color(0xFFEAF2FF)),
      'volunteer_assigned': (_primary, _primaryLight),
      'institution_ready': (_primary, _primaryLight),
      'volunteer_departed': (const Color(0xFF8A5BB7), const Color(0xFFF0EBF8)),
      'picked_up': (const Color(0xFF2F6DA5), const Color(0xFFE8F0FB)),
      'completed': (_primary, _primaryLight),
      'rejected': (_error, const Color(0xFFFFEEEE)),
      'cancelled': (_error, const Color(0xFFFFEEEE)),
      'expired': (_textMuted, const Color(0xFFF0F0F0)),
    };
    final pair = colors[status] ?? (_textMuted, const Color(0xFFF0F0F0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: pair.$2,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: pair.$1.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: pair.$1,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String? _nestedName(dynamic value) =>
      value is Map ? value['name']?.toString() : null;

  String _formatDate(String date) {
    if (date.isEmpty) return '--';
    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
      if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
      if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
      return 'الآن';
    } catch (_) {
      return date.substring(0, 10);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFB36B12);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'volunteer_assigned':
      case 'institution_ready':
        return _primary;
      case 'volunteer_departed':
        return const Color(0xFF8A5BB7);
      case 'picked_up':
        return const Color(0xFF2F6DA5);
      case 'completed':
        return _primary;
      case 'rejected':
      case 'cancelled':
        return _error;
      case 'expired':
        return _textMuted;
      default:
        return _textMuted;
    }
  }

  static String _statusLabel(String status) {
    const labels = {
      'pending': 'في انتظار المراجعة',
      'accepted': 'تم القبول',
      'rejected': 'مرفوض',
      'volunteer_assigned': 'تم تعيين المتطوع',
      'institution_ready': 'جاهز للتسليم',
      'volunteer_departed': 'المتطوع في الطريق',
      'picked_up': 'تم الاستلام',
      'completed': 'تم التسليم',
      'cancelled': 'ملغي',
      'expired': 'منتهي',
    };
    return labels[status] ?? 'حالة غير معروفة';
  }
}

// ============================================================
// ✅ Widget مساعد
// ============================================================

class _DonationNoticeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _DonationNoticeCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7A8E87),
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
