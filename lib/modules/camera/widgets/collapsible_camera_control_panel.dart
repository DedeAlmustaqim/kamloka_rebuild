import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';

class CollapsibleCameraControlPanel extends StatelessWidget {
  const CollapsibleCameraControlPanel({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  CameraController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 42,
            child: Center(child: _Brand()),
          ),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ratioCell()),
        Expanded(child: _timerCell()),
        Expanded(child: _cameraCell()),
        Expanded(child: _flashCell()),
        Expanded(child: _gridCell()),
        Expanded(child: _exposureCell()),
      ],
    );
  }

  Widget _ratioCell() {
    return Obx(() => _toolbarControl(
          icon: Icons.aspect_ratio_outlined,
          label: 'Ratio',
          state: c.aspectRatioLabel,
          onTap: c.cycleAspectRatio,
        ));
  }

  Widget _timerCell() {
    return Obx(() => _toolbarControl(
          icon: c.timerSeconds.value == 0
              ? Icons.timer_off_outlined
              : Icons.timer_outlined,
          label: 'Timer',
          state: c.timerSeconds.value == 0
              ? 'OFF'
              : '${'${'}c.timerSeconds.value}s',
          onTap: c.cycleTimer,
        ));
  }

  Widget _cameraCell() {
    return Obx(() => _toolbarControl(
          icon: Icons.cameraswitch_outlined,
          label: 'Camera',
          state: c.lensDirection.value == camera.CameraLensDirection.back
              ? 'Back'
              : 'Front',
          onTap: c.switchCamera,
        ));
  }

  Widget _flashCell() {
    return Obx(() {
      final mode = c.flashMode.value;
      final state = switch (mode) {
        camera.FlashMode.off => 'OFF',
        camera.FlashMode.auto => 'AUTO',
        camera.FlashMode.always => 'ON',
        camera.FlashMode.torch => 'OFF',
      };
      final icon = switch (mode) {
        camera.FlashMode.off => Icons.flash_off_outlined,
        camera.FlashMode.auto => Icons.flash_auto_outlined,
        camera.FlashMode.always => Icons.flash_on_outlined,
        camera.FlashMode.torch => Icons.flash_off_outlined,
      };

      return _toolbarControl(
        icon: icon,
        label: 'Flash',
        state: state,
        onTap: c.cycleFlashMode,
      );
    });
  }

  Widget _gridCell() {
    return Obx(() => _toolbarControl(
          icon: c.showGrid.value ? Icons.grid_on : Icons.grid_off,
          label: 'Grid',
          state: c.showGrid.value ? 'ON' : 'OFF',
          onTap: c.toggleGrid,
        ));
  }

  Widget _exposureCell() {
    return Obx(() => _toolbarControl(
          icon: c.isExposureExpanded.value
              ? Icons.exposure_plus_1_outlined
              : Icons.exposure_outlined,
          label: 'Exposure',
          state: c.isExposureExpanded.value
              ? c.exposureOffset.value.toStringAsFixed(1)
              : 'AUTO',
          active: c.isExposureExpanded.value,
          onTap: c.toggleExposureControl,
        ));
  }

  Widget _toolbarControl({
    required IconData icon,
    required String label,
    required String state,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    final disabled = c.isCapturing.value || c.isCountingDown;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active
                        ? Colors.white70
                        : Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              Text(
                state,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'KAMLOKA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        shadows: [
          Shadow(
            color: Colors.black87,
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
