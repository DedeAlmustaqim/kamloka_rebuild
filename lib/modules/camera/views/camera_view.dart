import 'dart:io';

import 'package:camera/camera.dart' as camera;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import '../services/capture_service.dart';
import 'photo_preview_view.dart';
import '../widgets/collapsible_camera_control_panel.dart';
import '../../location/services/location_service.dart';
import '../../settings/views/settings_screen.dart';
import '../../pro/views/pro_trips_screen.dart';
import '../../pro/services/pro_access_service.dart';
import '../../pro/models/trip.dart';
import '../../pro/models/visit_location.dart';
import '../../pro/services/pro_database_service.dart';

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

            final scale = _coverScale(previewAspectRatio, screenAspectRatio);

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

                Get.find<CameraController>().setFocusAndExposure(normalized);
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
                  child: Center(child: camera.CameraPreview(controller)),
                ),
              ),
            );
          },
        ),
        const _TopScrim(),
        SafeArea(
          child: _CameraTopControls(controller: Get.find<CameraController>()),
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
        Obx(() {
          final value = Get.find<CameraController>().countdown.value;
          if (value <= 0) return const SizedBox.shrink();

          return Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(value),
                  tween: Tween(begin: 1.35, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        Obx(() {
          if (!Get.find<CameraController>().showGrid.value) {
            return const SizedBox.shrink();
          }
          return const Positioned.fill(
            child: IgnorePointer(child: _GridOverlay()),
          );
        }),
        Obx(() {
          final ratio = _visibleAspectRatio(
            Get.find<CameraController>().aspectRatio.value,
            MediaQuery.sizeOf(context),
          );
          if (ratio == null) return const SizedBox.shrink();
          return Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AspectRatioMaskPainter(ratio)),
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
        Positioned(
          left: 14,
          right: 14,
          bottom: 200,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CollapsibleCameraControlPanel(
                      controller: Get.find<CameraController>(),
                      toggleOnly: true,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/kamloka_typo_white.png',
                            width: 132,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 5),
                          _LocationStatus(service: locationService),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: CollapsibleCameraControlPanel(
                    controller: Get.find<CameraController>(),
                    panelOnly: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const _BottomScrim(),
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

  double? _visibleAspectRatio(CaptureAspectRatio aspectRatio, Size size) {
    final landscapeRatio = switch (aspectRatio) {
      CaptureAspectRatio.full => null,
      CaptureAspectRatio.ratio16x9 => 16 / 9,
      CaptureAspectRatio.ratio4x3 => 4 / 3,
      CaptureAspectRatio.square => 1.0,
    };

    if (landscapeRatio == null) return null;

    return size.width >= size.height ? landscapeRatio : 1 / landscapeRatio;
  }
}

class _CameraTopControls extends StatelessWidget {
  const _CameraTopControls({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: _DocumentationLocationButton(),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: _FieldDocumentationButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 150,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 190,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldDocumentationButton extends StatelessWidget {
  const _FieldDocumentationButton();

  Future<void> _openDocumentation(BuildContext context) async {
    final access = Get.find<ProAccessService>();
    if (access.isPro.value) {
      Get.to(() => const ProTripsScreen(), transition: Transition.cupertino);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF2C8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: Color(0xFF6A5200),
            size: 32,
          ),
        ),
        title: const Text(
          'Dokumentasi Lapangan',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Catat kegiatan lapangan dengan lebih terstruktur melalui KAMLOKA Pro.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18),
            _DocumentationBenefit(
              icon: Icons.route_outlined,
              text: 'Kelola perjalanan dan kegiatan',
            ),
            SizedBox(height: 12),
            _DocumentationBenefit(
              icon: Icons.add_location_alt_outlined,
              text: 'Susun lokasi kunjungan, foto, dan catatan',
            ),
            SizedBox(height: 12),
            _DocumentationBenefit(
              icon: Icons.picture_as_pdf_outlined,
              text: 'Ekspor dokumentasi menjadi laporan PDF',
            ),
            SizedBox(height: 18),
            Text(
              'Fitur ini tersedia untuk pengguna KAMLOKA Pro.',
              style: TextStyle(color: Color(0xFF68716B), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Get.to(
                () => const KamlokaProScreen(),
                transition: Transition.cupertino,
              );
            },
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: const Text('Kenali Pro'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDocumentation(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E6E0)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
              SizedBox(width: 7),
              Text(
                'Dokumentasi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFE4B957),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    'PRO',
                    style: TextStyle(
                      color: Color(0xFF292B25),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentationBenefit extends StatelessWidget {
  const _DocumentationBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF6A5200)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
                  children: [
                    const _CaptureThumbnail(),
                    const Spacer(),
                    GestureDetector(
                      onTap: isBusy ? null : () => controller.capturePhoto(context: context),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isBusy ? 0.6 : 1,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3.5),
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
                    const Spacer(),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: IconButton(
                        tooltip: 'Pengaturan',
                        onPressed: isBusy
                            ? null
                            : () => Get.to(
                                () => const SettingsScreen(),
                                transition: Transition.cupertino,
                              ),
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
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

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), size: Size.infinite);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _AspectRatioMaskPainter extends CustomPainter {
  const _AspectRatioMaskPainter(this.targetRatio);
  final double targetRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final screenRatio = size.width / size.height;
    final cropSize = screenRatio > targetRatio
        ? Size(size.height * targetRatio, size.height)
        : Size(size.width, size.width / targetRatio);
    final left = (size.width - cropSize.width) / 2;
    final top = (size.height - cropSize.height) / 2;
    final cropRect = Rect.fromLTWH(left, top, cropSize.width, cropSize.height);

    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.52);
    final outside = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRect(cropRect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, outside, hole),
      overlay,
    );

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, border);
  }

  @override
  bool shouldRepaint(covariant _AspectRatioMaskPainter oldDelegate) =>
      oldDelegate.targetRatio != targetRatio;
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
      final expanded = controller.isExposureExpanded.value;
      final disabled = !supported || controller.isCapturing.value;

      if (!supported) {
        return const SizedBox.shrink();
      }

      return Positioned(
        top: 210,
        right: 20,
        child: SafeArea(
          child: IgnorePointer(
            ignoring: disabled,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: controller.toggleExposureControl,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(
                              Icons.wb_sunny_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      if (expanded) ...[
                        SizedBox(
                          width: 30,
                          height: 150,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10,
                                ),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white38,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
                              ),
                              child: Slider(
                                value: value.clamp(min, max).toDouble(),
                                min: min,
                                max: max,
                                divisions: ((max - min) * 2)
                                    .round()
                                    .clamp(1, 100)
                                    .toInt(),
                                onChanged: controller.setExposure,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          value.abs() < 0.05
                              ? '0'
                              : value > 0
                              ? value.toStringAsFixed(1)
                              : value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 3),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: value.abs() > 0.01
                              ? () => controller.setExposure(0)
                              : null,
                          child: Icon(
                            Icons.refresh,
                            color: Colors.white.withValues(
                              alpha: value.abs() > 0.01 ? 0.85 : 0.3,
                            ),
                            size: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                  errorBuilder: (context, error, stackTrace) => const Icon(
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

class _DocumentationLocationButton extends StatelessWidget {
  const _DocumentationLocationButton();

  Future<void> _openSelector(BuildContext context) async {
    final cameraController = Get.find<CameraController>();
    final database = Get.find<ProDatabaseService>();

    try {
      final trips = await database.listTrips();
      final options = <_DocumentationLocationOption>[];
      for (final trip in trips) {
        final locations = await database.listLocations(trip.id);
        options.addAll(
          locations.map(
            (location) =>
                _DocumentationLocationOption(trip: trip, location: location),
          ),
        );
      }

      if (!context.mounted) return;
      final choice = await showModalBottomSheet<_DocumentationLocationChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DocumentationLocationSheet(
          options: options,
          selectedLocationId:
              cameraController.selectedDocumentationLocation.value?.id,
        ),
      );

      if (choice != null) {
        cameraController.selectedDocumentationLocation.value = choice.location;
      }
    } catch (error) {
      if (context.mounted) {
        Get.snackbar(
          'Lokasi dokumentasi tidak dapat dimuat',
          error.toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final access = Get.find<ProAccessService>();
      if (!access.hasAccess(KamlokaFeature.fieldDocumentation)) {
        return const SizedBox.shrink();
      }

      final selected =
          Get.find<CameraController>().selectedDocumentationLocation.value;
      return Material(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _openSelector(context),
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected == null
                        ? Icons.add_location_alt_outlined
                        : Icons.location_on,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      selected?.name ?? 'Pilih lokasi foto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white70,
                    size: 17,
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

class _DocumentationLocationOption {
  const _DocumentationLocationOption({
    required this.trip,
    required this.location,
  });

  final Trip trip;
  final VisitLocation location;
}

class _DocumentationLocationChoice {
  const _DocumentationLocationChoice(this.location);

  final VisitLocation? location;
}

class _DocumentationLocationSheet extends StatelessWidget {
  const _DocumentationLocationSheet({
    required this.options,
    required this.selectedLocationId,
  });

  final List<_DocumentationLocationOption> options;
  final String? selectedLocationId;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih lokasi dokumentasi',
                          style: TextStyle(
                            color: Color(0xFF202820),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Foto tetap masuk ke album KAMLOKA.',
                          style: TextStyle(
                            color: Color(0xFF68716B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE7EAE6),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xFF39433B),
                ),
              ),
              title: const Text(
                'Kamera biasa',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Simpan ke album tanpa mengaitkan lokasi kunjungan',
              ),
              trailing: selectedLocationId == null
                  ? const Icon(Icons.check_circle, color: Color(0xFF28784B))
                  : null,
              onTap: () => Navigator.of(
                context,
              ).pop(const _DocumentationLocationChoice(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: options.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 42,
                              color: Color(0xFF68716B),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Belum ada lokasi kunjungan',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Buat perjalanan dan tambahkan lokasi melalui tombol Dokumentasi Lapangan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF68716B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected =
                            option.location.id == selectedLocationId;
                        return Card(
                          elevation: 0,
                          color: selected
                              ? const Color(0xFFE5F2E8)
                              : Colors.white,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: selected
                                  ? const Color(0xFFC7E5CF)
                                  : const Color(0xFFFFF2C8),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: selected
                                    ? const Color(0xFF28784B)
                                    : const Color(0xFF6A5200),
                              ),
                            ),
                            title: Text(
                              option.location.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(option.trip.title),
                                if (option.location.address?.isNotEmpty == true)
                                  Text(
                                    option.location.address!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF28784B),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(
                              _DocumentationLocationChoice(option.location),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.service});

  final LocationService service;

  static const _shadow = [
    Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
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
                  size: 19,
                  color: Colors.white,
                  shadows: _shadow,
                ),
                SizedBox(width: 5),
                Text(
                  'GPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: _shadow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              service.coordinateText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                shadows: _shadow,
              ),
            ),
            if (service.address.value.isNotEmpty) ...[
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  service.address.value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
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
              'Akurasi ${service.accuracyText} | Alt ${service.altitudeText}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
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
  const _ErrorView({required this.message, required this.onRetry});

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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
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
