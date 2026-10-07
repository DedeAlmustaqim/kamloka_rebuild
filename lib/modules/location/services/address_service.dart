import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AddressService {
  static const _userAgent =
      'KAMLOKA/1.0 (+https://github.com/DedeAlmustaqim/kamloka_rebuild)';

  final http.Client _client;

  AddressService({http.Client? client}) : _client = client ?? http.Client();

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'lat': latitude.toStringAsFixed(6),
        'lon': longitude.toStringAsFixed(6),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
        'accept-language': 'id',
      },
    );

    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          '[KAMLOKA ADDRESS] Nominatim HTTP ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final displayName = data['display_name'];
      if (displayName is String && displayName.trim().isNotEmpty) {
        return displayName.trim();
      }

      final address = data['address'];
      if (address is Map<String, dynamic>) {
        return _formatAddress(address);
      }
    } catch (error, stack) {
      debugPrint('[KAMLOKA ADDRESS] reverse geocode: $error');
      debugPrintStack(stackTrace: stack);
    }

    return null;
  }

  String? _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[
      _value(address['road']),
      _value(address['village']),
      _value(address['town']),
      _value(address['city']),
      _value(address['municipality']),
      _value(address['state']),
      _value(address['postcode']),
    ].where((value) => value.isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.toSet().join(', ');
  }

  String _value(dynamic value) {
    return value is String ? value.trim() : '';
  }

  void dispose() {
    _client.close();
  }
}
