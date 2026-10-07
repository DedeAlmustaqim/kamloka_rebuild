import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import '../services/device_orientation_service.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DeviceOrientationService(), permanent: true);
    Get.put(CameraController(), permanent: true);
  }
}
