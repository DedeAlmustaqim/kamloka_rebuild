import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns durable photo copies used by Pro trip reports.
/// The camera's temporary output and gallery copy are not used as database
/// source paths because either may be removed independently.
class ProPhotoStorageService {
  Future<String> importProcessedPhoto({
    required String sourcePath,
    required String tripId,
    required String locationId,
    required String photoId,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Foto sumber tidak ditemukan.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'kamloka_pro', 'photos', tripId, locationId),
    );
    await directory.create(recursive: true);

    final destinationPath = p.join(directory.path, '$photoId.jpg');
    final copied = await source.copy(destinationPath);
    return copied.path;
  }

  Future<bool> exists(String filePath) => File(filePath).exists();

  Future<void> deleteManagedPhoto(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
