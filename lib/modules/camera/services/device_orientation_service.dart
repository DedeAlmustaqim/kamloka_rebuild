import 'dart:async';

import 'package:get/get.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class DeviceOrientationService extends GetxService {
  final orientation = NativeDeviceOrientation.portraitUp.obs;

  StreamSubscription<NativeDeviceOrientation>? _subscription;

  Future<DeviceOrientationService> init() async {
    if (_subscription != null) return this;

    final communicator = NativeDeviceOrientationCommunicator();

    orientation.value = await communicator.orientation(useSensor: true);

    _subscription = communicator
        .onOrientationChanged(useSensor: true)
        .listen((value) {
      if (value != NativeDeviceOrientation.unknown) {
        orientation.value = value;
      }
    });

    return this;
  }

  bool get isPortrait =>
      orientation.value == NativeDeviceOrientation.portraitUp ||
      orientation.value == NativeDeviceOrientation.portraitDown;

  bool get isLandscape =>
      orientation.value == NativeDeviceOrientation.landscapeLeft ||
      orientation.value == NativeDeviceOrientation.landscapeRight;

  @override
  void onClose() {
    _subscription?.cancel();
    _subscription = null;
    super.onClose();
  }
}
