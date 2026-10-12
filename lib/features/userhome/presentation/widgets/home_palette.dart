import 'package:flutter/material.dart';
import 'package:loqma/core/theme/theme_notifier.dart';

/// Shared colors for presentation-only widgets used by the user home.
abstract final class HomePalette {
  static bool get isDark => ThemeNotifier.isDarkMode.value;
  static Color get bg => const Color(0xFF202124);
  static Color get card => const Color(0xFF2A2C30);
  static Color get cardSoft => const Color(0xFF303238);
  static Color get primaryRed => const Color(0xFFFF2E3B);
  static Color get primaryRedDark => const Color(0xFFD8202C);
  static Color get textPrimary => const Color(0xFFF7F7F8);
  static Color get textSecondary => const Color(0xFFB8B9BE);
  static Color get border => const Color(0x22FFFFFF);
}
