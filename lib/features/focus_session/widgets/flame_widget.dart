import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ekran 03'ün meşalesi. SPEC.md §5.5: "`progress` 0→1 ile alev büyür...
/// Duraklıyken `ColorFiltered` ile doygunluk 0... Lottie gerekmez." Prototipin
/// `flick` keyframe'inin sayısal değerleri `_ds_bundle.js` içinde derlenmiş
/// halde, kaynak yüzdeleri prototip HTML'inde görünmüyor — SPEC.md §0 kural 5
/// gereği (belirtilmemiş detayda kendi kararını ver) sinüs tabanlı hafif bir
/// titreşim (salınım + gerilme + eğim) olarak yorumlandı, aynı "canlı alev"
/// izlenimini verir.
class FlameWidget extends StatefulWidget {
  const FlameWidget({required this.running, required this.progress, super.key});

  final bool running;
  final double progress;

  @override
  State<FlameWidget> createState() => _FlameWidgetState();
}

class _FlameWidgetState extends State<FlameWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _flick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    _syncFlick();
  }

  @override
  void didUpdateWidget(FlameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlick();
  }

  /// SPEC.md §6: odak ekranı 25 dakika wakelock ile açık kalıyor. Duraklatılmış
  /// seansta alev soluyor (`_desaturate`) ama titremeye devam ediyordu —
  /// süresiz durabilen bir ekranda saniyede 60 kare çizmenin sebebi yok, ve
  /// donmuş alev "duraklatıldı"yı zaten en doğru anlatan hâl. §6.4'ün "meşale
  /// ve halka çalışmaya devam eder" istisnası **süren** seans için.
  void _syncFlick() {
    if (widget.running && !_flick.isAnimating) {
      _flick.repeat();
    } else if (!widget.running && _flick.isAnimating) {
      _flick.stop();
    }
  }

  @override
  void dispose() {
    _flick.dispose();
    super.dispose();
  }

  static const ColorFilter _desaturate = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final double growthScale = 0.55 + 0.45 * widget.progress.clamp(0.0, 1.0);

    Widget flame = AnimatedBuilder(
      animation: _flick,
      builder: (BuildContext context, Widget? child) {
        final double t = _flick.value * 2 * math.pi;
        final double sway = math.sin(t) * 3;
        final double stretch = 1 + math.sin(t * 1.3) * 0.045;
        final double skew = math.sin(t * 0.7) * 0.05;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(sway, 0.0, 0.0, 1.0)
            ..scaleByDouble(1.0, stretch, 1.0, 1.0)
            ..setEntry(0, 1, skew),
          child: child,
        );
      },
      // SPEC.md §6 kural 5 ("`RepaintBoundary` ile meşaleyi ayır"), içteki
      // yarısı: alevin şekli hiç değişmiyor, yalnızca üstündeki `Transform`
      // değişiyor. Sınır sayesinde `Transform` bileşikleşiyor (composited) ve
      // kare başına iş, hazır katmanın matrisini güncellemeye iniyor —
      // gradyanlı gövde yeniden rasterize edilmiyor.
      child: const RepaintBoundary(child: _FlameShape()),
    );

    if (!widget.running) {
      flame = ColorFiltered(colorFilter: _desaturate, child: flame);
    }

    // Dıştaki yarısı: bu sınır olmadan `Transform`un her karedeki
    // `markNeedsPaint`i en yakın üst sınıra kadar çıkıyordu — o sınır Ekran
    // 03'te alevle **aynı** katmanda duran 72px sayaç metnini de kapsıyor, yani
    // saat saniyede 60 kez yeniden çiziliyordu.
    return RepaintBoundary(
      child: Transform.scale(
        scale: growthScale,
        alignment: Alignment.bottomCenter,
        child: flame,
      ),
    );
  }
}

class _FlameShape extends StatelessWidget {
  const _FlameShape();

  /// Gövdenin közden aleve giden gradyanı. Koyu temada prototipin değerleri
  /// birebir: en üstteki durak neredeyse beyaz, gece zemininde alevin ucu orada
  /// parlıyor. Açık temada o krem uç (#FFF3D8) zeminle 1.02:1 kontrasta düşüyor
  /// — meşalenin tepesi sayfaya karışıyor, alev kesilmiş gibi duruyordu. Uç bu
  /// yüzden ember'ın kendisine çekiliyor: halkanın gradyanına uygulanan
  /// düzeltmeyle (`_focusRingGradient`) aynı gerekçe, aynı varış noktası.
  /// İçteki beyaz çekirdek gövdenin **içinde** kaldığı için iki temada da aynı.
  static const List<Color> _darkBody = <Color>[Color(0xFF7A2F0C), Color(0xFFFFB03A), Color(0xFFFFF3D8)];
  static const List<Color> _lightBody = <Color>[Color(0xFF7A2F0C), Color(0xFFE8880F), Color(0xFFFFB03A)];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 64,
      height: 98,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          Container(
            width: 44,
            height: 86,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDark ? _darkBody : _lightBody,
                stops: const <double>[0, 0.56, 1],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(22, 58),
                topRight: Radius.elliptical(22, 58),
                bottomLeft: Radius.elliptical(20, 27),
                bottomRight: Radius.elliptical(20, 27),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 18,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xF2FFFAF0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.elliptical(9, 28),
                  topRight: Radius.elliptical(9, 28),
                  bottomLeft: Radius.elliptical(9, 17),
                  bottomRight: Radius.elliptical(9, 17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
