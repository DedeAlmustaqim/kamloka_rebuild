abstract interface class AddressProvider {
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}
