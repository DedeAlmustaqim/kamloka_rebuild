import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    bool showBranding = true,
  }) async {
    final inputFile = File(source.path);
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw const FormatException('Foto tidak dapat diproses untuk watermark.');
    }

    final scale = image.width / 1080.0;

    // Layout mengacu pada referensi 1080x720 dan diskalakan proporsional.
    final panelWidth = (image.width * 0.867).round();
    final panelX = ((image.width - panelWidth) / 2).round();
    final bottomMargin = (image.height * 0.10).round();
    final radius = (image.width * 0.032).round().clamp(18, 180).toInt();
    final panelHeight = (image.height * 0.30).round();
    final panelY = image.height - bottomMargin - panelHeight;

    final horizontalPadding =
        (image.width * 0.038).round().clamp(24, 160).toInt();
    final dividerX = panelX + (panelWidth * 0.305).round();

    final dayFont = image.width >= 1800 ? img.arial48 : img.arial24;
    final timeFont = img.arial48;
    final bodyFont = image.width >= 1800 ? img.arial48 : img.arial24;
    final dateFont = img.arial24;

    final white = img.ColorRgb8(255, 255, 255);
    final panelColor = img.ColorRgb8(82, 82, 82);

    _fillRoundedRect(
      image,
      x1: panelX,
      y1: panelY,
      x2: panelX + panelWidth,
      y2: panelY + panelHeight,
      radius: radius,
      color: panelColor,
    );

    // Divider vertikal antara kolom waktu dan informasi lokasi.
    final dividerTop = panelY + (panelHeight * 0.13).round();
    final dividerBottom = panelY + (panelHeight * 0.87).round();
    final dividerThickness = (scale * 4).round().clamp(3, 10).toInt();

    img.fillRect(
      image,
      x1: dividerX,
      y1: dividerTop,
      x2: dividerX + dividerThickness,
      y2: dividerBottom,
      color: white,
    );

    final local = data.dateTime.toLocal();
    final dayName = _dayName(local.weekday);
    final timeText = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateText =
        '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year}';

    // Kolom kiri: hari, jam, tanggal.
    final leftX = panelX + horizontalPadding;
    final dayY = panelY + (panelHeight * 0.16).round();
    final timeY = panelY + (panelHeight * 0.35).round();
    final dateY = panelY + (panelHeight * 0.75).round();

    img.drawString(
      image,
      dayName,
      font: dayFont,
      x: leftX,
      y: dayY,
      color: white,
    );

    img.drawString(
      image,
      timeText,
      font: timeFont,
      x: leftX,
      y: timeY,
      color: white,
    );

    img.drawString(
      image,
      dateText,
      font: dateFont,
      x: leftX,
      y: dateY,
      color: white,
    );

    // Kolom kanan: alamat di atas, koordinat dan metrik di bawah.
    final rightX = dividerX + (image.width * 0.038).round();
    final rightWidth = panelX + panelWidth - rightX - horizontalPadding;
    final columnGap = (image.width * 0.028).round();
    final detailColumnWidth = ((rightWidth - columnGap) / 2).round();
    final secondColumnX = rightX + detailColumnWidth + columnGap;

    final address = data.address.trim().isEmpty
        ? 'Alamat tidak tersedia'
        : data.address.trim();

    final addressLines = _wrapText(
      address,
      maxChars: _addressMaxChars(
        width: rightWidth,
        fontScale: scale,
      ),
      maxLines: 2,
    );

    final addressY = panelY + (panelHeight * 0.15).round();
    final addressLineHeight = bodyFont.lineHeight + (scale * 5).round();

    for (var index = 0; index < addressLines.length; index++) {
      img.drawString(
        image,
        addressLines[index],
        font: bodyFont,
        x: rightX,
        y: addressY + (index * addressLineHeight),
        color: white,
      );
    }

    final coordinatesY = panelY + (panelHeight * 0.55).round();
    final metricsY = panelY + (panelHeight * 0.73).round();

    img.drawString(
      image,
      _formatLatitude(data.latitude),
      font: bodyFont,
      x: rightX,
      y: coordinatesY,
      color: white,
    );

    img.drawString(
      image,
      _formatLongitude(data.longitude),
      font: bodyFont,
      x: secondColumnX,
      y: coordinatesY,
      color: white,
    );

    img.drawString(
      image,
      _formatAccuracy(data.accuracy),
      font: bodyFont,
      x: rightX,
      y: metricsY,
      color: white,
    );

    img.drawString(
      image,
      _formatAltitude(data.altitude),
      font: bodyFont,
      x: secondColumnX,
      y: metricsY,
      color: white,
    );

    // Logo KAMLOKA berada di atas panel dan rata kanan.
    if (showBranding) {
      final logo = await _loadLogo();
      if (logo != null) {
        final logoMaxWidth = (image.width * 0.31).round();
        final logoMaxHeight = (panelY - (image.height * 0.025)).round();

        if (logoMaxWidth > 0 && logoMaxHeight > 0) {
          final logoScale = [
            logoMaxWidth / logo.width,
            logoMaxHeight / logo.height,
            1.0,
          ].reduce((a, b) => a < b ? a : b);

          final logoWidth = (logo.width * logoScale).round();
          final logoHeight = (logo.height * logoScale).round();

          final logoX =
              panelX + panelWidth - logoWidth - (image.width * 0.01).round();
          final logoY =
              panelY - logoHeight - (image.height * 0.018).round();

          final resizedLogo = img.copyResize(
            logo,
            width: logoWidth,
            height: logoHeight,
          );

          img.compositeImage(
            image,
            resizedLogo,
            dstX: logoX,
            dstY: logoY,
            blend: img.BlendMode.alpha,
          );
        }
      }
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

  void _fillRoundedRect(
    img.Image image, {
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    required int radius,
    required img.Color color,
  }) {
    img.fillRect(
      image,
      x1: x1 + radius,
      y1: y1,
      x2: x2 - radius,
      y2: y2,
      color: color,
    );
    img.fillRect(
      image,
      x1: x1,
      y1: y1 + radius,
      x2: x2,
      y2: y2 - radius,
      color: color,
    );

    img.fillCircle(
      image,
      x: x1 + radius,
      y: y1 + radius,
      radius: radius,
      color: color,
    );
    img.fillCircle(
      image,
      x: x2 - radius,
      y: y1 + radius,
      radius: radius,
      color: color,
    );
    img.fillCircle(
      image,
      x: x1 + radius,
      y: y2 - radius,
      radius: radius,
      color: color,
    );
    img.fillCircle(
      image,
      x: x2 - radius,
      y: y2 - radius,
      radius: radius,
      color: color,
    );
  }

  String _dayName(int weekday) {
    const names = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return names[month - 1];
  }

  String _formatLatitude(double? value) {
    if (value == null) return 'Lat --';
    return 'Lat ${value.toStringAsFixed(6)}°';
  }

  String _formatLongitude(double? value) {
    if (value == null) return 'Long --';
    return 'Long ${value.toStringAsFixed(6)}°';
  }

  String _formatAccuracy(double? value) {
    if (value == null) return 'Akurasi --';
    return 'Akurasi ${value.toStringAsFixed(1)}';
  }

  String _formatAltitude(double? value) {
    if (value == null) return 'Alt --';
    return 'Alt ${value.toStringAsFixed(1)} m';
  }

  int _addressMaxChars({
    required int width,
    required double fontScale,
  }) {
    final baseFont = fontScale >= 1.67 ? 48 : 24;
    final chars = (width / (baseFont * 0.58)).floor();
    return chars.clamp(18, 90).toInt();
  }

  List<String> _wrapText(
    String value, {
    required int maxChars,
    required int maxLines,
  }) {
    final words = value.split(RegExp(r'\s+'));
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

      current = word;

      if (lines.length == maxLines - 1) {
        break;
      }
    }

    if (current.isNotEmpty && lines.length < maxLines) {
      lines.add(current);
    }

    if (lines.length > maxLines) {
      return lines.take(maxLines).toList();
    }

    if (lines.length == maxLines) {
      final renderedLength = lines.join(' ').length;
      if (renderedLength < value.length) {
        final last = lines.last;
        lines[lines.length - 1] = last.length > 3
            ? '${last.substring(0, last.length - 3)}...'
            : last;
      }
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
}
