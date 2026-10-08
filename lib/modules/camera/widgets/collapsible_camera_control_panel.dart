import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller.dart';

class CollapsibleCameraControlPanel extends StatefulWidget {
  const CollapsibleCameraControlPanel({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  State<CollapsibleCameraControlPanel> createState() =>
      _CollapsibleCameraControlPanelState();
}

class _CollapsibleCameraControlPanelState
    extends State<CollapsibleCameraControlPanel> {
  bool _expanded = false;

  CameraController get c => widget.controller;

  void _toggle() {
    if (c.isCapturing.value || c.isCountingDown.value) return;
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded ? _controlsGrid() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          _iconButton(
            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            onTap: _toggle,
          ),
          const Expanded(
            child: Center(child: _Brand()),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _controlsGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row([
            _ratioCell(),
            _timerCell(),
            _cameraCell(),
          ]),
          const SizedBox(height: 8),
          _row([
            _flashCell(),
            _gridCell(),
            _exposureCell(),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children) Expanded(child: child),
      ],
    );
  }

  Widget _ratioCell() {
    return Obx(() => _quickControl(
          icon: Icons.aspect_ratio_outlined,
          label: 'Ratio',
          state: c.aspectRatioLabel,
          onTap: c.cycleAspectRatio,
        ));
  }

  Widget _timerCell() {
    return Obx(() => _quickControl(
          icon: c.timerSeconds.value == 0
              ? Icons.timer_off_outlined
              : Icons.timer_outlined,
          label: 'Timer',
          state: c.timerSeconds.value == 0
              ? 'OFF'
              : '\${c.timerSeconds.value}s',
          onTap: c.cycleTimer,
        ));
  }

  Widget _cameraCell() {
    return Obx(() => _quickControl(
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
      return _quickControl(
        icon: icon,
        label: 'Flash',
        state: state,
        onTap: c.cycleFlashMode,
      );
    });
  }

  Widget _gridCell() {
    return Obx(() => _quickControl(
          icon: c.showGrid.value ? Icons.grid_on : Icons.grid_off,
          label: 'Grid',
          state: c.showGrid.value ? 'ON' : 'OFF',
          onTap: c.toggleGrid,
        ));
  }

  Widget _exposureCell() {
    return Obx(() => _quickControl(
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

  Widget _quickControl({
    required IconData icon,
    required String label,
    required String state,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    final disabled = c.isCapturing.value || c.isCountingDown.value;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Colors.white70
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            Text(
              state,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.white,
            size: 25,
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
