import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import '../services/device_orientation_service.dart';

class CameraView extends GetView<CameraController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final orientationService = Get.find<DeviceOrientationService>();

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
        );
      }),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.controller,
    required this.isLandscape,
  });

  final camera.CameraController controller;
  final bool isLandscape;

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
