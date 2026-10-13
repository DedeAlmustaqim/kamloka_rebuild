import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../camera/controllers/camera_controller.dart';

class ProCameraCaptureScreen extends StatelessWidget {
  const ProCameraCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraController>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Foto Dokumentasi'),
      ),
      body: Obx(() {
        if (!controller.isReady.value) {
          return Center(
            child: controller.errorMessage.value.isEmpty
                ? const CircularProgressIndicator()
                : Text(
                    controller.errorMessage.value,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(child: camera.CameraPreview(controller.cameraController)),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.captureErrorMessage.value.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            controller.captureErrorMessage.value,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      GestureDetector(
                        onTap: controller.isCapturing.value
                            ? null
                            : () async {
                                final path = await controller.capturePhoto();
                                if (path != null && context.mounted) {
                                  Get.back(result: path);
                                }
                              },
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: controller.isCapturing.value
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
                      const SizedBox(height: 12),
                      const Text(
                        'Foto akan diberi watermark dan disimpan ke galeri KAMLOKA.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
