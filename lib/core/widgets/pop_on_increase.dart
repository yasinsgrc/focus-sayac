import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Bir sayı **arttığında** çocuğu bir kez 1.0 → [scale] → 1.0 ölçekleyen vurgu.
///
/// Ekran 02'nin seri rozetinde kullanılıyor: `RollingNumber` sayıyı zaten
/// çeviriyor, alev ikonunun ona eşlik edecek bir karşılığı yoktu. Yalnızca
/// artışta çalışıyor — ekran her açıldığında ya da değer düştüğünde değil;
/// seri kırıldığında zıplayan bir alev yanlış şeyi kutlardı.
///
/// Bir kez çalışıp duran bir animasyon (SPEC.md §6.4): denetleyici boştayken
/// hiç tik atmıyor ve ağaca `Transform` bile girmiyor.
class PopOnIncrease extends StatefulWidget {
  const PopOnIncrease({
    required this.value,
    required this.child,
    super.key,
    this.scale = 1.25,
  });

  /// İzlenen sayı; yalnızca büyüdüğünde vurgu çalışır.
  final int value;

  /// Vurgunun tepe noktası.
  final double scale;

  final Widget child;

  @override
  State<PopOnIncrease> createState() => _PopOnIncreaseState();
}

class _PopOnIncreaseState extends State<PopOnIncrease> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.base);

  late final Animation<double> _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
    // Çıkış hedefi hafifçe aşıyor (`pop`), dönüş iki ucu da yumuşak.
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: 1, end: widget.scale).chain(CurveTween(curve: AppMotion.pop)),
      weight: 1,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(begin: widget.scale, end: 1).chain(CurveTween(curve: AppMotion.standard)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(PopOnIncrease oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value <= oldWidget.value) return;
    // "Hareketi azalt" açıkken vurgu hiç kurulmuyor: ölçek zaten 1'de duruyor,
    // atlanacak bir son hâl yok.
    if (AppMotion.respectingMotion(context, AppMotion.base) == Duration.zero) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      // İlk build'de ve vurgu bittikten sonra ölçek tam 1: çocuk olduğu gibi
      // geçiyor, araya `Transform` bile girmiyor.
      builder: (BuildContext context, Widget? child) {
        final double scale = _scale.value;
        return scale == 1 ? child! : Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
