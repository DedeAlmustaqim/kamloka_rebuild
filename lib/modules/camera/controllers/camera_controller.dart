import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraController extends GetxController {
  final isInitializing = true.obs;
  final isReady = false.obs;
  final errorMessage = ''.obs;
  CameraController? _cameraController;
  CameraController get cameraController => _cameraController!;

  @override
  void onInit() { super.onInit(); initialize(); }

  Future<void> initialize() async {
    isInitializing.value = true;
    isReady.value = false;
    errorMessage.value = '';
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw Exception(permission.isPermanentlyDenied ? 'Izin kamera ditolak permanen.' : 'Izin kamera diperlukan untuk menggunakan KAMLOKA.');
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Tidak ada kamera yang tersedia pada perangkat.');
      final backCamera = cameras.firstWhere((item) => item.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      await _cameraController?.dispose();
      final controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      _cameraController = controller;
      await controller.initialize();
      isReady.value = true;
    } on CameraException catch (error, stack) {
      debugPrint('[KAMLOKA CAMERA] ${error.code}: ${error.description}');
      debugPrintStack(stackTrace: stack);
      errorMessage.value = error.description ?? error.code;
    } catch (error, stack) {
      debugPrint('[KAMLOKA CAMERA] $error');
      debugPrintStack(stackTrace: stack);
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally { isInitializing.value = false; }
  }

  Future<void> retry() => initialize();

  @override
  void onClose() { _cameraController?.dispose(); _cameraController = null; super.onClose(); }
}
