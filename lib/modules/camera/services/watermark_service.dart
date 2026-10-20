import 'package:camera/camera.dart' as camera;

/// Data yang nantinya digunakan oleh implementasi watermark baru.
class WatermarkData {
  const WatermarkData({
    required this.dateTime,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
  });

  final DateTime dateTime;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? altitude;
}

/// Implementasi sementara yang sengaja tidak menggambar watermark.
/// API dipertahankan agar pemanggil yang ada tidak rusak saat service
/// watermark dibangun ulang dari awal.
class WatermarkService {
  Future<camera.XFile> apply(
    camera.XFile source, {
    required WatermarkData data,
    bool showBranding = true,
  }) async {
    return source;
  }

  void dispose() {}
}
