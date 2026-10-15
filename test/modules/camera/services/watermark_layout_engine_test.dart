import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kamloka/modules/camera/services/watermark_layout_engine.dart';

void main() {
  const engine = WatermarkLayoutEngine();
  const bodyStyle = TextStyle(fontSize: 18, height: 1.2);
  const timeStyle = TextStyle(fontSize: 42, height: 1.0);

  group('WatermarkLayoutEngine', () {
    test('keeps landscape panel inside image bounds', () {
      final layout = engine.calculate(
        imageSize: const Size(4000, 3000),
        address: 'Jalan Baruh Rintis, Tamiang Layang, Barito Timur',
        bodyStyle: bodyStyle,
        timeStyle: timeStyle,
        textDirection: TextDirection.ltr,
      );

      expect(layout.isLandscape, isTrue);
      expect(layout.panelRect.left, greaterThanOrEqualTo(0));
      expect(layout.panelRect.right, lessThanOrEqualTo(4000));
      expect(layout.panelRect.bottom, lessThanOrEqualTo(3000));
      expect(layout.logoRect.right, lessThanOrEqualTo(layout.panelRect.right));
      expect(layout.logoRect.bottom, lessThan(layout.panelRect.top));
    });

    test('measures long addresses and wraps to multiple lines', () {
      final layout = engine.calculate(
        imageSize: const Size(4000, 3000),
        address: 'Jalan Baruh Rintis, Tamiang Layang, Barito Timur, Kalimantan Tengah, Indonesia, dekat kantor pemerintahan daerah',
        bodyStyle: bodyStyle,
        timeStyle: timeStyle,
        textDirection: TextDirection.ltr,
      );

      expect(layout.addressLineCount, greaterThan(1));
      expect(layout.addressHeight, greaterThan(layout.bodyLineHeight));
    });

    test('uses a single content column for portrait images', () {
      final layout = engine.calculate(
        imageSize: const Size(3000, 4000),
        address: 'Tamiang Layang, Barito Timur',
        bodyStyle: bodyStyle,
        timeStyle: timeStyle,
        textDirection: TextDirection.ltr,
      );

      expect(layout.isLandscape, isFalse);
      expect(layout.isWideLandscape, isFalse);
      expect(layout.dividerX, isNull);
      expect(layout.rightContentRect.left, greaterThan(layout.panelRect.left));
    });

    test('rejects invalid image dimensions', () {
      expect(
        () => engine.calculate(
          imageSize: Size.zero,
          address: 'Tamiang Layang',
          bodyStyle: bodyStyle,
          timeStyle: timeStyle,
          textDirection: TextDirection.ltr,
        ),
        throwsArgumentError,
      );
    });
  });
}
