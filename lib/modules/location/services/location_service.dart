import 'dart:async';
import 'dart:ui';

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
  final isGeocoderAvailable = false.obs;
  final errorMessage = ''.obs;
  final Geocoding _geocoding = Geocoding(locale: const Locale('id', 'ID'));

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _initialized = false;
  bool _reverseGeocodingInProgress = false;
  double? _lastGeocodedLatitude;
  double? _lastGeocodedLongitude;

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

      isGeocoderAvailable.value = await _geocoding.isPresent();
      debugPrint(
        '[KAMLOKA LOCATION] geocoder available: ${isGeocoderAvailable.value}',
      );

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

  Future<void> _refreshCurrentPosition() async {
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    try {
      position.value = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      errorMessage.value = '';
      await _reverseGeocode(position.value!);
    } on TimeoutException {
      rethrow;
    } catch (error, stack) {
      debugPrint('[KAMLOKA LOCATION] getCurrentPosition: $error');
      debugPrintStack(stackTrace: stack);

      final fallback = await Geolocator.getLastKnownPosition();
      if (fallback != null) {
        position.value = fallback;
        errorMessage.value = 'Menggunakan lokasi terakhir yang tersedia.';
        await _reverseGeocode(fallback);
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

      await _refreshCurrentPosition().catchError((error) {
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
        unawaited(_reverseGeocode(value));
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[KAMLOKA LOCATION] stream: $error');
        debugPrintStack(stackTrace: stack);
        errorMessage.value = 'Pembaruan lokasi gagal.';
      },
    );
  }

  Future<void> _stopStreams() async {
    await _positionSubscription?.cancel();
    await _serviceStatusSubscription?.cancel();
    _positionSubscription = null;
    _serviceStatusSubscription = null;
  }

  Future<void> _reverseGeocode(Position value) async {
    final lastLat = _lastGeocodedLatitude;
    final lastLng = _lastGeocodedLongitude;

    if (lastLat != null &&
        lastLng != null &&
        Geolocator.distanceBetween(
              lastLat,
              lastLng,
              value.latitude,
              value.longitude,
            ) <
            50) {
      return;
    }

    // Android geocoding uses Pigeon-backed native listener objects.
    // Keep only one reverse-geocoding request alive at a time so rapid
    // position updates cannot overlap their native listener lifecycle.
    if (_reverseGeocodingInProgress) {
      return;
    }

    _reverseGeocodingInProgress = true;
    isResolvingAddress.value = true;

    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        value.latitude,
        value.longitude,
        locale: const Locale('id', 'ID'),
      );

      debugPrint(
        '[KAMLOKA LOCATION] reverse geocode result count: ${placemarks.length}',
      );

      if (placemarks.isEmpty) {
        address.value = 'Alamat tidak ditemukan';
        return;
      }

      final place = placemarks.first;
      debugPrint('[KAMLOKA LOCATION] placemark: $place');

      final formattedAddress = _formatPlacemark(place);
      address.value = formattedAddress.isEmpty
          ? 'Alamat tidak tersedia'
          : formattedAddress;

      if (formattedAddress.isNotEmpty) {
        _lastGeocodedLatitude = value.latitude;
        _lastGeocodedLongitude = value.longitude;
      }
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
