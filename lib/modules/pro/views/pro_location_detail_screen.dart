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
import '../theme/pro_theme.dart';
import '../widgets/pro_message_dialog.dart';
import 'pro_camera_capture_screen.dart';

class ProLocationDetailScreen extends StatefulWidget {
  const ProLocationDetailScreen({
    super.key,
    required this.trip,
    required this.location,
    this.autoTakePhoto = false,
  });

  final Trip trip;
  final VisitLocation location;
  final bool autoTakePhoto;

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
    if (widget.autoTakePhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takePhoto();
      });
    }
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
        await showProMessageDialog(
          context: context,
          title: 'Foto berhasil ditambahkan',
          message: 'Foto tersimpan pada dokumentasi lokasi ini.',
          type: ProMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Gagal menyimpan foto',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _editCaption(DocumentedPhoto photo) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EditCaptionDialog(initialCaption: photo.caption ?? ''),
    );
    if (result == null) return;

    try {
      await _database.updatePhotoCaption(photo.id, result);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Keterangan belum tersimpan',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    }
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
    final confirmed = await showProConfirmDialog(
      context: context,
      title: 'Hapus foto dokumentasi?',
      message:
          'Foto akan dihapus dari perjalanan ini. Salinan yang sudah tersimpan di galeri tidak ikut dihapus.',
      confirmText: 'Hapus foto',
      cancelText: 'Batal',
      type: ProMessageType.error,
    );
    if (!confirmed) return;
    try {
      await _database.deletePhoto(photo.id);
      await _photoStorage.deleteManagedPhoto(photo.filePath);
      final remaining = await _database.listPhotos(widget.location.id);
      await _database.reorderPhotos(
        widget.location.id,
        remaining.map((item) => item.id).toList(),
      );
      if (mounted) {
        setState(_reload);
        await showProMessageDialog(
          context: context,
          title: 'Foto berhasil dihapus',
          message: 'Foto dihapus dari dokumentasi perjalanan.',
          type: ProMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Foto belum berhasil dihapus',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(
          title: const Text('Dokumentasi lokasi'),
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: ProTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ProTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOKASI KUNJUNGAN',
                      style: TextStyle(
                        color: ProTheme.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      widget.location.name,
                      style: const TextStyle(
                        color: ProTheme.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: ProTheme.secondaryText),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            widget.location.address ?? 'Alamat belum tersedia',
                            style: const TextStyle(
                              color: ProTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Foto dokumentasi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: ProTheme.border),
                    ),
                    child: Text(
                      '${photos.length} foto',
                      style: const TextStyle(
                        color: ProTheme.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih foto yang akan dimasukkan ke laporan PDF. Ketuk keterangan pada foto untuk mengubahnya.',
                style: TextStyle(color: ProTheme.secondaryText, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 12),
              if (photos.isEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF2C8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_outlined,
                          size: 28,
                          color: ProTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum ada foto',
                        style: TextStyle(
                          color: ProTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ambil foto pertama untuk mulai mendokumentasikan lokasi ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProTheme.secondaryText,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isTakingPhoto ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Ambil foto pertama'),
                      ),
                    ],
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _editCaption(photo),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            photo.caption?.isNotEmpty == true
                                                ? photo.caption!
                                                : 'Tambah keterangan foto',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: photo.caption?.isNotEmpty == true
                                                  ? ProTheme.text
                                                  : ProTheme.secondaryText,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            photo.capturedAt == null
                                                ? 'Waktu tidak tersedia'
                                                : _dateTimeLabel(photo.capturedAt!),
                                            style: const TextStyle(
                                              color: ProTheme.secondaryText,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (photo.address?.isNotEmpty == true) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              photo.address!,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: ProTheme.secondaryText,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: photo.includeInReport,
                                      onChanged: (value) async {
                                        await _database.setPhotoIncludedInReport(
                                          photo.id,
                                          value ?? false,
                                        );
                                        if (mounted) setState(_reload);
                                      },
                                    ),
                                    const Text(
                                      'PDF',
                                      style: TextStyle(
                                        color: ProTheme.secondaryText,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Pilihan foto',
                                  onSelected: (value) {
                                    if (value == 'caption') _editCaption(photo);
                                    if (value == 'up') _movePhoto(photo, -1);
                                    if (value == 'down') _movePhoto(photo, 1);
                                    if (value == 'delete') _deletePhoto(photo);
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'caption',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 10),
                                          Text('Ubah keterangan'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'up',
                                      enabled: photo.sortOrder > 0,
                                      child: const Row(
                                        children: [
                                          Icon(Icons.arrow_upward_rounded, size: 18),
                                          SizedBox(width: 10),
                                          Text('Pindahkan ke atas'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'down',
                                      enabled: photo.sortOrder < photos.length - 1,
                                      child: const Row(
                                        children: [
                                          Icon(Icons.arrow_downward_rounded, size: 18),
                                          SizedBox(width: 10),
                                          Text('Pindahkan ke bawah'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, color: ProTheme.danger, size: 18),
                                          SizedBox(width: 10),
                                          Text('Hapus foto'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          );
        },
      ),
    ));
  }
}

String _dateTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}


class _EditCaptionDialog extends StatefulWidget {
  const _EditCaptionDialog({required this.initialCaption});

  final String initialCaption;

  @override
  State<_EditCaptionDialog> createState() => _EditCaptionDialogState();
}

class _EditCaptionDialogState extends State<_EditCaptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keterangan foto'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Contoh: Kondisi objek saat monitoring',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
