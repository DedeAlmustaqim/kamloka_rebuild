import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/trip.dart';
import '../services/pro_database_service.dart';
import '../services/pro_photo_storage_service.dart';
import '../theme/pro_theme.dart';
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
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _tripsFuture = _database.listTrips();
  }

  Future<void> _createTrip() async {
    if (_isCreating) return;
    final draft = await showModalBottomSheet<_TripDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ProTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _CreateTripSheet(),
    );
    if (draft == null) return;

    setState(() => _isCreating = true);
    try {
      final now = DateTime.now();
      await _database.saveTrip(
        Trip(
          id: _uuid.v4(),
          title: draft.title,
          purpose: draft.purpose,
          startDate: draft.startDate,
          endDate: draft.endDate,
          officerName: _nullableText(draft.officerName),
          assignmentNumber: _nullableText(draft.assignmentNumber),
          notes: _nullableText(draft.notes),
          status: 'draft',
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (mounted) {
        setState(_reload);
        Get.snackbar('Perjalanan dibuat', 'Kegiatan siap untuk didokumentasikan.');
      }
    } catch (error) {
      if (mounted) Get.snackbar('Belum berhasil menyimpan', error.toString());
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus perjalanan?'),
        content: Text(
          '“${trip.title}” beserta lokasi, foto dokumentasi, dan datanya akan dihapus dari KAMLOKA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Jangan hapus'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus perjalanan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final photos = await _database.listPhotosForTrip(trip.id);
      final storage = Get.find<ProPhotoStorageService>();
      for (final photo in photos) {
        await storage.deleteManagedPhoto(photo.filePath);
      }
      await _database.deleteTrip(trip.id);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) Get.snackbar('Gagal menghapus perjalanan', error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(
          title: const Text('Perjalanan Saya'),
          actions: [
            IconButton(
              tooltip: 'Buat perjalanan',
              onPressed: _isCreating ? null : _createTrip,
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isCreating ? null : _createTrip,
          icon: _isCreating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(_isCreating ? 'Menyimpan...' : 'Perjalanan Baru'),
        ),
        body: FutureBuilder<List<Trip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                message: 'Perjalanan belum dapat dimuat.',
                onRetry: () => setState(_reload),
              );
            }

            final trips = snapshot.data ?? const <Trip>[];
            return RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
                children: [
                  const Text(
                    'Dokumentasi kegiatan lapangan',
                    style: TextStyle(
                      color: ProTheme.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Satukan lokasi, foto, dan laporan setiap perjalanan dalam satu tempat.',
                    style: TextStyle(
                      color: ProTheme.secondaryText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SummaryCard(
                    count: trips.length,
                    onCreate: _isCreating ? null : _createTrip,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Perjalanan',
                          style: TextStyle(
                            color: ProTheme.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${trips.length} kegiatan',
                        style: const TextStyle(
                          color: ProTheme.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (trips.isEmpty)
                    _EmptyTrips(onCreate: _createTrip)
                  else
                    ...trips.map(
                      (trip) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: trip,
                          onDelete: () => _deleteTrip(trip),
                          onOpen: () async {
                            await Get.to(
                              () => ProTripDetailScreen(trip: trip),
                              transition: Transition.cupertino,
                            );
                            if (mounted) setState(_reload);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.onCreate});

  final int count;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE69A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.folder_copy_outlined,
              color: ProTheme.text,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count perjalanan tersimpan',
                  style: const TextStyle(
                    color: ProTheme.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mulai dokumentasi kegiatan berikutnya.',
                  style: TextStyle(color: ProTheme.text, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton.filled(
            tooltip: 'Buat perjalanan',
            onPressed: onCreate,
            style: IconButton.styleFrom(
              backgroundColor: ProTheme.text,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onOpen,
    required this.onDelete,
  });

  final Trip trip;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2C8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: ProTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      trip.purpose,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProTheme.secondaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: _dateRange(trip.startDate, trip.endDate),
                        ),
                        if (trip.assignmentNumber?.isNotEmpty == true)
                          _MetaChip(
                            icon: Icons.description_outlined,
                            label: trip.assignmentNumber!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Pilihan perjalanan',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: ProTheme.danger),
                        SizedBox(width: 10),
                        Text('Hapus perjalanan'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: ProTheme.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ProTheme.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ProTheme.secondaryText),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ProTheme.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProTheme.border),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF2C8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 31,
              color: ProTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada perjalanan',
            style: TextStyle(
              color: ProTheme.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Buat perjalanan pertama untuk mulai menyimpan lokasi dan foto dokumentasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ProTheme.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Buat perjalanan pertama'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: ProTheme.secondaryText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripDraft {
  const _TripDraft({
    required this.title,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    required this.officerName,
    required this.assignmentNumber,
    required this.notes,
  });

  final String title;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate;
  final String officerName;
  final String assignmentNumber;
  final String notes;
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet();

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _purpose = TextEditingController();
  final _officer = TextEditingController();
  final _assignment = TextEditingController();
  final _notes = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showOptional = false;

  @override
  void dispose() {
    _title.dispose();
    _purpose.dispose();
    _officer.dispose();
    _assignment.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate.isBefore(_startDate) ? _startDate : _endDate),
      firstDate: isStart ? DateTime(2000) : _startDate,
      lastDate: DateTime(2100),
      helpText: isStart ? 'Pilih tanggal mulai' : 'Pilih tanggal selesai',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = selected;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = selected;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TripDraft(
        title: _title.text.trim(),
        purpose: _purpose.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        officerName: _officer.text,
        assignmentNumber: _assignment.text,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ProTheme.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Perjalanan baru',
                  style: TextStyle(
                    color: ProTheme.text,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Isi informasi utama dulu. Detail lainnya bisa ditambahkan jika diperlukan.',
                  style: TextStyle(color: ProTheme.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nama kegiatan *',
                    hintText: 'Contoh: Monitoring pembangunan',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama kegiatan wajib diisi.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purpose,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Tujuan kegiatan *',
                    hintText: 'Apa yang ingin dicapai?',
                    prefixIcon: Icon(Icons.flag_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Tujuan kegiatan wajib diisi.'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jadwal perjalanan',
                  style: TextStyle(color: ProTheme.text, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Mulai',
                        date: _startDate,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateButton(
                        label: 'Selesai',
                        date: _endDate,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _showOptional = !_showOptional),
                  icon: Icon(_showOptional ? Icons.remove_circle_outline : Icons.add_circle_outline),
                  label: Text(_showOptional ? 'Sembunyikan detail opsional' : 'Tambah detail opsional'),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
                if (_showOptional) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _officer,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama pelaksana',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assignment,
                    decoration: const InputDecoration(
                      labelText: 'Nomor surat tugas',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan umum',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Simpan perjalanan'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12)),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dateLabel(date),
                  style: const TextStyle(color: ProTheme.text, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${_monthLabel(date.month)} ${date.year}';

String _dateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return _dateLabel(start);
  }
  return '${start.day.toString().padLeft(2, '0')} ${_monthLabel(start.month)} – '
      '${end.day.toString().padLeft(2, '0')} ${_monthLabel(end.month)} ${end.year}';
}

String _monthLabel(int month) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ][month - 1];

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
