import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Data yang dicetak ke watermark pada saat foto diambil.
class WatermarkDetails {
  const WatermarkDetails({
    required this.capturedAt,
    required this.coordinates,
    required this.accuracy,
    required this.altitude,
    required this.address,
  });

  final DateTime capturedAt;
  final String coordinates;
  final String accuracy;
  final String altitude;
  final String address;
}

/// Renderer widget-to-PNG dan komposisi watermark ke foto asli.
///
/// Widget hanya dirender saat capture. Penggabungan gambar dilakukan melalui
/// compute() agar decoding dan encoding JPEG tidak memblokir UI thread.
class WatermarkService {
  static const double _logicalWidth = 320;
  static const double _renderPixelRatio = 8;

  Future<camera.XFile> apply(
    camera.XFile source, {
    required BuildContext context,
    required WatermarkDetails details,
  }) async {
    final totalWatch = Stopwatch()..start();
    final renderWatch = Stopwatch()..start();
    await precacheImage(
      const AssetImage('assets/images/kamloka_typo_white.png'),
      context,
    );
    if (!context.mounted) {
      throw StateError('Halaman kamera sudah ditutup sebelum watermark dirender.');
    }

    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: Opacity(
            // Opasitas sangat kecil membuat subtree tetap dilukis sehingga
            // RepaintBoundary dapat dirasterisasi. Panel hampir tidak terlihat.
            opacity: 0.01,
            child: SizedBox(
              width: _logicalWidth,
              child: RepaintBoundary(
                key: boundaryKey,
                child: _WatermarkCard(details: details),
              ),
            ),
          ),
        ),
      ),
    );

    Uint8List watermarkBytes;
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary || !renderObject.hasSize) {
        throw StateError('Widget watermark belum siap dirender.');
      }

      final rendered = await renderObject.toImage(
        pixelRatio: _renderPixelRatio,
      );
      try {
        final byteData = await rendered.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) {
          throw StateError('PNG watermark gagal dibuat.');
        }
        watermarkBytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      entry.remove();
    }

    renderWatch.stop();
    final compositeWatch = Stopwatch()..start();

    final outputPath = p.join(
      p.dirname(source.path),
      '${p.basenameWithoutExtension(source.path)}_watermarked.jpg',
    );

    var compositor = 'dart';
    if (Platform.isAndroid) {
      try {
        final nativePath = await const MethodChannel('kamloka/watermark')
            .invokeMethod<String>(
          'composite',
          <String, Object>{
            'sourcePath': source.path,
            'outputPath': outputPath,
            'watermarkBytes': watermarkBytes,
            'widthRatio': 0.75,
            'bottomMarginRatio': 0.035,
            'jpegQuality': 95,
          },
        );
        if (nativePath == null || nativePath.isEmpty) {
          throw StateError('Native watermark tidak mengembalikan path foto.');
        }
        compositor = 'android-native';
      } catch (error, stack) {
        debugPrint('[KAMLOKA WATERMARK] native compositor failed: $error');
        debugPrintStack(stackTrace: stack);
        // Fallback agar watermark tetap berfungsi jika native compositor gagal.
        await compute(
          _compositeWatermark,
          <String, Object>{
            'sourcePath': source.path,
            'outputPath': outputPath,
            'watermarkBytes': watermarkBytes,
          },
        );
      }
    } else {
      await compute(
        _compositeWatermark,
        <String, Object>{
          'sourcePath': source.path,
          'outputPath': outputPath,
          'watermarkBytes': watermarkBytes,
        },
      );
    }

    compositeWatch.stop();
    totalWatch.stop();
    debugPrint(
      '[KAMLOKA WATERMARK] compositor=$compositor '
      'render=${renderWatch.elapsedMilliseconds}ms '
      'composite=${compositeWatch.elapsedMilliseconds}ms '
      'total=${totalWatch.elapsedMilliseconds}ms',
    );
    return camera.XFile(outputPath);
  }

  void dispose() {}
}

class _WatermarkCard extends StatelessWidget {
  const _WatermarkCard({required this.details});

  final WatermarkDetails details;

  static const _textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final time = details.capturedAt;
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    final dateText = '${time.day} ${_monthName(time.month)} ${time.year}';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: WatermarkService._logicalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 68,
              child: Image.asset(
                'assets/images/kamloka_typo_white.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    maxLines: 1,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 17,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateText,
                    maxLines: 1,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  Text(
                    details.coordinates,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Akurasi ${details.accuracy} m  •  Alt ${details.altitude} m',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textColor,
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (details.address.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      details.address.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = <String>[
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
    ];
    return months[month - 1];
  }
}

/// Worker top-level agar pengolahan gambar berjalan di isolate terpisah.
String _compositeWatermark(Map<String, Object> args) {
  final sourcePath = args['sourcePath']! as String;
  final outputPath = args['outputPath']! as String;
  final watermarkBytes = args['watermarkBytes']! as Uint8List;

  final photoBytes = File(sourcePath).readAsBytesSync();
  final photo = img.decodeImage(photoBytes);
  if (photo == null) {
    throw const FormatException('Foto asli tidak dapat dibaca.');
  }

  final watermark = img.decodePng(watermarkBytes);
  if (watermark == null) {
    throw const FormatException('PNG watermark tidak dapat dibaca.');
  }

  // Ukuran watermark dinormalisasi ke 75% lebar foto, baik portrait maupun
  // landscape. PNG dirender pada resolusi tinggi untuk menjaga ketajaman teks.
  final targetWidth = (photo.width * 0.75).round();
  final resizedWatermark = img.copyResize(
    watermark,
    width: targetWidth,
    interpolation: img.Interpolation.linear,
  );

  final horizontal = ((photo.width - resizedWatermark.width) / 2).round();
  final bottomMargin = (photo.height * 0.035).round();
  final vertical = photo.height - resizedWatermark.height - bottomMargin;

  img.compositeImage(
    photo,
    resizedWatermark,
    dstX: horizontal < 0 ? 0 : horizontal,
    dstY: vertical < 0 ? 0 : vertical,
  );

  File(outputPath).writeAsBytesSync(
    img.encodeJpg(photo, quality: 95),
    flush: true,
  );
  return outputPath;
}
