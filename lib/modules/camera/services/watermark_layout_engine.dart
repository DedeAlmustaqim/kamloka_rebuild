import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Computes a watermark composition from the final bitmap dimensions.
///
/// This class is deliberately independent from the image encoder. Preview and
/// bitmap rendering can consume the same geometry so spacing decisions are
/// made once instead of being duplicated across renderers.
class WatermarkLayoutEngine {
  const WatermarkLayoutEngine();

  WatermarkLayout calculate({
    required Size imageSize,
    required String address,
    required TextStyle bodyStyle,
    required TextStyle timeStyle,
    required TextDirection textDirection,
    bool hasBranding = true,
  }) {
    final width = imageSize.width;
    final height = imageSize.height;
    if (width <= 0 || height <= 0) {
      throw ArgumentError.value(imageSize, 'imageSize', 'Must be positive.');
    }

    // Watermark panel occupies 75% of the photo width and is centered.
    // Keep its content geometry relative to the panel rather than the full image.
    final shortSide = math.min(width, height);
    final isLandscape = width >= height;
    final contentWidth = width * 0.75;
    final margin = (width - contentWidth) / 2;
    final padding = shortSide * 0.018;
    final gap = shortSide * 0.012;
    final leftWidth = isLandscape ? contentWidth * 0.30 : contentWidth;
    final rightWidth = isLandscape ? contentWidth - leftWidth - gap : contentWidth;

    final addressPainter = TextPainter(
      text: TextSpan(
        text: address.trim().isEmpty ? 'Alamat tidak tersedia' : address.trim(),
        style: bodyStyle,
      ),
      textDirection: textDirection,
    )..layout(maxWidth: math.max(1.0, rightWidth - padding * 2));

    final bodyHeight = _lineHeight(bodyStyle);
    final timeHeight = _lineHeight(timeStyle);
    final addressHeight = math.max(bodyHeight, addressPainter.height);
    final sectionGap = shortSide * 0.009;
    final logoHeight = hasBranding ? shortSide * 0.052 : 0.0;
    final detailsHeight = bodyHeight * 2;
    final leftHeight = timeHeight + bodyHeight * 2 + sectionGap * 2;
    // Reserve vertical room for the logo inside the panel, not above it.
    final rightHeight = addressHeight +
        detailsHeight +
        sectionGap * 2 +
        (hasBranding ? logoHeight + sectionGap : 0.0);
    final panelHeight = math.max(leftHeight, rightHeight) + padding * 2;
    final bottomMargin = shortSide * 0.02;
    final panelRect = Rect.fromLTWH(
      margin,
      height - bottomMargin - panelHeight,
      contentWidth,
      panelHeight,
    );

    final contentTop = panelRect.top + padding;
    final contentHeight = panelRect.height - padding * 2;
    final leftRect = Rect.fromLTWH(
      panelRect.left + padding,
      contentTop,
      math.max(1.0, leftWidth - padding),
      contentHeight,
    );
    final rightLeft = isLandscape
        ? panelRect.left + leftWidth + gap
        : panelRect.left + padding;
    final rightRect = Rect.fromLTWH(
      rightLeft,
      contentTop,
      math.max(
        1.0,
        isLandscape
            ? panelRect.right - padding - rightLeft
            : panelRect.width - padding * 2,
      ),
      contentHeight,
    );

    final logoWidth = math.min(rightWidth * 0.48, logoHeight * 4.2);
    final logoRect = hasBranding
        ? Rect.fromLTWH(
            panelRect.right - padding - logoWidth,
            panelRect.top + padding,
            logoWidth,
            logoHeight,
          )
        : Rect.zero;

    return WatermarkLayout(
      imageSize: imageSize,
      isLandscape: isLandscape,
      isWideLandscape: isLandscape,
      panelRect: panelRect,
      leftContentRect: leftRect,
      rightContentRect: rightRect,
      dividerX: isLandscape ? panelRect.left + leftWidth + gap / 2 : null,
      logoRect: logoRect,
      addressHeight: addressHeight,
      bodyLineHeight: bodyHeight,
      timeLineHeight: timeHeight,
      sectionGap: sectionGap,
      addressLineCount: addressPainter.computeLineMetrics().length,
      timeFitsLeftColumn: true,
    );
  }

  double _lineHeight(TextStyle style) {
    final fontSize = style.fontSize ?? 14;
    final height = style.height ?? 1.2;
    return fontSize * height;
  }
}

class WatermarkLayout {
  const WatermarkLayout({
    required this.imageSize,
    required this.isLandscape,
    required this.isWideLandscape,
    required this.panelRect,
    required this.leftContentRect,
    required this.rightContentRect,
    required this.dividerX,
    required this.logoRect,
    required this.addressHeight,
    required this.bodyLineHeight,
    required this.timeLineHeight,
    required this.sectionGap,
    required this.addressLineCount,
    required this.timeFitsLeftColumn,
  });

  final Size imageSize;
  final bool isLandscape;
  final bool isWideLandscape;
  final Rect panelRect;
  final Rect leftContentRect;
  final Rect rightContentRect;
  final double? dividerX;
  final Rect logoRect;
  final double addressHeight;
  final double bodyLineHeight;
  final double timeLineHeight;
  final double sectionGap;
  final int addressLineCount;
  final bool timeFitsLeftColumn;
}
