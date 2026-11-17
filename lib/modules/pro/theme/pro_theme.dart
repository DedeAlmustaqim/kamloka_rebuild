import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Backward-compatible aliases for existing Pro screens.
/// The canonical design tokens and ThemeData live in core/theme.
abstract final class ProTheme {
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color brandGreen = AppColors.brand;
  static const Color primary = AppColors.premium;
  static const Color primaryDark = AppColors.premiumDark;
  static const Color text = AppColors.textPrimary;
  static const Color secondaryText = AppColors.textSecondary;
  static const Color border = AppColors.border;
  static const Color green = AppColors.success;
  static const Color danger = AppColors.danger;

  static ThemeData get light => AppTheme.light;

  /// Kept for existing screens that intentionally scope system-bar styling.
  static Widget apply(Widget child) {
    return Theme(
      data: AppTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child,
      ),
    );
  }
}
