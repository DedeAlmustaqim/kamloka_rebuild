import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/trip.dart';
import '../services/pro_database_service.dart';
import '../services/pro_pdf_export_service.dart';
import '../theme/pro_theme.dart';

class ProPdfPreviewScreen extends StatefulWidget {
  const ProPdfPreviewScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<ProPdfPreviewScreen> createState() => _ProPdfPreviewScreenState();
}

class _ProPdfPreviewScreenState extends State<ProPdfPreviewScreen> {
  late final ProPdfExportService _pdfService;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _pdfService = ProPdfExportService(
      // The database service is already registered by the Pro module.
      Get.find<ProDatabaseService>(),
    );
  }

  String get _fileName {
    final safeTitle = widget.trip.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'KAMLOKA_${safeTitle.isEmpty ? 'Dokumentasi' : safeTitle}.pdf';
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) {
    return _pdfService.buildTripPdf(widget.trip);
  }

  Future<void> _downloadPdf() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final bytes = await _pdfService.buildTripPdf(widget.trip);
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF belum dapat diunduh: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProTheme.apply(
      Scaffold(
        appBar: AppBar(
          title: const Text('Pratinjau PDF'),
          actions: [
            IconButton(
              tooltip: 'Unduh atau bagikan PDF',
              onPressed: _isSharing ? null : _downloadPdf,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: PdfPreview(
          build: _buildPdf,
          pdfFileName: _fileName,
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
          useActions: true,
          loadingWidget: const Center(child: CircularProgressIndicator()),
          onError: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal membuat pratinjau PDF.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
