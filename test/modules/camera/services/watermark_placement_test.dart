import 'package:flutter_test/flutter_test.dart';
import 'package:kamloka/modules/camera/services/watermark_placement.dart';

void main() {
  group('WatermarkPlacement', () {
    const watermarkWidth = 320;
    const watermarkHeight = 100;

    test('centers watermark with bottom margin in portrait photo', () {
      const photoWidth = 3000;
      const photoHeight = 4000;
      final result = WatermarkPlacement.calculate(
        photoWidth: photoWidth,
        photoHeight: photoHeight,
        watermarkWidth: watermarkWidth,
        watermarkHeight: watermarkHeight,
      );

      expect(result.width, 1800);
      expect(result.height, 563);
      expect(result.left, 600);
      expect(result.top, 3297);
      expect(photoWidth - (result.left + result.width), result.left);
      expect(photoHeight - (result.top + result.height), 140);
    });

    test('centers watermark with bottom margin in landscape photo', () {
      const photoWidth = 4000;
      const photoHeight = 3000;
      final result = WatermarkPlacement.calculate(
        photoWidth: photoWidth,
        photoHeight: photoHeight,
        watermarkWidth: watermarkWidth,
        watermarkHeight: watermarkHeight,
      );

      expect(result.width, 2400);
      expect(result.height, 750);
      expect(result.left, 800);
      expect(result.top, 2145);
      expect(photoWidth - (result.left + result.width), result.left);
      expect(photoHeight - (result.top + result.height), 105);
    });

    test('uses the same geometry for front and rear camera dimensions', () {
      // Placement intentionally has no lens/orientation input. The same pixel
      // dimensions must always produce exactly the same placement.
      final first = WatermarkPlacement.calculate(
        photoWidth: 4000,
        photoHeight: 3000,
        watermarkWidth: watermarkWidth,
        watermarkHeight: watermarkHeight,
      );
      final second = WatermarkPlacement.calculate(
        photoWidth: 4000,
        photoHeight: 3000,
        watermarkWidth: watermarkWidth,
        watermarkHeight: watermarkHeight,
      );

      expect(second.left, first.left);
      expect(second.top, first.top);
      expect(second.width, first.width);
      expect(second.height, first.height);
    });

    test('rejects invalid image dimensions', () {
      expect(
        () => WatermarkPlacement.calculate(
          photoWidth: 0,
          photoHeight: 3000,
          watermarkWidth: watermarkWidth,
          watermarkHeight: watermarkHeight,
        ),
        throwsArgumentError,
      );
    });
  });
}
