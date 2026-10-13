import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/trip.dart';
import '../services/pro_photo_storage_service.dart';
import '../services/pro_database_service.dart';
import 'pro_trip_detail_screen.dart';

class ProTripsScreen extends StatefulWidget {
  const ProTripsScreen({super.key});

  @override
  State<ProTripsScreen> createState() => _ProTripsScreenState();
}

class _ProTripsScreenState extends State<ProTripsScreen> {
  final _database = Get.find<ProDatabaseService>();
  final _uuid = const Uuid();
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _tripsFuture = _database.listTrips();
  }

  Future<void> _createTrip() async {
    final titleController = TextEditingController();
    final purposeController = TextEditingController();
    final officerController = TextEditingController();
    final assignmentController = TextEditingController();
    final notesController = TextEditingController();
    var startDate = DateTime.now();
    var endDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Perjalanan dinas baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama kegiatan *',
                    hintText: 'Contoh: Monitoring pembangunan',
                  ),
                ),
                TextField(
                  controller: purposeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Tujuan kegiatan *'),
                ),
                TextField(
                  controller: officerController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nama pelaksana (opsional)'),
                ),
                TextField(
                  controller: assignmentController,
                  decoration: const InputDecoration(labelText: 'Nomor surat tugas (opsional)'),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Catatan umum (opsional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            helpText: 'Tanggal mulai',
                          );
                          if (selected != null) {
                            setDialogState(() {
                              startDate = selected;
                              if (endDate.isBefore(startDate)) endDate = startDate;
                            });
                          }
                        },
                        child: Text('Mulai\n${_dateLabel(startDate)}', textAlign: TextAlign.center),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                            helpText: 'Tanggal selesai',
                          );
                          if (selected != null) setDialogState(() => endDate = selected);
                        },
                        child: Text('Selesai\n${_dateLabel(endDate)}', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
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
                if (titleController.text.trim().isEmpty ||
                    purposeController.text.trim().isEmpty) {
                  Get.snackbar('Data belum lengkap', 'Nama kegiatan dan tujuan wajib diisi.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final now = DateTime.now();
      await _database.saveTrip(
        Trip(
          id: _uuid.v4(),
          title: titleController.text.trim(),
          purpose: purposeController.text.trim(),
          startDate: startDate,
          endDate: endDate,
          officerName: _nullableText(officerController.text),
          assignmentNumber: _nullableText(assignmentController.text),
          notes: _nullableText(notesController.text),
          status: 'draft',
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (mounted) setState(_reload);
    }

    titleController.dispose();
    purposeController.dispose();
    officerController.dispose();
    assignmentController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus perjalanan?'),
        content: Text('Perjalanan "${trip.title}" dan metadata lokasi/fotonya akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final photos = await _database.listPhotosForTrip(trip.id);
      final storage = Get.find<ProPhotoStorageService>();
      for (final photo in photos) {
        await storage.deleteManagedPhoto(photo.filePath);
      }
      await _database.deleteTrip(trip.id);
      if (mounted) setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perjalanan Dinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTrip,
        icon: const Icon(Icons.add),
        label: const Text('Perjalanan Baru'),
      ),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat perjalanan: ${snapshot.error}'));
          }
          final trips = snapshot.data ?? const <Trip>[];
          if (trips.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 56, color: Colors.white54),
                    SizedBox(height: 14),
                    Text('Belum ada perjalanan dinas', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                      'Buat perjalanan untuk mulai mengelompokkan lokasi dan foto dokumentasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.work_outline)),
                  title: Text(trip.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_dateLabel(trip.startDate)} – ${_dateLabel(trip.endDate)}\n${trip.purpose}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _deleteTrip(trip);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                  onTap: () async {
                    await Get.to(() => ProTripDetailScreen(trip: trip));
                    if (mounted) setState(_reload);
                  },
                ),
              );
            },
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
