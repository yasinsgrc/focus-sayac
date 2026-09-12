import '../../l10n/gen/app_localizations.dart';

/// Meşale avatarının tek bir kademesi. Görsel parametreler (ölçek, süsleme)
/// burada duruyor çünkü Kotlin tarafındaki widget da aynı sayıları çiziyor ve
/// `test/android/flame_tier_sync_test.dart` iki kopyayı karşılaştırıyor.
///
/// Palet duraklarının **burada olmamasının** sebebi: gradyan açık/koyu temaya
/// göre dallanıyor ve bu bir çizim kararı — `FlameWidget` içinde kalıyor,
/// bugünkü `_darkBody`/`_lightBody` ayrımının aynısı.
class FlameTier {
  const FlameTier({
    required this.index,
    required this.thresholdHours,
    required this.scale,
    required this.emberBase,
    required this.sparkCount,
    required this.haloOpacity,
  });

  /// 1..10. Kullanıcıya gösterilen kademe numarası, liste konumu değil.
  final int index;

  /// Bu kademeye girmek için gereken kümülatif tamamlanmış odak saati.
  final int thresholdHours;

  /// Yüzeyin verdiği kutuya oranı (0.35 → 1.0). Mutlak piksel yok: odak
  /// ekranı 98px, rozet kartı 120px, widget ~64dp kutu veriyor.
  final double scale;

  /// Alevin altında kor yatağı çizilir mi.
  final bool emberBase;

  /// Alevin üstünde yükselen kıvılcım parçacığı sayısı.
  final int sparkCount;

  /// Alevin arkasındaki hâlenin opaklığı; 0 ise hâle çizilmez.
  final double haloOpacity;

  /// Ad ARB'den — katalog `const` kalsın diye alan değil metot
  /// (`BadgeDefinition.name` ile aynı gerekçe).
  String name(AppLocalizations l10n) => switch (index) {
        1 => l10n.flameTier1Name,
        2 => l10n.flameTier2Name,
        3 => l10n.flameTier3Name,
        4 => l10n.flameTier4Name,
        5 => l10n.flameTier5Name,
        6 => l10n.flameTier6Name,
        7 => l10n.flameTier7Name,
        8 => l10n.flameTier8Name,
        9 => l10n.flameTier9Name,
        10 => l10n.flameTier10Name,
        _ => throw ArgumentError.value(index, 'index', 'Bilinmeyen kademe'),
      };
}

/// Kademe merdiveni. **Yayınlandıktan sonra eşikler değiştirilemez** —
/// kademe düşüren bir değişiklik kazanılmış kimliği geri almak olur
/// (`BadgeKeys` ile aynı kısıt).
///
/// Eşikler `badge_rules.dart`'ın saat merdivenini (10/50/100/250) **içerir**:
/// K4, K6, K7 ve K9 aynı anda bir rozet de açar. Aradaki kademelerin rozeti
/// yok, sessizce geçilir. Hizalamayı `flame_tier_test.dart` çiviliyor.
///
/// Aralıklar erken sık, geç seyrek: ilk 10 saatte dört kademe (yeni kullanıcı
/// hemen ilerleme görür), 100 saatten sonra üç kademe (eksen tükenmez).
const List<FlameTier> kFlameTierLadder = <FlameTier>[
  FlameTier(index: 1, thresholdHours: 0, scale: 0.35, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 2, thresholdHours: 1, scale: 0.42, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 3, thresholdHours: 3, scale: 0.50, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 4, thresholdHours: 10, scale: 0.58, emberBase: true, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 5, thresholdHours: 25, scale: 0.65, emberBase: true, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 6, thresholdHours: 50, scale: 0.72, emberBase: true, sparkCount: 2, haloOpacity: 0),
  FlameTier(index: 7, thresholdHours: 100, scale: 0.80, emberBase: true, sparkCount: 3, haloOpacity: 0),
  FlameTier(index: 8, thresholdHours: 175, scale: 0.87, emberBase: true, sparkCount: 3, haloOpacity: 0.18),
  FlameTier(index: 9, thresholdHours: 250, scale: 0.94, emberBase: true, sparkCount: 4, haloOpacity: 0.26),
  FlameTier(index: 10, thresholdHours: 400, scale: 1.00, emberBase: true, sparkCount: 5, haloOpacity: 0.34),
];

