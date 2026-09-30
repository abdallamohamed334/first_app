import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'IBM Plex Sans Arabic';

  static const Color _lightBackground = Color(0xFFF8F8F7);
  static const Color _lightText = Color(0xFF111111);
  static const Color _darkBackground = Color(0xFF101010);
  static const Color _darkText = Color(0xFFFFFFFF);
  static const Color _black = Color(0xFF111111);
  static const Color _white = Color(0xFFFFFFFF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _black,
      brightness: Brightness.light,
    ).copyWith(
      primary: _black,
      onPrimary: Colors.white,
      secondary: const Color(0xFF333333),
      onSecondary: Colors.white,
      tertiary: _black,
      onTertiary: Colors.white,
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: _lightBackground,
      onSurface: _lightText,
      outline: const Color(0xFF666666),
      outlineVariant: const Color(0xFFD0D0D0),
    );

    return _baseTheme(
      scheme: scheme,
      brightness: Brightness.light,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _white,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _white,
      onPrimary: _black,
      secondary: const Color(0xFFDDDDDD),
      onSecondary: _black,
      tertiary: _white,
      onTertiary: _black,
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      surface: _darkBackground,
      onSurface: _darkText,
      outline: const Color(0xFFAAAAAA),
      outlineVariant: const Color(0xFF444444),
    );

    return _baseTheme(
      scheme: scheme,
      brightness: Brightness.dark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Brightness brightness,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final inputFill =
        isDark ? scheme.surfaceContainerHighest : const Color(0xFFF0F0EE);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error, width: 2),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.outline),
        errorStyle: TextStyle(color: scheme.error),
      ),
      textTheme: _textTheme(scheme),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displayLarge: _text(57, FontWeight.w700, scheme.onSurface, 1.12, -0.25),
      displayMedium: _text(45, FontWeight.w600, scheme.onSurface, 1.16),
      displaySmall: _text(36, FontWeight.w600, scheme.onSurface, 1.22),
      headlineLarge: _text(32, FontWeight.w600, scheme.onSurface, 1.25),
      headlineMedium: _text(28, FontWeight.w600, scheme.onSurface, 1.29),
      headlineSmall: _text(24, FontWeight.w600, scheme.onSurface, 1.33),
      titleLarge: _text(22, FontWeight.w500, scheme.onSurface, 1.27),
      titleMedium: _text(16, FontWeight.w500, scheme.onSurface, 1.5),
      titleSmall: _text(14, FontWeight.w500, scheme.onSurface, 1.43),
      bodyLarge: _text(16, FontWeight.w400, scheme.onSurface, 1.5),
      bodyMedium: _text(14, FontWeight.w400, scheme.onSurface, 1.43),
      bodySmall: _text(12, FontWeight.w400, scheme.onSurface, 1.33),
      labelLarge: _text(14, FontWeight.w500, scheme.onSurface, 1.43, 0.1),
      labelMedium: _text(12, FontWeight.w500, scheme.onSurface, 1.33, 0.5),
      labelSmall: _text(11, FontWeight.w500, scheme.onSurface, 1.45, 0.5),
    );
  }

  static TextStyle _text(
    double size,
    FontWeight weight,
    Color color,
    double height, [
    double letterSpacing = 0,
  ]) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
