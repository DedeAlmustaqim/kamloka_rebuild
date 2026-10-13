import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../location/services/location_service.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';
import '../services/pro_database_service.dart';
import '../services/pro_pdf_export_service.dart';
import '../theme/pro_theme.dart';
import 'pro_location_detail_screen.dart';

class ProTripDetailScreen extends StatefulWidget {
  const ProTripDetailScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<ProTripDetailScreen> createState() => _ProTripDetailScreenState();
}

class _ProTripDetailScreenState extends State<ProTripDetailScreen> {
  final _database = Get.find<ProDatabaseService>();
  final _uuid = const Uuid();
  late Future<List<VisitLocation>> _locationsFuture;
  bool _isExporting = false;

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
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= locations.length) return;

    final orderedIds = locations.map((item) => item.id).toList();
    final movedId = orderedIds.removeAt(currentIndex);
    orderedIds.insert(targetIndex, movedId);
    await _database.reorderLocations(widget.trip.id, orderedIds);
    if (mounted) setState(_reload);
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
        Get.snackbar('PDF belum dapat dibuat', error.toString());
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _addLocation() async {
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
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(
          title: const Text('Detail perjalanan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor dokumentasi PDF',
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
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
            return Center(child: Text('Gagal memuat lokasi: ${snapshot.error}'));
          }

          final locations = snapshot.data ?? const <VisitLocation>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.trip.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(widget.trip.purpose),
                      const SizedBox(height: 8),
                      Text(
                        '${_dateLabel(widget.trip.startDate)} – ${_dateLabel(widget.trip.endDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ProTheme.secondaryText),
                      ),
                      if (widget.trip.assignmentNumber?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('Surat tugas: ${widget.trip.assignmentNumber}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Lokasi kunjungan', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Belum ada lokasi. Tambahkan lokasi pertama untuk mulai mendokumentasikan kegiatan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                ...locations.map((location) => Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${location.sortOrder + 1}')),
                        title: Text(location.name),
                        subtitle: Text(
                          location.address ?? 'Alamat tidak tersedia',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Naikkan urutan',
                              visualDensity: VisualDensity.compact,
                              onPressed: location.sortOrder <= 0
                                  ? null
                                  : () => _moveLocation(location, -1),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Turunkan urutan',
                              visualDensity: VisualDensity.compact,
                              onPressed: location.sortOrder >= locations.length - 1
                                  ? null
                                  : () => _moveLocation(location, 1),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () async {
                          await Get.to(() => ProLocationDetailScreen(
                                trip: widget.trip,
                                location: location,
                              ));
                          if (mounted) setState(_reload);
                        },
                      ),
                    )),
            ],
          );
        },
      ),
    ));
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

    Navigator.of(context).pop(
      _NewLocationInput(name: name, notes: _notesController.text),
    );
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
                hintText: 'Contoh: Ruas jalan Desa Sumber Garunggung',
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white60),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

