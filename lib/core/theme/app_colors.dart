import 'package:flutter/material.dart';

/// Canonical color tokens for the KAMLOKA editorial utility design system.
abstract final class AppColors {
  static const Color background = Color(0xFFF5F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFFAFBF8);

  static const Color brand = Color(0xFF0C5A3E);
  static const Color brandDark = Color(0xFF084B35);
  static const Color brandSoft = Color(0xFFE5F1EB);

  /// Reserved for premium status and Pro-specific emphasis.
  static const Color premium = Color(0xFFE4B957);
  static const Color premiumDark = Color(0xFF6A5200);

  static const Color textPrimary = Color(0xFF202522);
  static const Color textSecondary = Color(0xFF68716B);
  static const Color border = Color(0xFFE2E6E0);
  static const Color success = Color(0xFF23764A);
  static const Color danger = Color(0xFFB3261E);
  static const Color disabled = Color(0xFFE5E6E1);
}
