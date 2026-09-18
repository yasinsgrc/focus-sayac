import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Ekran 02'nin dairesel ilerleme halkası. SPEC.md binding haritası:
/// "Dairesel ilerleme ... `CustomPainter`, `C = 2πr`, r=130" — prototipin
/// `viewBox="0 0 316 316"`, merkez (158,158) geometrisi birebir.
class CountdownRingPainter extends CustomPainter {
  const CountdownRingPainter({
    required this.progressRatio,
    required this.effortRatio,
    required this.effortReached,
    required this.dashRotation,
    required this.colors,
  });

  /// Zaman ekseni: `clamp(1 - days/400, 0.06, 1)`. Sınava yaklaştıkça dolar.
  final double progressRatio;

  /// Emek ekseni (ROADMAP madde 27): bu haftanın odağının haftalık hedefe oranı.
  ///
  /// `null` = hedef kapalı, yay **hiç çizilmiyor** — izi de dahil. Kasten `0.0`
  /// değil: boş bir yay "hedefinin %0'ındasın" der, oysa kullanıcının koyduğu
  /// bir hedef yok. `_WeeklyGoalRow`un kapalı hedefte satırı tamamen
  /// gizlemesiyle aynı karar.
  final double? effortRatio;

  /// Hedef doldu mu — ton közden naneye dönüyor (`mint` uygulamanın tamamlanma
  /// dili; haftalık hedef çubuğu da aynı iki tonu kullanıyor).
  final bool effortReached;

  final double dashRotation;

  /// Painter'ın `BuildContext`i yok; palet çağıran ekrandan geçiriliyor.
  /// [AppColors.dark]/[AppColors.light] `const` olduğu için her çağrıda aynı
  /// örnek dönüyor — [shouldRepaint]'teki kimlik karşılaştırması bu sayede
  /// yalnızca tema gerçekten değiştiğinde yeniden çizdiriyor.
  final AppColors colors;

  static const double _viewBoxSize = 316;
  static const double _outerRadius = 142;
  static const double _trackRadius = 130;
  static const double _dashedRadius = 112;
  /// Halkanın içine yazı koyan her şeyin sığması gereken çember: en içteki
  /// **dolu** yayın iç kenarı. Madde 27'den beri bu, zaman izi (125.5) değil
  /// emek yayı — 119 yarıçap, 4px kalınlık → 117.
  ///
  /// 112'lik kesik çizgili çember kasten hesaba katılmıyor: 1px, %35 saydam,
  /// dönen bir dekor ve satırın uçları onu madde 32'den **önce** de teğet
  /// geçiyordu; metni ona sığdırmak 12px'lik satırı küçültmek demekti.
  ///
  /// `countdown_screen.dart`taki meta satırının kapağı ve onun testi (ROADMAP
  /// madde 32) sayıyı buradan okuyor, iki yerde iki kez yazılıp zamanla
  /// ayrışmasın diye.
  static const double innerContentRadius = _effortRadius - _effortStrokeWidth / 2;

  /// Emek yayı prototipin **boş bandına** yerleşiyor: zaman izinin iç kenarı
  /// 125.5 (130 − 9/2), kesikli çember 112. 119 yarıçap ve 4px kalınlıkla
  /// (117–121) iki komşuya da ~4.5px kalıyor, yani prototipin hiçbir ölçüsü
  /// değişmeden ikinci eksen sığıyor.
  static const double _effortRadius = 119;
  static const double _effortStrokeWidth = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / _viewBoxSize;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint outer = Paint()
      ..color = colors.fillSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;
    canvas.drawCircle(center, _outerRadius * scale, outer);

    final Paint track = Paint()
      ..color = colors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale;
    canvas.drawCircle(center, _trackRadius * scale, track);

    final Rect progressRect = Rect.fromCircle(center: center, radius: _trackRadius * scale);
    final Paint progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 * scale
      ..strokeCap = StrokeCap.round
      // Koyu temada bu üçlü prototipin `#63b4ff → #b5abfc → #ffb03a`
      // duraklarıyla birebir aynı değerlere çözülüyor; açık temada rollerin
      // koyulaştırılmış karşılıklarına geçip beyaz zeminde solmayı önlüyor.
      ..shader = SweepGradient(
        colors: <Color>[colors.sky, colors.accent400, colors.ember],
        stops: const <double>[0, 0.48, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(progressRect);
    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progressRatio.clamp(0.0, 1.0);
    canvas.drawArc(progressRect, startAngle, sweepAngle, false, progress);

    // Emek ekseni (ROADMAP madde 27). Zaman yayı sınava 300 gün kalan
    // kullanıcıda aylarca ~%25'te duruyordu: geçen zamanı gösteriyor, harcanan
    // emeği değil. Bu yay her tamamlanan seansta kıpırdıyor ve haftalık hedef
    // dolunca kapanıyor.
    //
    // Gradyan **yok**: zaman yayı üç duraklı gradyanla dekoratif, emek yayı tek
    // düz tonla anlamsal. İkisi aynı boyayı paylaşsaydı göz onları tek bir
    // göstergenin iki parçası sanırdı — oysa bunlar iki ayrı eksen.
    final double? effort = effortRatio;
    if (effort != null) {
      final Paint effortTrack = Paint()
        ..color = colors.fillSubtle
        ..style = PaintingStyle.stroke
        ..strokeWidth = _effortStrokeWidth * scale;
      canvas.drawCircle(center, _effortRadius * scale, effortTrack);

      // Sıfır uzunluklu yay yuvarlak uçla nokta bırakırdı; haftanın başında
      // ekranda açıklanamayan bir leke olurdu — iz zaten ekseni gösteriyor.
      if (effort > 0) {
        final Paint effortProgress = Paint()
          ..color = effortReached ? colors.mint : colors.ember
          ..style = PaintingStyle.stroke
          ..strokeWidth = _effortStrokeWidth * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: _effortRadius * scale),
          startAngle,
          2 * math.pi * effort.clamp(0.0, 1.0),
          false,
          effortProgress,
        );
      }
    }

    final Paint dashed = Paint()
      ..color = colors.ember.withValues(alpha: 0.35)
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
    return oldDelegate.progressRatio != progressRatio ||
        oldDelegate.effortRatio != effortRatio ||
        oldDelegate.effortReached != effortReached ||
        oldDelegate.dashRotation != dashRotation ||
        oldDelegate.colors != colors;
  }
}
