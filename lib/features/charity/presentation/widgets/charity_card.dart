import 'package:flutter/material.dart';
import 'package:loqma/core/widgets/page_transition.dart';
import '../pages/charity_details_page.dart';

class CharityCard extends StatelessWidget {
  final Map<String, dynamic> charity;

  const CharityCard({super.key, required this.charity});

  static const _green = Color(0xFF2E7D32);
  static const _lightGreen = Color(0xFFF1F8E9);

  String _stringValue(String key) {
    final value = charity[key]?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? '' : value;
  }

  String get _imageUrl {
    for (final key in const [
      'logo',
      'logo_url',
      'image_url',
      'avatar_url',
      'cover_image_url',
    ]) {
      final value = _stringValue(key);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get _name {
    final value = _stringValue('name');
    return value.isEmpty ? 'جمعية خيرية' : value;
  }

  String get _initials {
    final words = _name
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.isEmpty) return 'خ';
    if (words.length == 1) return words.first.characters.take(2).toString();
    return '${words.first.characters.first}${words[1].characters.first}';
  }

  bool _hasValue(String key) {
    final value = charity[key];
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _stringValue('status').toLowerCase();
    final isActive = status.isEmpty || status == 'active';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageTransition.slideRightToLeft(
              CharityDetailsPage(charity: charity),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _lightGreen,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _green.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCoverImage(colorScheme),
              _buildContent(colorScheme, isActive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(ColorScheme colorScheme) {
    final colors = <List<Color>>[
      [
        colorScheme.primaryContainer.withValues(alpha: 0.85),
        colorScheme.secondaryContainer.withValues(alpha: 0.65),
      ],
      [Colors.blue.shade300, Colors.blue.shade100],
      [Colors.orange.shade300, Colors.orange.shade100],
      [Colors.purple.shade300, Colors.purple.shade100],
      [Colors.pink.shade300, Colors.pink.shade100],
    ];
    final index = charity['id']?.toString().hashCode.abs() ?? 0;
    final gradientColors = colors[index % colors.length];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageUrl.isNotEmpty)
              Image.network(
                _imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackCover(gradientColors),
              )
            else
              _fallbackCover(gradientColors),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 12,
              start: 12,
              child: _badge(
                icon: Icons.location_on,
                label: _locationLabel,
                color: Colors.white.withValues(alpha: 0.92),
                textColor: colorScheme.onSurface,
              ),
            ),
            PositionedDirectional(
              top: 12,
              end: 12,
              child: _badge(
                label: _stringValue('status').isEmpty
                    ? 'نشطة'
                    : (_stringValue('status').toLowerCase() == 'active'
                        ? 'نشطة'
                        : 'غير نشطة'),
                color: _stringValue('status').toLowerCase() == 'active'
                    ? Colors.green.withValues(alpha: 0.9)
                    : Colors.grey.withValues(alpha: 0.9),
                textColor: Colors.white,
              ),
            ),
            PositionedDirectional(
              bottom: -24,
              end: 16,
              child: _logoBubble(colorScheme),
            ),
            PositionedDirectional(
              bottom: 12,
              start: 16,
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _locationLabel {
    final city = _stringValue('city');
    final distance = _stringValue('distance');
    if (city.isEmpty && distance.isEmpty) return 'الموقع غير محدد';
    if (distance.isEmpty) return city;
    if (city.isEmpty) return distance;
    return '$city • $distance';
  }

  Widget _fallbackCover(List<Color> colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.volunteer_activism_rounded,
          size: 54,
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _badge({
    required String label,
    required Color color,
    required Color textColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoBubble(ColorScheme colorScheme) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _lightGreen, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _imageUrl.isEmpty
          ? Icon(Icons.volunteer_activism_rounded,
              size: 28, color: colorScheme.primary)
          : Image.network(
              _imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.volunteer_activism_rounded,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, bool isActive) {
    final description = _stringValue('description');
    final rating = _stringValue('rating');
    final ratingCount = _stringValue('rating_count');
    final mealsSaved = _stringValue('meals_saved');
    final volunteers = _stringValue('volunteers_count');
    final responseRate = _stringValue('response_rate');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
            ],
          ),
          if (rating.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (ratingCount.isNotEmpty)
                  Text(
                    ' ($ratingCount تقييم)',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (mealsSaved.isNotEmpty ||
              volunteers.isNotEmpty ||
              responseRate.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (mealsSaved.isNotEmpty)
                  _buildStatChip('🍱', '$mealsSaved وجبة', colorScheme),
                if (volunteers.isNotEmpty)
                  _buildStatChip('👥', '$volunteers متطوع', colorScheme),
                if (responseRate.isNotEmpty)
                  _buildStatChip('⚡', '$responseRate استجابة', colorScheme),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'عرض التفاصيل',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String icon, String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
