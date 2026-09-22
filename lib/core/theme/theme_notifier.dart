import 'package:flutter/foundation.dart';

class ThemeNotifier {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);
}

// ✅ متغير عام للاستخدام المباشر
final themeNotifier = ThemeNotifier.isDarkMode;
