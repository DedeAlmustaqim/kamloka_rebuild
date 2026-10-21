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
      appBar: AppBar(
        title: const Text('Detail kegiatan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor PDF',
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _location == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isTakingPhoto ? null : _takePhoto,
              icon: _isTakingPhoto
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_isTakingPhoto ? 'Menyimpan foto...' : 'Ambil Foto'),
            ),
      body: FutureBuilder<List<VisitLocation>>(
        future: _locationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Gagal memuat kegiatan: ${snapshot.error}', textAlign: TextAlign.center),
            ));
          }
          final locations = snapshot.data ?? const <VisitLocation>[];
          if (locations.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Lokasi kegiatan belum tersedia. Buat kegiatan baru dengan mengisi lokasi awal.', textAlign: TextAlign.center),
            ));
          }

          final location = locations.first;
          if (_location?.id != location.id) _loadPhotos(location);

          return RefreshIndicator(
            onRefresh: () async {
              final refreshedLocations = _database.listLocations(widget.trip.id);
              final refreshedPhotos = _database.listPhotos(location.id);
              setState(() {
                _locationsFuture = refreshedLocations;
                _photosFuture = refreshedPhotos;
              });
              await Future.wait([refreshedLocations, refreshedPhotos]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0C5A3E), Color(0xFF174A37)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('DETAIL KEGIATAN', style: TextStyle(color: Color(0xFFD9E7DF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                    const SizedBox(height: 8),
                    Text(widget.trip.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.2, fontWeight: FontWeight.w800)),
                    if (widget.trip.purpose.trim().isNotEmpty && widget.trip.purpose.trim() != widget.trip.title.trim()) ...[
                      const SizedBox(height: 4),
                      Text(widget.trip.purpose, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD9E7DF), fontSize: 11)),
                    ],
                    const SizedBox(height: 9),
                    Row(children: [
                      const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFFE4B957)),
                      const SizedBox(width: 7),
                      Expanded(child: Text('${_dateLabel(widget.trip.startDate)} – ${_dateLabel(widget.trip.endDate)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                    ]),
                    if (widget.trip.assignmentNumber?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text('No. surat: ${widget.trip.assignmentNumber}', style: const TextStyle(color: Color(0xFFD9E7DF), fontSize: 10)),
                    ],
                    Padding(padding: const EdgeInsets.symmetric(vertical: 11), child: Container(height: 1, color: Colors.white.withValues(alpha: 0.18))),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.location_on_rounded, size: 17, color: Color(0xFFE4B957)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(location.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(location.address?.trim().isNotEmpty == true ? location.address! : 'Alamat belum tersedia', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD9E7DF), fontSize: 11, height: 1.35)),
                        if (location.latitude != null && location.longitude != null) ...[
                          const SizedBox(height: 4),
                          Text('${location.latitude!.toStringAsFixed(6)}, ${location.longitude!.toStringAsFixed(6)}', style: const TextStyle(color: Color(0xFFB9D0C3), fontSize: 9)),
                        ],
                      ])),
                    ]),
                    const SizedBox(height: 13),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: _isExporting ? null : _exportPdf,
                      icon: _isExporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C5A3E))) : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text(_isExporting ? 'Menyiapkan PDF...' : 'Ekspor laporan PDF'),
                      style: FilledButton.styleFrom(foregroundColor: const Color(0xFF0C5A3E), backgroundColor: Colors.white, minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                    )),
                  ]),
                ),
                const SizedBox(height: 22),

                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Dokumentasi foto', style: TextStyle(color: ProTheme.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    SizedBox(height: 3),
                    Text('Kumpulkan bukti kegiatan di sini', style: TextStyle(color: ProTheme.secondaryText, fontSize: 12)),
                  ])),
                  FutureBuilder<List<DocumentedPhoto>>(
                    future: _photosFuture,
                    builder: (_, photoSnapshot) {
                      final count = photoSnapshot.data?.length ?? 0;
                      final selected = photoSnapshot.data?.where((photo) => photo.includeInReport).length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: const Color(0xFFE7F2EC), borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$count foto', style: const TextStyle(color: ProTheme.brandGreen, fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('$selected untuk PDF', style: const TextStyle(color: ProTheme.secondaryText, fontSize: 9)),
                        ]),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 12),
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
