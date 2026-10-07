import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class WatermarkData {
  const WatermarkData({
    required this.dateTime,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
  });

  final DateTime dateTime;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? altitude;
}

class WatermarkService {
  static const _logoAsset = 'assets/images/kamloka_typo.png';

  img.Image? _logo;
  Future<img.Image?>? _logoLoading;

  Future<img.Image?> _loadLogo() {
    final cached = _logo;
    if (cached != null) return Future.value(cached);

    final loading = _logoLoading;
    if (loading != null) return loading;

    final future = _loadLogoInternal();
    _logoLoading = future;
    return future;
  }

  Future<img.Image?> _loadLogoInternal() async {
    try {
      final data = await rootBundle.load(_logoAsset);
      final bytes = Uint8List.view(
        data.buffer,
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final decoded = img.decodeImage(bytes);
      _logo = decoded;
      return decoded;
    } catch (error) {
      debugPrint('[KAMLOKA WATERMARK] Logo tidak tersedia: $error');
      return null;
    }
  }

  Future<camera.XFile> apply(
    camera.XFile source, {
    required WatermarkData data,
  }) async {
    final inputFile = File(source.path);
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw const FormatException('Foto tidak dapat diproses untuk watermark.');
    }

    final font = image.width >= 3000 ? img.arial48 : img.arial24;
    final lineHeight = font.lineHeight + 8;
    final horizontalPadding = image.width >= 3000 ? 36 : 20;
    final verticalPadding = image.width >= 3000 ? 28 : 16;
    final panelWidth = (image.width * 0.92).round();
    final panelX = ((image.width - panelWidth) / 2).round();
    final panelGap = image.width >= 3000 ? 28 : 16;
    final logoColumnWidth = (panelWidth * 0.30).round();
    final infoColumnWidth = panelWidth - logoColumnWidth;

    final address = data.address.isEmpty
        ? 'Alamat tidak tersedia'
        : data.address;
    final addressLines = _wrapText(
      address,
      maxChars: _addressMaxChars(
        panelWidth: panelWidth,
        horizontalPadding: horizontalPadding,
        fontSize: image.width >= 3000 ? 48 : 24,
      ),
    );

    final lines = <String>[
      _formatDateTime(data.dateTime),
      ...addressLines,
      _formatCoordinates(data.latitude, data.longitude),
      _formatMetrics(data.accuracy, data.altitude),
    ];

    final panelHeight =
        (verticalPadding * 2) + (lineHeight * lines.length) - 8;
    final panelY = image.height - panelHeight - verticalPadding;

    img.fillRect(
      image,
      x1: panelX,
      y1: panelY,
      x2: panelX + panelWidth,
      y2: image.height - verticalPadding,
      color: img.ColorRgba8(0, 0, 0, 185),
    );

    var textY = panelY + verticalPadding;
    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: font,
        x: panelX + horizontalPadding,
        y: textY,
        color: img.ColorRgb8(255, 255, 255),
      );
      textY += lineHeight;
    }

    // Kolom kanan khusus branding KAMLOKA.
    final logo = await _loadLogo();
    if (logo != null) {
      final logoAreaX = panelX + infoColumnWidth + panelGap;
      final logoAreaWidth = logoColumnWidth - panelGap - horizontalPadding;
      final logoMaxWidth = logoAreaWidth.clamp(40, 1000).toInt();
      final logoMaxHeight =
          (panelHeight - (verticalPadding * 2)).clamp(40, 1000).toInt();

      var logoWidth = logo.width;
      var logoHeight = logo.height;
      final scale = [
        logoMaxWidth / logoWidth,
        logoMaxHeight / logoHeight,
        1.0,
      ].reduce((a, b) => a < b ? a : b);

      logoWidth = (logoWidth * scale).round().clamp(1, logo.width).toInt();
      logoHeight =
          (logoHeight * scale).round().clamp(1, logo.height).toInt();

      final resizedLogo = img.copyResize(
        logo,
        width: logoWidth,
        height: logoHeight,
      );

      final logoX =
          logoAreaX + ((logoAreaWidth - logoWidth) / 2).round();
      final logoY =
          panelY + ((panelHeight - logoHeight) / 2).round();

      img.compositeImage(
        image,
        resizedLogo,
        dstX: logoX,
        dstY: logoY,
        blend: img.BlendMode.alpha,
      );
    }

    final outputPath = _outputPath(source.path);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(
      img.encodeJpg(image, quality: 100),
      flush: true,
    );

    debugPrint(
      '[KAMLOKA WATERMARK] ${image.width}x${image.height} -> $outputPath',
    );

    return camera.XFile(outputPath);
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Koordinat tidak tersedia';
    }

    return '${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)}';
  }

  String _formatMetrics(double? accuracy, double? altitude) {
    final accuracyText =
        accuracy == null ? '--' : '${accuracy.toStringAsFixed(1)} m';
    final altitudeText =
        altitude == null ? '--' : '${altitude.toStringAsFixed(1)} m';

    return 'Akurasi $accuracyText  •  Alt $altitudeText';
  }

  int _addressMaxChars({
    required int panelWidth,
    required int horizontalPadding,
    required int fontSize,
  }) {
    final usableWidth = panelWidth - (horizontalPadding * 2);
    return (usableWidth / (fontSize * 0.58)).floor().clamp(18, 120).toInt();
  }

  List<String> _wrapText(
    String value, {
    required int maxChars,
  }) {
    final words = value.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';

      if (candidate.length <= maxChars) {
        current = candidate;
        continue;
      }

      if (current.isNotEmpty) {
        lines.add(current);
      }

      current = word.length <= maxChars
          ? word
          : word.substring(0, maxChars);
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines.isEmpty ? ['Alamat tidak tersedia'] : lines;
  }

  String _outputPath(String inputPath) {
    final separator = Platform.pathSeparator;
    final name = inputPath.split(separator).last;
    final baseName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final directory = inputPath.substring(0, inputPath.length - name.length);
    return '$directory${baseName}_watermarked.jpg';
  }

  void dispose() {}
}
