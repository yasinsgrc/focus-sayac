import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Ekran 03/09'un dairesel ilerleme halkası. SPEC.md binding haritası:
/// "Dairesel halka `FC = 2π×135` — prototipin sabiti"; prototipin
/// `viewBox="0 0 330 330"`, merkez (165,165) geometrisi birebir. Odak ve mola
/// ekranı aynı geometriyi, farklı renk kaynağıyla paylaşır (`fdg`/`mdg`
/// gradyanları ya da duraklatılmışken düz renk).
class SessionRingPainter extends CustomPainter {
  const SessionRingPainter({
    required this.progress,
    required this.colors,
    this.gradientColors,
    this.gradientStops,
    this.solidColor,
  });

  final double progress;

  /// Painter'ın `BuildContext`i yok; palet çağıran ekrandan geçiriliyor
  /// ([CountdownRingPainter] ile aynı gerekçe).
  final AppColors colors;
  final List<Color>? gradientColors;
  final List<double>? gradientStops;
  final Color? solidColor;

  static const double _viewBoxSize = 330;
  static const double _outerRadius = 149;
  static const double _trackRadius = 135;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _viewBoxSize;
    final Offset center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      _outerRadius * scale,
      Paint()
        ..color = colors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale,
    );

    canvas.drawCircle(
      center,
      _trackRadius * scale,
      Paint()
        ..color = colors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * scale,
    );

    final Rect progressRect = Rect.fromCircle(center: center, radius: _trackRadius * scale);
    final Paint progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * scale
      ..strokeCap = StrokeCap.round;

    final List<Color>? gradient = gradientColors;
    if (gradient != null) {
      progressPaint.shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: gradient,
        stops: gradientStops,
      ).createShader(progressRect);
    } else {
      progressPaint.color = solidColor ?? colors.neutral700;
    }

    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(progressRect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant SessionRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.solidColor != solidColor ||
        oldDelegate.colors != colors;
  }
}
