import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Consistent section title with an optional editorial index and supporting text.
class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({
    super.key,
    required this.title,
    this.index,
    this.description,
    this.trailing,
  });

  final String title;
  final String? index;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (index != null) ...[
              Text(
                index!,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(title, style: AppTypography.sectionTitle),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(description!, style: AppTypography.caption),
        ],
      ],
    );

    if (trailing == null) return content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: content),
        const SizedBox(width: AppSpacing.sm),
        trailing!,
      ],
    );
  }
}
