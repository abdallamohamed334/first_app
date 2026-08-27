import 'dart:async';

import 'package:flutter/material.dart';

class MapSearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const MapSearchBar({
    super.key,
    required this.onSearch,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _hasText = false;
  bool _waitingToSearch = false;

  static const _debounceDuration = Duration(milliseconds: 550);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final query = value.trim();

    setState(() {
      _hasText = query.isNotEmpty;
      _waitingToSearch = query.length >= 2;
    });

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() => _waitingToSearch = false);
      widget.onSearch('');
      return;
    }

    // لا نبحث عن حرف واحد، لتقليل النتائج غير الدقيقة.
    if (query.length < 2) {
      setState(() => _waitingToSearch = false);
      return;
    }

    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() => _waitingToSearch = false);
      widget.onSearch(query);
    });
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    setState(() => _waitingToSearch = false);

    if (query.isNotEmpty) {
      widget.onSearch(query);
      _focusNode.unfocus();
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _hasText = false;
      _waitingToSearch = false;
    });
    widget.onSearch('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(248),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _focusNode.hasFocus
                ? colorScheme.primary.withAlpha(150)
                : colorScheme.outlineVariant.withAlpha(100),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(24),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: colorScheme.primary,
              size: 23,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.streetAddress,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  hintText: 'ابحث عن منطقة، مدينة أو بلد...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_waitingToSearch)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              )
            else if (_hasText)
              IconButton(
                onPressed: _clearSearch,
                tooltip: 'مسح البحث',
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
