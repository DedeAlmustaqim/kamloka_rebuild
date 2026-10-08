import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'image_orientation_service.dart';

/// Output aspect ratio applied after physical orientation normalization.
enum CaptureAspectRatio {
  full,
  ratio16x9,
  ratio4x3,
  square,
}

class CaptureService {
  bool _isCapturing = false;
  final ImageOrientationService _orientationService =
      ImageOrientationService();

  Future<camera.XFile?> capture(
    camera.CameraController controller, {
    required NativeDeviceOrientation physicalOrientation,
    CaptureAspectRatio aspectRatio = CaptureAspectRatio.full,
  }) async {
    if (_isCapturing || !controller.value.isInitialized) {
      return null;
    }

    if (controller.value.isTakingPicture) {
      return null;
    }

    _isCapturing = true;

    try {
      final file = await controller.takePicture();

      debugPrint(
        '[KAMLOKA CAPTURE] captured: ${file.path}',
      );

      final normalizedFile =
          await _orientationService.normalize(
        file,
        physicalOrientation: physicalOrientation,
      );

      debugPrint(
        '[KAMLOKA CAPTURE] normalized: ${normalizedFile.path}',
      );

      return _cropToAspectRatio(normalizedFile, aspectRatio);
    } on camera.CameraException catch (error, stack) {
      debugPrint(
        '[KAMLOKA CAPTURE] ${error.code}: ${error.description}',
      );
      debugPrintStack(stackTrace: stack);
      rethrow;
    } catch (error, stack) {
      debugPrint('[KAMLOKA CAPTURE] $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    } finally {
      _isCapturing = false;
    }
  }

  Future<camera.XFile> _cropToAspectRatio(
    camera.XFile source,
    CaptureAspectRatio aspectRatio,
  ) async {
    if (aspectRatio == CaptureAspectRatio.full) return source;

    final bytes = await File(source.path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Foto tidak dapat diproses untuk aspect ratio.');
    }

    final landscapeRatio = switch (aspectRatio) {
      CaptureAspectRatio.full => image.width / image.height,
      CaptureAspectRatio.ratio16x9 => 16 / 9,
      CaptureAspectRatio.ratio4x3 => 4 / 3,
      CaptureAspectRatio.square => 1.0,
    };

    final targetRatio =
        image.width >= image.height ? landscapeRatio : 1 / landscapeRatio;
    final sourceRatio = image.width / image.height;

    var cropWidth = image.width;
    var cropHeight = image.height;

    if (sourceRatio > targetRatio) {
      cropWidth = (image.height * targetRatio).round();
    } else if (sourceRatio < targetRatio) {
      cropHeight = (image.width / targetRatio).round();
    }

    cropWidth = cropWidth.clamp(1, image.width).toInt();
    cropHeight = cropHeight.clamp(1, image.height).toInt();

    final x = ((image.width - cropWidth) / 2).round();
    final y = ((image.height - cropHeight) / 2).round();

    final cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );

    final separator = Platform.pathSeparator;
    final name = source.path.split(separator).last;
    final base = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final directory = source.path.substring(0, source.path.length - name.length);
    final outputPath = '$directory${base}_aspect.jpg';

    await File(outputPath).writeAsBytes(
      img.encodeJpg(cropped, quality: 100),
      flush: true,
    );

    debugPrint(
      '[KAMLOKA ASPECT] ${image.width}x${image.height} -> ${cropped.width}x${cropped.height}',
    );

    return camera.XFile(outputPath);
  }

  void dispose() {
    _orientationService.dispose();
  }
}
