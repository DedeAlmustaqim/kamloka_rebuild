import 'dart:io';
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
      final bytes = data.buffer.asUint8List(
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

    final isPortrait = image.height > image.width;

    // Watermark tanpa panel/background. Semua elemen dirancang sebagai
    // teks putih tegas agar menyatu dengan foto tanpa menutupinya.
    final textFont = isPortrait ? img.arial14 : img.arial24;
    final timeFont = isPortrait ? img.arial24 : img.arial48;
    final dateFont = isPortrait ? img.arial14 : img.arial24;

    final horizontalPadding =
        (image.width * (isPortrait ? 0.035 : 0.038)).round().clamp(18, 160).toInt();
    final bottomPadding =
        (image.height * (isPortrait ? 0.035 : 0.045)).round().clamp(24, 180).toInt();

    final leftX = horizontalPadding;
    final contentRight = image.width - horizontalPadding;

    final local = data.dateTime.toLocal();
    final dayName = _dayName(local.weekday);
    final timeText =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateText =
        '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year}';

    final address = data.address.trim().isEmpty
        ? 'Alamat tidak tersedia'
        : data.address.trim();

    final infoColumnWidth = isPortrait
        ? (image.width * 0.90).round()
        : (image.width * 0.55).round();

    final addressLines = _wrapText(
      address,
      maxChars: _addressMaxChars(
        width: infoColumnWidth,
        fontScale: isPortrait ? 0.75 : 1.0,
      ),
    );

    // Posisi dasar dari bawah foto. Tidak ada box sehingga foto tetap penuh.
    final metricsLineHeight =
        textFont.lineHeight + (isPortrait ? 2 : 6);
    final addressHeight = addressLines.length * metricsLineHeight;
    final detailsHeight = textFont.lineHeight * 2 + (isPortrait ? 8 : 14);
    final contentHeight =
        timeFont.lineHeight +
        dateFont.lineHeight +
        addressHeight +
        detailsHeight +
        (isPortrait ? 20 : 36);

    final contentBottom = image.height - bottomPadding;
    final contentTop = contentBottom - contentHeight;

    // Logo tetap sebagai branding Free, berada di atas informasi dan rata kanan.
    if (showBranding) {
      final logo = await _loadLogo();

      if (logo != null) {
        final logoMaxWidth =
            (image.width * (isPortrait ? 0.23 : 0.27)).round();
        final logoMaxHeight =
            (image.height * (isPortrait ? 0.08 : 0.10)).round();

        final logoScale = [
          logoMaxWidth / logo.width,
          logoMaxHeight / logo.height,
          1.0,
        ].reduce((a, b) => a < b ? a : b);

        final logoWidth = (logo.width * logoScale).round();
        final logoHeight = (logo.height * logoScale).round();

        final logoX = contentRight - logoWidth;
        final logoY = contentTop - logoHeight - (isPortrait ? 8 : 14);

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

    final white = img.ColorRgb8(255, 255, 255);
    final shadow = img.ColorRgba8(0, 0, 0, 190);

    // Kolom kiri: hari, jam, tanggal.
    final leftColumnWidth = isPortrait
        ? (image.width * 0.30).round()
        : (image.width * 0.23).round();

    final dayY = contentTop;
    final timeY = dayY + textFont.lineHeight + (isPortrait ? 2 : 4);
    final dateY = timeY + timeFont.lineHeight + (isPortrait ? 3 : 6);

    _drawStrongText(
      image,
      dayName,
      font: textFont,
      x: leftX,
      y: dayY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      timeText,
      font: timeFont,
      x: leftX,
      y: timeY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      dateText,
      font: dateFont,
      x: leftX,
      y: dateY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    // Kolom kanan.
    final rightX = leftX + leftColumnWidth;
    final rightWidth = contentRight - rightX;

    final addressX = rightX;
    final addressY = contentTop;

    for (var index = 0; index < addressLines.length; index++) {
      _drawStrongText(
        image,
        addressLines[index],
        font: textFont,
        x: addressX,
        y: addressY + (index * metricsLineHeight),
        color: white,
        shadow: shadow,
        shadowOffset: isPortrait ? 1 : 2,
      );
    }

    final detailsY = addressY + addressHeight + (isPortrait ? 5 : 10);
    final detailGap = (rightWidth * 0.06).round();
    final secondColumnX = addressX + ((rightWidth - detailGap) / 2).round() + detailGap;

    _drawStrongText(
      image,
      _formatLatitude(data.latitude),
      font: textFont,
      x: addressX,
      y: detailsY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      _formatLongitude(data.longitude),
      font: textFont,
      x: secondColumnX,
      y: detailsY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    final metricsY = detailsY + textFont.lineHeight + (isPortrait ? 4 : 8);

    _drawStrongText(
      image,
      _formatAccuracy(data.accuracy),
      font: textFont,
      x: addressX,
      y: metricsY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      _formatAltitude(data.altitude),
      font: textFont,
      x: secondColumnX,
      y: metricsY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

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

  void _drawStrongText(
    img.Image image,
    String text, {
    required img.BitmapFont font,
    required int x,
    required int y,
    required img.Color color,
    required img.Color shadow,
    required int shadowOffset,
  }) {
    // Fake-bold + shadow menggunakan dua layer kecil. Ini memberi karakter
    // putih yang tegas tanpa perlu menambah font asset khusus.
    img.drawString(
      image,
      text,
      font: font,
      x: x + shadowOffset,
      y: y + shadowOffset,
      color: shadow,
    );
    img.drawString(
      image,
      text,
      font: font,
      x: x + 1,
      y: y,
      color: color,
    );
    img.drawString(
      image,
      text,
      font: font,
      x: x,
      y: y,
      color: color,
    );
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
    final baseFont = fontScale >= 1.0 ? 48 : 16;
    final chars = (width / (baseFont * 0.58)).floor();
    return chars.clamp(18, 90).toInt();
  }

  List<String> _wrapText(
    String value, {
    required int maxChars,
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

      // Kata panjang tidak dipotong; alamat harus tetap utuh.
      current = word;
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }

    return lines.isEmpty ? ['Alamat tidak tersedia'] : lines;
  }

  void dispose() {
    _logo = null;
    _logoLoading = null;
  }

  String _outputPath(String inputPath) {
    final separator = Platform.pathSeparator;
    final name = inputPath.split(separator).last;
    final baseName = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final directory = inputPath.substring(0, inputPath.length - name.length);
    return '$directory${baseName}_watermarked.jpg';
  }
}
