// lib/features/home/presentation/widgets/home_leaderboard.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';

class HomeLeaderboard extends StatefulWidget {
  const HomeLeaderboard({super.key});

  @override
  State<HomeLeaderboard> createState() => _HomeLeaderboardState();
}

class _HomeLeaderboardState extends State<HomeLeaderboard> {
  List<Map<String, dynamic>> _topDonors = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopDonors();
  }

  Future<void> _loadTopDonors() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService().client.rpc(
        'list_public_charity_donors',
      );
      if (!mounted) return;
      setState(() {
        _topDonors = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('❌ Error loading charity donor leaderboard: $error');
      if (!mounted) return;
      setState(() {
        _topDonors = const [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                'ترتيب المتبرعين للجمعيات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else if (_topDonors.isEmpty)
            _buildEmptyState(colorScheme)
          else
            ..._topDonors.asMap().entries.map((entry) {
              return _buildLeaderboardItem(
                context,
                entry.value,
                entry.key + 1,
                colorScheme,
                isDark,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Center(
        child: Text(
          'لا يوجد متبرعون مكتملو التبرع حتى الآن',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    Map<String, dynamic> donor,
    int rank,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final name = donor['name']?.toString().trim().isNotEmpty == true
        ? donor['name'].toString()
        : 'متبرع';
    final avatarUrl = donor['avatar_url']?.toString();
    final donations = _asInt(donor['donation_count']);
    final items = _asInt(donor['items_count']);
    final isTop3 = rank <= 3;
    final rankColor = rank == 1
        ? Colors.amber
        : rank == 2
            ? (isDark ? const Color(0xFF9E9E9E) : Colors.grey.shade400)
            : rank == 3
                ? (isDark ? const Color(0xFFB08968) : Colors.brown.shade300)
                : (isDark ? const Color(0xFF757575) : Colors.grey.shade500);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: isTop3 ? Border.all(color: rankColor.withAlpha(50)) : null,
        boxShadow: isTop3
            ? [BoxShadow(color: rankColor.withAlpha(20), blurRadius: 8,
                offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isTop3
                    ? (rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉')
                    : '#$rank',
                style: TextStyle(
                  fontSize: isTop3 ? 16 : 12,
                  fontWeight: FontWeight.bold,
                  color: rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withAlpha(20),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initial(name),
                    ),
                  )
                : _initial(name),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$donations تبرع',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                '$items قطعة',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initial(String name) => Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(fontSize: 14),
      );

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
