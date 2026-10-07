import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';

class CaptureService {
  bool _isCapturing = false;

  Future<camera.XFile?> capture(camera.CameraController controller) async {
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

      return file;
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

  void dispose() {}
}
