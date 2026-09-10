import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Basılı tutulduğunda çocuğunu [scale]'e küçültüp bırakınca yerine geri
/// getiren dokunma geri bildirimi.
///
/// Sardığı `InkWell`in dalgasının **yerine geçmiyor**, üstüne biniyor: dalga
/// "nereye bastım"ı, ölçek "bastım"ı söyler. Bu yüzden jest arenasına hiç
/// girmiyor — `GestureDetector` kullanılsaydı kendi `TapGestureRecognizer`ı
/// çocuktaki `InkWell`inkiyle yarışır, arenayı içteki kazandığında dıştakinin
/// `onTapCancel`i basılı hâlden erken çıkardı. `Listener` ise ham işaretçi
/// olaylarını arenayı hiç ilgilendirmeden alıyor: `onTap` yine `InkWell`in.
///
/// Ölçek `Transform` ile uygulanıyor, düzenle değil: dokunma hedefi
/// küçülmüyor (madde 12'nin 48px kuralı korunuyor).
///
/// `Transform` ölçek tam 1'ken de ağaçta duruyor — `PopOnIncrease`in aksine.
/// Orada vurgu bir **değer** değişince başlıyor ve ağacın o an yeniden
/// kurulmasının kimseye zararı yok; burada ise animasyonu başlatan şeyin
/// kendisi parmağın teması. `Transform`u basış anında araya sokmak
/// `InkWell`in bulunduğu alt ağacı yeni bir ebeveynin altına taşır, eski
/// öğeler sökülür ve tanıyıcısı jesti ortasında iptal edilir: buton basılı
/// görünür ama `onTap` **hiç** çalışmaz.
///
/// Bir kez çalışıp duran bir animasyon (SPEC.md §6.4): parmak değmiyorken
/// denetleyici boşta ve ölçek tam 1, yani `RenderTransform` kimlik matrisiyle
/// oturuyor — kare üretmiyor.
class AppPressable extends StatefulWidget {
  const AppPressable({required this.child, super.key, this.enabled = true, this.scale = 0.97});

  final Widget child;

  /// Kapalı butonda (`onPressed: null`) basılı hâl çalışmaz — dokunuşun bir
  /// karşılığı yokken geri bildirim vermek yanlış söz verir.
  final bool enabled;

  /// Basılı hâlin ölçeği.
  final double scale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> with SingleTickerProviderStateMixin {
  /// Bırakış basıştan biraz uzun: `pop` eğrisinin hedefi aşan kuyruğu 120ms'ye
  /// sığmıyor.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.instant,
    reverseDuration: AppMotion.fast,
  );

  /// Bırakışta `pop`un ters çevrilmişi: ölçek 1'e dönerken hedefi hafifçe
  /// aşıyor (`AppMotion.pop` doğrudan verilseydi eğri ileri yönde okunur ve
  /// aşma yanlış uca, basılı hâle düşerdi).
  late final Animation<double> _scale = Tween<double>(begin: 1, end: widget.scale).animate(
    CurvedAnimation(parent: _controller, curve: AppMotion.enter, reverseCurve: AppMotion.pop.flipped),
  );

  void _press() {
    // "Hareketi azalt" açıkken basılı hâl hiç kurulmuyor: ölçek zaten 1'de
    // duruyor, atlanacak bir son hâl yok (`PopOnIncrease` ile aynı desen).
    if (!widget.enabled) return;
    if (AppMotion.respectingMotion(context, AppMotion.instant) == Duration.zero) return;
    _controller.forward();
  }

  void _release() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) => _press(),
      // İşaretçi butonun dışına kayıp orada bırakılsa da ölçek geri dönüyor:
      // `InkWell` o dokunuşu zaten tap saymıyor, basılı görünen bir buton
      // bırakılmış olurdu.
      onPointerUp: (PointerUpEvent event) => _release(),
      onPointerCancel: (PointerCancelEvent event) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
