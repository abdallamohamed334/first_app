// lib/features/home/presentation/widgets/home_search_bar.dart

import 'package:flutter/material.dart';

class HomeSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: '🔍 ابحث عن فائض قريب منك...',
            hintStyle: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colors.primary,
              size: 22,
            ),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