/// Bir anın kademe durumu — kart, odak ekranı ve widget aynı nesneyi okur.
class FlameTierStatus {
  const FlameTierStatus({
    required this.tier,
    required this.nextTier,
    required this.hoursRemaining,
    required this.ratioInTier,
    required this.cumulativeHours,
  });

  final FlameTier tier;

  /// En üst kademede `null`.
  final FlameTier? nextTier;

  /// Sonraki eşiğe kalan tam saat; en üst kademede `null`. Null olması
  /// bilinçli: 0 yazsaydı kart "sonraki kademeye 0 saat" diye yalan kurardı.
  final int? hoursRemaining;

  /// 0–1, bu kademe içindeki ilerleme. En üst kademede 1.
  final double ratioInTier;

  /// Tüm zamanların tamamlanmış odak saati (aşağı yuvarlanmış).
  final int cumulativeHours;

  bool get isTopTier => nextTier == null;

  /// Riverpod bu değeri `==` ile karşılaştırıp gereksiz yeniden çizimi eliyor
  /// (`StreakStatus`/`WeeklySummary` ile aynı gerekçe). `tier`/`nextTier`
  /// karşılaştırması kimlikle çalışıyor çünkü her ikisi de tek `const
  /// kFlameTierLadder`'dan geliyor — aynı kademe her zaman aynı nesne.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlameTierStatus &&
          other.tier == tier &&
          other.nextTier == nextTier &&
          other.hoursRemaining == hoursRemaining &&
          other.ratioInTier == ratioInTier &&
          other.cumulativeHours == cumulativeHours;

  @override
  int get hashCode =>
      Object.hash(tier, nextTier, hoursRemaining, ratioInTier, cumulativeHours);

  @override
  String toString() =>
      'FlameTierStatus(tier: ${tier.index}, nextTier: ${nextTier?.index}, '
      'hoursRemaining: $hoursRemaining, ratioInTier: $ratioInTier, '
      'cumulativeHours: $cumulativeHours)';
}

/// Saf hesaplayıcı. [cumulativeSeconds] `FocusStats.cumulativeSeconds`tir.
///
/// Saat aşağı yuvarlanır — `badge_rules.dart`'taki `totalPlannedSeconds ~/ 3600`
/// ile **aynı** kural. İki merdivenin eşiklerde birlikte tetiklenmesi buna
/// bağlı; `floor(sn/3600) >= E` ile `sn >= E*3600` aynı kümeyi veriyor.
FlameTierStatus flameTierFor(int cumulativeSeconds) {
  final int hours = cumulativeSeconds <= 0 ? 0 : cumulativeSeconds ~/ 3600;

  int position = 0;
  for (int i = 1; i < kFlameTierLadder.length; i++) {
    if (hours >= kFlameTierLadder[i].thresholdHours) position = i;
  }

  final FlameTier tier = kFlameTierLadder[position];
  final FlameTier? next =
      position + 1 < kFlameTierLadder.length ? kFlameTierLadder[position + 1] : null;

  if (next == null) {
    return FlameTierStatus(
      tier: tier,
      nextTier: null,
      hoursRemaining: null,
      ratioInTier: 1,
      cumulativeHours: hours,
    );
  }

  final int span = next.thresholdHours - tier.thresholdHours;
  // clamp savunma amaçlı: `position` hours'a göre son "hours >= eşik" indeksi
  // olduğundan hours her zaman [tier.thresholdHours, next.thresholdHours)
  // aralığında — bu dalda oran zaten [0, 1)'de, clamp hiç tetiklenmiyor.
  return FlameTierStatus(
    tier: tier,
    nextTier: next,
    hoursRemaining: next.thresholdHours - hours,
    ratioInTier: ((hours - tier.thresholdHours) / span).clamp(0.0, 1.0),
    cumulativeHours: hours,
  );
}
