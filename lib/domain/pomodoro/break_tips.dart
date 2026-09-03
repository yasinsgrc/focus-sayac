import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/gen/app_localizations.dart';

/// Ekran 09'un "molada dene" ipucu rengi. `AppColors` `Theme`den okunduğu için
/// katalog `const` kalabilsin diye renk doğrudan değil, rol olarak tutuluyor —
/// Ekran 01'in `_PermissionTint`iyle aynı kalıp.
enum BreakTipTint { mint, sky }

/// SPEC.md Ekran 09: "molada dene" ipuçları **statik katalog, ARB'de; her
/// molada rastgele 2 tanesi**. İkon/renk çevrilebilir metin değil, o yüzden
/// burada kalıyor; yalnızca [text] ARB'den geliyor.
enum BreakTip {
  lookAway(PhosphorIconsRegular.eye, BreakTipTint.mint),
  drinkWater(PhosphorIconsRegular.drop, BreakTipTint.sky),
  standUp(PhosphorIconsRegular.footprints, BreakTipTint.mint),
  breathe(PhosphorIconsRegular.wind, BreakTipTint.sky),
  stretch(PhosphorIconsRegular.armchair, BreakTipTint.mint),
  closeEyes(PhosphorIconsRegular.eyeClosed, BreakTipTint.sky);

  const BreakTip(this.icon, this.tint);

  final IconData icon;
  final BreakTipTint tint;

  String text(AppLocalizations l10n) => switch (this) {
        BreakTip.lookAway => l10n.breakTipLookAway,
        BreakTip.drinkWater => l10n.breakTipDrinkWater,
        BreakTip.standUp => l10n.breakTipStandUp,
        BreakTip.breathe => l10n.breakTipBreathe,
        BreakTip.stretch => l10n.breakTipStretch,
        BreakTip.closeEyes => l10n.breakTipCloseEyes,
      };
}

/// SPEC.md Ekran 09'un prototipte gösterdiği ipucu sayısı.
const int kBreakTipsPerBreak = 2;

/// Molanın ipuçlarını seçer. Saf fonksiyon: tohum `Random()` değil molanın
/// **başlangıç anı**, çünkü Ekran 09 saniyede bir yeniden çiziliyor — her
/// karede yeniden zar atmak ipuçlarını gözün önünde titretirdi. Aynı mola
/// boyunca sonuç sabit, her yeni mola farklı.
List<BreakTip> selectBreakTips({
  required DateTime breakStartedAtUtc,
  int count = kBreakTipsPerBreak,
}) {
  final List<BreakTip> pool = List<BreakTip>.of(BreakTip.values)
    ..shuffle(math.Random(breakStartedAtUtc.millisecondsSinceEpoch));
  return pool.take(count.clamp(0, pool.length)).toList(growable: false);
}
