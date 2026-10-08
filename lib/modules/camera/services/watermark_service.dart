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
    final white = img.ColorRgb8(255, 255, 255);
    final shadow = img.ColorRgba8(0, 0, 0, 210);

    final local = data.dateTime.toLocal();
    final dayName = _dayName(local.weekday);
    final timeText =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final dateText =
        '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year}';
    final address = data.address.trim().isEmpty
        ? 'Alamat tidak tersedia'
        : data.address.trim();

    final horizontalPadding =
        (image.width * (isPortrait ? 0.035 : 0.030)).round().clamp(18, 100).toInt();
    final contentLeft = horizontalPadding;
    final contentRight = image.width - horizontalPadding;
    final contentWidth = contentRight - contentLeft;

    final bottomMargin =
        (image.height * (isPortrait ? 0.022 : 0.014)).round().clamp(12, 60).toInt();
    final topPadding =
        (image.height * (isPortrait ? 0.012 : 0.014)).round().clamp(8, 40).toInt();
    final sectionGap =
        (image.height * (isPortrait ? 0.005 : 0.006)).round().clamp(3, 14).toInt();

    final textFont = isPortrait ? img.arial14 : img.arial24;
    final timeFont = isPortrait ? img.arial24 : img.arial48;
    final dateFont = isPortrait ? img.arial14 : img.arial24;

    final logo = showBranding ? await _loadLogo() : null;
    var logoWidth = 0;
    var logoHeight = 0;

    if (logo != null) {
      final maxLogoWidth =
          (image.width * (isPortrait ? 0.20 : 0.22)).round();
      final maxLogoHeight =
          (image.height * (isPortrait ? 0.045 : 0.060)).round();

      final scale = [
        maxLogoWidth / logo.width,
        maxLogoHeight / logo.height,
        1.0,
      ].reduce((a, b) => a < b ? a : b);

      logoWidth = (logo.width * scale).round();
      logoHeight = (logo.height * scale).round();
    }

    int wrapChars(int width, {required bool large}) {
      final charWidth = large ? 13.0 : 8.0;
      return (width / charWidth).floor().clamp(24, 120).toInt();
    }

    final addressWidth = isPortrait
        ? contentWidth
        : (contentWidth * 0.70).round();

    final addressLines = _wrapText(
      address,
      maxChars: wrapChars(addressWidth, large: !isPortrait),
    );

    // Tight typography: the watermark should occupy as little photo area
    // as possible while remaining readable.
    final addressLineHeight = textFont.lineHeight + (isPortrait ? 0 : 2);
    final detailsLineHeight = textFont.lineHeight + (isPortrait ? 1 : 3);
    final addressHeight = addressLines.length * addressLineHeight;

    final headerTextHeight =
        textFont.lineHeight +
        timeFont.lineHeight +
        dateFont.lineHeight;

    final headerHeight = [
      headerTextHeight,
      logoHeight,
    ].reduce((a, b) => a > b ? a : b);

    final detailsGap = sectionGap;
    final detailsHeight = detailsLineHeight * 2;

    // Landscape uses a two-zone composition:
    // left = date/time, right = address + GPS details.
    // This keeps the watermark visually balanced and much more compact.
    final landscapeRightHeight =
        addressHeight + detailsGap + detailsHeight;

    final contentHeight = isPortrait
        ? topPadding +
            headerHeight +
            sectionGap +
            addressHeight +
            detailsGap +
            detailsHeight +
            bottomMargin
        : topPadding +
            (headerHeight > landscapeRightHeight
                ? headerHeight
                : landscapeRightHeight) +
            bottomMargin;

    final baseY = image.height - contentHeight;

    // No rectangle/panel: watermark floats directly over the photo.
    // A strong shadow keeps it readable on both light and dark backgrounds.
    final contentTop = baseY + topPadding;

    final dayY = contentTop;
    final timeY = dayY + textFont.lineHeight;
    final dateY = timeY + timeFont.lineHeight;

    _drawStrongText(
      image,
      dayName,
      font: textFont,
      x: contentLeft,
      y: dayY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      timeText,
      font: timeFont,
      x: contentLeft,
      y: timeY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    _drawStrongText(
      image,
      dateText,
      font: dateFont,
      x: contentLeft,
      y: dateY,
      color: white,
      shadow: shadow,
      shadowOffset: isPortrait ? 1 : 2,
    );

    if (logo != null && logoWidth > 0 && logoHeight > 0) {
      final resizedLogo = img.copyResize(
        logo,
        width: logoWidth,
        height: logoHeight,
      );

      final logoX = contentRight - logoWidth;
      final logoY = contentTop + ((headerHeight - logoHeight) / 2).round();

      img.compositeImage(
        image,
        resizedLogo,
        dstX: logoX,
        dstY: logoY,
        blend: img.BlendMode.alpha,
      );
    }

    if (isPortrait) {
      final addressY = contentTop + headerHeight + sectionGap;

      for (var index = 0; index < addressLines.length; index++) {
        _drawStrongText(
          image,
          addressLines[index],
          font: textFont,
          x: contentLeft,
          y: addressY + (index * addressLineHeight),
          color: white,
          shadow: shadow,
          shadowOffset: 1,
        );
      }

      final detailsY = addressY + addressHeight + detailsGap;
      final detailGap = (contentWidth * 0.04).round();
      final detailWidth = ((contentWidth - detailGap) / 2).round();
      final secondColumnX = contentLeft + detailWidth + detailGap;

      _drawStrongText(
        image,
        _formatLatitude(data.latitude),
        font: textFont,
        x: contentLeft,
        y: detailsY,
        color: white,
        shadow: shadow,
        shadowOffset: 1,
      );

      _drawStrongText(
        image,
        _formatLongitude(data.longitude),
        font: textFont,
        x: secondColumnX,
        y: detailsY,
        color: white,
        shadow: shadow,
        shadowOffset: 1,
      );

      final metricsY = detailsY + detailsLineHeight;

      _drawStrongText(
        image,
        _formatAccuracy(data.accuracy),
        font: textFont,
        x: contentLeft,
        y: metricsY,
        color: white,
        shadow: shadow,
        shadowOffset: 1,
      );

      _drawStrongText(
        image,
        _formatAltitude(data.altitude),
        font: textFont,
        x: secondColumnX,
        y: metricsY,
        color: white,
        shadow: shadow,
        shadowOffset: 1,
      );
    } else {
      // Landscape: keep all secondary information in the right zone.
      // The left zone is reserved for the visual date/time identity.
      final rightX = contentLeft + (contentWidth * 0.34).round();
      final rightWidth = contentRight - rightX;
      final rightAddressLines = _wrapText(
        address,
        maxChars: wrapChars(rightWidth, large: true),
      );
      final rightAddressHeight =
          rightAddressLines.length * addressLineHeight;

      for (var index = 0; index < rightAddressLines.length; index++) {
        _drawStrongText(
          image,
          rightAddressLines[index],
          font: textFont,
          x: rightX,
          y: contentTop + (index * addressLineHeight),
          color: white,
          shadow: shadow,
          shadowOffset: 2,
        );
      }

      final detailsY =
          contentTop + rightAddressHeight + detailsGap;
      final detailGap = (rightWidth * 0.06).round();
      final detailWidth = ((rightWidth - detailGap) / 2).round();
      final secondColumnX = rightX + detailWidth + detailGap;

      _drawStrongText(
        image,
        _formatLatitude(data.latitude),
        font: textFont,
        x: rightX,
        y: detailsY,
        color: white,
        shadow: shadow,
        shadowOffset: 2,
      );

      _drawStrongText(
        image,
        _formatLongitude(data.longitude),
        font: textFont,
        x: secondColumnX,
        y: detailsY,
        color: white,
        shadow: shadow,
        shadowOffset: 2,
      );

      final metricsY = detailsY + detailsLineHeight;

      _drawStrongText(
        image,
        _formatAccuracy(data.accuracy),
        font: textFont,
        x: rightX,
        y: metricsY,
        color: white,
        shadow: shadow,
        shadowOffset: 2,
      );

      _drawStrongText(
        image,
        _formatAltitude(data.altitude),
        font: textFont,
        x: secondColumnX,
        y: metricsY,
        color: white,
        shadow: shadow,
        shadowOffset: 2,
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
