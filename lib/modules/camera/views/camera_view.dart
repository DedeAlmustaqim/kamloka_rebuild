import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
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
              child: Obx(
                () => _LocationStatus(service: locationService),
              ),
            ),
          ),
        ),
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


class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.service});

  final LocationService service;

  @override
  Widget build(BuildContext context) {
    final position = service.position.value;
    final hasPosition = position != null;
    final isEnabled = service.isServiceEnabled.value;
    final error = service.errorMessage.value;

    if (hasPosition) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'GPS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                service.coordinateText,
                style: const TextStyle(
                  fontSize: 10,
                ),
              ),
              Text(
                'Akurasi ${service.accuracyText} • Alt ${service.altitudeText}',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isEnabled ? Icons.gps_fixed : Icons.gps_off, size: 14),
            const SizedBox(width: 6),
            Text(
              error.isNotEmpty
                  ? error
                  : (isEnabled ? 'Mencari GPS...' : 'GPS mati'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
