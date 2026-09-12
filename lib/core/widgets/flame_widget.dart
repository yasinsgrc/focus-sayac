import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/flame/flame_tier.dart';

/// Meşale avatarı. **İki ayrı eksen, ayrı kanallar:**
///
/// - **Kademe** (kalıcı): boyut oranı, kor yatağı, kıvılcımlar, hâle.
///   Kümülatif odak saatinden gelir, asla küçülmez.
/// - **Seans** (geçici): çekirdek parlaklığı, titreşim genliği, kıvılcım
///   yoğunluğu. Seans bitince alev kademenin dinlenme hâline döner.
///
/// Seans [intensity]si **boyutu değiştirmiyor**. Sebep: K9→K10 arası oran
/// farkı %6; seans şişmesi eklenseydi iki eksen birbirine karışır, "kademe
/// atladım mı?" sorusu belirsizleşirdi.
///
/// Titreşimin sayısal keyframe değerleri prototipte yok (`_ds_bundle.js`
/// içinde derlenmiş); sinüs tabanlı salınım + gerilme + eğim olarak
/// yorumlandı (SPEC.md §0 kural 5, DECISIONS.md:272).
class FlameWidget extends StatefulWidget {
  const FlameWidget({
    required this.tier,
    required this.boxHeight,
    this.intensity = 0,
    this.flickering = false,
    this.desaturated = false,
    super.key,
  });

  final FlameTier tier;

  /// Yüzeyin verdiği taban ölçü: odak ekranı 98, rozet kartı 120, widget ~64
  /// (widget Kotlin'de çiziliyor — `FlameRenderer.kt` — bu koddan hiç
  /// geçmiyor). **Sözleşme:** tam büyümüş bir alev (`tier.scale == 1.0`) bu
  /// yüksekliği tam doldurur; düşük kademeler aynı oranla küçülür. Bunu
  /// `_FlameShape._kShapeHeight`e göre ölçekleyerek sağlıyoruz — aksi halde
  /// `_FlameShape`nin sabit 98'i `boxHeight`i yalnızca bir tavan gibi
  /// kırpar, asla büyütmez (rozet kartının 120'si tam bu yüzden kırılıyordu).
  final double boxHeight;

  /// Seans ilerlemesi 0→1. Yalnızca parlaklık/titreşim/kıvılcım kanallarına
  /// bağlı.
  final double intensity;

  /// Titreşim tikleyicisi çalışsın mı. Duraklatılmış seansta ve seans dışı
  /// yüzeylerde `false` — süresiz açık kalabilen bir ekranda saniyede 60 kare
  /// çizmenin sebebi yok (DECISIONS.md:816).
  final bool flickering;

  /// Duraklatılmış seans: doygunluk 0 (SPEC.md §5.5).
  final bool desaturated;

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

  void _syncFlick() {
    if (widget.flickering && !_flick.isAnimating) {
      _flick.repeat();
    } else if (!widget.flickering && _flick.isAnimating) {
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
    final double intensity = widget.intensity.clamp(0.0, 1.0);

    Widget flame = AnimatedBuilder(
      animation: _flick,
      builder: (BuildContext context, Widget? child) {
        // Genlik seansla büyüyor: dinlenen alev hafif, tam ısınmış alev canlı
        // oynuyor. Taban 0.45, çünkü tamamen durgun bir alev ölü görünüyor.
        final double amplitude = 0.45 + 0.55 * intensity;
        final double t = _flick.value * 2 * math.pi;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(math.sin(t) * 3 * amplitude, 0.0, 0.0, 1.0)
            ..scaleByDouble(1.0, 1 + math.sin(t * 1.3) * 0.045 * amplitude, 1.0, 1.0)
            ..setEntry(0, 1, math.sin(t * 0.7) * 0.05 * amplitude),
          child: child,
        );
      },
      // İçteki sınır: alevin şekli hiç değişmiyor, yalnızca üstündeki
      // `Transform` değişiyor. Sınır sayesinde `Transform` bileşikleşiyor ve
      // kare başına iş, hazır katmanın matrisini güncellemeye iniyor.
      child: RepaintBoundary(
        child: _FlameShape(tier: widget.tier, intensity: intensity),
      ),
    );

    if (widget.desaturated) {
      flame = ColorFiltered(colorFilter: _desaturate, child: flame);
    }

    // Dıştaki sınır: bu olmadan `Transform`un her karedeki `markNeedsPaint`i
    // en yakın üst sınıra kadar çıkıyor — o sınır Ekran 03'te alevle aynı
    // katmanda duran 72px sayaç metnini de kapsıyor.
    // `_FlameShape` her zaman kendi doğal `_kShapeHeight`inde çiziliyor
    // (`Transform` layout'u etkilemez, yalnızca paint'i). `boxHeight` oranı
    // bu yüzden burada, ölçeğin içine katlanıyor: `boxHeight` tam
    // `_kShapeHeight` ise çarpan 1 (odak ekranı, regresyon yok); 120 gibi
    // daha büyük bir kutuda K10 kutuyu gerçekten dolduruyor.
    final double fillScale = (widget.boxHeight / _FlameShape._kShapeHeight) * widget.tier.scale;

    return RepaintBoundary(
      child: SizedBox(
        height: widget.boxHeight,
        child: Transform.scale(
          scale: fillScale,
          alignment: Alignment.bottomCenter,
          child: Align(alignment: Alignment.bottomCenter, child: flame),
        ),
      ),
    );
  }
}

