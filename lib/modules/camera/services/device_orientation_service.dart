import 'dart:async';

import 'package:get/get.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class DeviceOrientationService extends GetxService {
  final orientation = NativeDeviceOrientation.portraitUp.obs;

  StreamSubscription<NativeDeviceOrientation>? _subscription;
  Future<DeviceOrientationService>? _initFuture;
  bool _hasInitialReading = false;

  Future<DeviceOrientationService> init() {
    if (_hasInitialReading) return Future.value(this);
    return _initFuture ??= _initialize();
  }

  Future<DeviceOrientationService> _initialize() async {
    try {
      final communicator = NativeDeviceOrientationCommunicator();

      final initialOrientation = await communicator.orientation(
        useSensor: true,
      );
      if (initialOrientation != NativeDeviceOrientation.unknown) {
        orientation.value = initialOrientation;
      }
      _hasInitialReading = true;

      _subscription = communicator
          .onOrientationChanged(useSensor: true)
          .listen((value) {
        if (value == NativeDeviceOrientation.unknown) return;
        orientation.value = value;
      });

      return this;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
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
