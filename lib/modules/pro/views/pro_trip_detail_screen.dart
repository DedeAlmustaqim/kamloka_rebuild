import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../location/services/location_service.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';
import '../services/pro_database_service.dart';
import '../services/pro_pdf_export_service.dart';
import '../services/pro_photo_storage_service.dart';
import '../theme/pro_theme.dart';
import '../widgets/pro_message_dialog.dart';
import 'pro_location_detail_screen.dart';

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
  bool _isExporting = false;
  bool _isAddingLocation = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _locationsFuture = _database.listLocations(widget.trip.id);
  }

  Future<void> _moveLocation(VisitLocation location, int offset) async {
    final locations = await _database.listLocations(widget.trip.id);
    final currentIndex = locations.indexWhere((item) => item.id == location.id);
    final targetIndex = currentIndex + offset;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= locations.length)
      return;

    final orderedIds = locations.map((item) => item.id).toList();
    final movedId = orderedIds.removeAt(currentIndex);
    orderedIds.insert(targetIndex, movedId);
    await _database.reorderLocations(widget.trip.id, orderedIds);
    if (mounted) setState(_reload);
  }

  Future<void> _deleteLocation(VisitLocation location) async {
    final photos = await _database.listPhotos(location.id);
    final confirmed = await showProConfirmDialog(
      context: context,
      title: 'Hapus lokasi kunjungan?',
      message: photos.isEmpty
          ? 'Lokasi “${location.name}” akan dihapus dari perjalanan ini.'
          : 'Lokasi “${location.name}” dan ${photos.length} foto dokumentasi di dalamnya akan dihapus. Salinan foto di galeri tidak ikut dihapus.',
      confirmText: 'Hapus lokasi',
      cancelText: 'Batal',
      type: ProMessageType.error,
    );
    if (!confirmed) return;

    try {
      // Remove managed photo files before deleting their database records.
      for (final photo in photos) {
        await _photoStorage.deleteManagedPhoto(photo.filePath);
      }
      await _database.deleteLocation(location.id);
      final remaining = await _database.listLocations(widget.trip.id);
      await _database.reorderLocations(
        widget.trip.id,
        remaining.map((item) => item.id).toList(),
      );
      if (!mounted) return;
      setState(_reload);
      await showProMessageDialog(
        context: context,
        title: 'Lokasi berhasil dihapus',
        message: 'Lokasi dan dokumentasi yang terkait telah dihapus dari perjalanan.',
        type: ProMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Lokasi belum berhasil dihapus',
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
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: file.uri.pathSegments.last,
      );
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

  Future<void> _addLocation() async {
    if (_isAddingLocation) return;
    setState(() => _isAddingLocation = true);

    try {
      final locationService = Get.find<LocationService>();
      final currentPosition = locationService.position.value;
      final currentAddress = locationService.address.value.trim();

      // The dialog owns its text controllers and disposes them with its State.
      // This avoids disposing controllers while the dialog route is still closing.
      final result = await showDialog<_NewLocationInput>(
        context: context,
        builder: (_) => _AddLocationDialog(currentAddress: currentAddress),
      );
      if (result == null) return;

      final existing = await _database.listLocations(widget.trip.id);
      await _database.saveLocation(
        VisitLocation(
          id: _uuid.v4(),
          tripId: widget.trip.id,
          name: result.name,
          address: currentAddress.isEmpty ? null : currentAddress,
          latitude: currentPosition?.latitude,
          longitude: currentPosition?.longitude,
          visitedAt: DateTime.now(),
          notes: _nullableText(result.notes),
          sortOrder: existing.length,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(_reload);
        await showProMessageDialog(
          context: context,
          title: 'Lokasi berhasil ditambahkan',
          message: 'Lokasi kunjungan siap diisi dengan foto dan catatan dokumentasi.',
          type: ProMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Lokasi belum berhasil disimpan',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(
          title: const Text('Detail perjalanan'),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isAddingLocation ? null : _addLocation,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Tambah Lokasi'),
        ),
        body: FutureBuilder<List<VisitLocation>>(
          future: _locationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Gagal memuat lokasi: ${snapshot.error}'),
              );
            }

            final locations = snapshot.data ?? const <VisitLocation>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ProTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ProTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2C8),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'RINGKASAN PERJALANAN',
                          style: TextStyle(
                            color: ProTheme.primaryDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.trip.title,
                        style: const TextStyle(
                          color: ProTheme.text,
                          fontSize: 22,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.trip.purpose,
                        style: const TextStyle(
                          color: ProTheme.secondaryText,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: ProTheme.background,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: ProTheme.secondaryText,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _dateLabel(widget.trip.startDate) +
                                  ' – ' +
                                  _dateLabel(widget.trip.endDate),
                              style: const TextStyle(
                                color: ProTheme.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.trip.assignmentNumber?.isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 17,
                              color: ProTheme.secondaryText,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Nomor surat tugas',
                              style: TextStyle(
                                color: ProTheme.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.trip.assignmentNumber!,
                          style: const TextStyle(
                            color: ProTheme.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isExporting ? null : _exportPdf,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(
                      _isExporting ? 'Menyiapkan PDF...' : 'Ekspor Dokumentasi PDF',
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Lokasi kunjungan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (locations.isEmpty)
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
                            Icons.add_location_alt_outlined,
                            size: 29,
                            color: ProTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Belum ada lokasi',
                          style: TextStyle(
                            color: ProTheme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tambahkan lokasi pertama agar foto dan catatan kegiatan tersusun rapi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ProTheme.secondaryText,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isAddingLocation ? null : _addLocation,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Tambah lokasi pertama'),
                        ),
                      ],
                    ),
                  )
                else
                  ...locations.map(
                    (location) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${location.sortOrder + 1}'),
                        ),
                        title: Text(location.name),
                        subtitle: Text(
                          location.address ?? 'Alamat tidak tersedia',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Atur urutan lokasi',
                              onSelected: (value) {
                                if (value == 'up') _moveLocation(location, -1);
                                if (value == 'down') _moveLocation(location, 1);
                                if (value == 'delete') _deleteLocation(location);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'up',
                                  enabled: location.sortOrder > 0,
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Pindahkan ke atas'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'down',
                                  enabled:
                                      location.sortOrder < locations.length - 1,
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Pindahkan ke bawah'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        color: ProTheme.danger,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Hapus lokasi'),
                                    ],
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_vert_rounded),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: ProTheme.secondaryText,
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Get.to(
                            () => ProLocationDetailScreen(
                              trip: widget.trip,
                              location: location,
                            ),
                          );
                          if (mounted) setState(_reload);
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _NewLocationInput {
  const _NewLocationInput({required this.name, required this.notes});

  final String name;
  final String notes;
}

class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog({required this.currentAddress});

  final String currentAddress;

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama lokasi wajib diisi.');
      return;
    }

    Navigator.of(
      context,
    ).pop(_NewLocationInput(name: name, notes: _notesController.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah lokasi kunjungan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: InputDecoration(
                labelText: 'Nama lokasi *',
                hintText: 'Contoh: Ruas jalan A, Kantor B',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.currentAddress.isEmpty
                    ? 'Alamat GPS belum tersedia.'
                    : widget.currentAddress,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ProTheme.secondaryText),
              ),
            ),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan lokasi (opsional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
