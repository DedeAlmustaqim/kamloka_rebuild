import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared visual system for KAMLOKA Pro's field-documentation workflow.
/// The camera itself deliberately keeps its immersive dark presentation.
abstract final class ProTheme {
  static const Color background = Color(0xFFF5F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  /// Brand color for primary actions and interactive states.
  static const Color brandGreen = Color(0xFF0C5A3E);
  /// Gold is reserved for KAMLOKA Pro highlights and premium states.
  static const Color primary = Color(0xFFE4B957);
  static const Color primaryDark = Color(0xFF6A5200);
  static const Color text = Color(0xFF202522);
  static const Color secondaryText = Color(0xFF68716B);
  static const Color border = Color(0xFFE2E6E0);
  static const Color green = Color(0xFF23764A);
  static const Color danger = Color(0xFFB3261E);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.light,
      surface: surface,
      primary: brandGreen,
      onPrimary: Colors.white,
      secondary: primary,
      onSecondary: const Color(0xFF292B25),
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFBF8),
        labelStyle: const TextStyle(color: secondaryText),
        hintStyle: const TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E6E1),
          disabledForegroundColor: secondaryText,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F1EC),
        selectedColor: const Color(0xFFFFE69A),
        labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w600),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: text,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static Widget apply(Widget child) {
    return Theme(
      data: light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child,
      ),
    );
  }
}
