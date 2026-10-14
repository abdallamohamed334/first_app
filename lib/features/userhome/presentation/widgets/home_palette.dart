import 'package:flutter/material.dart';
import 'package:loqma/core/theme/theme_notifier.dart';

/// Shared colors for presentation-only widgets used by the user home.
abstract final class HomePalette {
  static bool get isDark => ThemeNotifier.isDarkMode.value;
  static Color get bg => isDark ? const Color(0xFF202124) : const Color(0xFFF7F8FA);
  static Color get card => isDark ? const Color(0xFF2A2C30) : Colors.white;
  static Color get cardSoft => isDark ? const Color(0xFF303238) : const Color(0xFFEEF1F5);
  static Color get primaryRed => const Color(0xFFFF2E3B);
  static Color get primaryRedDark => const Color(0xFFD8202C);
  static Color get textPrimary => isDark ? const Color(0xFFF7F7F8) : const Color(0xFF1B1D22);
  static Color get textSecondary => isDark ? const Color(0xFFB8B9BE) : const Color(0xFF68707C);
  static Color get border => isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E6EC);
}
