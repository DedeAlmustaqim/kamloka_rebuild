import 'address_provider.dart';
import 'nominatim_address_provider.dart';

class AddressService {
  final AddressProvider _provider;

  AddressService({AddressProvider? provider})
      : _provider = provider ?? NominatimAddressProvider();

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return _provider.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
  }

  void dispose() {
    final provider = _provider;
    if (provider is NominatimAddressProvider) {
      provider.dispose();
    }
  }
}
