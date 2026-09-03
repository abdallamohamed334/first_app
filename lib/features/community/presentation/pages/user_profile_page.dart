// lib/features/community/presentation/pages/user_profile_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userAvatar;
  final String? userPhone;
  final String? userEmail;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.userPhone,
    this.userEmail,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final SupabaseService _supabase = SupabaseService();
  bool _loading = true;
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _userInfo = {};

  // 🎨 الألوان نفسها من الـ HTML
  static const Color _primary = Color(0xFF005B3C);
  static const Color _primaryContainer = Color(0xFF0B7650);
  static const Color _secondaryContainer = Color(0xFFBEEDD8);
  static const Color _surface = Color(0xFFF7FAF9);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF181C1C);
  static const Color _onSurfaceVariant = Color(0xFF3F4942);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _outlineVariant = Color(0xFFBEC9C0);
  static const Color _tertiaryContainer = Color(0xFF5E6A65);
  static const Color _onTertiaryContainer = Color(0xFFDDEAE3);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      // جلب إحصائيات المستخدم
      final stats = await _supabase.getUserStats(widget.userId);

      // جلب معلومات المستخدم
      final user = await _supabase.getUserById(widget.userId);

      setState(() {
        _userStats = stats;
        _userInfo = {
          'email': user?.email ?? widget.userEmail ?? 'غير متوفر',
          'phone': user?.phone ?? widget.userPhone ?? 'غير متوفر',
          'city': user?.city ?? 'غير محدد',
          'joinDate': user?.createdAt ?? DateTime.now(),
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _primaryContainer,
                ),
              )
            : RefreshIndicator(
                color: _primaryContainer,
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildStatsGrid(),
                      const SizedBox(height: 24),
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildAchievements(),
                      const SizedBox(height: 24),
                      _buildContactButtons(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: _onSurface,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          padding: EdgeInsets.zero,
        ),
      ),
      title: const Text(
        'الملف الشخصي',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: _secondaryContainer,
                backgroundImage: widget.userAvatar.isNotEmpty
                    ? NetworkImage(widget.userAvatar)
                    : null,
                child: widget.userAvatar.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: _primaryContainer,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: _primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: _onPrimary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.userName,
            style: const TextStyle(
              color: _onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B7650), Color(0xFF005B3C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: _onPrimary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'المستوى ${_userStats['level'] ?? 1}',
                  style: const TextStyle(
                    color: _onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                icon: Icons.volunteer_activism_rounded,
                label: 'متطوع نشط',
              ),
              const SizedBox(width: 8),
              _buildBadge(
                icon: Icons.verified_rounded,
                label: 'موثوق',
                color: const Color(0xFF3679C8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    Color color = _primaryContainer,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF005B3C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryContainer.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 إحصائيات المتطوع',
            style: TextStyle(
              color: _onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.volunteer_activism_rounded,
                value: '${_userStats['mealsSaved'] ?? 0}',
                label: 'وجبة منقذة',
              ),
              _buildStatItem(
                icon: Icons.local_shipping_rounded,
                value: '${_userStats['deliveriesCount'] ?? 0}',
                label: 'توصيل',
              ),
              _buildStatItem(
                icon: Icons.stars_rounded,
                value: '${_userStats['points'] ?? 0}',
                label: 'نقطة',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.emoji_events_rounded,
                value: '${_userStats['level'] ?? 1}',
                label: 'المستوى',
              ),
              _buildStatItem(
                icon: Icons.task_alt_rounded,
                value: '${_userStats['tasksCompleted'] ?? 0}',
                label: 'مهمة مكتملة',
              ),
              _buildStatItem(
                icon: Icons.people_rounded,
                value: '${(_userStats['mealsSaved'] ?? 0) * 2}',
                label: 'مستفيد',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: _onPrimary, size: 22),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: _onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _onPrimary.withOpacity(0.8),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ℹ️ معلومات شخصية',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.email_rounded,
            'البريد الإلكتروني',
            _userInfo['email'] ?? 'غير متوفر',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.phone_rounded,
            'رقم الهاتف',
            _userInfo['phone'] ?? 'غير متوفر',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.location_on_rounded,
            'المدينة',
            _userInfo['city'] ?? 'غير محدد',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.calendar_today_rounded,
            'تاريخ الانضمام',
            _formatDate(_userInfo['joinDate']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryContainer, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: _onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    final achievements = _getAchievements();
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 الإنجازات',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: achievements.map((achievement) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0DA), Color(0xFFFFE4B5)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8C88A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFB36B12),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      achievement,
                      style: const TextStyle(
                        color: Color(0xFFB36B12),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: فتح صفحة المحادثة
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📨 جاري فتح المحادثة...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('مراسلة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryContainer,
              side: const BorderSide(color: _primaryContainer),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // TODO: فتح واتساب
              final phone = _userInfo['phone']?.toString() ?? '';
              if (phone.isNotEmpty && phone != 'غير متوفر') {
                // فتح واتساب
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ رقم الهاتف غير متوفر'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: const Text('اتصال'),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _getAchievements() {
    final result = <String>[];
    final mealsSaved = _userStats['mealsSaved'] ?? 0;
    final points = _userStats['points'] ?? 0;
    final deliveries = _userStats['deliveriesCount'] ?? 0;
    final level = _userStats['level'] ?? 1;

    if (mealsSaved >= 1) result.add('🍽️ أول وجبة منقذة');
    if (mealsSaved >= 10) result.add('🎯 10 وجبات منقذة');
    if (mealsSaved >= 50) result.add('🏅 50 وجبة منقذة');
    if (points >= 100) result.add('⭐ 100 نقطة');
    if (points >= 500) result.add('🌟 500 نقطة');
    if (deliveries >= 1) result.add('🚚 أول توصيل');
    if (deliveries >= 10) result.add('📦 10 توصيلات');
    if (level >= 3) result.add('🏆 متطوع محترف');
    if (level >= 5) result.add('👑 سفير الخير');

    return result;
  }

  String _formatDate(String date) {
    if (date.isEmpty) return 'غير معروف';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }
}
