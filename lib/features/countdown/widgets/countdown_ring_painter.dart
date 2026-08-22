import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ekran 02'nin dairesel ilerleme halkası. SPEC.md binding haritası:
/// "Dairesel ilerleme ... `CustomPainter`, `C = 2πr`, r=130" — prototipin
/// `viewBox="0 0 316 316"`, merkez (158,158) geometrisi birebir.
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({required this.progressRatio, required this.dashRotation});

  final double progressRatio;
  final double dashRotation;

  static const double _viewBoxSize = 316;
  static const double _outerRadius = 142;
  static const double _trackRadius = 130;
  static const double _dashedRadius = 112;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _viewBoxSize;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint outer = Paint()
      ..color = const Color(0x17FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;
    canvas.drawCircle(center, _outerRadius * scale, outer);

    final Paint track = Paint()
      ..color = const Color(0x12FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale;
    canvas.drawCircle(center, _trackRadius * scale, track);

    final Rect progressRect = Rect.fromCircle(center: center, radius: _trackRadius * scale);
    final Paint progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: <Color>[Color(0xFF63B4FF), Color(0xFFB5ABFC), Color(0xFFFFB03A)],
        stops: <double>[0, 0.48, 1],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(progressRect);
    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progressRatio.clamp(0.0, 1.0);
    canvas.drawArc(progressRect, startAngle, sweepAngle, false, progress);

    final Paint dashed = Paint()
      ..color = const Color(0x59FFB03A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;
    _drawDashedCircle(
      canvas: canvas,
      center: center,
      radius: _dashedRadius * scale,
      dashLength: 2 * scale,
      gapLength: 12 * scale,
      rotation: dashRotation,
      paint: dashed,
    );
  }

  void _drawDashedCircle({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double dashLength,
    required double gapLength,
    required double rotation,
    required Paint paint,
  }) {
    final double circumference = 2 * math.pi * radius;
    final int dashCount = (circumference / (dashLength + gapLength)).floor();
    if (dashCount <= 0) return;
    final double anglePerDash = (2 * math.pi) / dashCount;
    final double dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));
    for (int i = 0; i < dashCount; i++) {
      final double start = rotation + i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CountdownRingPainter oldDelegate) {
    return oldDelegate.progressRatio != progressRatio || oldDelegate.dashRotation != dashRotation;
  }
}
