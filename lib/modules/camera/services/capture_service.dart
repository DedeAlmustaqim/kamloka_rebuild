import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'image_orientation_service.dart';

class CaptureService {
  bool _isCapturing = false;
  final ImageOrientationService _orientationService =
      ImageOrientationService();

  Future<camera.XFile?> capture(
    camera.CameraController controller, {
    required NativeDeviceOrientation physicalOrientation,
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

      return normalizedFile;
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

  void dispose() {
    _orientationService.dispose();
  }
}
