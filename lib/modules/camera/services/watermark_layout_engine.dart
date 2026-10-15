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

    final shortSide = math.min(width, height);
    final isLandscape = width >= height;
    final outerMargin = isLandscape
        ? (width * 0.075).clamp(36.0, 220.0).toDouble()
        : (shortSide * 0.035).clamp(12.0, 100.0).toDouble();
    final contentWidth = width - (outerMargin * 2);
    final isWideLandscape = true; // Dua kolom dipertahankan pada portrait dan landscape.

    // Keep the composition proportional to the final bitmap, not screen size.
    final panelPadding = (shortSide * 0.028).clamp(10.0, 52.0).toDouble();
    final columnGap = (contentWidth * 0.045).clamp(12.0, 80.0).toDouble();
    final leftColumnWidth = isWideLandscape
        ? (contentWidth * 0.30).clamp(shortSide * 0.25, contentWidth * 0.38).toDouble()
        : contentWidth;
    final rightColumnWidth = isWideLandscape
        ? contentWidth - leftColumnWidth - columnGap
        : contentWidth;

    final addressPainter = TextPainter(
      text: TextSpan(text: address.trim().isEmpty ? 'Alamat tidak tersedia' : address.trim(), style: bodyStyle),
      textDirection: textDirection,
      textAlign: TextAlign.start,
    )..layout(maxWidth: rightColumnWidth - (panelPadding * 2));

    final timePainter = TextPainter(
      text: TextSpan(text: '00:00', style: timeStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: leftColumnWidth - (panelPadding * 2));

    final bodyLineHeight = _lineHeight(bodyStyle);
    final timeLineHeight = _lineHeight(timeStyle);
    final addressHeight = math.max(bodyLineHeight, addressPainter.height);
    final detailsRows = 2;
    final detailHeight = bodyLineHeight * detailsRows;
    final sectionGap = (shortSide * 0.018).clamp(6.0, 28.0).toDouble();
    final logoHeight = hasBranding
        ? (shortSide * 0.052).clamp(22.0, 84.0).toDouble()
        : 0.0;
    final rightInfoHeight = (hasBranding ? logoHeight + sectionGap * 0.5 : 0) +
        addressHeight +
        detailHeight +
        sectionGap * 2;
    final contentHeight = math.max(
      timeLineHeight + bodyLineHeight * 2 + sectionGap * 2,
      rightInfoHeight,
    );
    final panelHeight = contentHeight + panelPadding * 2;
    final bottomMargin = (shortSide * 0.025).clamp(12.0, 36.0).toDouble();
    final panelRect = Rect.fromLTWH(
      outerMargin,
      height - bottomMargin - panelHeight,
      contentWidth,
      panelHeight,
    );

    final leftRect = Rect.fromLTWH(
      panelRect.left + panelPadding,
      panelRect.top + panelPadding,
      leftColumnWidth - panelPadding,
      panelRect.height - panelPadding * 2,
    );
    final dividerX = isWideLandscape
        ? panelRect.left + leftColumnWidth
        : null;
    final rightRect = Rect.fromLTWH(
      panelRect.left + leftColumnWidth + columnGap,
      panelRect.top + panelPadding,
      rightColumnWidth - panelPadding,
      panelRect.height - panelPadding * 2,
    );

    final logoWidth = math.min(rightColumnWidth * 0.48, logoHeight * 4.2);
    final logoRect = hasBranding
        ? Rect.fromLTWH(
            panelRect.right - panelPadding - logoWidth,
            panelRect.top + panelPadding,
            logoWidth,
            logoHeight,
          )
        : Rect.zero;

    return WatermarkLayout(
      imageSize: imageSize,
      isLandscape: isLandscape,
      isWideLandscape: isWideLandscape,
      panelRect: panelRect,
      leftContentRect: leftRect,
      rightContentRect: rightRect,
      dividerX: dividerX,
      logoRect: logoRect,
      addressHeight: addressHeight,
      bodyLineHeight: bodyLineHeight,
      timeLineHeight: timeLineHeight,
      sectionGap: sectionGap,
      addressLineCount: addressPainter.computeLineMetrics().length,
      timeFitsLeftColumn: timePainter.didExceedMaxLines == false,
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
