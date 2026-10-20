import 'package:camera/camera.dart' as camera;

/// Stub sementara: foto dikembalikan tanpa watermark.
/// Renderer dan model data akan dirancang ulang kemudian.
class WatermarkService {
  Future<camera.XFile> apply(camera.XFile source) async => source;

  void dispose() {}
}
