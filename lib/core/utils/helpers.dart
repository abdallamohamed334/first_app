import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  Helpers._();

  static String formatDate(
    DateTime date, {
    String pattern = 'dd/MM/yyyy',
  }) {
    try {
      return DateFormat(pattern, 'ar').format(date.toLocal());
    } catch (_) {
      return date.toLocal().toIso8601String();
    }
  }

  static String formatTime(DateTime time) {
    try {
      return DateFormat('hh:mm a', 'ar').format(time.toLocal());
    } catch (_) {
      return time.toLocal().toIso8601String();
    }
  }

  static String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime.toLocal());
    if (difference.isNegative || difference.inSeconds < 60) return 'الآن';
    if (difference.inDays >= 365) return 'منذ ${difference.inDays ~/ 365} سنة';
    if (difference.inDays >= 30) return 'منذ ${difference.inDays ~/ 30} شهر';
    if (difference.inDays >= 7) return 'منذ ${difference.inDays ~/ 7} أسبوع';
    if (difference.inDays > 0) return 'منذ ${difference.inDays} يوم';
    if (difference.inHours > 0) return 'منذ ${difference.inHours} ساعة';
    return 'منذ ${difference.inMinutes} دقيقة';
  }

  static bool isPastDate(DateTime date) => date.isBefore(DateTime.now());

  static bool isFutureDate(DateTime date) => date.isAfter(DateTime.now());

  static String truncateText(String text, int maxLength) {
    if (maxLength <= 0) return '';
    final value = text.trim();
    if (value.length <= maxLength) return value;
    if (maxLength <= 3) return value.substring(0, maxLength);
    return '${value.substring(0, maxLength - 3)}...';
  }

  static String capitalize(String text) {
    final value = text.trim();
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String toTitleCase(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(capitalize)
        .join(' ');
  }

  static String generateId() {
    final random = Random.secure().nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  static String generateRandomPassword({int length = 12}) {
    final safeLength = length.clamp(6, 128);
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        safeLength,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  static String formatNumber(num number) {
    try {
      return NumberFormat('#,###', 'ar').format(number);
    } catch (_) {
      return number.toString();
    }
  }

  static String formatCurrency(
    num amount, {
    String currency = 'EGP',
  }) {
    try {
      return NumberFormat.currency(
        locale: 'ar',
        symbol: currency,
        decimalDigits: 0,
      ).format(amount);
    } catch (_) {
      return '$amount $currency';
    }
  }

  static bool isBetween(num number, num min, num max) {
    return number >= min && number <= max;
  }

  static String formatPercentage(num value, num total) {
    if (total == 0) return '0%';
    return '${((value / total) * 100).toStringAsFixed(1)}%';
  }

  static bool isNullOrEmpty(String? text) =>
      text == null || text.trim().isEmpty;

  static bool isNumeric(String text) => RegExp(r'^\d+$').hasMatch(text.trim());

  static bool isAlpha(String text) => RegExp(
        r"^[a-zA-Z\u0600-\u06FF\s'_-]+$",
      ).hasMatch(text.trim());

  static bool isAlphaNumeric(String text) => RegExp(
        r"^[a-zA-Z0-9\u0600-\u06FF\s'_-]+$",
      ).hasMatch(text.trim());

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 1200;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static double percentage(num value, num total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      _showSnackBar(
        context,
        message,
        Colors.green,
        Icons.check_circle,
        duration,
      );

  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) =>
      _showSnackBar(
        context,
        message,
        Colors.red,
        Icons.error,
        duration,
      );

  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      _showSnackBar(
        context,
        message,
        Colors.orange,
        Icons.warning,
        duration,
      );

  static void showInfoSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      _showSnackBar(
        context,
        message,
        Colors.blue,
        Icons.info,
        duration,
      );

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
    Duration duration,
  ) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  static Future<void> showLoadingDialog(
    BuildContext context, {
    String? message,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              if (message != null && message.trim().isNotEmpty) ...[
                const SizedBox(width: 16),
                Flexible(child: Text(message)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    if (!context.mounted) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) navigator.pop();
  }
}
