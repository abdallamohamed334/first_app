import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/presentation/pages/community_offers_page.dart';

class CommunityHomeOffersSection extends StatefulWidget {
  const CommunityHomeOffersSection({super.key});

  @override
  State<CommunityHomeOffersSection> createState() =>
      _CommunityHomeOffersSectionState();
}

class _CommunityHomeOffersSectionState
    extends State<CommunityHomeOffersSection> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _muted = Color(0xFF6C8077);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('community_offers')
          .select('id,title,category,listing_type,price,image,images,status')
          .eq('status', 'available')
          .neq('listing_type', 'charity_donation')
          .inFilter('category', ['clothing', 'furniture'])
          .order('created_at', ascending: false)
          .limit(6);

      if (!mounted) return;
      setState(() {
        _offers = List<Map<String, dynamic>>.from(rows)
            .where(
                (row) => row['listing_type']?.toString() != 'charity_donation')
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('Community home offers error: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل عروض الملابس والأثاث';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_error != null) {
      return _MessageCard(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        actionLabel: 'إعادة المحاولة',
        onAction: _loadOffers,
      );
    }

    if (_offers.isEmpty) {
      return const _MessageCard(
        icon: Icons.checkroom_rounded,
        title: 'لا توجد عروض ملابس أو أثاث الآن',
        subtitle: 'سنظهر لك أي عرض جديد فور توفره.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.checkroom_rounded, color: _green, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملابس وأثاث',
                      style: TextStyle(
                        color: _darkGreen,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'عروض للبيع بسعر رمزي فقط',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunityOffersPage(),
                  ),
                ),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 238,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _CommunityOfferCard(
              offer: _offers[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CommunityOffersPage(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF2FAF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD6EDE0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0B7650), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF123F31),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFF6C8077),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (onAction != null && actionLabel != null)
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel!),
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

class _CommunityOfferCard extends StatelessWidget {
  const _CommunityOfferCard({required this.offer, required this.onTap});

  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  String _value(String key) {
    final value = offer[key];
    return value == null ? '' : value.toString().trim();
  }

  String _imageUrl() {
    final image = _value('image');
    if (image.isNotEmpty) return image;
    final images = offer['images'];
    if (images is List && images.isNotEmpty) {
      return images.first.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final category = _value('category') == 'furniture' ? 'أثاث' : 'ملابس';
    final sale = _value('listing_type') == 'symbolic_sale';
    final price = num.tryParse(_value('price')) ?? 0;
    final image = _imageUrl();

    return SizedBox(
      width: 210,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: image.isEmpty
                      ? _placeholder(category)
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(category),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _tag(category),
                          const Spacer(),
                          Icon(
                            sale
                                ? Icons.sell_outlined
                                : Icons.volunteer_activism_outlined,
                            color: const Color(0xFF0B7650),
                            size: 17,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _value('title').isEmpty
                            ? 'عرض مجتمعي'
                            : _value('title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF123F31),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        sale && price > 0
                            ? '${price.toStringAsFixed(0)} جنيه'
                            : 'تبرع مجاني',
                        style: const TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0B7650),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _placeholder(String category) {
    return Container(
      color: const Color(0xFFEAF7EF),
      alignment: Alignment.center,
      child: Icon(
        category == 'أثاث' ? Icons.chair_rounded : Icons.checkroom_rounded,
        color: const Color(0xFF0B7650),
        size: 44,
      ),
    );
  }
}
