import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Editorial page introduction shared by primary KAMLOKA screens.
class EditorialPageHeader extends StatelessWidget {
  const EditorialPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
    this.titleStyle,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(title, style: titleStyle ?? AppTypography.headline),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(description!, style: AppTypography.supporting),
        ],
      ],
    );

    if (trailing == null) return heading;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.md),
        trailing!,
      ],
    );
  }
}
