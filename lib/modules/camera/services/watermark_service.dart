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
  static const _logoAsset = 'assets/images/kamloka_typo_white.png';

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

    final layout = _WatermarkLayout.forImage(image.width, image.height);
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
        : data.address;
    final detailText = _formatDetails(data);

    final logo = showBranding ? await _loadLogo() : null;
    final logoSize = logo == null
        ? null
        : _scaledSize(
            logo,
            maxWidth: layout.logoMaxWidth,
            maxHeight: layout.logoMaxHeight,
          );

    if (layout.useSingleColumn) {
      final addressLines = _wrapText(
        address,
        maxChars: _wrapChars(layout.contentWidth, layout.charWidth),
      );
      final detailLines = _wrapText(
        detailText,
        maxChars: _wrapChars(layout.contentWidth, layout.charWidth),
      );
      final headerHeight = _headerHeight(layout);
      final addressHeight = addressLines.length * layout.textLineHeight;
      final detailHeight = detailLines.length * layout.textLineHeight;
      final contentHeight =
          layout.topPadding +
          headerHeight +
          layout.sectionGap +
          addressHeight +
          layout.sectionGap +
          detailHeight +
          layout.bottomMargin;
      final contentTop = image.height - contentHeight + layout.topPadding;

      _drawBottomScrim(image, contentTop - layout.scrimBleed);
      _drawHeader(
        image,
        dayName: dayName,
        timeText: timeText,
        dateText: dateText,
        x: layout.contentLeft,
        y: contentTop,
        layout: layout,
        color: white,
        shadow: shadow,
      );

      final addressY = contentTop + headerHeight + layout.sectionGap;
      _drawTextLines(
        image,
        addressLines,
        font: layout.textFont,
        x: layout.contentLeft,
        y: addressY,
        lineHeight: layout.textLineHeight,
        color: white,
        shadow: shadow,
        shadowOffset: layout.shadowOffset,
      );

      final detailsY = addressY + addressHeight + layout.sectionGap;
      _drawTextLines(
        image,
        detailLines,
        font: layout.textFont,
        x: layout.contentLeft,
        y: detailsY,
        lineHeight: layout.textLineHeight,
        color: white,
        shadow: shadow,
        shadowOffset: layout.shadowOffset,
      );
    } else {
      final leftWidth = (layout.contentWidth * 0.32).round();
      final rightX = layout.contentLeft + leftWidth + layout.columnGap;
      final rightWidth = layout.contentRight - rightX;
      final addressLines = _wrapText(
        address,
        maxChars: _wrapChars(rightWidth, layout.charWidth),
      );
      final detailLines = _wrapText(
        detailText,
        maxChars: _wrapChars(rightWidth, layout.charWidth),
      );
      final headerHeight = _headerHeight(layout);
      final rightHeight =
          (addressLines.length * layout.textLineHeight) +
          layout.sectionGap +
          (detailLines.length * layout.textLineHeight);
      final bodyHeight = headerHeight > rightHeight
          ? headerHeight
          : rightHeight;
      final contentHeight =
          layout.topPadding + bodyHeight + layout.bottomMargin;
      final contentTop = image.height - contentHeight + layout.topPadding;

      _drawBottomScrim(image, contentTop - layout.scrimBleed);
      _drawHeader(
        image,
        dayName: dayName,
        timeText: timeText,
        dateText: dateText,
        x: layout.contentLeft,
        y: contentTop,
        layout: layout,
        color: white,
        shadow: shadow,
      );

      _drawTextLines(
        image,
        addressLines,
        font: layout.textFont,
        x: rightX,
        y: contentTop,
        lineHeight: layout.textLineHeight,
        color: white,
        shadow: shadow,
        shadowOffset: layout.shadowOffset,
      );

      final detailsY =
          contentTop +
          (addressLines.length * layout.textLineHeight) +
          layout.sectionGap;
      _drawTextLines(
        image,
        detailLines,
        font: layout.textFont,
        x: rightX,
        y: detailsY,
        lineHeight: layout.textLineHeight,
        color: white,
        shadow: shadow,
        shadowOffset: layout.shadowOffset,
      );
    }

    if (logo != null && logoSize != null) {
      _drawLogo(image, logo, logoSize, layout);
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

  void _drawHeader(
    img.Image image, {
    required String dayName,
    required String timeText,
    required String dateText,
    required int x,
    required int y,
    required _WatermarkLayout layout,
    required img.Color color,
    required img.Color shadow,
  }) {
    _drawStrongText(
      image,
      dayName,
      font: layout.textFont,
      x: x,
      y: y,
      color: color,
      shadow: shadow,
      shadowOffset: layout.shadowOffset,
    );

    final timeY = y + layout.textLineHeight;
    _drawStrongText(
      image,
      timeText,
      font: layout.timeFont,
      x: x,
      y: timeY,
      color: color,
      shadow: shadow,
      shadowOffset: layout.shadowOffset,
    );

    _drawStrongText(
      image,
      dateText,
      font: layout.textFont,
      x: x,
      y: timeY + layout.timeFont.lineHeight,
      color: color,
      shadow: shadow,
      shadowOffset: layout.shadowOffset,
    );
  }

  void _drawTextLines(
    img.Image image,
    List<String> lines, {
    required img.BitmapFont font,
    required int x,
    required int y,
    required int lineHeight,
    required img.Color color,
    required img.Color shadow,
    required int shadowOffset,
  }) {
    for (var index = 0; index < lines.length; index++) {
      _drawStrongText(
        image,
        lines[index],
        font: font,
        x: x,
        y: y + (index * lineHeight),
        color: color,
        shadow: shadow,
        shadowOffset: shadowOffset,
      );
    }
  }

  void _drawLogo(
    img.Image image,
    img.Image logo,
    _ImageSize size,
    _WatermarkLayout layout,
  ) {
    final resizedLogo = img.copyResize(
      logo,
      width: size.width,
      height: size.height,
    );

    img.compositeImage(
      image,
      resizedLogo,
      dstX: layout.contentRight - size.width,
      dstY: layout.logoTop,
      blend: img.BlendMode.alpha,
    );
  }

  void _drawBottomScrim(img.Image image, int fromY) {
    final startY = fromY.clamp(0, image.height - 1).toInt();
    final scrimHeight = image.height - startY;
    if (scrimHeight <= 0) return;

    const bands = 48;
    final bandHeight = (scrimHeight / bands)
        .ceil()
        .clamp(1, image.height)
        .toInt();

    for (var index = 0; index < bands; index++) {
      final y1 = startY + (index * bandHeight);
      if (y1 >= image.height) break;

      final y2 = (y1 + bandHeight - 1).clamp(y1, image.height - 1).toInt();
      final progress = index / (bands - 1);
      final alpha = (26 + (progress * 134)).round().clamp(26, 160).toInt();

      img.fillRect(
        image,
        x1: 0,
        y1: y1,
        x2: image.width - 1,
        y2: y2,
        color: img.ColorRgba8(0, 0, 0, alpha),
      );
    }
  }

  int _headerHeight(_WatermarkLayout layout) {
    return layout.textLineHeight +
        layout.timeFont.lineHeight +
        layout.textFont.lineHeight;
  }

  int _wrapChars(int width, double charWidth) {
    return (width / charWidth).floor().clamp(18, 160).toInt();
  }

  _ImageSize? _scaledSize(
    img.Image source, {
    required int maxWidth,
    required int maxHeight,
  }) {
    if (source.width <= 0 || source.height <= 0) return null;

    final widthScale = maxWidth / source.width;
    final heightScale = maxHeight / source.height;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    if (scale <= 0) return null;

    return _ImageSize(
      (source.width * scale).round().clamp(1, maxWidth).toInt(),
      (source.height * scale).round().clamp(1, maxHeight).toInt(),
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
    img.drawString(image, text, font: font, x: x + 1, y: y, color: color);
    img.drawString(image, text, font: font, x: x, y: y, color: color);
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
    return 'Lat ${value.toStringAsFixed(6)} deg';
  }

  String _formatLongitude(double? value) {
    if (value == null) return 'Long --';
    return 'Long ${value.toStringAsFixed(6)} deg';
  }

  String _formatAccuracy(double? value) {
    if (value == null) return 'Akurasi --';
    return 'Akurasi ${value.toStringAsFixed(1)}';
  }

  String _formatAltitude(double? value) {
    if (value == null) return 'Alt --';
    return 'Alt ${value.toStringAsFixed(1)} m';
  }

  String _formatDetails(WatermarkData data) {
    return [
      _formatLatitude(data.latitude),
      _formatLongitude(data.longitude),
      _formatAccuracy(data.accuracy),
      _formatAltitude(data.altitude),
    ].join(' | ');
  }

  List<String> _wrapText(String value, {required int maxChars}) {
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

      // Alamat harus tetap lengkap. Baris boleh bertambah, teks tidak dipotong.
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

class _WatermarkLayout {
  const _WatermarkLayout({
    required this.contentLeft,
    required this.contentRight,
    required this.contentWidth,
    required this.topPadding,
    required this.bottomMargin,
    required this.sectionGap,
    required this.columnGap,
    required this.scrimBleed,
    required this.logoTop,
    required this.logoMaxWidth,
    required this.logoMaxHeight,
    required this.textFont,
    required this.timeFont,
    required this.textLineHeight,
    required this.charWidth,
    required this.shadowOffset,
    required this.useSingleColumn,
  });

  factory _WatermarkLayout.forImage(int width, int height) {
    final shortSide = width < height ? width : height;
    final ratio = width / height;
    final isWide = ratio >= 1.35;
    final padding = (shortSide * 0.035).round().clamp(18, 120).toInt();
    final contentWidth = width - (padding * 2);
    final textFont = shortSide >= 1200 ? img.arial24 : img.arial14;
    final timeFont = shortSide >= 1200 ? img.arial48 : img.arial24;
    final textLineHeight = textFont.lineHeight + (shortSide >= 1200 ? 4 : 2);

    return _WatermarkLayout(
      contentLeft: padding,
      contentRight: width - padding,
      contentWidth: contentWidth,
      topPadding: (shortSide * 0.022).round().clamp(10, 48).toInt(),
      bottomMargin: (shortSide * 0.028).round().clamp(14, 60).toInt(),
      sectionGap: (shortSide * 0.012).round().clamp(6, 22).toInt(),
      columnGap: (contentWidth * 0.045).round().clamp(18, 80).toInt(),
      scrimBleed: (shortSide * 0.055).round().clamp(24, 110).toInt(),
      logoTop: (shortSide * 0.035).round().clamp(18, 100).toInt(),
      logoMaxWidth: (width * (isWide ? 0.22 : 0.30)).round(),
      logoMaxHeight: (shortSide * (isWide ? 0.11 : 0.085)).round(),
      textFont: textFont,
      timeFont: timeFont,
      textLineHeight: textLineHeight,
      charWidth: shortSide >= 1200 ? 13.0 : 8.0,
      shadowOffset: shortSide >= 1200 ? 2 : 1,
      useSingleColumn: !isWide,
    );
  }

  final int contentLeft;
  final int contentRight;
  final int contentWidth;
  final int topPadding;
  final int bottomMargin;
  final int sectionGap;
  final int columnGap;
  final int scrimBleed;
  final int logoTop;
  final int logoMaxWidth;
  final int logoMaxHeight;
  final img.BitmapFont textFont;
  final img.BitmapFont timeFont;
  final int textLineHeight;
  final double charWidth;
  final int shadowOffset;
  final bool useSingleColumn;
}

class _ImageSize {
  const _ImageSize(this.width, this.height);

  final int width;
  final int height;
}
