// lib/features/community/presentation/utils/offer_expiry_helper.dart

import 'package:flutter/material.dart';

/// Helper مشترك لعرض المدة المتبقية للعروض المجتمعية
/// يستخدم في:
///   - community_my_offers_page.dart (عروضي)
///   - user_home_page.dart (الرئيسية - قسم شراء بسعر رمزي)
class OfferExpiryHelper {
  // ═══════════════════════════════════════════════════════════
  // الحالة
  // ═══════════════════════════════════════════════════════════

  /// هل العرض لسه فعّال؟ (null = بدون نهاية)
  static bool isActive(DateTime? expiresAt) {
    if (expiresAt == null) return true;
    return expiresAt.isAfter(DateTime.now());
  }

  /// هل العرض منتهي؟
  static bool isExpired(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    final now = DateTime.now();
    return expiresAt.isBefore(now) || expiresAt.isAtSameMomentAs(now);
  }

  // ═══════════════════════════════════════════════════════════
  // النصوص
  // ═══════════════════════════════════════════════════════════

  /// نص المدة المتبقية بالعربي (كامل)
  static String remainingText(DateTime? expiresAt) {
    if (expiresAt == null) return 'بدون نهاية';

    final diff = expiresAt.difference(DateTime.now());

    if (diff.isNegative) return 'انتهى';

    // أقل من ساعة
    if (diff.inMinutes < 60) {
      if (diff.inMinutes < 1) return 'أقل من دقيقة';
      return 'متبقي ${diff.inMinutes} دقيقة';
    }

    // أقل من يوم
    if (diff.inHours < 24) {
      return 'متبقي ${diff.inHours} ساعة';
    }

    // أيام
    if (diff.inDays == 1) return 'متبقي يوم';
    if (diff.inDays == 2) return 'متبقي يومين';
    if (diff.inDays <= 10) return 'متبقي ${diff.inDays} أيام';

    // أسابيع
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      if (weeks == 1) return 'متبقي أسبوع';
      if (weeks == 2) return 'متبقي أسبوعين';
      return 'متبقي $weeks أسابيع';
    }

    // شهور
    final months = (diff.inDays / 30).floor();
    if (months == 1) return 'متبقي شهر';
    if (months == 2) return 'متبقي شهرين';
    return 'متبقي $months أشهر';
  }

  /// نص مختصر (للشارة الصغيرة)
  static String shortText(DateTime? expiresAt) {
    if (expiresAt == null) return 'دائم';

    final diff = expiresAt.difference(DateTime.now());

    if (diff.isNegative) return 'انتهى';

    if (diff.inMinutes < 60) return '${diff.inMinutes} د';
    if (diff.inHours < 24) return '${diff.inHours} س';
    if (diff.inDays < 30) return '${diff.inDays} يوم';

    final months = (diff.inDays / 30).floor();
    return '$months شهر';
  }

  // ═══════════════════════════════════════════════════════════
  // الألوان
  // ═══════════════════════════════════════════════════════════

  /// لون المؤشر حسب الوقت المتبقي
  static Color indicatorColor(DateTime? expiresAt) {
    // بدون نهاية → أزرق
    if (expiresAt == null) return const Color(0xFF3679C8);

    final diff = expiresAt.difference(DateTime.now());

    // منتهي → رمادي
    if (diff.isNegative) return const Color(0xFF71837C);

    // أقل من 24 ساعة → أحمر
    if (diff.inHours < 24) return const Color(0xFFD64545);

    // أقل من 3 أيام → برتقالي
    if (diff.inDays < 3) return const Color(0xFFE28B00);

    // أقل من 7 أيام → أصفر
    if (diff.inDays < 7) return const Color(0xFFB77700);

    // أكثر من 7 أيام → أخضر
    return const Color(0xFF0B7650);
  }

  /// أيقونة حسب الوقت
  static IconData indicatorIcon(DateTime? expiresAt) {
    if (expiresAt == null) return Icons.all_inclusive_rounded;

    final diff = expiresAt.difference(DateTime.now());

    if (diff.isNegative) return Icons.timer_off_rounded;
    if (diff.inHours < 24) return Icons.warning_amber_rounded;

    return Icons.timer_outlined;
  }

  // ═══════════════════════════════════════════════════════════
  // التحذيرات
  // ═══════════════════════════════════════════════════════════

  /// هل العرض "عاجل" (أقل من 24 ساعة)؟
  static bool isUrgent(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    final diff = expiresAt.difference(DateTime.now());
    return !diff.isNegative && diff.inHours < 24;
  }

  /// هل العرض قرب يخلص (أقل من 3 أيام)؟
  static bool isEndingSoon(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    final diff = expiresAt.difference(DateTime.now());
    return !diff.isNegative && diff.inDays < 3;
  }

  // ═══════════════════════════════════════════════════════════
  // Widget: شارة المدة المتبقية (مشتركة)
  // ═══════════════════════════════════════════════════════════

  /// شارة صغيرة تعرض المدة المتبقية
  /// [compact] = true → نص مختصر وحجم أصغر
  static Widget buildBadge({
    required DateTime? expiresAt,
    bool compact = false,
  }) {
    final color = indicatorColor(expiresAt);
    final icon = indicatorIcon(expiresAt);
    final text = compact ? shortText(expiresAt) : remainingText(expiresAt);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
