import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

/// `UserBadge.badgeKey` değerleri — bir kez yayınlandıktan sonra
/// değiştirilmemeli (DB'de metin olarak saklanıyor, `SessionType` ile aynı kısıt).
abstract final class BadgeKeys {
  static const String firstSpark = 'first_spark';
  static const String focusTorch = 'focus_torch';
  static const String morningStar = 'morning_star';
  static const String nightWatch = 'night_watch';
  static const String weeklyStreak = 'weekly_streak';
  static const String marathon = 'marathon';
  static const String hundredHours = 'hundred_hours';
}

/// Prototipin renk ROL sistemine göre bir rozetin vurgu rengi — gerçek
/// [AppColors] örneği yalnızca widget katmanında ([resolve]) çözülür, bu
/// dosya saf veri kalır (SPEC.md §5.4 "saf fonksiyonlar, IO yok").
enum BadgeTint {
  ember,
  mint,
  sky,
  accent,
  rose;

  Color resolve(AppColors colors) => switch (this) {
        BadgeTint.ember => colors.ember,
        BadgeTint.mint => colors.mint,
        BadgeTint.sky => colors.sky,
        BadgeTint.accent => colors.accent400,
        BadgeTint.rose => colors.rose,
      };
}

/// Statik rozet kataloğu — ad/kural/ikon/renk. DB yalnızca `badgeKey` +
/// `unlockedAt` tutar (SPEC.md §4/§5.4); bu liste hiçbir zaman satın almayla
/// değişmez.
class BadgeDefinition {
  const BadgeDefinition({
    required this.key,
    required this.name,
    required this.rule,
    required this.icon,
    required this.tint,
  });

  final String key;
  final String name;
  final String rule;
  final IconData icon;
  final BadgeTint tint;
}

/// Prototip `badgeData()` (design/FocusSayac Prototip v2.dc.html satır 485-495)
/// ile birebir ad/kural/ikon/renk ve sıra — sıra grid yerleşimini belirler.
const List<BadgeDefinition> kBadgeCatalog = <BadgeDefinition>[
  BadgeDefinition(
    key: BadgeKeys.firstSpark,
    name: 'İlk Kıvılcım',
    rule: 'İlk tamamlanan pomodoro',
    icon: PhosphorIconsFill.sparkle,
    tint: BadgeTint.ember,
  ),
  BadgeDefinition(
    key: BadgeKeys.focusTorch,
    name: 'Odak Meşalesi',
    rule: 'Tek günde 4 pomodoro',
    icon: PhosphorIconsFill.flame,
    tint: BadgeTint.ember,
  ),
  BadgeDefinition(
    key: BadgeKeys.morningStar,
    name: 'Sabah Yıldızı',
    rule: '08:00 öncesi bir seans',
    icon: PhosphorIconsFill.sunHorizon,
    tint: BadgeTint.mint,
  ),
  BadgeDefinition(
    key: BadgeKeys.nightWatch,
    name: 'Gece Nöbeti',
    rule: '23:00 sonrası bir seans',
    icon: PhosphorIconsDuotone.moonStars,
    tint: BadgeTint.sky,
  ),
  BadgeDefinition(
    key: BadgeKeys.weeklyStreak,
    name: 'Haftalık Seri',
    rule: '7 gün üst üste ≥1 seans',
    icon: PhosphorIconsDuotone.calendarCheck,
    tint: BadgeTint.accent,
  ),
  BadgeDefinition(
    key: BadgeKeys.marathon,
    name: 'Maraton',
    rule: 'Tek günde 8 pomodoro',
    icon: PhosphorIconsDuotone.personSimpleRun,
    tint: BadgeTint.rose,
  ),
  BadgeDefinition(
    key: BadgeKeys.hundredHours,
    name: '100 Saat Kulübü',
    rule: 'Kümülatif 100 saat odak',
    icon: PhosphorIconsDuotone.trophy,
    tint: BadgeTint.accent,
  ),
];

BadgeDefinition badgeByKey(String key) => kBadgeCatalog.firstWhere((BadgeDefinition b) => b.key == key);
