import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// İlk değerine **bir kez** yumuşak yerleşen ilerleme oranı.
///
/// Odak/mola halkası saniyede bir kendiliğinden ilerliyor; oradaki her adımı
/// tween'lemek 420ms'lik bir animasyonu saniyede bir yeniden başlatmak, yani
/// süren bir seans boyunca kesintisiz kare üretmek olurdu — SPEC.md §6.4'ün
/// tam olarak yasakladığı şey. Bu yüzden geçiş yalnızca ilk yerleşmede var:
/// kurtarılan bir seans ekranı %40 dolu bir halkayla açmak yerine oraya akıyor,
/// sonrasında değer doğrudan geçiyor.
class SettlingProgress extends StatefulWidget {
  const SettlingProgress({required this.progress, required this.builder, super.key});

  final double progress;

  /// Animasyonlu oranı alan çizim geri araması.
  final ValueWidgetBuilder<double> builder;

  @override
  State<SettlingProgress> createState() => _SettlingProgressState();
}

class _SettlingProgressState extends State<SettlingProgress> {
  bool _settled = false;

  /// Bilerek `setState`siz: "hareketi azalt" açıkken `TweenAnimationBuilder`
  /// sıfır süreli animasyonu daha `initState`indeyken bitiriyor ve geri arama
  /// bu widget'ın `build`ı sürerken geliyor — orada `setState` çağırmak hata.
  /// Bayrağın etkisi zaten bir sonraki `build`de: ilerleme saniyede bir
  /// değiştiği için o build kendiliğinden geliyor.
  void _markSettled() => _settled = true;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.progress),
      duration: _settled ? Duration.zero : AppMotion.respectingMotion(context, AppMotion.slow),
      curve: AppMotion.standard,
      onEnd: _markSettled,
      builder: widget.builder,
    );
  }
}
