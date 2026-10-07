import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
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

      await _refreshCurrentPosition();
      _startStreams();

      _initialized = true;
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
        await _reverseGeocode(fallback);
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
      final placemarks = await placemarkFromCoordinates(
        value.latitude,
        value.longitude,
      );

      debugPrint(
        '[KAMLOKA LOCATION] reverse geocode result count: ${placemarks.length}',
      );

      if (placemarks.isEmpty) {
        address.value = 'Alamat tidak ditemukan';
        return;
      }

      final formattedAddress = _formatPlacemark(placemarks.first);

      if (formattedAddress.isEmpty) {
        address.value = 'Alamat tidak tersedia';
        return;
      }

      _addressCache[key] = formattedAddress;
      address.value = formattedAddress;

      debugPrint('[KAMLOKA LOCATION] address: $formattedAddress');
    } catch (error, stack) {
      debugPrint('[KAMLOKA LOCATION] reverse geocode: $error');
      debugPrintStack(stackTrace: stack);
      address.value = 'Alamat tidak tersedia';
    } finally {
      isResolvingAddress.value = false;
      _reverseGeocodingInProgress = false;
    }
  }

  String _formatPlacemark(Placemark place) {
    final parts = <String>[
      if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.thoroughfare ?? '').trim().isNotEmpty)
        place.thoroughfare!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.subAdministrativeArea ?? '').trim().isNotEmpty)
        place.subAdministrativeArea!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
    ];

    return parts.toSet().join(', ');
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
