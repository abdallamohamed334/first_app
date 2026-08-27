import 'dart:async';

import 'package:flutter/material.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final FutureOr<void> Function()? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final theme = Theme.of(context);
    final background = backgroundColor ?? theme.colorScheme.primary;
    final foreground = foregroundColor ?? theme.colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? _handlePressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withAlpha(110),
          disabledForegroundColor: foreground.withAlpha(180),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _handlePressed() {
    final callback = onPressed;
    if (callback == null || isLoading) return;
    final result = callback();
    if (result is Future<void>) {
      // The owning page remains responsible for loading state and errors.
      // Awaiting here prevents an unhandled Future while preserving the
      // standard VoidCallback contract required by ElevatedButton.
      result.catchError((_) {});
    }
  }
}
