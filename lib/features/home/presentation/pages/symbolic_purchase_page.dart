import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/donation/presentation/pages/offer_details_page.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/institutions/data/repositories/institutions_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';

class SymbolicPurchasePage extends StatefulWidget {
  const SymbolicPurchasePage({super.key});

  @override
  State<SymbolicPurchasePage> createState() => _SymbolicPurchasePageState();
}

class _SymbolicPurchasePageState extends State<SymbolicPurchasePage> {
  static const green = Color(0xFF0B7650);
  static const darkGreen = Color(0xFF123F31);
  static const background = Color(0xFFF5F8F6);

  final SupabaseClient _client = SupabaseService().client;
  final CommunityOfferRepository _communityRepository =
      CommunityOfferRepository();
  final InstitutionsRepository _institutionRepository =
      InstitutionsRepository();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String _filter = 'الكل';
  String _query = '';

  static const filters = ['الكل', 'مطاعم', 'مؤسسات', 'أشخاص'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (mounted) setState(() => _query = _search.text.trim());
    });
    _loadOffers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ Normalization عربي: أكل = اكل = أكل
  // ============================================================
  String _norm(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  // ============================================================
  // ✅ لسه فيه كمية؟ (شغال حتى لو reserved_quantity مش موجودة)
  // ============================================================
  bool _hasRemaining(Map<String, dynamic> row) {
    final remaining = row['remaining_quantity'];
    if (remaining is num) return remaining > 0;
    final q = row['quantity'];
    if (q is num) {
      final reserved = row['reserved_quantity'];
      return q - (reserved is num ? reserved : 0) > 0;
    }
    return true;
  }

  Future<void> _loadOffers() async {
    if (mounted) setState(() => _loading = true);
    final parts = await Future.wait<List<Map<String, dynamic>>>([
      _restaurantOffers(),
      _institutionOffers(),
      _personOffers(),
    ]);
    final merged = <Map<String, dynamic>>[];
    for (final part in parts) {
      merged.addAll(part);
    }
    merged.sort((a, b) => _date(b).compareTo(_date(a)));
    if (!mounted) return;
    setState(() {
      _offers = merged;
      _loading = false;
    });
  }

  // ============================================================
  // ✅ 1) مطاعم — food_offers
  // ============================================================
  Future<List<Map<String, dynamic>>> _restaurantOffers() async {
    try {
      final rows = await _client.from('food_offers').select('''
        *, businesses:business_id (id, name, logo)
      ''').inFilter('status', [
        'available',
      ]).order('created_at', ascending: false);
      return (rows as List)
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            row['_type'] = 'مطاعم';
            row['_owner'] = _name(row['businesses']) ?? 'مطعم مشارك';
            row['_price'] = row['sale_price'];
            row['_image'] =
                _firstImage('restaurant-offers', row['image'], row['images']);
            if (row['_image'] != null) {
              row['images'] = <String>[row['_image']];
            }
            return row;
          })
          .where(_isLive)
          .where(_hasRemaining)
          .toList();
    } catch (e) {
      debugPrint('[SymbolicPurchase] restaurant error: $e');
      return [];
    }
  }

  // ============================================================
  // ✅ 2) مؤسسات — institution_offers_core + side tables
  // ============================================================
  Future<List<Map<String, dynamic>>> _institutionOffers() async {
    try {
      final rows = await _client.from('institution_offers_core').select('''
        *,
        institutions(id, name, institution_type, logo_url),
        institution_offer_pricing(*),
        institution_offer_inventory(*),
        institution_offer_pickup(*),
        institution_offer_media(*)
      ''').eq('status', 'active').order('created_at', ascending: false);

      return (rows as List).map((raw) {
        final source = Map<String, dynamic>.from(raw as Map);
        final pricing = _nestedMap(source['institution_offer_pricing']);
        final inventory = _nestedMap(source['institution_offer_inventory']);
        final pickup = _nestedMap(source['institution_offer_pickup']);
        final media = _nestedMaps(source['institution_offer_media']);
        final images = media
            .map((item) => item['public_url']?.toString().trim() ?? '')
            .where((url) => url.isNotEmpty)
            .toList(growable: false);
        final row = <String, dynamic>{
          'id': source['id'],
          'institution_id': source['institution_id'],
          'title': source['title'],
          'description': source['description'],
          'category': source['category'] ?? 'other',
          'quantity': inventory['quantity'] ?? 0,
          'remaining_quantity': inventory['remaining_quantity'] ?? 0,
          'symbolic_price': pricing['symbolic_price'] ?? 0,
          'original_price': pricing['original_price'],
          'images': images,
          'pickup_location': pickup['location_text'] ?? pickup['address'],
          'expires_at': source['expires_at'],
          'status': source['status'],
          'created_at': source['created_at'],
          'updated_at': source['updated_at'] ?? source['created_at'],
          'institutions': source['institutions'],
          '_type': 'مؤسسات',
          '_owner': _name(source['institutions']) ?? 'مؤسسة مشاركة',
          '_price': pricing['symbolic_price'],
          '_image': images.isEmpty ? null : images.first,
        };
        return row;
      }).where((row) {
        final expiry = DateTime.tryParse(row['expires_at']?.toString() ?? '');
        return row['status']?.toString() == 'active' &&
            (expiry == null || expiry.isAfter(DateTime.now())) &&
            _hasRemaining(row);
      }).toList(growable: false);
    } catch (e, stack) {
      debugPrint('[SymbolicPurchase] institution error: $e');
      debugPrint('[SymbolicPurchase] institution stack: $stack');
      return [];
    }
  }

  // ============================================================
  // ✅ 3) أشخاص — community_offers (symbolic_sale)
  // ============================================================
  Future<List<Map<String, dynamic>>> _personOffers() async {
    try {
      final rows = await _communityRepository.getOffers(
        listingType: 'symbolic_sale',
      );
      return rows
          .map((raw) {
            final row = Map<String, dynamic>.from(raw);
            row['_type'] = 'أشخاص';
            row['_owner'] = 'مستخدم Loqma';
            row['_price'] = row['price'];
            row['_image'] =
                _firstImage('community-offers', row['image'], row['images']);
            if (row['_image'] != null) {
              row['images'] = <String>[row['_image']];
            }
            return row;
          })
          .where(_isLive)
          .where(_hasRemaining)
          .toList(growable: false);
    } catch (e) {
      debugPrint('[SymbolicPurchase] person error: $e');
      return [];
    }
  }

  bool _isLive(Map<String, dynamic> row) {
    final status = row['status']?.toString().toLowerCase();
    if (status == 'paused' ||
        status == 'expired' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'sold_out') {
      return false;
    }
    final rawExpiry = row['expiry_time'] ?? row['expires_at'];
    final expiry = DateTime.tryParse(rawExpiry?.toString() ?? '');
    return expiry == null || expiry.isAfter(DateTime.now());
  }

  DateTime _date(Map<String, dynamic> row) =>
      DateTime.tryParse(
        row['created_at']?.toString() ?? '',
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _nestedMaps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  String? _name(dynamic value) {
    if (value is Map) return value['name']?.toString();
    if (value is List && value.isNotEmpty && value.first is Map) {
      return (value.first as Map)['name']?.toString();
    }
    return null;
  }

  // ============================================================
  // ✅ الصور: بيتخطى القيم الفاضية والـ paths المكسورة بهدوء
  // ============================================================
  String? _firstImage(String? bucket, dynamic one, dynamic many) {
    final values = <dynamic>[
      if (one != null) one,
      if (many is List) ...many,
    ];
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty || text == 'null') continue;
      if (text.startsWith('http')) return text;
      if (bucket != null) {
        try {
          return _client.storage
              .from(bucket)
              .getPublicUrl(text.replaceFirst(RegExp(r'^/+'), ''));
        } catch (_) {
          continue;
        }
      }
      return text;
    }
    return null;
  }

  // ============================================================
  // ✅ الفلترة: نوع + بحث (بالـ normalization العربي)
  // ============================================================
  List<Map<String, dynamic>> get _visibleOffers => _offers.where((row) {
        final type = row['_type']?.toString() ?? '';
        if (_filter != 'الكل' && type != _filter) return false;
        if (_query.isEmpty) return true;
        final q = _norm(_query);
        final haystack = _norm([
          row['title'],
          row['description'],
          row['category'],
          row['food_type'],
          row['_owner'],
          type,
        ].map((v) => v?.toString() ?? '').join(' '));
        return haystack.contains(q);
      }).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOffers;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('شراء بسعر رمزي',
              style: TextStyle(fontWeight: FontWeight.w900)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: darkGreen,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: green))
            : RefreshIndicator(
                color: green,
                onRefresh: _loadOffers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _hero(),
                    const SizedBox(height: 14),
                    _searchBox(),
                    const SizedBox(height: 12),
                    _filterBar(),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('العروض المتاحة',
                            style: TextStyle(
                                color: darkGreen,
                                fontSize: 19,
                                fontWeight: FontWeight.w900)),
                        Text('${visible.length} عرض',
                            style: const TextStyle(
                                color: green, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      _empty()
                    else
                      ...visible.map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OfferCard(
                                row: row, onTap: () => _openDetails(row)),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [darkGreen, green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: green.withAlpha(35),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختار اللي يناسبك',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('عروض حقيقية من المطاعم والمؤسسات والأشخاص بأسعار رمزية.',
                  style: TextStyle(color: Colors.white70, height: 1.5)),
            ]),
      );

  Widget _searchBox() => TextField(
        controller: _search,
        decoration: InputDecoration(
          hintText: 'ابحث عن عرض أو تصنيف...',
          prefixIcon: const Icon(Icons.search_rounded, color: green),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: _search.clear,
                  icon: const Icon(Icons.close_rounded)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(17),
              borderSide: BorderSide.none),
        ),
      );

  Widget _filterBar() => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = filters[i] == _filter;
            return ChoiceChip(
              label: Text(filters[i]),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filters[i]),
              selectedColor: green,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                  color: selected ? Colors.white : darkGreen,
                  fontWeight: FontWeight.w800),
              side:
                  BorderSide(color: selected ? green : const Color(0xFFE1EAE5)),
            );
          },
        ),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Column(children: [
          Icon(Icons.search_off_rounded, size: 68, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('لا توجد عروض مطابقة',
              style: TextStyle(
                  color: darkGreen, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('غيّر الفلتر أو جرّب كلمة بحث أخرى.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );

  // ============================================================
  // ✅ التفاصيل: كل نوع بياخد الـ shape اللي صفحته بتستناه
  // ============================================================
  void _openDetails(Map<String, dynamic> row) {
    final type = row['_type']?.toString();
    if (type == 'مطاعم') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OfferDetailsPage(offer: _restaurantDetailsMap(row))));
    } else if (type == 'أشخاص') {
      final normalized = Map<String, dynamic>.from(row);
      normalized['images'] = row['images'] is List
          ? row['images']
          : (row['_image'] != null ? <String>[row['_image']] : <String>[]);
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PersonOfferDetailsPage(offer: normalized)));
    } else {
      final normalized = Map<String, dynamic>.from(row)
        ..removeWhere((key, value) => key.startsWith('_'));
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InstitutionOfferDetailsPage(
          offer: InstitutionOffer.fromJson(normalized),
        ),
      ));
    }
  }

  // ✅ الـ shape اللي OfferDetailsPage بيقراها بالظبط (زي ما كانت الـ Home بتبعتها)
  Map<String, dynamic> _restaurantDetailsMap(Map<String, dynamic> row) {
    final biz = row['businesses'];
    final bizMap = biz is Map
        ? Map<String, dynamic>.from(biz)
        : (biz is List && biz.isNotEmpty
            ? Map<String, dynamic>.from(biz.first as Map)
            : <String, dynamic>{});
    return {
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'quantity': row['quantity'],
      'food_type': row['food_type'],
      'expiry_time': row['expiry_time'],
      'pickup_before': row['pickup_before'],
      'pickup_location': row['pickup_location'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'image': row['_image'],
      'status': row['status'],
      'business_id': row['business_id'],
      'charity_id': row['charity_id'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'businesses': {
        'name': bizMap['name'] ?? '',
        'logo': bizMap['logo'],
      },
      'images': row['images'] is List
          ? row['images']
          : (row['_image'] != null ? <String>[row['_image']] : <String>[]),
    };
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  const _OfferCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = row['_image']?.toString();
    final type = row['_type']?.toString() ?? '';
    final price = row['_price'];
    final title = row['title']?.toString().trim();
    final remaining = row['remaining_quantity'];
    final quantity = row['quantity'];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 155,
            child: Stack(fit: StackFit.expand, children: [
              image == null || image.isEmpty
                  ? Container(
                      color: const Color(0xFFE2F1E8),
                      child: const Icon(Icons.shopping_bag_rounded,
                          color: Color(0xFF0B7650), size: 48))
                  : Image.network(image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE2F1E8),
                          child: const Icon(Icons.shopping_bag_rounded,
                              color: Color(0xFF0B7650), size: 48))),
              Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xEEFFFFFF),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(type,
                          style: const TextStyle(
                              color: Color(0xFF0B7650),
                              fontSize: 11,
                              fontWeight: FontWeight.w900)))),
              if (price != null)
                Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0B7650),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('$price جنيه',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title?.isNotEmpty == true ? title! : 'عرض متاح',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF123F31),
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(row['_owner']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (remaining is num || quantity != null)
                        Text(
                          remaining is num
                              ? 'المتاح: $remaining'
                              : 'الكمية: $quantity',
                          style: const TextStyle(
                              color: Color(0xFF71837C), fontSize: 11),
                        ),
                      if (row['category'] != null) ...[
                        const SizedBox(width: 10),
                        Text(row['category'].toString(),
                            style: const TextStyle(
                                color: Color(0xFF0B7650),
                                fontSize: 11,
                                fontWeight: FontWeight.w800))
                      ],
                    ]),
                  ])),
              const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Color(0xFF0B7650)),
            ]),
          ),
        ]),
      ),
    );
  }
}
