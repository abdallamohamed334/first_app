// lib/features/home/presentation/widgets/home_leaderboard.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/volunteer/presentation/pages/volunteer_leaderboard_page.dart';

class HomeLeaderboard extends StatefulWidget {
  const HomeLeaderboard({super.key});

  @override
  State<HomeLeaderboard> createState() => _HomeLeaderboardState();
}

class _HomeLeaderboardState extends State<HomeLeaderboard> {
  List<Map<String, dynamic>> _topVolunteers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopVolunteers();
  }

  Future<void> _loadTopVolunteers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('users')
          .select('id, name, avatar_url, points, level')
          .eq('user_type', 'user')
          .order('points', ascending: false)
          .limit(5);

      setState(() {
        _topVolunteers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading leaderboard: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '🏆 أفضل المتطوعين',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // ✅ التنقل لصفحة المتطوعين
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VolunteerLeaderboardPage(),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_topVolunteers.isEmpty)
            _buildEmptyState(colorScheme)
          else
            ..._topVolunteers.asMap().entries.map((entry) {
              final index = entry.key;
              final volunteer = entry.value;
              final rank = index + 1;
              return _buildLeaderboardItem(
                  context, volunteer, rank, colorScheme);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: Center(
        child: Text(
          'لا يوجد متطوعين حتى الآن',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context,
    Map<String, dynamic> volunteer,
    int rank,
    ColorScheme colorScheme,
  ) {
    final name = volunteer['name'] ?? 'مستخدم';
    final points = volunteer['points'] ?? 0;
    final avatarUrl = volunteer['avatar_url'] as String?;
    final isTop3 = rank <= 3;

    Color rankColor;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        break;
      case 3:
        rankColor = Colors.brown.shade300;
        break;
      default:
        rankColor = Colors.grey.shade500;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: isTop3 ? Border.all(color: rankColor.withAlpha(50)) : null,
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: rankColor.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // ✅ المركز
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
                    ? (rank == 1
                        ? '🥇'
                        : rank == 2
                            ? '🥈'
                            : '🥉')
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
          // ✅ الصورة
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withAlpha(20),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                : Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
          const SizedBox(width: 10),
          // ✅ الاسم
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ✅ النقاط
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '$points',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
