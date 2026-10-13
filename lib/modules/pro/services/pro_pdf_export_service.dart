import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../models/documented_photo.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';
import 'pro_database_service.dart';

class ProPdfExportService {
  ProPdfExportService(this._database);

  final ProDatabaseService _database;
  final _uuid = const Uuid();

  Future<File> exportTrip(Trip trip) async {
    final bytes = await buildTripPdf(trip);
    final documents = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      p.join(documents.path, 'kamloka_pro', 'exports'),
    );
    await exportDirectory.create(recursive: true);

    final safeTitle = trip.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'KAMLOKA_${safeTitle.isEmpty ? 'Dokumentasi' : safeTitle}_${_uuid.v4().substring(0, 8)}.pdf';
    final file = File(p.join(exportDirectory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> buildTripPdf(Trip trip) async {
    final locations = await _database.listLocations(trip.id);
    final document = pw.Document();
    final content = <pw.Widget>[
      pw.SizedBox(height: 22),
      pw.Center(
        child: pw.Text(
          'DOKUMENTASI PERJALANAN DINAS',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pw.Text(
          trip.title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 20),
      _metadataRow('Tujuan kegiatan', trip.purpose),
      _metadataRow('Periode', '${_dateLabel(trip.startDate)} – ${_dateLabel(trip.endDate)}'),
      if (trip.officerName?.isNotEmpty == true)
        _metadataRow('Pelaksana', trip.officerName!),
      if (trip.assignmentNumber?.isNotEmpty == true)
        _metadataRow('Nomor surat tugas', trip.assignmentNumber!),
      if (trip.notes?.isNotEmpty == true)
        _metadataRow('Catatan', trip.notes!),
      pw.SizedBox(height: 18),
      pw.Divider(),
    ];

    var includedPhotoCount = 0;
    for (var index = 0; index < locations.length; index++) {
      final VisitLocation location = locations[index];
      final photos = await _database.listPhotos(location.id);
      final includedPhotos = photos.where((photo) => photo.includeInReport).toList();

      if (includedPhotos.isEmpty) continue;

      content.addAll([
        pw.SizedBox(height: 12),
        pw.Text(
          'Lokasi ${index + 1}: ${location.name}',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        if (location.address?.isNotEmpty == true)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3, bottom: 8),
            child: pw.Text(location.address!, style: const pw.TextStyle(fontSize: 9)),
          ),
      ]);

      for (var photoIndex = 0; photoIndex < includedPhotos.length; photoIndex++) {
        final DocumentedPhoto photo = includedPhotos[photoIndex];
        final file = File(photo.filePath);
        if (!await file.exists()) {
          throw FileSystemException(
            'File foto tidak ditemukan. Buka kembali dokumentasi lokasi dan periksa foto yang bermasalah.',
            photo.filePath,
          );
        }

        final imageBytes = _preparePdfImage(await file.readAsBytes());
        final image = pw.MemoryImage(imageBytes);
        final caption = photo.caption?.trim().isNotEmpty == true
            ? photo.caption!.trim()
            : 'Foto ${photoIndex + 1}';

        content.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14, top: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Image(
                    image,
                    fit: pw.BoxFit.contain,
                    height: 260,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  caption,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  _photoMetadata(photo),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        );
        includedPhotoCount++;
      }
    }

    if (includedPhotoCount == 0) {
      throw StateError('Pilih minimal satu foto untuk dimasukkan ke PDF.');
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 42),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'KAMLOKA • ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (_) => content,
      ),
    );

    return document.save();
  }

  Uint8List _preparePdfImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Salah satu foto tidak dapat dibaca untuk PDF.');
    }

    final resized = decoded.width > 1600
        ? img.copyResize(decoded, width: 1600)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  pw.Widget _metadataRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 115,
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            ),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

  String _photoMetadata(DocumentedPhoto photo) {
    final parts = <String>[];
    if (photo.capturedAt != null) parts.add(_dateTimeLabel(photo.capturedAt!));
    if (photo.address?.isNotEmpty == true) parts.add(photo.address!);
    if (photo.latitude != null && photo.longitude != null) {
      parts.add(
        '${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}',
      );
    }
    return parts.isEmpty ? 'Informasi waktu/lokasi tidak tersedia' : parts.join(' • ');
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _dateTimeLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${_dateLabel(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
