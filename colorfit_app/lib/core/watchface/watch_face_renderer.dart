import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WatchFaceRenderer {
  static Future<Uint8List> renderToPng({
    required WatchFaceStyle style,
    required DateTime time,
    required double width,
    required double height,
    Map<String, dynamic>? healthData,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    _drawBackground(canvas, style, width, height);
    _drawTime(canvas, style, time, width, height);
    if (style.showDate) _drawDate(canvas, style, time, width, height);
    if (style.showHealth) _drawHealth(canvas, style, healthData, width, height);
    if (style.showComplications) _drawComplications(canvas, style, time, healthData, width, height);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Render watch face design directly into watch-native compressed buffer (RLE RGB565)
  static Future<Uint8List> renderToRGB565({
    required WatchFaceStyle style,
    required DateTime time,
    required int width,
    required int height,
    Map<String, dynamic>? healthData,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    _drawBackground(canvas, style, width.toDouble(), height.toDouble());
    _drawTime(canvas, style, time, width.toDouble(), height.toDouble());
    if (style.showDate) _drawDate(canvas, style, time, width.toDouble(), height.toDouble());
    if (style.showHealth) _drawHealth(canvas, style, healthData, width.toDouble(), height.toDouble());
    if (style.showComplications) _drawComplications(canvas, style, time, healthData, width.toDouble(), height.toDouble());

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final rawByteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rawByteData == null) throw Exception('Failed to get raw RGBA bytes');

    return encodeWatchFaceBitmap(rawByteData.buffer.asUint8List(), width, height);
  }

  /// Convert an arbitrary image into watch-native compressed buffer (RLE RGB565)
  static Future<Uint8List> convertImageToRGB565(Uint8List imageBytes, int targetWidth, int targetHeight) async {
    final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: targetWidth, targetHeight: targetHeight);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rawByteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rawByteData == null) throw Exception('Failed to convert image');

    return encodeWatchFaceBitmap(rawByteData.buffer.asUint8List(), targetWidth, targetHeight);
  }

  /// Encodes raw RGBA bytes into CrRePa native RLE format (up to 90% bandwidth reduction)
  static Uint8List encodeWatchFaceBitmap(Uint8List rgba, int width, int height) {
    final rawRgb565 = Uint8List(width * height * 2);
    final rleColors = <int>[];
    final rleCounts = <int>[];

    int rawIndex = 0;
    int prevColor = -1;
    int runLength = 0;

    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];

      final r5 = (r >> 3) & 0x1F;
      final g6 = (g >> 2) & 0x3F;
      final b5 = (b >> 3) & 0x1F;
      int color16 = (r5 << 11) | (g6 << 5) | b5;
      if (color16 == 2081) color16++;

      rawRgb565[rawIndex++] = (color16 >> 8) & 0xFF;
      rawRgb565[rawIndex++] = color16 & 0xFF;

      if (i == 0) {
        prevColor = color16;
        runLength = 1;
      } else {
        if (color16 != prevColor || runLength == 255) {
          rleColors.add(prevColor);
          rleCounts.add(runLength);
          prevColor = color16;
          runLength = 1;
        } else {
          runLength++;
        }
      }
    }

    if (runLength > 0) {
      rleColors.add(prevColor);
      rleCounts.add(runLength);
    }

    final rleSize = (rleColors.length * 3) + 2;
    if (rleSize < rawRgb565.length) {
      final rleBytes = Uint8List(rleSize);
      rleBytes[0] = 8;
      rleBytes[1] = 33;
      int rleIdx = 2;
      for (int k = 0; k < rleColors.length; k++) {
        final c = rleColors[k];
        rleBytes[rleIdx++] = (c >> 8) & 0xFF;
        rleBytes[rleIdx++] = c & 0xFF;
        rleBytes[rleIdx++] = rleCounts[k] & 0xFF;
      }
      return rleBytes;
    }

    return rawRgb565;
  }

  static void _drawBackground(Canvas canvas, WatchFaceStyle style, double w, double h) {
    final paint = Paint();
    switch (style.backgroundType) {
      case BackgroundType.solid:
        paint.color = style.backgroundColor;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        break;
      case BackgroundType.gradient:
        final gradient = LinearGradient(
          colors: style.gradientColors,
          begin: style.gradientStart,
          end: style.gradientEnd,
        );
        paint.shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h));
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
        break;
      case BackgroundType.rings:
        final bgPaint = Paint()..color = Colors.black;
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);
        _drawRings(canvas, style, w, h);
        break;
    }
  }

  static void _drawRings(Canvas canvas, WatchFaceStyle style, double w, double h) {
    final center = Offset(w / 2, h / 2);
    final ringRadius = w * 0.35;
    final ringWidth = w * 0.06;

    final rings = [
      (color: const Color(0xFF1DB954), progress: 0.75),
      (color: const Color(0xFFE74C3C), progress: 0.50),
      (color: const Color(0xFF3498DB), progress: 0.30),
    ];

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final radius = ringRadius - (i * ringWidth * 1.5);
      final paint = Paint()
        ..color = ring.color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, paint);

      final progressPaint = Paint()
        ..color = ring.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        6.2832 * ring.progress,
        false,
        progressPaint,
      );
    }
  }

  static void _drawTime(Canvas canvas, WatchFaceStyle style, DateTime time, double w, double h) {
    final hour = time.hour;
    final minute = time.minute;
    final timeStr = style.use24Hour
        ? '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        : '${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    final fontSize = style.timeFontSize ?? (w * 0.22);
    final textPainter = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          color: style.timeColor,
          fontSize: fontSize,
          fontWeight: style.timeFontWeight,
          fontFamily: style.timeFontFamily,
          letterSpacing: style.timeLetterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = Offset(
      (w - textPainter.width) / 2,
      style.timePositionY ?? (h * 0.35),
    );
    textPainter.paint(canvas, offset);
  }

  static void _drawDate(Canvas canvas, WatchFaceStyle style, DateTime time, double w, double h) {
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dateStr = '${days[time.weekday - 1]}  ${months[time.month - 1]} ${time.day}';

    final fontSize = style.dateFontSize ?? (w * 0.06);
    final textPainter = TextPainter(
      text: TextSpan(
        text: dateStr,
        style: TextStyle(
          color: style.dateColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = Offset(
      (w - textPainter.width) / 2,
      style.datePositionY ?? (h * 0.55),
    );
    textPainter.paint(canvas, offset);
  }

  static void _drawHealth(Canvas canvas, WatchFaceStyle style, Map<String, dynamic>? data, double w, double h) {
    if (data == null) return;
    final steps = data['steps'] ?? 0;
    final bpm = data['bpm'] ?? '--';

    final fontSize = w * 0.05;
    final yPos = h * 0.68;

    final stepsPainter = TextPainter(
      text: TextSpan(
        text: '$steps steps',
        style: TextStyle(color: const Color(0xFF1DB954), fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stepsPainter.paint(canvas, Offset((w - stepsPainter.width) / 2, yPos));

    final hrPainter = TextPainter(
      text: TextSpan(
        text: '$bpm bpm',
        style: TextStyle(color: const Color(0xFFE74C3C), fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hrPainter.paint(canvas, Offset((w - hrPainter.width) / 2, yPos + fontSize * 1.5));
  }

  static void _drawComplications(Canvas canvas, WatchFaceStyle style, DateTime time, Map<String, dynamic>? data, double w, double h) {
    final battery = data?['battery'] ?? '--';
    final fontSize = w * 0.04;

    final batteryPainter = TextPainter(
      text: TextSpan(
        text: '$battery%',
        style: TextStyle(color: Colors.white54, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    batteryPainter.paint(canvas, Offset(w * 0.1, h * 0.1));
  }
}

enum BackgroundType { solid, gradient, rings }

class WatchFaceStyle {
  final String name;
  final String description;
  final BackgroundType backgroundType;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final Alignment gradientStart;
  final Alignment gradientEnd;
  final Color timeColor;
  final Color dateColor;
  final double? timeFontSize;
  final double? dateFontSize;
  final double? timePositionY;
  final double? datePositionY;
  final FontWeight timeFontWeight;
  final String? timeFontFamily;
  final double? timeLetterSpacing;
  final bool showDate;
  final bool showHealth;
  final bool showComplications;
  final bool use24Hour;

  const WatchFaceStyle({
    required this.name,
    required this.description,
    this.backgroundType = BackgroundType.solid,
    this.backgroundColor = Colors.black,
    this.gradientColors = const [Colors.black, Color(0xFF1a1a2e)],
    this.gradientStart = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    this.timeColor = Colors.white,
    this.dateColor = Colors.white70,
    this.timeFontSize,
    this.dateFontSize,
    this.timePositionY,
    this.datePositionY,
    this.timeFontWeight = FontWeight.w200,
    this.timeFontFamily,
    this.timeLetterSpacing,
    this.showDate = true,
    this.showHealth = true,
    this.showComplications = true,
    this.use24Hour = true,
  });
}

final List<WatchFaceStyle> defaultWatchFaces = [
  // 1. Elegant Minimal — clean black with thin white time
  const WatchFaceStyle(
    name: 'Minimal',
    description: 'Clean and elegant',
    backgroundType: BackgroundType.solid,
    backgroundColor: Colors.black,
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w100,
    timeFontSize: 72,
    dateColor: Colors.white54,
    showHealth: false,
    showComplications: false,
  ),
  // 2. Aurora — purple-teal northern lights gradient
  const WatchFaceStyle(
    name: 'Aurora',
    description: 'Northern lights glow',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0D001A), Color(0xFF1A0033), Color(0xFF00332E), Color(0xFF001A0D)],
    gradientStart: Alignment.topLeft,
    gradientEnd: Alignment.bottomRight,
    timeColor: Color(0xFFE0B0FF),
    timeFontWeight: FontWeight.w200,
    timeFontSize: 68,
    dateColor: Color(0xFF80CBC4),
  ),
  // 3. Fitness Rings — Apple Watch-inspired
  const WatchFaceStyle(
    name: 'Fitness Rings',
    description: 'Activity ring tracker',
    backgroundType: BackgroundType.rings,
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w200,
    timeFontSize: 48,
    timePositionY: 108,
    datePositionY: 160,
    showHealth: true,
  ),
  // 4. Neon Cyberpunk — hot cyan on deep dark
  const WatchFaceStyle(
    name: 'Cyberpunk',
    description: 'Neon future vibes',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0a0014), Color(0xFF0a001a), Color(0xFF140028)],
    timeColor: Color(0xFF00FFFF),
    timeFontWeight: FontWeight.w300,
    timeFontSize: 64,
    dateColor: Color(0xFFFF00FF),
    showHealth: true,
  ),
  // 5. Classic Sport — bold white on dark blue
  const WatchFaceStyle(
    name: 'Classic Sport',
    description: 'Bold athletic look',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF1B3A4B)],
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w900,
    timeFontSize: 76,
    timeLetterSpacing: -2,
    dateColor: Color(0xFF4FC3F7),
    showHealth: true,
  ),
  // 6. Golden Hour — warm amber sunset
  const WatchFaceStyle(
    name: 'Golden Hour',
    description: 'Warm sunset glow',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF1a0800), Color(0xFF331500), Color(0xFF4D2200)],
    gradientStart: Alignment.topCenter,
    gradientEnd: Alignment.bottomCenter,
    timeColor: Color(0xFFFFB74D),
    timeFontWeight: FontWeight.w200,
    timeFontSize: 70,
    dateColor: Color(0xFFFFCC80),
  ),
  // 7. Deep Ocean — dark navy to teal
  const WatchFaceStyle(
    name: 'Deep Ocean',
    description: 'Underwater calm',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF000814), Color(0xFF001D3D), Color(0xFF003566)],
    timeColor: Color(0xFFB2DFDB),
    timeFontWeight: FontWeight.w100,
    timeFontSize: 72,
    dateColor: Color(0xFF80CBC4),
  ),
  // 8. Cherry Blossom — soft pink accent on dark
  const WatchFaceStyle(
    name: 'Cherry Blossom',
    description: 'Soft pink elegance',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF1A0010), Color(0xFF2D001A), Color(0xFF1A0010)],
    timeColor: Color(0xFFF48FB1),
    timeFontWeight: FontWeight.w200,
    timeFontSize: 68,
    dateColor: Color(0xFFCE93D8),
    showHealth: true,
  ),
  // 9. Matrix Terminal — retro green monospace
  const WatchFaceStyle(
    name: 'Matrix',
    description: 'Hacker terminal',
    backgroundType: BackgroundType.solid,
    backgroundColor: Color(0xFF000000),
    timeColor: Color(0xFF00FF41),
    timeFontWeight: FontWeight.w700,
    timeFontFamily: 'monospace',
    timeFontSize: 60,
    dateColor: Color(0xFF00CC33),
    showHealth: true,
  ),
  // 10. Luxury — gold on deep black
  const WatchFaceStyle(
    name: 'Luxury',
    description: 'Premium gold accent',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0A0A0A), Color(0xFF1A1A0A), Color(0xFF0A0A0A)],
    timeColor: Color(0xFFFFD700),
    timeFontWeight: FontWeight.w200,
    timeFontSize: 70,
    dateColor: Color(0xFFDAA520),
    showHealth: false,
    showComplications: false,
  ),
];
