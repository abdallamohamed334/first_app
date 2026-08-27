import 'package:flutter/material.dart';

class CharityActionFeedback {
  const CharityActionFeedback._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, success: true);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, success: false);
  }

  static void _show(
    BuildContext context,
    String message, {
    required bool success,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          elevation: 5,
          backgroundColor:
              success ? const Color(0xFFE9F7F0) : const Color(0xFFFFEFEE),
          leading: CircleAvatar(
            backgroundColor:
                (success ? const Color(0xFF087A52) : const Color(0xFFB54747))
                    .withAlpha(22),
            foregroundColor:
                success ? const Color(0xFF087A52) : const Color(0xFFB54747),
            child: Icon(
              success ? Icons.check_rounded : Icons.error_outline_rounded,
            ),
          ),
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color:
                  success ? const Color(0xFF123D31) : const Color(0xFF7D2929),
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text(
                'إغلاق',
                style: TextStyle(
                  color: success
                      ? const Color(0xFF087A52)
                      : const Color(0xFFB54747),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (messenger.mounted) messenger.hideCurrentMaterialBanner();
    });
  }
}
