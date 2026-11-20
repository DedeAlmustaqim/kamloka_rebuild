import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'watermark_placement.dart';

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
/// Widget hanya dirender saat capture. Android memakai Bitmap/Canvas native
/// untuk komposisi JPEG; platform lain atau kegagalan native memakai fallback
/// image package di isolate agar UI thread tetap responsif.
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
      throw StateError(
        'Halaman kamera sudah ditutup sebelum watermark dirender.',
      );
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
            .invokeMethod<String>('composite', <String, Object>{
              'sourcePath': source.path,
              'outputPath': outputPath,
              'watermarkBytes': watermarkBytes,
              'widthRatio': 0.72,
              'bottomMarginRatio': 0.035,
              'jpegQuality': 95,
            });
        if (nativePath == null || nativePath.isEmpty) {
          throw StateError('Native watermark tidak mengembalikan path foto.');
        }
        compositor = 'android-native';
      } catch (error, stack) {
        debugPrint('[KAMLOKA WATERMARK] native compositor failed: $error');
        debugPrintStack(stackTrace: stack);
        // Fallback agar watermark tetap berfungsi jika native compositor gagal.
        await compute(_compositeWatermark, <String, Object>{
          'sourcePath': source.path,
          'outputPath': outputPath,
          'watermarkBytes': watermarkBytes,
        });
      }
    } else {
      await compute(_compositeWatermark, <String, Object>{
        'sourcePath': source.path,
        'outputPath': outputPath,
        'watermarkBytes': watermarkBytes,
      });
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
  static const _mutedColor = Color(0xFFD0D8D2);
  static const _accentColor = Color(0xFFB8DCC5);

  @override
  Widget build(BuildContext context) {
    final time = details.capturedAt;
    final timeText =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
    final dateText = '${time.day} ${_monthName(time.month)} ${time.year}';
    final address = details.address.trim();
    final coordinates = details.coordinates.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: WatermarkService._logicalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xD9000000),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: compact identity, capture time and date.
            Row(
              children: [
                Image.asset(
                  'assets/images/kamloka_typo_white.png',
                  width: 43,
                  height: 14,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                Text(
                  timeText,
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 14,
                    height: 1,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: _mutedColor,
                    fontSize: 7.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: location address, limited to a single line.
            if (address.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _accentColor,
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 8.5,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            // Row 3: coordinates and field metadata share one baseline.
            Row(
              children: [
                if (coordinates.isNotEmpty) ...[
                  Expanded(
                    flex: 5,
                    child: Text(
                      coordinates,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 7,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                _CompactMetric(label: 'AKURASI', value: '${details.accuracy} m'),
                const SizedBox(width: 7),
                _CompactMetric(label: 'ELEVASI', value: '${details.altitude} m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return months[month - 1];
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            color: _WatermarkCard._mutedColor,
            fontSize: 5.5,
            height: 1,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _WatermarkCard._textColor,
            fontSize: 7,
            height: 1,
            fontWeight: FontWeight.w700,
            fontFeatures: [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
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

  // Keep watermark geometry independent from lens direction and orientation.
  // This is shared with unit tests for portrait and landscape dimensions.
  final placement = WatermarkPlacement.calculate(
    photoWidth: photo.width,
    photoHeight: photo.height,
    watermarkWidth: watermark.width,
    watermarkHeight: watermark.height,
  );
  final resizedWatermark = img.copyResize(
    watermark,
    width: placement.width,
    height: placement.height,
    interpolation: img.Interpolation.linear,
  );

  img.compositeImage(
    photo,
    resizedWatermark,
    dstX: placement.left,
    dstY: placement.top,
  );

  File(
    outputPath,
  ).writeAsBytesSync(img.encodeJpg(photo, quality: 95), flush: true);
  return outputPath;
}
