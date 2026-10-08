import 'dart:io';

import 'package:camera/camera.dart' as camera;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import 'photo_preview_view.dart';
import '../../location/services/location_service.dart';

class CameraView extends GetView<CameraController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final locationService = Get.find<LocationService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isInitializing.value) {
          return const _LoadingView();
        }

        if (controller.isSwitchingCamera.value) {
          return const _LoadingView(message: 'Mengganti kamera...');
        }

        if (!controller.isReady.value) {
          return _ErrorView(
            message: controller.errorMessage.value,
            onRetry: controller.retry,
          );
        }

        return _CameraPreview(
          controller: controller.cameraController,
          locationService: locationService,
        );
      }),
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.controller,
    required this.locationService,
  });

  final camera.CameraController controller;
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
            // The UI stays portrait; physical orientation is handled
            // separately by DeviceOrientationService/capture processing.
            final previewAspectRatio = 1 / sensorAspectRatio;

            final scale = _coverScale(
              previewAspectRatio,
              screenAspectRatio,
            );

            double baseZoom = 1.0;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;

                final local = box.globalToLocal(details.globalPosition);
                final normalized = Offset(
                  (local.dx / box.size.width).clamp(0.0, 1.0),
                  (local.dy / box.size.height).clamp(0.0, 1.0),
                );

                Get.find<CameraController>()
                    .setFocusAndExposure(normalized);
              },
              onScaleStart: (_) {
                final zoom = Get.find<CameraController>().zoomLevel.value;
                baseZoom = zoom;
              },
              onScaleUpdate: (details) {
                final zoomController = Get.find<CameraController>();
                if (details.scale == 1.0) return;

                final nextZoom = baseZoom * details.scale;
                zoomController.setZoom(nextZoom);
              },
              onDoubleTap: () {
                Get.find<CameraController>().setZoom(1.0);
              },
              child: ClipRect(
                child: Transform.scale(
                  scale: scale,
                  child: Center(
                    child: camera.CameraPreview(controller),
                  ),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _FlashButton(),
                  SizedBox(width: 8),
                  _SwitchCameraButton(),
                ],
              ),
            ),
          ),
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
        Obx(() {
          final point = Get.find<CameraController>().focusPoint.value;
          if (point == null) return const SizedBox.shrink();

          return Positioned(
            left: point.dx * MediaQuery.sizeOf(context).width - 28,
            top: point.dy * MediaQuery.sizeOf(context).height - 28,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.25, end: 1),
                duration: const Duration(milliseconds: 220),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        const _ExposureControl(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 182,
          child: IgnorePointer(
            child: Center(
              child: Obx(() {
                final zoom = Get.find<CameraController>().zoomLevel.value;
                return AnimatedOpacity(
                  opacity: zoom > 1.01 ? 1 : 0.72,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${zoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
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
      final isBusy = controller.isCapturing.value;
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
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _CaptureThumbnail(),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: isBusy ? null : controller.capturePhoto,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isBusy ? 0.6 : 1,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: isBusy
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

class _FlashButton extends GetView<CameraController> {
  const _FlashButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.flashMode.value;
      final icon = switch (mode) {
        camera.FlashMode.off => Icons.flash_off,
        camera.FlashMode.auto => Icons.flash_auto,
        camera.FlashMode.always => Icons.flash_on,
        camera.FlashMode.torch => Icons.flash_on,
      };
      final label = switch (mode) {
        camera.FlashMode.off => 'OFF',
        camera.FlashMode.auto => 'AUTO',
        camera.FlashMode.always => 'ON',
        camera.FlashMode.torch => 'TORCH',
      };

      return Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: controller.cycleFlashMode,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 19),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ExposureControl extends GetView<CameraController> {
  const _ExposureControl();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final min = controller.minExposure;
      final max = controller.maxExposure;
      final value = controller.exposureOffset.value;
      final supported = max > min;

      return Positioned(
        left: 24,
        right: 24,
        bottom: 116,
        child: SafeArea(
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  Expanded(
                    child: Slider(
                      value: supported ? value.clamp(min, max).toDouble() : 0,
                      min: supported ? min : -1,
                      max: supported ? max : 1,
                      divisions: supported
                          ? ((max - min) * 2).round().clamp(1, 100)
                          : 1,
                      onChanged: supported && !controller.isCapturing.value
                          ? controller.setExposure
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      value >= 0
                          ? '+${value.toStringAsFixed(1)}'
                          : value.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reset exposure',
                    onPressed: supported && value.abs() > 0.01
                        ? () => controller.setExposure(0)
                        : null,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _SwitchCameraButton extends GetView<CameraController> {
  const _SwitchCameraButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.isReady.value &&
          !controller.isCapturing.value;

      return Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? controller.switchCamera : null,
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(
              Icons.flip_camera_ios_outlined,
              color: Colors.white,
              size: 20,
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
            : () => Get.to(() => PhotoPreviewView(filePath: path)),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
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
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
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
  const _LoadingView({this.message = 'Menyiapkan kamera...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 16),
          Text(message),
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
