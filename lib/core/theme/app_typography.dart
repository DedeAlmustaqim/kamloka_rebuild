import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for editorial hierarchy and readable field documentation.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 32,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );
  static const TextStyle headline = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 27,
    height: 1.16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.45,
  );
  static const TextStyle title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    height: 1.45,
  );
  static const TextStyle supporting = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.45,
  );
  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.35,
  );
}
