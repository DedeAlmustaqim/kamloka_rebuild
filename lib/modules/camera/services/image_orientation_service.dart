import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:native_device_orientation/native_device_orientation.dart';

class ImageOrientationService {
  Future<camera.XFile> normalize(
    camera.XFile source, {
    required NativeDeviceOrientation physicalOrientation,
  }) async {
    final inputPath = source.path;
    final inputFile = File(inputPath);
    final bytes = await inputFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw const FormatException('Format foto tidak dapat diproses.');
    }

    // The app UI is portrait-locked, so EXIF/display orientation cannot be
    // trusted for landscape captures. Physical sensor orientation is the
    // source of truth for the captured pixels.
    final normalized = _rotateForPhysicalOrientation(
      decoded,
      physicalOrientation,
    );
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

  img.Image _rotateForPhysicalOrientation(
    img.Image image,
    NativeDeviceOrientation orientation,
  ) {
    switch (orientation) {
      case NativeDeviceOrientation.landscapeLeft:
        return img.copyRotate(image, angle: -90);
      case NativeDeviceOrientation.landscapeRight:
        return img.copyRotate(image, angle: 90);
      case NativeDeviceOrientation.portraitDown:
        return img.copyRotate(image, angle: 180);
      case NativeDeviceOrientation.portraitUp:
      case NativeDeviceOrientation.unknown:
        return image;
    }
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