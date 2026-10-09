import 'package:get/get.dart';

import '../controllers/camera_controller.dart';
import '../services/device_orientation_service.dart';
import '../../location/services/location_service.dart';
import '../../pro/services/pro_access_service.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DeviceOrientationService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(ProAccessService(), permanent: true);
    Get.put(CameraController(), permanent: true);
  }
}
