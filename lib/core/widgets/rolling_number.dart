import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Odometre sayacı: değer değiştiğinde yalnızca **değişen** karakterler dikey
/// olarak kayar, sabit kalanlar yerinde durur (132 → 131'de yalnızca son hane
/// hareket eder). Uygulamanın ekrana çıkan her sayısı kullanıcının kendi
/// verisinden türüyor ve bir kısmı ekran açıkken değişiyor (gece yarısı gün
/// sayısı, seans bitince bugünkü odak süresi ve seri) — o değişimler bugüne
/// kadar bir kareden diğerine zıplıyordu.
///
/// [text] verilmezse `'$value'` çizilir. ARB'den gelen kısa **değer etiketleri**
/// de geçilebilir (`%75`, `3 SAAT`, `5 gün seri`): karşılaştırma karakter
/// bazlı olduğu için sabit ekler kımıldamaz. Cümleler için değil — karakterler
/// ayrı `Text`lere bölündüğü için satır kırma ve kerning kaybolur.
///
/// Bir kez çalışıp duran bir animasyon (SPEC.md §6.4); boşta kare üretmez.
class RollingNumber extends StatefulWidget {
  const RollingNumber({
    required this.value,
    required this.style,
    super.key,
    this.text,
    this.duration = AppMotion.base,
  });

  /// Kayma yönünün kaynağı: artan sayı aşağıdan yukarı, azalan sayı yukarıdan
  /// aşağı akar. Geri sayım azalır, odak süresi artar.
  final int value;

  /// Çizilecek metin; `null` ise `'$value'`.
  final String? text;

  /// Dışarıdan verilir — `AppTypography.counter` ve `display` ile de çalışır.
  /// Basamak genişliği zıplamasın diye `tabularFigures` her hâlükârda eklenir.
  final TextStyle style;

  final Duration duration;

  String get label => text ?? '$value';

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  bool _increasing = true;

  @override
  void didUpdateWidget(RollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _increasing = widget.value > oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.respectingMotion(context, widget.duration);
    final String label = widget.label;
    final List<String> characters = label.split('');
    final TextStyle style = widget.style.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    final Widget slots = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < characters.length; i++)
          _RollingCharacter(
            // Anahtar **sağdan** sayılıyor: hane eklenip çıktığında birler
            // basamağı yerinde kalır, yeni hane soldan girer.
            key: ValueKey<int>(characters.length - 1 - i),
            character: characters[i],
            style: style,
            duration: duration,
            increasing: _increasing,
          ),
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      // Ekran okuyucu karakterleri tek tek okumasın: yuvalar görsel bir
      // ayrıntı, okunacak olan sayının tamamı.
      label: label,
      // Tek bir `Text` sığmadığında satır kırıyordu; karakter yuvalarından
      // kurulu bir `Row` ise taşma hatası veriyor. Beklenen genişliklerde
      // ölçek hiç devreye girmiyor (kutu çocuğun boyunu alıyor); alışılmadık
      // uzun bir değer geldiğinde sayı kırpılmak yerine küçülüyor.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        // Hane sayısı değişince (100 → 99) düzenin genişliği de değişir. Sabit
        // genişlik en fazla haneye göre yer ayırmak demekti: gün sayacı ömrü
        // boyunca dört hanelik bir kutunun içinde merkezden kaçardı.
        //
        // "Hareketi azalt" açıkken `AnimatedSize` ağaca hiç girmiyor: sıfır
        // süreli denetleyici `performLayout` içinde kendini bitirip aynı
        // düzen geçişinde yeniden kirletiyor ve çerçeve bunu hata sayıyor.
        child: duration == Duration.zero
            ? slots
            : AnimatedSize(duration: duration, curve: AppMotion.standard, child: slots),
      ),
    );
  }
}

/// Tek bir karakter yuvası. Karakteri değişmediği sürece hiç animasyon kurmaz
/// ve tek bir [Text] çizer — "değişmeyen basamaklar hiç hareket etmiyor"
/// kuralı bu yüzden yapının kendisinden geliyor, bir eşik kontrolünden değil.
class _RollingCharacter extends StatefulWidget {
  const _RollingCharacter({
    required this.character,
    required this.style,
    required this.duration,
    required this.increasing,
    super.key,
  });

  final String character;
  final TextStyle style;
  final Duration duration;
  final bool increasing;

  @override
  State<_RollingCharacter> createState() => _RollingCharacterState();
}

class _RollingCharacterState extends State<_RollingCharacter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  late final CurvedAnimation _curved = CurvedAnimation(parent: _controller, curve: AppMotion.standard);

  /// Yalnızca kayma sürerken dolu; boşken ağaçta tek bir [Text] var.
  String? _outgoing;

  /// Kayma yönü animasyon **başladığı** anda dondurulur: sayı kayma bitmeden
  /// bir kez daha değişirse yön ortada dönmesin.
  bool _increasing = true;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatusChanged);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(_RollingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.character == oldWidget.character) return;
    if (widget.duration == Duration.zero) {
      // "Hareketi azalt": ara kare yok, yeni karakter ilk karede yerinde.
      _outgoing = null;
      _controller.value = 0;
      return;
    }
    _outgoing = oldWidget.character;
    _increasing = widget.increasing;
    _controller.duration = widget.duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? outgoing = _outgoing;
    final Text current = Text(widget.character, style: widget.style);
    if (outgoing == null) return current;

    // Artan sayıda yeni karakter aşağıdan (+1) girer ve eskisi yukarı çıkar;
    // azalan sayıda tersi.
    final double enterFrom = _increasing ? 1 : -1;

    return ClipRect(
      child: AnimatedBuilder(
        animation: _curved,
        builder: (BuildContext context, Widget? child) {
          final double t = _curved.value;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // İkisi de konumlandırılmamış: yığın en büyük çocuğun boyunu
              // alıyor, `FractionalTranslation` ise boyutu değil yalnızca
              // çizimi kaydırıyor — kayma düzeni bozmuyor.
              FractionalTranslation(
                translation: Offset(0, enterFrom * (1 - t)),
                child: current,
              ),
              FractionalTranslation(
                translation: Offset(0, -enterFrom * t),
                child: Text(outgoing, style: widget.style),
              ),
            ],
          );
        },
      ),
    );
  }
}
