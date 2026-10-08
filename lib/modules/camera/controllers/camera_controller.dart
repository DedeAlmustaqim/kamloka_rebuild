import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/capture_service.dart';
import '../services/device_orientation_service.dart';
import '../../location/services/location_service.dart';
import '../../gallery/services/gallery_service.dart';
import '../services/watermark_service.dart';

class CameraController extends GetxController {
  final isInitializing = true.obs;
  final isReady = false.obs;
  final isCapturing = false.obs;
  final isSwitchingCamera = false.obs;
  final errorMessage = ''.obs;
  final captureErrorMessage = ''.obs;
  final lastCapturePath = ''.obs;
  final isSaving = false.obs;
  final flashMode = camera.FlashMode.off.obs;
  final lensDirection = camera.CameraLensDirection.back.obs;
  final zoomLevel = 1.0.obs;
  final focusPoint = Rxn<Offset>();
  final exposureOffset = 0.0.obs;
  final isExposureExpanded = false.obs;
  final timerSeconds = 0.obs;
  final aspectRatio = CaptureAspectRatio.full.obs;
  final showGrid = false.obs;
  final countdown = 0.obs;
  Timer? _countdownTimer;
  double _minExposure = 0.0;
  double _maxExposure = 0.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  List<camera.CameraDescription> _cameras = const [];
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

      _cameras = cameras;

