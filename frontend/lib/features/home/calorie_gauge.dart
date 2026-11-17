import 'dart:math' as math;

import 'package:flutter/material.dart';

class CalorieGauge extends StatelessWidget {
  const CalorieGauge({
    super.key,
    required this.progress,
    required this.color,
    required this.number,
    required this.numberColor,
    required this.label,
  });

  final double progress;
  final Color color;
  final int number;
  final Color numberColor;
  final String label;

  static const double _width = 220;
  static const double _height = 180;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: const Size(_width, _height),
            painter: _GaugePainter(progress: progress, color: color),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.local_fire_department, color: color, size: 28),
                Text(
                  '$number',
                  style: TextStyle(color: numberColor, fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const double _strokeWidth = 26;
  static const double _startDegrees = 150;
  static const double _sweepDegrees = 240;

  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2 - _strokeWidth / 2;
    final Offset center = Offset(size.width / 2, size.width / 2);
    final Rect circleBounds = Rect.fromCircle(center: center, radius: radius);

    final double startAngle = _toRadians(_startDegrees);
    final double fullSweep = _toRadians(_sweepDegrees);

    final Paint trackPaint = Paint();
    trackPaint.color = color.withValues(alpha: 0.35);
    trackPaint.style = PaintingStyle.stroke;
    trackPaint.strokeWidth = _strokeWidth;
    trackPaint.strokeCap = StrokeCap.round;

    final Paint valuePaint = Paint();
    valuePaint.color = color;
    valuePaint.style = PaintingStyle.stroke;
    valuePaint.strokeWidth = _strokeWidth;
    valuePaint.strokeCap = StrokeCap.round;

    canvas.drawArc(circleBounds, startAngle, fullSweep, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(circleBounds, startAngle, fullSweep * progress, false, valuePaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    if (oldDelegate.progress != progress) {
      return true;
    }
    if (oldDelegate.color != color) {
      return true;
    }
    return false;
  }
}
