import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../location/services/location_service.dart';
import '../models/documented_photo.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';
import '../services/pro_database_service.dart';
import '../services/pro_pdf_export_service.dart';
import '../services/pro_photo_storage_service.dart';
import '../theme/pro_theme.dart';
import '../widgets/pro_message_dialog.dart';
import 'pro_camera_capture_screen.dart';

class ProTripDetailScreen extends StatefulWidget {
  const ProTripDetailScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<ProTripDetailScreen> createState() => _ProTripDetailScreenState();
}

class _ProTripDetailScreenState extends State<ProTripDetailScreen> {
  final _database = Get.find<ProDatabaseService>();
  final _photoStorage = Get.find<ProPhotoStorageService>();
  final _uuid = const Uuid();
  late Future<List<VisitLocation>> _locationsFuture;
  Future<List<DocumentedPhoto>>? _photosFuture;
  VisitLocation? _location;
  bool _isTakingPhoto = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _locationsFuture = _database.listLocations(widget.trip.id);
  }

  void _loadPhotos(VisitLocation location) {
    _location = location;
    _photosFuture = _database.listPhotos(location.id);
  }

  Future<void> _takePhoto() async {
    final location = _location;
    if (_isTakingPhoto || location == null) return;
    setState(() => _isTakingPhoto = true);
    try {
      final path = await Get.to<String>(() => const ProCameraCaptureScreen());
      if (path == null || path.isEmpty) return;

      final photoId = _uuid.v4();
      final locationService = Get.find<LocationService>();
      final position = locationService.position.value;
      final address = locationService.address.value.trim();
      final existing = await _database.listPhotos(location.id);
      final permanentPath = await _photoStorage.importProcessedPhoto(
        sourcePath: path,
        tripId: widget.trip.id,
        locationId: location.id,
        photoId: photoId,
      );

      try {
        await _database.savePhoto(DocumentedPhoto(
          id: photoId,
          locationId: location.id,
          filePath: permanentPath,
          capturedAt: DateTime.now(),
          latitude: position?.latitude,
          longitude: position?.longitude,
          address: address.isEmpty ? location.address : address,
          sortOrder: existing.length,
          includeInReport: true,
          createdAt: DateTime.now(),
        ));
      } catch (_) {
        await _photoStorage.deleteManagedPhoto(permanentPath);
        rethrow;
      }

      if (mounted) {
        setState(() => _photosFuture = _database.listPhotos(location.id));
        await showProMessageDialog(
          context: context,
          title: 'Foto berhasil ditambahkan',
          message: 'Foto tersimpan pada dokumentasi kegiatan ini.',
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
      final location = _location;
      if (mounted && location != null) {
        setState(() => _photosFuture = _database.listPhotos(location.id));
      }
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

  Future<void> _movePhoto(DocumentedPhoto photo, int offset, List<DocumentedPhoto> photos) async {
    final currentIndex = photos.indexWhere((item) => item.id == photo.id);
    final targetIndex = currentIndex + offset;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= photos.length) return;
    final orderedIds = photos.map((item) => item.id).toList();
    final movedId = orderedIds.removeAt(currentIndex);
    orderedIds.insert(targetIndex, movedId);
    await _database.reorderPhotos(photo.locationId, orderedIds);
    if (mounted) setState(() => _photosFuture = _database.listPhotos(photo.locationId));
  }

  Future<void> _deletePhoto(DocumentedPhoto photo) async {
    final confirmed = await showProConfirmDialog(
      context: context,
      title: 'Hapus foto dokumentasi?',
      message: 'Foto dihapus dari dokumentasi kegiatan. Salinan di galeri tidak ikut dihapus.',
      confirmText: 'Hapus foto',
      cancelText: 'Batal',
      type: ProMessageType.error,
    );
    if (!confirmed) return;
    try {
      await _database.deletePhoto(photo.id);
      await _photoStorage.deleteManagedPhoto(photo.filePath);
      final remaining = await _database.listPhotos(photo.locationId);
      await _database.reorderPhotos(photo.locationId, remaining.map((item) => item.id).toList());
      if (mounted) {
        setState(() => _photosFuture = _database.listPhotos(photo.locationId));
        await showProMessageDialog(
          context: context,
          title: 'Foto berhasil dihapus',
          message: 'Foto dihapus dari dokumentasi kegiatan.',
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

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final file = await ProPdfExportService(_database).exportTrip(widget.trip);
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.uri.pathSegments.last);
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'PDF belum dapat dibuat',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(Scaffold(
      appBar: AppBar(title: const Text('Detail kegiatan')),
      floatingActionButton: _location == null ? null : FloatingActionButton.extended(
        onPressed: _isTakingPhoto ? null : _takePhoto,
        icon: _isTakingPhoto
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.camera_alt_outlined),
        label: Text(_isTakingPhoto ? 'Menyimpan...' : 'Ambil Foto'),
      ),
      body: FutureBuilder<List<VisitLocation>>(
        future: _locationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Gagal memuat kegiatan: ${snapshot.error}'));
          final locations = snapshot.data ?? const <VisitLocation>[];
          if (locations.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Lokasi kegiatan belum tersedia. Buat kegiatan baru dengan mengisi lokasi awal.'),
            ));
          }
          final location = locations.first;
          if (_location?.id != location.id) _loadPhotos(location);
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _reload();
                _photosFuture = _database.listPhotos(location.id);
              });
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('RINGKASAN KEGIATAN', style: TextStyle(
                      color: ProTheme.primaryDark, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.7,
                    )),
                    const SizedBox(height: 12),
                    Text(widget.trip.title, style: const TextStyle(
                      color: ProTheme.text, fontSize: 22, height: 1.2, fontWeight: FontWeight.w800,
                    )),
                    if (widget.trip.purpose.trim().isNotEmpty && widget.trip.purpose.trim() != widget.trip.title.trim()) ...[
                      const SizedBox(height: 8),
                      Text(widget.trip.purpose, style: const TextStyle(color: ProTheme.secondaryText, fontSize: 14, height: 1.5)),
                    ],
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _InfoChip(icon: Icons.calendar_month_outlined, text: '${_dateLabel(widget.trip.startDate)} – ${_dateLabel(widget.trip.endDate)}'),
                      if (widget.trip.assignmentNumber?.isNotEmpty == true)
                        _InfoChip(icon: Icons.description_outlined, text: widget.trip.assignmentNumber!),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: ProTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: ProTheme.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.location_on_outlined, color: ProTheme.brandGreen),
                      SizedBox(width: 8),
                      Text('Lokasi kegiatan', style: TextStyle(color: ProTheme.text, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                    const SizedBox(height: 10),
                    Text(location.name, style: const TextStyle(color: ProTheme.text, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(location.address?.trim().isNotEmpty == true ? location.address! : 'Alamat belum tersedia', style: const TextStyle(color: ProTheme.secondaryText, fontSize: 13, height: 1.4)),
                    if (location.latitude != null && location.longitude != null) ...[
                      const SizedBox(height: 6),
                      Text('${location.latitude}, ${location.longitude}', style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12)),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Text('Foto dokumentasi', style: TextStyle(color: ProTheme.text, fontSize: 19, fontWeight: FontWeight.w800))),
                  FutureBuilder<List<DocumentedPhoto>>(
                    future: _photosFuture,
                    builder: (_, photoSnapshot) => Text('${photoSnapshot.data?.length ?? 0} foto', style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text('Semua foto kegiatan tersimpan di halaman ini. Tambahkan keterangan dan pilih foto untuk laporan PDF.', style: TextStyle(color: ProTheme.secondaryText, fontSize: 12, height: 1.45)),
                const SizedBox(height: 12),
                FutureBuilder<List<DocumentedPhoto>>(
                  future: _photosFuture,
                  builder: (context, photoSnapshot) {
                    if (photoSnapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                    if (photoSnapshot.hasError) return Text('Gagal memuat foto: ${photoSnapshot.error}');
                    final photos = photoSnapshot.data ?? const <DocumentedPhoto>[];
                    if (photos.isEmpty) return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: ProTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: ProTheme.border)),
                      child: Column(children: [
                        const Icon(Icons.add_a_photo_outlined, size: 42, color: ProTheme.primaryDark),
                        const SizedBox(height: 10),
                        const Text('Belum ada foto', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Tekan Ambil Foto untuk mulai mendokumentasikan kegiatan.', textAlign: TextAlign.center, style: TextStyle(color: ProTheme.secondaryText)),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: _isTakingPhoto ? null : _takePhoto, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Ambil Foto')),
                      ]),
                    );
                    return Column(children: photos.map((photo) => Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        AspectRatio(aspectRatio: 16 / 9, child: File(photo.filePath).existsSync() ? Image.file(File(photo.filePath), fit: BoxFit.cover) : const Center(child: Text('File foto tidak ditemukan'))),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: InkWell(
                              onTap: () => _editCaption(photo),
                              child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(photo.caption?.isNotEmpty == true ? photo.caption! : 'Tambah keterangan foto', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: photo.caption?.isNotEmpty == true ? ProTheme.text : ProTheme.secondaryText, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 5),
                                Text(photo.capturedAt == null ? 'Waktu tidak tersedia' : _dateTimeLabel(photo.capturedAt!), style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12)),
                                if (photo.address?.isNotEmpty == true) Text(photo.address!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12)),
                              ])),
                            )),
                            Column(children: [
                              Checkbox(value: photo.includeInReport, onChanged: (value) async {
                                await _database.setPhotoIncludedInReport(photo.id, value ?? false);
                                if (mounted) setState(() => _photosFuture = _database.listPhotos(location.id));
                              }),
                              const Text('PDF', style: TextStyle(color: ProTheme.secondaryText, fontSize: 10)),
                            ]),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'caption') _editCaption(photo);
                                if (value == 'up') _movePhoto(photo, -1, photos);
                                if (value == 'down') _movePhoto(photo, 1, photos);
                                if (value == 'delete') _deletePhoto(photo);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'caption', child: Text('Ubah keterangan')),
                                PopupMenuItem(value: 'up', enabled: photo.sortOrder > 0, child: const Text('Pindahkan ke atas')),
                                PopupMenuItem(value: 'down', enabled: photo.sortOrder < photos.length - 1, child: const Text('Pindahkan ke bawah')),
                                const PopupMenuItem(value: 'delete', child: Text('Hapus foto')),
                              ],
                            ),
                          ]),
                        ),
                      ]),
                    )).toList());
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _isExporting ? null : _exportPdf,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  icon: _isExporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_isExporting ? 'Menyiapkan PDF...' : 'Ekspor Dokumentasi PDF'),
                )),
              ],
            ),
          );
        },
      ),
    ));
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: ProTheme.background, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: ProTheme.secondaryText),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: const TextStyle(color: ProTheme.text, fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Keterangan foto'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Contoh: Kondisi objek saat monitoring'),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
      FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text.trim()), child: const Text('Simpan')),
    ],
  );
}

String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _dateTimeLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${_dateLabel(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
