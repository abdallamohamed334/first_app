import 'package:flutter/material.dart';

import 'home_palette.dart';

/// A global entry point for opening any published provider by their code.
///
/// This deliberately lives on the home screen instead of a service category,
/// because the code already identifies the provider and is independent of the
/// provider's service category.
class HomeProviderCodeSearch extends StatefulWidget {
  final Future<bool> Function(String code) onSearch;

  const HomeProviderCodeSearch({
    super.key,
    required this.onSearch,
  });

  @override
  State<HomeProviderCodeSearch> createState() => _HomeProviderCodeSearchState();
}

class _HomeProviderCodeSearchState extends State<HomeProviderCodeSearch> {
  final _controller = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _searching) return;

    FocusScope.of(context).unfocus();
    setState(() => _searching = true);

    final found = await widget.onSearch(code);
    if (!mounted) return;
    setState(() => _searching = false);

    if (!found) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('مش لاقيين مقدم خدمة بالكود ده'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomePalette.textPrimary,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = HomePalette.isDark;
    final primary = HomePalette.primaryRed;
    final card = HomePalette.card;
    final textPrimary = HomePalette.textPrimary;
    final textSecondary = HomePalette.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF3B2025), const Color(0xFF2A2C30)]
                : [const Color(0xFFFFF1F2), Colors.white],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isDark ? 0.10 : 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.manage_search_rounded,
                      color: primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بتدور على صنايعي بعينه؟',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'اكتب كود التقييم وافتح بروفايله مباشرة',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'مثال: KHD-000001',
                      hintStyle: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                      filled: true,
                      fillColor: card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: HomePalette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: HomePalette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _searching ? null : _submit,
                  tooltip: 'بحث بالكود',
                  style: IconButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.35),
                  ),
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
