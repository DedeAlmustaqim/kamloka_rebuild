import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trip.dart';
import '../models/visit_location.dart';
import '../services/pro_access_service.dart';
import '../services/pro_database_service.dart';
import '../services/pro_photo_storage_service.dart';
import '../theme/pro_theme.dart';
import '../widgets/pro_message_dialog.dart';
import 'pro_trip_detail_screen.dart';

class ProTripsScreen extends StatefulWidget {
  const ProTripsScreen({super.key});

  @override
  State<ProTripsScreen> createState() => _ProTripsScreenState();
}

class _ProTripsScreenState extends State<ProTripsScreen> {
  final _database = Get.find<ProDatabaseService>();
  final _uuid = const Uuid();
  late Future<List<_TripSummary>> _tripsFuture;
  bool _isCreating = false;
  final _searchController = TextEditingController();
  String _tripFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _tripsFuture = _loadTripSummaries();
  }

  Future<List<_TripSummary>> _loadTripSummaries() async {
    final trips = await _database.listTrips();
    final locationsByTrip = await Future.wait(
      trips.map((trip) => _database.listLocations(trip.id)),
    );
    return [
      for (var index = 0; index < trips.length; index++)
        _TripSummary(trip: trips[index], locations: locationsByTrip[index]),
    ];
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
      final trip = Trip(
        id: _uuid.v4(),
        title: draft.title,
        // Keep the existing database field populated for backward compatibility.
        purpose: draft.title,
        startDate: draft.startDate,
        endDate: draft.endDate,
        officerName: _nullableText(draft.officerName),
        assignmentNumber: _nullableText(draft.assignmentNumber),
        notes: _nullableText(draft.notes),
        status: 'single_location',
        createdAt: now,
        updatedAt: now,
      );
      await _database.saveTripWithInitialLocation(
        trip,
        VisitLocation(
          id: _uuid.v4(),
          tripId: trip.id,
          name: draft.locationName,
          address: _nullableText(draft.locationAddress),
          latitude: draft.latitude,
          longitude: draft.longitude,
          visitedAt: draft.startDate,
          notes: null,
          sortOrder: 0,
          createdAt: now,
        ),
      );
      if (mounted) {
        setState(_reload);
        await showProMessageDialog(
          context: context,
          title: 'Kegiatan berhasil dibuat',
          message:
              'Kegiatan dan lokasi awal sudah tersimpan. Anda dapat menambahkan beberapa foto pada lokasi ini.',
          type: ProMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Belum berhasil menyimpan',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showProConfirmDialog(
      context: context,
      title: 'Hapus perjalanan?',
      message:
          '“${trip.title}” beserta lokasi, foto dokumentasi, dan datanya akan dihapus dari KAMLOKA. Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      cancelText: 'Jangan hapus',
      type: ProMessageType.error,
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
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Gagal menghapus perjalanan',
          message: error.toString(),
          type: ProMessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = Get.find<ProAccessService>();
    if (!access.hasAccess(KamlokaFeature.fieldDocumentation)) {
      return ProTheme.apply(
        Scaffold(
          appBar: AppBar(title: const Text('Dokumentasi PRO')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 54,
                    color: ProTheme.secondaryText,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Dokumentasi lapangan adalah fitur PRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ProTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aktifkan mode PRO melalui Pengaturan saat pengembangan, atau gunakan akses PRO setelah pembelian tersedia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ProTheme.secondaryText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: Get.back,
                    child: const Text('Kembali ke pengaturan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(title: const Text('Dokumentasi Lapangan')),
        body: FutureBuilder<List<_TripSummary>>(
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

            final summaries = snapshot.data ?? const <_TripSummary>[];
            final trips = summaries.map((summary) => summary.trip).toList();
            final summaryByTripId = {
              for (final summary in summaries) summary.trip.id: summary,
            };
            final query = _searchController.text.trim().toLowerCase();
            final visibleTrips = trips
                .where((trip) {
                  final matchesQuery =
                      trip.title.toLowerCase().contains(query) ||
                      (trip.assignmentNumber ?? '').toLowerCase().contains(
                        query,
                      );
                  final matchesFilter =
                      _tripFilter == 'Semua' ||
                      (_tripFilter == 'Satu hari'
                          ? trip.startDate.year == trip.endDate.year &&
                                trip.startDate.month == trip.endDate.month &&
                                trip.startDate.day == trip.endDate.day
                          : trip.startDate.year != trip.endDate.year ||
                                trip.startDate.month != trip.endDate.month ||
                                trip.startDate.day != trip.endDate.day);
                  return matchesQuery && matchesFilter;
                })
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async => setState(_reload),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perjalanan Saya',
                              style: TextStyle(
                                color: ProTheme.text,
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              trips.isEmpty
                                  ? 'Mulai dokumentasikan kegiatan lapangan Anda.'
                                  : 'Kelola kegiatan dan lanjutkan dokumentasinya.',
                              style: const TextStyle(
                                color: ProTheme.secondaryText,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F0E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: ProTheme.brandGreen,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (trips.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ProTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: ProTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.folder_copy_outlined,
                                color: ProTheme.brandGreen,
                                size: 18,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${trips.length} kegiatan tersimpan',
                                style: const TextStyle(
                                  color: ProTheme.secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Catat kegiatan berikutnya',
                            style: TextStyle(
                              color: ProTheme.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Buat kegiatan dan simpan lokasi awal untuk dokumentasinya.',
                            style: TextStyle(
                              color: ProTheme.secondaryText,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isCreating ? null : _createTrip,
                              icon: _isCreating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ProTheme.brandGreen,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded),
                              label: Text(
                                _isCreating
                                    ? 'Menyimpan...'
                                    : 'Buat kegiatan baru',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (trips.isNotEmpty) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Daftar kegiatan',
                            style: TextStyle(
                              color: ProTheme.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: ProTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ProTheme.border),
                          ),
                          child: Text(
                            '${visibleTrips.length} dari ${trips.length}',
                            style: const TextStyle(
                              color: ProTheme.secondaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari nama kegiatan atau surat tugas',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final filter in [
                          'Semua',
                          'Satu hari',
                          'Lebih dari sehari',
                        ])
                          ChoiceChip(
                            label: Text(filter),
                            selected: _tripFilter == filter,
                            onSelected: (_) =>
                                setState(() => _tripFilter = filter),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (trips.isEmpty)
                    _EmptyTrips(onCreate: _createTrip)
                  else if (visibleTrips.isEmpty)
                    const _NoTripResults()
                  else
                    ...visibleTrips.map(
                      (trip) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(
                          trip: trip,
                          primaryLocation:
                              summaryByTripId[trip.id]?.primaryLocation,
                          additionalLocationCount:
                              summaryByTripId[trip.id]
                                  ?.additionalLocationCount ??
                              0,
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
                  const SizedBox(height: 10),
                  if (trips.isNotEmpty)
                    const Text(
                      'Tip: ketuk kartu kegiatan untuk membuka detail dan melanjutkan dokumentasi foto.',
                      style: TextStyle(
                        color: ProTheme.secondaryText,
                        fontSize: 12,
                        height: 1.45,
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

class _TripSummary {
  const _TripSummary({required this.trip, required this.locations});

  final Trip trip;
  final List<VisitLocation> locations;

  VisitLocation? get primaryLocation =>
      locations.isEmpty ? null : locations.first;
  int get additionalLocationCount =>
      locations.length > 1 ? locations.length - 1 : 0;
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.primaryLocation,
    required this.additionalLocationCount,
    required this.onOpen,
    required this.onDelete,
  });

  final Trip trip;
  final VisitLocation? primaryLocation;
  final int additionalLocationCount;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (trip.purpose.trim().isNotEmpty &&
                        trip.purpose.trim() != trip.title.trim()) ...[
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
                    ] else
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
                    const SizedBox(height: 10),
                    _LocationSummary(
                      location: primaryLocation,
                      additionalLocationCount: additionalLocationCount,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          size: 15,
                          color: ProTheme.brandGreen,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'Ketuk untuk buka detail kegiatan',
                            style: TextStyle(
                              color: ProTheme.brandGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: ProTheme.brandGreen,
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
                        Icon(
                          Icons.delete_outline_rounded,
                          color: ProTheme.danger,
                        ),
                        SizedBox(width: 10),
                        Text('Hapus perjalanan'),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: ProTheme.secondaryText,
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ProTheme.background,
        borderRadius: BorderRadius.circular(8),
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

class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.location,
    required this.additionalLocationCount,
  });

  final VisitLocation? location;
  final int additionalLocationCount;

  @override
  Widget build(BuildContext context) {
    final currentLocation = location;
    if (currentLocation == null) {
      return const Row(
        children: [
          Icon(Icons.place_outlined, size: 16, color: ProTheme.secondaryText),
          SizedBox(width: 6),
          Text(
            'Lokasi belum ditambahkan',
            style: TextStyle(color: ProTheme.secondaryText, fontSize: 12),
          ),
        ],
      );
    }

    final address = currentLocation.address?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.place_outlined,
            size: 16,
            color: ProTheme.secondaryText,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currentLocation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProTheme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (additionalLocationCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '+$additionalLocationCount lokasi',
                      style: const TextStyle(
                        color: ProTheme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              if (address != null && address.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProTheme.secondaryText,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFE4F0E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                size: 34,
                color: ProTheme.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Mulai dari satu kegiatan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ProTheme.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Ikuti tiga langkah sederhana untuk membuat dokumentasi lapangan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ProTheme.secondaryText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const _GettingStartedStep(
            number: '1',
            title: 'Buat kegiatan',
            description: 'Isi nama kegiatan dan jadwalnya.',
          ),
          const SizedBox(height: 14),
          const _GettingStartedStep(
            number: '2',
            title: 'Tambahkan lokasi',
            description: 'Simpan tempat yang dikunjungi.',
          ),
          const SizedBox(height: 14),
          const _GettingStartedStep(
            number: '3',
            title: 'Ambil foto',
            description: 'Dokumentasikan kegiatan dengan kamera KAMLOKA.',
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat kegiatan pertama'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GettingStartedStep extends StatelessWidget {
  const _GettingStartedStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE4F0E9),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: ProTheme.brandGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ProTheme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: ProTheme.secondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoTripResults extends StatelessWidget {
  const _NoTripResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProTheme.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 34,
            color: ProTheme.secondaryText,
          ),
          SizedBox(height: 10),
          Text(
            'Kegiatan tidak ditemukan',
            style: TextStyle(
              color: ProTheme.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Coba kata kunci lain atau ubah filter tanggal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ProTheme.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
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
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: ProTheme.secondaryText,
            ),
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
    required this.startDate,
    required this.endDate,
    required this.officerName,
    required this.assignmentNumber,
    required this.notes,
    required this.locationName,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String officerName;
  final String assignmentNumber;
  final String notes;
  final String locationName;
  final String locationAddress;
  final double? latitude;
  final double? longitude;
}

class _CreateTripSheet extends StatefulWidget {
  const _CreateTripSheet();

  @override
  State<_CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<_CreateTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _officer = TextEditingController();
  final _assignment = TextEditingController();
  final _notes = TextEditingController();
  final _locationName = TextEditingController();
  final _locationAddress = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  bool _isGettingLocation = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showOptional = false;

  @override
  void dispose() {
    _title.dispose();
    _officer.dispose();
    _assignment.dispose();
    _notes.dispose();
    _locationName.dispose();
    _locationAddress.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate
          : (_endDate.isBefore(_startDate) ? _startDate : _endDate),
      firstDate: isStart ? DateTime(2000) : _startDate,
      lastDate: DateTime(2100),
      helpText: isStart ? 'Pilih tanggal mulai' : 'Pilih tanggal selesai',
      cancelText: 'Batal',
      confirmText: 'Pilih tanggal',
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

  void _setSchedule(int daysFromToday) {
    final today = DateTime.now();
    final date = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: daysFromToday));
    setState(() {
      _startDate = date;
      _endDate = date;
    });
  }

  Future<void> _captureGpsLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Layanan lokasi/GPS sedang dimatikan.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          permission == LocationPermission.deniedForever
              ? 'Izin lokasi ditolak permanen. Aktifkan melalui pengaturan aplikasi.'
              : 'Izin lokasi diperlukan untuk mengambil koordinat.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
      });

      // Reverse geocoding is requested only after the user explicitly taps GPS.
      // Keep coordinates even when the network or geocoding service is unavailable.
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'addressdetails': '1',
          'accept-language': 'id',
          'zoom': '18',
        });
        final response = await http
            .get(
              uri,
              headers: const {
                'User-Agent': 'KAMLOKA/1.0 (Kamera Lokasi)',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final address = decoded['address'];
            final addressParts = address is Map<String, dynamic>
                ? address
                : <String, dynamic>{};
            final placeName = _firstNonEmpty([
              decoded['name'],
              addressParts['amenity'],
              addressParts['building'],
              addressParts['tourism'],
              addressParts['shop'],
              addressParts['office'],
              addressParts['leisure'],
              addressParts['road'],
              addressParts['village'],
              addressParts['town'],
              addressParts['city'],
              addressParts['municipality'],
              addressParts['county'],
              addressParts['state'],
            ]);
            final displayAddress = (decoded['display_name'] as String?)?.trim();
            if (!mounted) return;
            setState(() {
              if (placeName != null) _locationName.text = placeName;
              if (displayAddress != null && displayAddress.isNotEmpty) {
                _locationAddress.text = displayAddress;
              }
            });
          }
        }
      } catch (_) {
        // Geocoding is best-effort; manual name/address and GPS coordinates remain usable.
      }
    } catch (error) {
      if (mounted) {
        await showProMessageDialog(
          context: context,
          title: 'Lokasi belum berhasil diambil',
          message: error.toString().replaceFirst('Exception: ', ''),
          type: ProMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && latitude == null) ||
        (longitudeText.isNotEmpty && longitude == null) ||
        ((latitude == null) != (longitude == null))) {
      showProMessageDialog(
        context: context,
        title: 'Koordinat belum valid',
        message:
            'Isi latitude dan longitude dengan angka yang valid, atau kosongkan keduanya.',
        type: ProMessageType.error,
      );
      return;
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      showProMessageDialog(
        context: context,
        title: 'Latitude di luar batas',
        message: 'Periksa kembali nilai latitude.',
        type: ProMessageType.error,
      );
      return;
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      showProMessageDialog(
        context: context,
        title: 'Longitude di luar batas',
        message: 'Periksa kembali nilai longitude.',
        type: ProMessageType.error,
      );
      return;
    }
    Navigator.of(context).pop(
      _TripDraft(
        title: _title.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        officerName: _officer.text,
        assignmentNumber: _assignment.text,
        notes: _notes.text,
        locationName: _locationName.text.trim(),
        locationAddress: _locationAddress.text,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday =
        _isSameDay(_startDate, DateTime.now()) &&
        _isSameDay(_endDate, DateTime.now());
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final isTomorrow =
        _isSameDay(_startDate, tomorrow) && _isSameDay(_endDate, tomorrow);
    final isMultiDay = !_isSameDay(_startDate, _endDate);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F0E9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.add_task_rounded,
                          color: ProTheme.brandGreen,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat kegiatan baru',
                              style: TextStyle(
                                color: ProTheme.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Mulai dengan nama dan jadwal kegiatan. Informasi lainnya bisa diisi nanti.',
                              style: TextStyle(
                                color: ProTheme.secondaryText,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _FormSectionLabel(
                    number: '01',
                    title: 'Informasi kegiatan',
                    subtitle: 'Nama kegiatan wajib diisi.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Nama kegiatan',
                      hintText: 'Masukkan nama kegiatan',
                      helperText: 'Gunakan nama yang mudah dikenali.',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama kegiatan wajib diisi.';
                      }
                      if (value.trim().length < 3) {
                        return 'Masukkan minimal 3 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const _FormSectionLabel(
                    number: '02',
                    title: 'Lokasi kegiatan',
                    subtitle: 'Tentukan lokasi secara manual atau melalui GPS.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationName,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama lokasi',
                      hintText: 'Masukkan nama lokasi',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Nama lokasi wajib diisi.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationAddress,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alamat lokasi',
                      hintText: 'Masukkan alamat lokasi',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ProTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Koordinat lokasi',
                                style: TextStyle(
                                  color: ProTheme.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isGettingLocation
                                  ? null
                                  : _captureGpsLocation,
                              icon: _isGettingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                _isGettingLocation
                                    ? 'Mengambil...'
                                    : 'Ambil Lokasi Saya',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitude,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  hintText: 'Masukkan latitude',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _longitude,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  hintText: 'Masukkan longitude',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Koordinat bersifat opsional. GPS hanya diakses saat tombol ditekan.',
                          style: TextStyle(
                            color: ProTheme.secondaryText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _FormSectionLabel(
                    number: '03',
                    title: 'Jadwal kegiatan',
                    subtitle:
                        'Pilih jadwal cepat atau tentukan tanggal sendiri.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SchedulePresetChip(
                        label: 'Hari ini',
                        icon: Icons.today_rounded,
                        selected: isToday,
                        onTap: () => _setSchedule(0),
                      ),
                      _SchedulePresetChip(
                        label: 'Besok',
                        icon: Icons.event_available_rounded,
                        selected: isTomorrow,
                        onTap: () => _setSchedule(1),
                      ),
                      _SchedulePresetChip(
                        label: 'Beberapa hari',
                        icon: Icons.date_range_rounded,
                        selected: isMultiDay,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ProTheme.border),
                    ),
                    child: Column(
                      children: [
                        _DateRow(
                          label: 'Tanggal mulai',
                          date: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 42),
                          child: Divider(height: 1, color: ProTheme.border),
                        ),
                        _DateRow(
                          label: 'Tanggal selesai',
                          date: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: ProTheme.secondaryText,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tanggal selesai tidak bisa lebih awal dari tanggal mulai.',
                          style: TextStyle(
                            color: ProTheme.secondaryText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: ProTheme.surface,
                      border: Border.all(color: ProTheme.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: ProTheme.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _showOptional
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.tune_rounded,
                              color: ProTheme.brandGreen,
                            ),
                          ),
                          title: const Text(
                            'Detail tambahan',
                            style: TextStyle(
                              color: ProTheme.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Opsional · nomor surat, pelaksana, catatan',
                            style: TextStyle(
                              color: ProTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            _showOptional
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: ProTheme.secondaryText,
                          ),
                          onTap: () =>
                              setState(() => _showOptional = !_showOptional),
                        ),
                        if (_showOptional) ...[
                          Divider(height: 1, color: ProTheme.border),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _officer,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama pelaksana',
                                    hintText: 'Nama petugas atau tim',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _assignment,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Nomor surat tugas',
                                    hintText: 'Masukkan nomor surat tugas',
                                    prefixIcon: Icon(
                                      Icons.description_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notes,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: 3,
                                  minLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Catatan umum',
                                    hintText:
                                        'Tambahkan catatan bila diperlukan',
                                    prefixIcon: Icon(Icons.notes_rounded),
                                    alignLabelWithHint: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Simpan kegiatan'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
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
      ),
    );
  }
}

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: ProTheme.brandGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ProTheme.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: ProTheme.secondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchedulePresetChip extends StatelessWidget {
  const _SchedulePresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? ProTheme.brandGreen : ProTheme.text,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: ProTheme.surface,
      selectedColor: const Color(0xFFE4F0E9),
      side: BorderSide(color: selected ? ProTheme.brandGreen : ProTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ProTheme.background,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: ProTheme.brandGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: ProTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dateLabel(date),
                    style: const TextStyle(
                      color: ProTheme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              size: 19,
              color: ProTheme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

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
          Text(
            label,
            style: const TextStyle(color: ProTheme.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dateLabel(date),
                  style: const TextStyle(
                    color: ProTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
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
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return _dateLabel(start);
  }
  return '${start.day.toString().padLeft(2, '0')} ${_monthLabel(start.month)} – '
      '${end.day.toString().padLeft(2, '0')} ${_monthLabel(end.month)} ${end.year}';
}

String _monthLabel(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
][month - 1];

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
