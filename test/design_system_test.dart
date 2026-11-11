import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/modules/pro/theme/pro_theme.dart';

void main() {
  group('KAMLOKA editorial design system', () {
    test('uses a neutral monochrome foundation', () {
      expect(ProTheme.background, const Color(0xFFF4F4F2));
      expect(ProTheme.surface, Colors.white);
      expect(ProTheme.brandGreen, const Color(0xFF171717));
      expect(ProTheme.text, const Color(0xFF171717));
      expect(ProTheme.secondaryText, const Color(0xFF737373));
      expect(ProTheme.border, const Color(0xFFE4E4E4));
    });

    test('exposes a Material 3 light theme', () {
      expect(ProTheme.light.useMaterial3, isTrue);
      expect(ProTheme.light.brightness, Brightness.light);
      expect(ProTheme.light.scaffoldBackgroundColor, ProTheme.background);
    });
  });
}
