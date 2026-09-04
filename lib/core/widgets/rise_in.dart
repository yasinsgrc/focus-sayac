import 'package:flutter/material.dart';

/// Prototipin `@keyframes rise` girişi (v2 satır 27):
/// `0%{opacity:0;transform:translateY(14px)} 100%{opacity:1;transform:none}`.
///
/// Prototipte 19 yerde `animation:rise .6s ease-out <gecikme> both` olarak
/// kullanılıyor; ekranın blokları 0.06sn'lik basamaklarla sırayla beliriyor.
/// Uygulamada bu giriş hareketi hiç yoktu, ekranlar tek karede "hazır"
/// geliyordu — tipografi ve renkler prototiple aynıydı, eksik olan buydu.
///
/// **Bir kez** çalışıp duran bir animasyon; SPEC.md §6.4'ün durdurmayı şart
/// koştuğu sürekli dekoratif animasyonlardan (aurora/shimmer/marquee/sheen)
/// değil. Yine de odak seansı ekranına eklenmiyor: orası 25 dakika açık
/// kalıyor ve prototipte de sakin giriyor.
class RiseIn extends StatefulWidget {
  const RiseIn({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
  });

  /// Prototipin basamak aralığı: `.06s`. Sıra numarasını gecikmeye çeviren
  /// çarpan burada duruyor ki çağıran taraf `delay: RiseIn.step * 3` yazsın.
  static const Duration step = Duration(milliseconds: 60);

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  late final CurvedAnimation _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  /// CSS'teki `both` doldurma kipi: gecikme boyunca öğe ilk karesinde
  /// (görünmez) bekler. Denetleyici 0'da durduğu için bu bedavaya geliyor.
  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      // `Future.delayed` yerine denetleyicinin kendi zamanlayıcısı: widget
      // gecikme dolmadan ağaçtan kalkarsa geride bekleyen bir geri arama
      // kalmıyor, `animateTo` `dispose`ta sessizce iptal oluyor.
      _controller.animateTo(0, duration: widget.delay).whenComplete(() {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik: "hareketi azalt" açıkken giriş hareketi hiç çalışmaz,
    // içerik doğrudan son hâlinde çizilir.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _curved,
      // Çocuk `builder` dışında bir kez kuruluyor: her karede yeniden inşa
      // edilmesin, yalnızca opaklık/öteleme katmanı değişsin.
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: _curved.value,
          child: Transform.translate(offset: Offset(0, 14 * (1 - _curved.value)), child: child),
        );
      },
    );
  }
}
