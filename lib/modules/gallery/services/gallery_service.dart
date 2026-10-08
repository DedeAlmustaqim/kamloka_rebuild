import 'package:gal/gal.dart';

class GalleryService {
  static const albumName = 'KAMLOKA';

  Future<void> saveImage(String filePath) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);

    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw const GalleryAccessDeniedException();
      }
    }

    await Gal.putImage(filePath, album: albumName);
  }
}

class GalleryAccessDeniedException implements Exception {
  const GalleryAccessDeniedException();

  @override
  String toString() => 'Izin galeri diperlukan untuk menyimpan foto.';
}
