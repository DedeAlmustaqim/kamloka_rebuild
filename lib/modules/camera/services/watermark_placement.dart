/// Pure geometry for placing a watermark consistently on captured photos.
/// Coordinates are calculated from the decoded pixel dimensions, not the
/// device orientation or camera lens.
class WatermarkPlacement {
  const WatermarkPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  factory WatermarkPlacement.calculate({
    required int photoWidth,
    required int photoHeight,
    required int watermarkWidth,
    required int watermarkHeight,
    double widthRatio = 0.60,
    double bottomMarginRatio = 0.035,
  }) {
    if (photoWidth <= 0 || photoHeight <= 0 ||
        watermarkWidth <= 0 || watermarkHeight <= 0) {
      throw ArgumentError('Image dimensions must be greater than zero.');
    }
    if (widthRatio <= 0 || widthRatio > 1 ||
        bottomMarginRatio < 0 || bottomMarginRatio >= 1) {
      throw ArgumentError('Watermark ratios are outside valid bounds.');
    }

    final width = (photoWidth * widthRatio).round();
    final height = (watermarkHeight * width / watermarkWidth).round();
    final left = ((photoWidth - width) / 2).round();
    final bottomMargin = (photoHeight * bottomMarginRatio).round();
    final top = photoHeight - height - bottomMargin;

    return WatermarkPlacement(
      left: left < 0 ? 0 : left,
      top: top < 0 ? 0 : top,
      width: width,
      height: height,
    );
  }
}
