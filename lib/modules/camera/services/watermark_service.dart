import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'watermark_layout_engine.dart';

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

    // Use Flutter's TrueType text renderer for both orientations. Font sizes
    // are derived from the source image resolution inside the renderer.
    final measuredLayer = await _renderMeasuredLandscapeLayer(
      imageWidth: image.width,
      imageHeight: image.height,
      dayName: dayName,
      timeText: timeText,
      dateText: dateText,
      address: address,
      data: data,
      hasBranding: logo != null,
      logo: logo,
    );
    img.compositeImage(image, measuredLayer);

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

  Future<img.Image> _renderMeasuredLandscapeLayer({
    required int imageWidth,
    required int imageHeight,
    required String dayName,
    required String timeText,
    required String dateText,
    required String address,
    required WatermarkData data,
    required bool hasBranding,
    required img.Image? logo,
  }) async {
    final shortSide = imageWidth < imageHeight ? imageWidth : imageHeight;
    final bodyFontSize = (shortSide * 0.019).clamp(18.0, 54.0).toDouble();
    final timeFontSize = (shortSide * 0.082).clamp(44.0, 210.0).toDouble();
    final bodyStyle = TextStyle(
      color: const ui.Color(0xFFFFFFFF),
      fontSize: bodyFontSize,
      height: 1.18,
      fontWeight: FontWeight.w500,
    );
    final addressStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);
    final timeStyle = bodyStyle.copyWith(
      fontSize: timeFontSize,
      height: 1.0,
      fontWeight: FontWeight.w800,
    );
    final engine = const WatermarkLayoutEngine();
    final layout = engine.calculate(
      imageSize: ui.Size(imageWidth.toDouble(), imageHeight.toDouble()),
      address: address,
      bodyStyle: addressStyle,
      timeStyle: timeStyle,
      textDirection: ui.TextDirection.ltr,
      hasBranding: hasBranding,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final panelRect = layout.panelRect;
    final panelRadius = (shortSide * 0.022).clamp(12.0, 44.0).toDouble();

    // Render a distinct rounded panel inset from all image edges. Keeping the
    // gradient inside this shape avoids the old full-width black band.
    final panelPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset(0, panelRect.top),
        ui.Offset(0, panelRect.bottom),
        const [
          ui.Color(0x66101010),
          ui.Color(0xB8101010),
          ui.Color(0xE6101010),
        ],
        const [0.0, 0.42, 1.0],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        panelRect,
        ui.Radius.circular(panelRadius),
      ),
      panelPaint,
    );

    if (layout.dividerX != null) {
      final dividerPaint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..strokeWidth = (shortSide * 0.003).clamp(2.0, 8.0).toDouble();
      canvas.drawLine(
        ui.Offset(layout.dividerX!, layout.panelRect.top + layout.panelRect.height * 0.12),
        ui.Offset(layout.dividerX!, layout.panelRect.bottom - layout.panelRect.height * 0.12),
        dividerPaint,
      );
    }

    void drawText(
      String value,
      TextStyle style,
      double x,
      double y,
      double maxWidth, {
      int? maxLines,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, ui.Offset(x, y));
    }

    final left = layout.leftContentRect;
    final right = layout.rightContentRect;
    final innerGap = layout.sectionGap;
    if (layout.isWideLandscape) {
      drawText(dayName, addressStyle, left.left, left.top, left.width);
      drawText(
        timeText,
        timeStyle,
        left.left,
        left.top + layout.bodyLineHeight * 1.35,
        left.width,
        maxLines: 1,
      );
      drawText(
        dateText,
        bodyStyle,
        left.left,
        left.bottom - layout.bodyLineHeight,
        left.width,
        maxLines: 1,
      );

      var infoTop = right.top;
      if (hasBranding && layout.logoRect != ui.Rect.zero) {
        infoTop += layout.logoRect.height + innerGap * 0.5;
      }
      final addressPainter = TextPainter(
        text: TextSpan(text: address, style: addressStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: right.width);
      addressPainter.paint(canvas, ui.Offset(right.left, infoTop));
      final detailY = infoTop + addressPainter.height + innerGap;
      drawText(
        '${_formatLatitude(data.latitude)}    ${_formatLongitude(data.longitude)}',
        bodyStyle,
        right.left,
        detailY,
        right.width,
        maxLines: 1,
      );
      drawText(
        '${_formatAccuracy(data.accuracy)}    ${_formatAltitude(data.altitude)}',
        bodyStyle,
        right.left,
        detailY + layout.bodyLineHeight * 1.25,
        right.width,
        maxLines: 1,
      );
    } else {
      var y = right.top;
      drawText(dayName, addressStyle, right.left, y, right.width, maxLines: 1);
      y += layout.bodyLineHeight;
      drawText(timeText, timeStyle, right.left, y, right.width, maxLines: 1);
      y += layout.timeLineHeight + innerGap;
      drawText(dateText, bodyStyle, right.left, y, right.width, maxLines: 1);
      y += layout.bodyLineHeight + innerGap;
      final addressPainter = TextPainter(
        text: TextSpan(text: address, style: addressStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: right.width);
      addressPainter.paint(canvas, ui.Offset(right.left, y));
      y += addressPainter.height + innerGap;
      drawText(
        '${_formatLatitude(data.latitude)}  ${_formatLongitude(data.longitude)}',
        bodyStyle,
        right.left,
        y,
        right.width,
      );
      y += layout.bodyLineHeight;
      drawText(
        '${_formatAccuracy(data.accuracy)}  ${_formatAltitude(data.altitude)}',
        bodyStyle,
        right.left,
        y,
        right.width,
      );
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(imageWidth, imageHeight);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    picture.dispose();
    if (byteData == null) {
      throw const FormatException('Watermark layer gagal dirender.');
    }
    final pngBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw const FormatException('Watermark layer PNG tidak valid.');
    }
    if (logo != null && layout.logoRect != ui.Rect.zero) {
      // Fit the logo into the reserved top-right area without distorting it.
      final fitted = _scaledSize(
        logo,
        maxWidth: layout.logoRect.width.round().clamp(1, imageWidth).toInt(),
        maxHeight: layout.logoRect.height.round().clamp(1, imageHeight).toInt(),
      );
      if (fitted != null) {
        final resizedLogo = img.copyResize(
          logo,
          width: fitted.width,
          height: fitted.height,
        );
        img.compositeImage(
          decoded,
          resizedLogo,
          dstX: (layout.logoRect.right - fitted.width)
              .round()
              .clamp(0, imageWidth - fitted.width)
              .toInt(),
          dstY: layout.logoRect.top
              .round()
              .clamp(0, imageHeight - fitted.height)
              .toInt(),
          blend: img.BlendMode.alpha,
        );
      }
    }
    return decoded;
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
    // Portrait dan landscape memakai komposisi watermark yang sama.
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
      logoMaxWidth: (width * 0.30).round(),
      logoMaxHeight: (shortSide * 0.085).round(),
      textFont: textFont,
      timeFont: timeFont,
      textLineHeight: textLineHeight,
      charWidth: shortSide >= 1200 ? 13.0 : 8.0,
      shadowOffset: shortSide >= 1200 ? 2 : 1,
      useSingleColumn: true,
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