      final backCamera = cameras.firstWhere(
        (item) => item.lensDirection == camera.CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      lensDirection.value = backCamera.lensDirection;

      await _cameraController?.dispose();

      final controller = camera.CameraController(
        backCamera,
        camera.ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: camera.ImageFormatGroup.jpeg,
      );

      _cameraController = controller;

      await controller.initialize();
      await controller.setFlashMode(flashMode.value);
      await _loadZoomRange(controller);
      await _loadExposureRange(controller);

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

  Future<void> switchCamera() async {
    if (!isReady.value || isCapturing.value || _cameras.length < 2) return;

    final nextIndex = _cameras.indexWhere(
      (item) => item.lensDirection != lensDirection.value,
    );
    if (nextIndex < 0) return;

    isSwitchingCamera.value = true;
    isReady.value = false;

    try {
      final nextDescription = _cameras[nextIndex];
      final previousController = _cameraController;

      // Pastikan hanya satu controller kamera aktif saat switching.
      _cameraController = null;
      await previousController?.dispose();

      final nextController = camera.CameraController(
        nextDescription,
        camera.ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: camera.ImageFormatGroup.jpeg,
      );

      try {
        await nextController.initialize();

        // Kamera depan tidak diasumsikan memiliki flash.
        final nextFlash = nextDescription.lensDirection ==
                camera.CameraLensDirection.back
            ? flashMode.value
            : camera.FlashMode.off;

        try {
          await nextController.setFlashMode(nextFlash);
        } on camera.CameraException catch (error) {
          debugPrint(
            '[KAMLOKA FLASH] ${error.code}: ${error.description}',
          );
          await nextController.setFlashMode(camera.FlashMode.off);
        }

        _cameraController = nextController;
        lensDirection.value = nextDescription.lensDirection;

        if (nextDescription.lensDirection != camera.CameraLensDirection.back) {
          flashMode.value = camera.FlashMode.off;
        }

        focusPoint.value = null;
        await _loadZoomRange(nextController);
        await _loadExposureRange(nextController);
        isReady.value = true;
      } catch (_) {
        await nextController.dispose();
        rethrow;
      }
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Kamera tidak dapat diganti.';
      isReady.value = _cameraController?.value.isInitialized ?? false;
    } catch (error) {
      captureErrorMessage.value =
          error.toString().replaceFirst('Exception: ', '');
      isReady.value = _cameraController?.value.isInitialized ?? false;
    } finally {
      isSwitchingCamera.value = false;
    }
  }


  Future<void> _loadExposureRange(
    camera.CameraController controller,
  ) async {
    try {
      _minExposure = await controller.getMinExposureOffset();
      _maxExposure = await controller.getMaxExposureOffset();
      final initial = exposureOffset.value.clamp(
        _minExposure,
        _maxExposure,
      ).toDouble();
      await controller.setExposureOffset(initial);
      exposureOffset.value = initial;
    } on camera.CameraException catch (error) {
      debugPrint('[KAMLOKA EXPOSURE] ${error.code}: ${error.description}');
      _minExposure = 0.0;
      _maxExposure = 0.0;
      exposureOffset.value = 0.0;
    }
  }

  void toggleExposureControl() {
    if (_maxExposure <= _minExposure || isCapturing.value) return;
    isExposureExpanded.toggle();
  }

  Future<void> setExposure(double value) async {
    if (!isReady.value || isCapturing.value) return;

    final next = value.clamp(_minExposure, _maxExposure).toDouble();

    try {
      await cameraController.setExposureOffset(next);
      exposureOffset.value = next;
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Exposure tidak dapat diubah.';
    }
  }

  Future<void> setFocusAndExposure(Offset point) async {
    if (!isReady.value || isCapturing.value) return;

    final normalized = Offset(
      point.dx.clamp(0.0, 1.0),
      point.dy.clamp(0.0, 1.0),
    );

    try {
      await Future.wait([
        cameraController.setFocusPoint(normalized),
        cameraController.setExposurePoint(normalized),
      ]);
      focusPoint.value = normalized;
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Fokus tidak dapat diatur.';
    }
  }

  Future<void> resetFocus() async {
    if (!isReady.value) return;

    try {
      await Future.wait([
        cameraController.setFocusPoint(null),
        cameraController.setExposurePoint(null),
      ]);
      focusPoint.value = null;
    } on camera.CameraException catch (error) {
      debugPrint('[KAMLOKA FOCUS] ${error.code}: ${error.description}');
    }
  }

  Future<void> _loadZoomRange(camera.CameraController controller) async {
    try {
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      final initialZoom = zoomLevel.value.clamp(_minZoom, _maxZoom);
      await controller.setZoomLevel(initialZoom);
      zoomLevel.value = initialZoom;
    } on camera.CameraException catch (error) {
      debugPrint('[KAMLOKA ZOOM] ${error.code}: ${error.description}');
      _minZoom = 1.0;
      _maxZoom = 1.0;
      zoomLevel.value = 1.0;
    }
  }

  Future<void> setZoom(double value) async {
    if (!isReady.value || isCapturing.value) return;

    final nextZoom = value.clamp(_minZoom, _maxZoom).toDouble();
    if ((nextZoom - zoomLevel.value).abs() < 0.01) return;

    try {
      await cameraController.setZoomLevel(nextZoom);
      zoomLevel.value = nextZoom;
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Zoom tidak dapat diubah.';
    }
  }

  bool get isCountingDown => countdown.value > 0;

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get minExposure => _minExposure;
  double get maxExposure => _maxExposure;
  Future<void> cycleFlashMode() async {
    if (!isReady.value || isCapturing.value) return;

    final next = switch (flashMode.value) {
      camera.FlashMode.off => camera.FlashMode.auto,
      camera.FlashMode.auto => camera.FlashMode.always,
      camera.FlashMode.always => camera.FlashMode.off,
      camera.FlashMode.torch => camera.FlashMode.off,
    };

    try {
      await cameraController.setFlashMode(next);
      flashMode.value = next;
    } on camera.CameraException catch (error) {
      captureErrorMessage.value =
          error.description ?? 'Mode flash tidak dapat diubah.';
    }
  }

  Future<void> setTimer(int seconds) async {
    if (seconds != 0 && seconds != 3 && seconds != 5 && seconds != 10) {
      return;
    }
    if (isCapturing.value) return;
    timerSeconds.value = seconds;
  }

  void cycleTimer() {
    if (isCapturing.value || isCountingDown.value) return;
    timerSeconds.value = switch (timerSeconds.value) {
      0 => 3,
      3 => 5,
      5 => 10,
      _ => 0,
    };
  }

  void toggleGrid() {
    if (isCapturing.value) return;
    showGrid.toggle();
  }

  void cycleAspectRatio() {
    if (!isReady.value || isCapturing.value) return;
    aspectRatio.value = switch (aspectRatio.value) {
      CaptureAspectRatio.full => CaptureAspectRatio.ratio16x9,
      CaptureAspectRatio.ratio16x9 => CaptureAspectRatio.ratio4x3,
      CaptureAspectRatio.ratio4x3 => CaptureAspectRatio.square,
      CaptureAspectRatio.square => CaptureAspectRatio.full,
    };
  }

  String get aspectRatioLabel => switch (aspectRatio.value) {
    CaptureAspectRatio.full => 'FULL',
    CaptureAspectRatio.ratio16x9 => '16:9',
    CaptureAspectRatio.ratio4x3 => '4:3',
    CaptureAspectRatio.square => '1:1',
  };

  Future<void> _runCountdown() async {
    final seconds = timerSeconds.value;
    if (seconds <= 0) return;

    countdown.value = seconds;
    _countdownTimer?.cancel();

    final completer = Completer<void>();
    var remaining = seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      countdown.value = remaining;

      if (remaining <= 0) {
        timer.cancel();
        _countdownTimer = null;
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future;
  }

  Future<String?> capturePhoto() async {
    if (!isReady.value || isCapturing.value) {
      return null;
    }

    captureErrorMessage.value = '';
    isCapturing.value = true;

    try {
      await _runCountdown();
      final physicalOrientation =
          Get.find<DeviceOrientationService>().orientation.value;

      final file = await _captureService.capture(
        cameraController,
        physicalOrientation: physicalOrientation,
        aspectRatio: aspectRatio.value,
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
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cameraController?.dispose();
    _cameraController = null;
    _captureService.dispose();
    _watermarkService.dispose();
    super.onClose();
  }
}
