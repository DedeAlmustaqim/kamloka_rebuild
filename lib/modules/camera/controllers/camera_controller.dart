import 'dart:async';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/capture_service.dart';
import '../services/device_orientation_service.dart';
import '../../location/services/location_service.dart';
import '../../gallery/services/gallery_service.dart';
import '../services/watermark_service.dart';
import '../../gallery/services/gallery_service.dart';

class CameraController extends GetxController {
  final isInitializing = true.obs;
  final isReady = false.obs;
  final isCapturing = false.obs;
  final errorMessage = ''.obs;
  final captureErrorMessage = ''.obs;
  final lastCapturePath = ''.obs;
  final isSaving = false.obs;

  camera.CameraController? _cameraController;
  final CaptureService _captureService = CaptureService();
  final WatermarkService _watermarkService = WatermarkService();
  final GalleryService _galleryService = GalleryService();

  camera.CameraController get cameraController => _cameraController!;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  Future<void> initialize() async {
    isInitializing.value = true;
    isReady.value = false;
    errorMessage.value = '';

    try {
      await Get.find<DeviceOrientationService>().init();

      final permission = await Permission.camera.request();

      if (!permission.isGranted) {
        throw Exception(
          permission.isPermanentlyDenied
              ? 'Izin kamera ditolak permanen.'
              : 'Izin kamera diperlukan untuk menggunakan KAMLOKA.',
        );
      }

      final cameras = await camera.availableCameras();

      if (cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia pada perangkat.');
      }

      final backCamera = cameras.firstWhere(
        (item) => item.lensDirection == camera.CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      await _cameraController?.dispose();

      final controller = camera.CameraController(
        backCamera,
        camera.ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: camera.ImageFormatGroup.jpeg,
      );

      _cameraController = controller;

      await controller.initialize();

      isReady.value = true;

      unawaited(Get.find<LocationService>().init());
    } on camera.CameraException catch (error, stack) {
      debugPrint(
        '[KAMLOKA CAMERA] ${error.code}: ${error.description}',
      );
      debugPrintStack(stackTrace: stack);
      errorMessage.value = error.description ?? error.code;
    } catch (error, stack) {
      debugPrint('[KAMLOKA CAMERA] $error');
      debugPrintStack(stackTrace: stack);
      errorMessage.value =
          error.toString().replaceFirst('Exception: ', '');
    } finally {
      isInitializing.value = false;
    }
  }

  Future<String?> capturePhoto() async {
    if (!isReady.value || isCapturing.value) {
      return null;
    }

    captureErrorMessage.value = '';
    isCapturing.value = true;

    try {
      final physicalOrientation =
          Get.find<DeviceOrientationService>().orientation.value;

      final file = await _captureService.capture(
        cameraController,
        physicalOrientation: physicalOrientation,
      );

      if (file == null) {
        return null;
      }

      final location = Get.find<LocationService>();
      final position = location.position.value;

      final watermarked = await _watermarkService.apply(
        file,
        data: WatermarkData(
          dateTime: DateTime.now(),
          address: location.address.value,
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          altitude: position?.altitude,
        ),
      );

      lastCapturePath.value = watermarked.path;

      isSaving.value = true;
      try {
        await _galleryService.saveImage(watermarked.path);
      } finally {
        isSaving.value = false;
      }

      return watermarked.path;
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Gagal mengambil foto.';
      return null;
    } catch (error) {
      captureErrorMessage.value =
          error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isCapturing.value = false;
    }
  }

  void clearCapture() {
    lastCapturePath.value = '';
    captureErrorMessage.value = '';
  }

  Future<void> retry() => initialize();

  @override
  void onClose() {
    _cameraController?.dispose();
    _cameraController = null;
    _captureService.dispose();
    _watermarkService.dispose();
    super.onClose();
  }
}
