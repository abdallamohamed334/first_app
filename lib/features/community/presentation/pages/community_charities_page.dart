import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_details_page.dart'
    show CommunityCharityDetailsPage;
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

class CommunityCharitiesPage extends StatefulWidget {
  final String? initialCharityId;

  const CommunityCharitiesPage({super.key, this.initialCharityId});

  @override
  State<CommunityCharitiesPage> createState() => _CommunityCharitiesPageState();
}

class _CommunityCharitiesPageState extends State<CommunityCharitiesPage> {
  final _searchController = TextEditingController();
  final _repository = CommunityOfferRepository();
  List<CommunityCharityOption> _all = const [];
  List<CommunityCharityOption> _filtered = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filter)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository.getActiveCharities();
      final options = rows
          .map(CommunityCharityOption.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _all = options;
        _filtered = options;
        _loading = false;
      });
      _filter();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الجمعيات. تحقق من الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all.where((charity) {
              final haystack = [
                charity.name,
                charity.address ?? '',
                charity.description ?? '',
              ].join(' ').toLowerCase();
              return haystack.contains(query);
            }).toList();
    });
  }

  Future<void> _openDetails(CommunityCharityOption charity) async {
    final selected = await Navigator.push<CommunityCharityOption>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCharityDetailsPage(charity: charity),
      ),
    );
    if (!mounted || selected == null) return;
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      appBar: AppBar(
        title: const Text('اختيار الجمعية'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF123F31),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _header(),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث باسم الجمعية أو المنطقة',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorView()
            else if (_filtered.isEmpty)
              _emptyView()
            else
              ..._filtered.map(_charityCard),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7650), Color(0xFF21A36F)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: Colors.white24,
              child: Icon(Icons.volunteer_activism_rounded,
                  color: Colors.white, size: 30),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'اختار الجمعية التي تريد أن يصل إليها تبرعك',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _charityCard(CommunityCharityOption charity) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _openDetails(charity),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE1ECE6)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _logo(charity),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (charity.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.verified_rounded,
                                  color: Color(0xFF16865D), size: 17),
                            ),
                          Flexible(
                            child: Text(
                              charity.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Color(0xFF123F31),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        charity.address ?? 'العنوان غير متاح',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'اضغط لعرض التفاصيل واختيار الجمعية',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_left_rounded,
                    color: Color(0xFF0B7650)),
              ],
            ),
          ),
        ),
      );

  Widget _logo(CommunityCharityOption charity) {
    final logo = charity.logo;
    if (logo == null || logo.isEmpty) {
      return const CircleAvatar(
        radius: 30,
        backgroundColor: Color(0xFFE8F5EE),
        child: Icon(Icons.account_balance_rounded,
            color: Color(0xFF0B7650), size: 28),
      );
    }
    return ClipOval(
      child: Image.network(
        logo,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFE8F5EE),
          child: Icon(Icons.account_balance_rounded,
              color: Color(0xFF0B7650), size: 28),
        ),
      ),
    );
  }

  Widget _errorView() => _messageCard(
        Icons.wifi_off_rounded,
        _error!,
        'إعادة المحاولة',
        _load,
      );

  Widget _emptyView() => _messageCard(
        Icons.search_off_rounded,
        'لا توجد جمعية تطابق بحثك.',
        'مسح البحث',
        () {
          _searchController.clear();
          _filter();
        },
      );

  Widget _messageCard(
    IconData icon,
    String message,
    String action,
    VoidCallback onPressed,
  ) =>
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF0B7650), size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      );
}
