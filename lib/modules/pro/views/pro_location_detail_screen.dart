import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../location/services/location_service.dart';
import '../models/documented_photo.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';
import '../services/pro_database_service.dart';
import '../services/pro_photo_storage_service.dart';
import 'pro_camera_capture_screen.dart';

class ProLocationDetailScreen extends StatefulWidget {
  const ProLocationDetailScreen({
    super.key,
    required this.trip,
    required this.location,
  });

  final Trip trip;
  final VisitLocation location;

  @override
  State<ProLocationDetailScreen> createState() => _ProLocationDetailScreenState();
}

class _ProLocationDetailScreenState extends State<ProLocationDetailScreen> {
  final _database = Get.find<ProDatabaseService>();
  final _photoStorage = Get.find<ProPhotoStorageService>();
  final _uuid = const Uuid();
  late Future<List<DocumentedPhoto>> _photosFuture;
  bool _isTakingPhoto = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _photosFuture = _database.listPhotos(widget.location.id);
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    setState(() => _isTakingPhoto = true);
    try {
      final path = await Get.to<String>(() => const ProCameraCaptureScreen());
      if (path == null || path.isEmpty) return;

      final photoId = _uuid.v4();
      final locationService = Get.find<LocationService>();
      final position = locationService.position.value;
      final address = locationService.address.value.trim();
      final existing = await _database.listPhotos(widget.location.id);
      final permanentPath = await _photoStorage.importProcessedPhoto(
        sourcePath: path,
        tripId: widget.trip.id,
        locationId: widget.location.id,
        photoId: photoId,
      );

      try {
        await _database.savePhoto(
          DocumentedPhoto(
            id: photoId,
            locationId: widget.location.id,
            filePath: permanentPath,
            caption: null,
            capturedAt: DateTime.now(),
            latitude: position?.latitude,
            longitude: position?.longitude,
            address: address.isEmpty ? null : address,
            sortOrder: existing.length,
            includeInReport: true,
            createdAt: DateTime.now(),
          ),
        );
      } catch (_) {
        await _photoStorage.deleteManagedPhoto(permanentPath);
        rethrow;
      }

      if (mounted) {
        setState(_reload);
        Get.snackbar('Foto ditambahkan', 'Foto tersimpan pada dokumentasi lokasi ini.');
      }
    } catch (error) {
      if (mounted) {
        Get.snackbar('Gagal menyimpan foto', error.toString());
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _editCaption(DocumentedPhoto photo) async {
    final controller = TextEditingController(text: photo.caption ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keterangan foto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Contoh: Kondisi objek saat monitoring',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _database.updatePhotoCaption(photo.id, result);
    if (mounted) setState(_reload);
  }

  Future<void> _movePhoto(DocumentedPhoto photo, int offset) async {
    final photos = await _database.listPhotos(widget.location.id);
    final currentIndex = photos.indexWhere((item) => item.id == photo.id);
    final targetIndex = currentIndex + offset;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= photos.length) return;

    final orderedIds = photos.map((item) => item.id).toList();
    final movedId = orderedIds.removeAt(currentIndex);
    orderedIds.insert(targetIndex, movedId);
    await _database.reorderPhotos(widget.location.id, orderedIds);
    if (mounted) setState(_reload);
  }

  Future<void> _deletePhoto(DocumentedPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto dokumentasi?'),
        content: const Text('Foto akan dihapus dari perjalanan ini. Salinan di galeri tidak ikut dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deletePhoto(photo.id);
    await _photoStorage.deleteManagedPhoto(photo.filePath);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentasi Lokasi'),
        actions: [
          IconButton(
            tooltip: 'Ambil foto',
            onPressed: _isTakingPhoto ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTakingPhoto ? null : _takePhoto,
        icon: _isTakingPhoto
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.camera_alt),
        label: Text(_isTakingPhoto ? 'Menyimpan...' : 'Ambil Foto'),
      ),
      body: FutureBuilder<List<DocumentedPhoto>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat foto: ${snapshot.error}'));
          }
          final photos = snapshot.data ?? const <DocumentedPhoto>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(widget.location.name),
                  subtitle: Text(widget.location.address ?? 'Alamat tidak tersedia'),
                ),
              ),
              const SizedBox(height: 12),
              Text('FOTO DOKUMENTASI (${photos.length})',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (photos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Belum ada foto untuk lokasi ini. Ambil foto untuk menambah dokumentasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                ...photos.map((photo) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: File(photo.filePath).existsSync()
                                ? Image.file(File(photo.filePath), fit: BoxFit.cover)
                                : const Center(child: Text('File foto tidak ditemukan')),
                          ),
                          CheckboxListTile(
                            value: photo.includeInReport,
                            onChanged: (value) async {
                              await _database.setPhotoIncludedInReport(photo.id, value ?? false);
                              if (mounted) setState(_reload);
                            },
                            title: Text(photo.caption?.isNotEmpty == true ? photo.caption! : 'Tanpa keterangan'),
                            subtitle: Text(
                              photo.capturedAt == null
                                  ? 'Waktu pengambilan tidak tersedia'
                                  : _dateTimeLabel(photo.capturedAt!),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          ButtonBar(
                            children: [
                              TextButton.icon(
                                onPressed: photo.sortOrder <= 0
                                    ? null
                                    : () => _movePhoto(photo, -1),
                                icon: const Icon(Icons.arrow_upward),
                                label: const Text('Naik'),
                              ),
                              TextButton.icon(
                                onPressed: photo.sortOrder >= photos.length - 1
                                    ? null
                                    : () => _movePhoto(photo, 1),
                                icon: const Icon(Icons.arrow_downward),
                                label: const Text('Turun'),
                              ),
                              TextButton.icon(
                                onPressed: () => _editCaption(photo),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Keterangan'),
                              ),
                              TextButton.icon(
                                onPressed: () => _deletePhoto(photo),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Hapus'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

String _dateTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
