import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kilitli rozet kartındaki ince ilerleme halkası — ikon dairesini çevreliyor.
///
/// Ekran 02'nin `CountdownRingPainter`'ından ayrı duruyor: oradaki halka
/// ekranın kahramanı (9px kalınlık, üç duraklı gradyan, kesik çizgili iç
/// çember), buradaki ise kartın içinde bir yan bilgi. Aynı painter'ı ölçekleyip
/// paylaşmak, kahramanın geometrisini 56px'lik bir karta sıkıştırmak olurdu.
class BadgeProgressRingPainter extends CustomPainter {
  const BadgeProgressRingPainter({
    required this.ratio,
    required this.trackColor,
    required this.progressColor,
  });

  /// 0–1 arası; `BadgeProgress.ratio` zaten sınırlıyor.
  final double ratio;

  /// Kat edilmemiş yol. Halkanın tamamı çiziliyor ki "ne kadar kaldığı" da
  /// görünsün — yalnızca dolan yay, ölçeği olmayan bir parça olurdu.
  final Color trackColor;

  final Color progressColor;

  static const double _strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - _strokeWidth) / 2;

    final Paint track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas.drawCircle(center, radius, track);

    if (ratio <= 0) return;

    final Paint progress = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      // Yuvarlak uç: tek pomodoroluk ilerlemede bile yayın bir "başı" olsun.
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      // Saat 12'den başlayıp saat yönünde — sayacın okunma yönüyle aynı.
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0.0, 1.0),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant BadgeProgressRingPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
