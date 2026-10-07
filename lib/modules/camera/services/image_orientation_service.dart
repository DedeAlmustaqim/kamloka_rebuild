import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageOrientationService {
  Future<camera.XFile> normalize(camera.XFile source) async {
    final inputPath = source.path;
    final inputFile = File(inputPath);
    final bytes = await inputFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw const FormatException('Format foto tidak dapat diproses.');
    }

    // Bake the orientation into the pixels. No resize is performed.
    final normalized = img.bakeOrientation(decoded);
    final outputPath = _outputPath(inputPath);
    final outputBytes = img.encodeJpg(normalized, quality: 100);

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes, flush: true);

    debugPrint(
      '[KAMLOKA ORIENTATION] ${decoded.width}x${decoded.height} -> '
      '${normalized.width}x${normalized.height}',
    );

    return camera.XFile(outputFile.path);
  }

  String _outputPath(String inputPath) {
    final separator = Platform.pathSeparator;
    final name = inputPath.split(separator).last;
    final baseName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final directory = inputPath.substring(0, inputPath.length - name.length);
    return '$directory${baseName}_normalized.jpg';
  }

  void dispose() {}
}