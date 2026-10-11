import 'package:flutter/material.dart';
import 'package:loqma/core/constants/egypt_locations.dart';
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
  String? _selectedGovernorate;
  bool _loading = true;
  String? _error;

  ColorScheme get _colors => Theme.of(context).colorScheme;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _accent =>
      _isDark ? const Color(0xFF48C98A) : const Color(0xFF0B7650);
  Color get _surface => _colors.surface;
  Color get _cardSurface => _colors.surfaceContainerLow;
  Color get _textPrimary => _colors.onSurface;
  Color get _textSecondary => _colors.onSurfaceVariant;
  Color get _border => _colors.outlineVariant;

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

  String? _governorateFor(CommunityCharityOption charity) {
    final explicit = charity.governorate?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final normalized = explicit.toLowerCase();
      final match = EgyptLocations.names.where(
        (name) => normalized.contains(name.toLowerCase()),
      );
      if (match.isNotEmpty) return match.first;
      return explicit;
    }

    final location = '${charity.city ?? ''} ${charity.address ?? ''}'
        .toLowerCase();
    for (final entry in EgyptLocations.governorates.entries) {
      if (location.contains(entry.key.toLowerCase()) ||
          entry.value.any((city) => location.contains(city.toLowerCase()))) {
        return entry.key;
      }
    }
    return null;
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    final governorate = _selectedGovernorate;
    setState(() {
      _filtered = _all
          .where((charity) {
            final haystack = [
              charity.name,
              charity.address ?? '',
              charity.city ?? '',
              charity.governorate ?? '',
              charity.description ?? '',
            ].join(' ').toLowerCase();
            final matchesQuery = query.isEmpty || haystack.contains(query);
            final matchesGovernorate =
                governorate == null ||
                _governorateFor(charity)?.toLowerCase() ==
                    governorate.toLowerCase();
            return matchesQuery && matchesGovernorate;
          })
          .toList(growable: false);
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: const Text('اختيار الجمعية'),
          centerTitle: true,
          backgroundColor: _surface,
          foregroundColor: _textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: RefreshIndicator(
          color: _accent,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              _header(),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم الجمعية أو المنطقة',
                  hintStyle: TextStyle(color: _textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: _accent),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: _cardSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _governorateFilter(),
              const SizedBox(height: 14),
              if (!_loading && _error == null && _filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${_filtered.length} جمعية متاحة',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
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
      ),
    );
  }

  Widget _governorateFilter() => DropdownButtonFormField<String>(
    key: ValueKey(_selectedGovernorate ?? ''),
    initialValue: _selectedGovernorate ?? '',
    isExpanded: true,
    decoration: InputDecoration(
      labelText: 'المحافظة',
      prefixIcon: Icon(Icons.location_city_rounded, color: _accent),
      filled: true,
      fillColor: _cardSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accent, width: 1.5),
      ),
    ),
    items: [
      const DropdownMenuItem(value: '', child: Text('كل المحافظات')),
      ...EgyptLocations.names.map(
        (name) => DropdownMenuItem(value: name, child: Text(name)),
      ),
    ],
    onChanged: (value) {
      _selectedGovernorate = value == null || value.isEmpty ? null : value;
      _filter();
    },
  );

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
          child: Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.white,
            size: 30,
          ),
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
          color: _cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.28 : 0.05),
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
                        Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Icon(
                            Icons.verified_rounded,
                            color: _accent,
                            size: 17,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          charity.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _textPrimary,
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
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'اضغط لعرض التفاصيل واختيار الجمعية',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: _accent),
          ],
        ),
      ),
    ),
  );

  Widget _logo(CommunityCharityOption charity) {
    final logo = charity.logo;
    if (logo == null || logo.isEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: _colors.surfaceContainerHighest,
        child: Icon(Icons.account_balance_rounded, color: _accent, size: 28),
      );
    }
    return ClipOval(
      child: Image.network(
        logo,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: 30,
          backgroundColor: _colors.surfaceContainerHighest,
          child: Icon(Icons.account_balance_rounded, color: _accent, size: 28),
        ),
      ),
    );
  }

  Widget _errorView() =>
      _messageCard(Icons.wifi_off_rounded, _error!, 'إعادة المحاولة', _load);

  Widget _emptyView() => _messageCard(
    Icons.search_off_rounded,
    _selectedGovernorate == null
        ? 'لا توجد جمعية تطابق بحثك.'
        : 'لا توجد جمعيات مسجلة في محافظة $_selectedGovernorate ضمن نتائج البحث.',
    'مسح البحث والفلتر',
    () {
      _searchController.clear();
      _selectedGovernorate = null;
      _filter();
    },
  );

  Widget _messageCard(
    IconData icon,
    String message,
    String action,
    VoidCallback onPressed,
  ) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: _cardSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(icon, color: _accent, size: 42),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textPrimary),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}
