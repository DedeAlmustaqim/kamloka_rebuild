import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';

class CollapsibleCameraControlPanel extends StatelessWidget {
  const CollapsibleCameraControlPanel({
    super.key,
    required this.controller,
    this.toggleOnly = false,
    this.panelOnly = false,
  });

  final CameraController controller;
  final bool toggleOnly;
  final bool panelOnly;

  CameraController get c => controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = c.isControlPanelExpanded.value;
      final toggle = Material(
        color: Colors.black.withValues(alpha: 0.48),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white70, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: expanded ? 'Tutup kontrol kamera' : 'Buka kontrol kamera',
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          onPressed: c.isCapturing.value || c.isCountingDown
              ? null
              : c.isControlPanelExpanded.toggle,
          icon: Icon(
            expanded ? Icons.keyboard_arrow_down_rounded : Icons.tune_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      );

      if (toggleOnly) {
        return Transform.translate(
          offset: const Offset(0, 8),
          child: toggle,
        );
      }
      if (panelOnly) {
        if (!expanded) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white30),
          ),
          child: _toolbar(),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expanded) ...[_toolbar(), const SizedBox(height: 6)],
          toggle,
        ],
      );
    });
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
    return Obx(
      () => _toolbarControl(
        icon: Icons.aspect_ratio_outlined,
        label: 'Ratio',
        state: c.aspectRatioLabel,
        onTap: c.cycleAspectRatio,
      ),
    );
  }

  Widget _timerCell() {
    return Obx(
      () => _toolbarControl(
        icon: c.timerSeconds.value == 0
            ? Icons.timer_off_outlined
            : Icons.timer_outlined,
        label: 'Timer',
        state: c.timerSeconds.value == 0 ? 'OFF' : '${c.timerSeconds.value}s',
        onTap: c.cycleTimer,
      ),
    );
  }

  Widget _cameraCell() {
    return Obx(
      () => _toolbarControl(
        icon: Icons.cameraswitch_outlined,
        label: 'Camera',
        state: c.lensDirection.value == camera.CameraLensDirection.back
            ? 'Back'
            : 'Front',
        onTap: c.switchCamera,
      ),
    );
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
    return Obx(
      () => _toolbarControl(
        icon: c.showGrid.value ? Icons.grid_on : Icons.grid_off,
        label: 'Grid',
        state: c.showGrid.value ? 'ON' : 'OFF',
        onTap: c.toggleGrid,
      ),
    );
  }

  Widget _exposureCell() {
    return Obx(
      () => _toolbarControl(
        icon: c.isExposureExpanded.value
            ? Icons.exposure_plus_1_outlined
            : Icons.exposure_outlined,
        label: 'Exposure',
        state: c.isExposureExpanded.value
            ? c.exposureOffset.value.toStringAsFixed(1)
            : 'AUTO',
        active: c.isExposureExpanded.value,
        onTap: c.toggleExposureControl,
      ),
    );
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.24)
                        : Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? Colors.white : Colors.white54,
                      width: active ? 1.4 : 1,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white70,
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
