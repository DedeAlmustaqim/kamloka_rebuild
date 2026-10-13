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
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final locationService = Get.find<LocationService>();
    final currentPosition = locationService.position.value;
    final currentAddress = locationService.address.value.trim();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah lokasi kunjungan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama lokasi *',
                  hintText: 'Contoh: Ruas jalan Desa Sumber Garunggung',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  currentAddress.isEmpty ? 'Alamat GPS belum tersedia.' : currentAddress,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Catatan lokasi (opsional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                Get.snackbar('Nama lokasi wajib diisi', 'Masukkan nama lokasi kunjungan.');
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true) {
      final existing = await _database.listLocations(widget.trip.id);
      await _database.saveLocation(
        VisitLocation(
          id: _uuid.v4(),
          tripId: widget.trip.id,
          name: nameController.text.trim(),
          address: currentAddress.isEmpty ? null : currentAddress,
          latitude: currentPosition?.latitude,
          longitude: currentPosition?.longitude,
          visitedAt: DateTime.now(),
          notes: _nullableText(notesController.text),
          sortOrder: existing.length,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) setState(_reload);
    }

    nameController.dispose();
    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Perjalanan'),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
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
              Text('LOKASI KUNJUNGAN', style: Theme.of(context).textTheme.labelLarge),
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
                        trailing: const Icon(Icons.chevron_right),
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
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