/// Alevin gövdesi. Ölçüler tam kademe (K10) içindir; küçük kademeler dıştaki
/// `Transform.scale` ile küçülür — tek çizim yolu, tek raster.
class _FlameShape extends StatelessWidget {
  const _FlameShape({required this.tier, required this.intensity});

  final FlameTier tier;
  final double intensity;

  /// Gövdenin közden aleve gradyanı. Koyu temada prototipin değerleri birebir.
  /// Açık temada krem uç (#FFF3D8) zeminle 1.02:1 kontrasta düşüyordu —
  /// alevin tepesi sayfaya karışıyordu; uç ember'ın kendisine çekiliyor.
  static const List<Color> _darkBody = <Color>[
    Color(0xFF7A2F0C),
    Color(0xFFFFB03A),
    Color(0xFFFFF3D8),
  ];
  static const List<Color> _lightBody = <Color>[
    Color(0xFF7A2F0C),
    Color(0xFFE8880F),
    Color(0xFFFFB03A),
  ];

  /// Bu şeklin doğal (K10) yüksekliği. `FlameWidget.boxHeight`in "kutuyu
  /// doldur" sözleşmesi bu sayıya göre ölçekleniyor — sabit burada,
  /// kullanım orada.
  static const double _kShapeHeight = 98;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Çekirdek seansla parlıyor: dinlenirken yarı saydam, tam odakta opak.
    final double coreAlpha = 0.62 + 0.33 * intensity;

    return SizedBox(
      width: 64,
      height: _kShapeHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (tier.haloOpacity > 0)
            Positioned(
              bottom: -10,
              child: IgnorePointer(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFFFFB03A).withValues(alpha: tier.haloOpacity),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 0.72],
                    ),
                  ),
                ),
              ),
            ),
          if (tier.emberBase)
            Positioned(
              bottom: 0,
              child: Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0x007A2F0C), Color(0xFFCC5A10), Color(0x007A2F0C)],
                  ),
                ),
              ),
            ),
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
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAF0).withValues(alpha: coreAlpha),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(9, 28),
                  topRight: Radius.elliptical(9, 28),
                  bottomLeft: Radius.elliptical(9, 17),
                  bottomRight: Radius.elliptical(9, 17),
                ),
              ),
            ),
          ),
          // Kıvılcımlar deterministik konumda: rastgelelik kare kare zıplama
          // yaratır ve widget testini kararsızlaştırırdı.
          for (int i = 0; i < tier.sparkCount; i++)
            Positioned(
              bottom: 74.0 + i * 7,
              left: 22.0 + (i.isEven ? -13 : 13) + i * 1.5,
              child: IgnorePointer(
                child: Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // `.clamp` yok: `intensity` `build()`'in başında zaten
                    // [0,1]'e sıkıştırılıyor, bu ifade o yüzden hep
                    // [0.35, 0.80] aralığında — ek clamp hiç tetiklenmez.
                    color: const Color(0xFFFFD79A).withValues(alpha: 0.35 + 0.45 * intensity),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
