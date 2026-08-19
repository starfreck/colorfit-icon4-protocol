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
  const WatchFaceStyle(
    name: 'Minimal',
    description: 'Clean and simple',
    backgroundType: BackgroundType.solid,
    backgroundColor: Colors.black,
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w100,
    timeFontSize: 72,
    dateColor: Colors.white54,
  ),
  const WatchFaceStyle(
    name: 'Gradient',
    description: 'Smooth dark gradient',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w200,
    timeFontSize: 68,
  ),
  const WatchFaceStyle(
    name: 'Neon',
    description: 'Vibrant neon glow',
    backgroundType: BackgroundType.solid,
    backgroundColor: Color(0xFF0a0a0a),
    timeColor: Color(0xFF00FF88),
    timeFontWeight: FontWeight.w300,
    timeFontSize: 64,
    dateColor: Color(0xFF00FF88),
  ),
  const WatchFaceStyle(
    name: 'Activity Rings',
    description: 'Apple Watch style rings',
    backgroundType: BackgroundType.rings,
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w200,
    timeFontSize: 56,
    timePositionY: 140,
    datePositionY: 195,
  ),
  const WatchFaceStyle(
    name: 'Bold',
    description: 'Thick and impactful',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w900,
    timeFontSize: 80,
    timeLetterSpacing: -2,
    dateColor: Colors.white38,
  ),
  const WatchFaceStyle(
    name: 'Sunset',
    description: 'Warm orange gradient',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF1a0a00), Color(0xFF4a1a00)],
    timeColor: Color(0xFFFF8C42),
    timeFontWeight: FontWeight.w200,
    timeFontSize: 66,
    dateColor: Color(0xFFFF8C42),
  ),
  const WatchFaceStyle(
    name: 'Ocean',
    description: 'Deep blue waves',
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF000428), Color(0xFF004e92)],
    timeColor: Colors.white,
    timeFontWeight: FontWeight.w100,
    timeFontSize: 70,
    dateColor: Colors.white60,
  ),
  const WatchFaceStyle(
    name: 'Digital',
    description: 'Retro digital display',
    backgroundType: BackgroundType.solid,
    backgroundColor: Color(0xFF0a0a0a),
    timeColor: Color(0xFF00FF00),
    timeFontWeight: FontWeight.w700,
    timeFontFamily: 'monospace',
    timeFontSize: 62,
    dateColor: Color(0xFF00FF00),
  ),
];
