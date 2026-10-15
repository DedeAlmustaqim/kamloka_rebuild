import 'dart:async';
import 'package:flutter/foundation.dart';
import 'address_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class LocationService extends GetxService {
  final isInitializing = false.obs;
  final isServiceEnabled = false.obs;
  final permission = Rxn<LocationPermission>();
  final position = Rxn<Position>();
  final address = ''.obs;
  final isResolvingAddress = false.obs;
  final errorMessage = ''.obs;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _initialized = false;
  bool _reverseGeocodingInProgress = false;
  Timer? _reverseGeocodingDebounce;
  final Map<String, String> _addressCache = {};
  final AddressService _addressService = AddressService();

  Future<LocationService> init() async {
    await initialize();
    return this;
  }

  Future<void> initialize({bool force = false}) async {
    if (_initialized && !force) return;

    isInitializing.value = true;
    errorMessage.value = '';

    try {
      await _stopStreams();

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      isServiceEnabled.value = serviceEnabled;

      if (!serviceEnabled) {
        throw const _LocationServiceDisabledException();
      }

      var currentPermission = await Geolocator.checkPermission();

      if (currentPermission == LocationPermission.denied) {
        currentPermission = await Geolocator.requestPermission();
      }

      permission.value = currentPermission;

      if (currentPermission == LocationPermission.denied) {
        throw const _LocationPermissionDeniedException();
      }

      if (currentPermission == LocationPermission.deniedForever) {
        throw const _LocationPermissionDeniedForeverException();
      }

      // GPS acquisition is independent from reverse geocoding. Start the
      // position stream immediately so slow/offline internet cannot stall it.
      await _refreshCurrentPosition(resolveAddress: false);
      _startStreams();
      _initialized = true;

      final currentPosition = position.value;
      if (currentPosition != null) {
        unawaited(_reverseGeocode(currentPosition));
      }
    } on _LocationServiceDisabledException {
      errorMessage.value = 'Layanan lokasi/GPS sedang dimatikan.';
    } on _LocationPermissionDeniedException {
      errorMessage.value = 'Izin lokasi ditolak.';
    } on _LocationPermissionDeniedForeverException {
      errorMessage.value =
          'Izin lokasi ditolak permanen. Aktifkan dari Pengaturan aplikasi.';
    } on TimeoutException {
      errorMessage.value = 'GPS belum mendapatkan lokasi dalam batas waktu.';
      await _useLastKnownPosition();
      _startStreams();
      _initialized = true;
    } catch (error, stack) {
      debugPrint('[KAMLOKA LOCATION] $error');
      debugPrintStack(stackTrace: stack);
      errorMessage.value = 'Lokasi belum tersedia.';
      await _useLastKnownPosition();
      _startStreams();
      _initialized = true;
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> retry() => initialize(force: true);

  Future<void> _refreshCurrentPosition({
    bool resolveAddress = true,
  }) async {
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    try {
      position.value = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      errorMessage.value = '';
      if (resolveAddress) {
        await _reverseGeocode(position.value!);
      }
    } on TimeoutException {
      rethrow;
    } catch (error, stack) {
      debugPrint('[KAMLOKA LOCATION] getCurrentPosition: $error');
      debugPrintStack(stackTrace: stack);

      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null) {
        position.value = fallback;
        errorMessage.value = 'Menggunakan lokasi terakhir yang tersedia.';
        if (resolveAddress) {
          await _reverseGeocode(fallback);
        }
        return;
      }

      rethrow;
    }
  }

  Future<void> _useLastKnownPosition() async {
    try {
      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null) {
        position.value = fallback;
        // Keep last-known GPS data available even if the address lookup
        // cannot reach the network.
        unawaited(_reverseGeocode(fallback));
      }
    } catch (error) {
      debugPrint('[KAMLOKA LOCATION] last known: $error');
    }
  }

  void _startStreams() {
    _serviceStatusSubscription =
        Geolocator.getServiceStatusStream().listen((status) async {
      final enabled = status == ServiceStatus.enabled;
      isServiceEnabled.value = enabled;

      if (!enabled) {
        errorMessage.value = 'Layanan lokasi/GPS sedang dimatikan.';
        return;
      }

      if (permission.value == LocationPermission.denied ||
          permission.value == LocationPermission.deniedForever) {
        return;
      }

      await _refreshCurrentPosition(
        resolveAddress: false,
      ).catchError((error) {
        debugPrint('[KAMLOKA LOCATION] service refresh: $error');
      });
    });

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (value) {
        position.value = value;
        errorMessage.value = '';
        _scheduleReverseGeocode(value);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[KAMLOKA LOCATION] stream: $error');
        debugPrintStack(stackTrace: stack);
        errorMessage.value = 'Pembaruan lokasi gagal.';
      },
    );
  }

  Future<void> _stopStreams() async {
    _reverseGeocodingDebounce?.cancel();
    _reverseGeocodingDebounce = null;
    await _positionSubscription?.cancel();
    await _serviceStatusSubscription?.cancel();
    _positionSubscription = null;
    _serviceStatusSubscription = null;
  }

  void _scheduleReverseGeocode(Position value) {
    _reverseGeocodingDebounce?.cancel();
    _reverseGeocodingDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(_reverseGeocode(value));
    });
  }

  Future<void> _reverseGeocode(Position value) async {
    final key = '${value.latitude.toStringAsFixed(4)},'
        '${value.longitude.toStringAsFixed(4)}';

    final cached = _addressCache[key];
    if (cached != null) {
      address.value = cached;
      return;
    }

    if (_reverseGeocodingInProgress) {
      return;
    }

    _reverseGeocodingInProgress = true;
    isResolvingAddress.value = true;

    try {
      final resolvedAddress = await _addressService.reverseGeocode(
        latitude: value.latitude,
        longitude: value.longitude,
      );

      if (resolvedAddress == null || resolvedAddress.isEmpty) {
        address.value = 'Alamat tidak tersedia';
        return;
      }

      _addressCache[key] = resolvedAddress;
      address.value = resolvedAddress;

      debugPrint('[KAMLOKA LOCATION] address: $resolvedAddress');
    } catch (error, stack) {
      debugPrint('[KAMLOKA LOCATION] reverse geocode: $error');
      debugPrintStack(stackTrace: stack);
      address.value = 'Alamat tidak tersedia';
    } finally {
      isResolvingAddress.value = false;
      _reverseGeocodingInProgress = false;
    }
  }

  String get coordinateText {
    final value = position.value;
    if (value == null) return '--';

    return '${value.latitude.toStringAsFixed(6)}, '
        '${value.longitude.toStringAsFixed(6)}';
  }

  String get accuracyText {
    final value = position.value;
    if (value == null) return '--';

    return '${value.accuracy.toStringAsFixed(1)} m';
  }

  String get altitudeText {
    final value = position.value;
    if (value == null) return '--';

    return '${value.altitude.toStringAsFixed(1)} m';
  }

  bool get hasPosition => position.value != null;

  bool get isPrecise =>
      permission.value != null &&
      permission.value != LocationPermission.denied &&
      position.value != null &&
      position.value!.accuracy <= 100;

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  @override
  void onClose() {
    _reverseGeocodingDebounce?.cancel();
    _reverseGeocodingDebounce = null;
    _stopStreams();
    _addressService.dispose();
    super.onClose();
  }
}


class _LocationServiceDisabledException implements Exception {
  const _LocationServiceDisabledException();
}

class _LocationPermissionDeniedException implements Exception {
  const _LocationPermissionDeniedException();
}

class _LocationPermissionDeniedForeverException implements Exception {
  const _LocationPermissionDeniedForeverException();
}
