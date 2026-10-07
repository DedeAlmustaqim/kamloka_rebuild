import 'dart:io';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import 'photo_preview_view.dart';
import '../services/device_orientation_service.dart';
import '../../location/services/location_service.dart';

class CameraView extends GetView<CameraController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final orientationService = Get.find<DeviceOrientationService>();
    final locationService = Get.find<LocationService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isInitializing.value) {
          return const _LoadingView();
        }

        if (!controller.isReady.value) {
          return _ErrorView(
            message: controller.errorMessage.value,
            onRetry: controller.retry,
          );
        }

        return _CameraPreview(
          controller: controller.cameraController,
          isLandscape: orientationService.isLandscape,
          locationService: locationService,
        );
      }),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.controller,
    required this.isLandscape,
    required this.locationService,
  });

  final camera.CameraController controller;
  final bool isLandscape;
  final LocationService locationService;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final screenAspectRatio =
                constraints.maxWidth / constraints.maxHeight;
            final sensorAspectRatio = controller.value.aspectRatio;
            final previewAspectRatio = isLandscape
                ? sensorAspectRatio
                : 1 / sensorAspectRatio;

            final scale = _coverScale(
              previewAspectRatio,
              screenAspectRatio,
            );

            return ClipRect(
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: camera.CameraPreview(controller),
                ),
              ),
            );
          },
        ),
        const SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'KAMLOKA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _LocationStatus(service: locationService),
            ),
          ),
        ),
        const _CameraShutter(),
      ],
    );
  }

  double _coverScale(double cameraRatio, double screenRatio) {
    if (cameraRatio <= 0 || screenRatio <= 0) {
      return 1;
    }

    return cameraRatio > screenRatio
        ? cameraRatio / screenRatio
        : screenRatio / cameraRatio;
  }
}


class _CameraShutter extends GetView<CameraController> {
  const _CameraShutter();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isCapturing = controller.isCapturing.value;
      final error = controller.captureErrorMessage.value;

      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _CaptureThumbnail(),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: isCapturing
                          ? null
                          : controller.capturePhoto,
                      child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: isCapturing ? 0.6 : 1,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                    ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _CaptureThumbnail extends GetView<CameraController> {
  const _CaptureThumbnail();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final path = controller.lastCapturePath.value;

      return GestureDetector(
        onTap: path.isEmpty
            ? null
            : () => Get.to(
                  () => PhotoPreviewView(filePath: path),
                ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: path.isEmpty
              ? const Icon(
                  Icons.photo_outlined,
                  color: Colors.white70,
                  size: 25,
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 24,
                    );
                  },
                ),
        ),
      );
    });
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.service});

  final LocationService service;

  static const _shadow = [
    Shadow(
      color: Colors.black87,
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final position = service.position.value;
      final hasPosition = position != null;
      final isEnabled = service.isServiceEnabled.value;
      final error = service.errorMessage.value;

      if (hasPosition) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 21,
                  color: Colors.white,
                  shadows: _shadow,
                ),
                SizedBox(width: 5),
                Text(
                  'GPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: _shadow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              service.coordinateText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: _shadow,
              ),
            ),
            if (service.address.value.isNotEmpty) ...[
              const SizedBox(height: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  service.address.value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    shadows: _shadow,
                  ),
                ),
              ),
            ] else if (service.isResolvingAddress.value) ...[
              const SizedBox(height: 3),
              const Text(
                'Mencari alamat...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  shadows: _shadow,
                ),
              ),
            ],
            const SizedBox(height: 3),
            Text(
              'Akurasi ${service.accuracyText} • Alt ${service.altitudeText}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: _shadow,
              ),
            ),
          ],
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled ? Icons.gps_fixed : Icons.gps_off,
            size: 20,
            color: Colors.white,
            shadows: _shadow,
          ),
          const SizedBox(width: 5),
          Text(
            error.isNotEmpty
                ? error
                : (isEnabled ? 'Mencari GPS...' : 'GPS mati'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              shadows: _shadow,
            ),
          ),
        ],
      );
    });
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 16),
          Text('Menyiapkan kamera...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Kamera tidak dapat digunakan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
