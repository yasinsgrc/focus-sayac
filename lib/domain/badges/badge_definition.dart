import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/gen/app_localizations.dart';

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
    required this.icon,
    required this.tint,
  });

  final String key;
  final IconData icon;
  final BadgeTint tint;

  /// Ad ve kural açıklaması ARB'den (SPEC.md §0 kural 7, Faz 13). Katalog
  /// `const` kalabilsin diye metinler alan değil metot: `AppLocalizations`
  /// örneği çalışma zamanında geliyor, [key] ise DB'de saklanan sabit kimlik.
  String name(AppLocalizations l10n) => switch (key) {
        BadgeKeys.firstSpark => l10n.badgeFirstSparkName,
        BadgeKeys.focusTorch => l10n.badgeFocusTorchName,
        BadgeKeys.morningStar => l10n.badgeMorningStarName,
        BadgeKeys.nightWatch => l10n.badgeNightWatchName,
        BadgeKeys.weeklyStreak => l10n.badgeWeeklyStreakName,
        BadgeKeys.marathon => l10n.badgeMarathonName,
        BadgeKeys.hundredHours => l10n.badgeHundredHoursName,
        _ => throw ArgumentError.value(key, 'key', 'Bilinmeyen rozet anahtarı'),
      };

  String rule(AppLocalizations l10n) => switch (key) {
        BadgeKeys.firstSpark => l10n.badgeFirstSparkRule,
        BadgeKeys.focusTorch => l10n.badgeFocusTorchRule,
        BadgeKeys.morningStar => l10n.badgeMorningStarRule,
        BadgeKeys.nightWatch => l10n.badgeNightWatchRule,
        BadgeKeys.weeklyStreak => l10n.badgeWeeklyStreakRule,
        BadgeKeys.marathon => l10n.badgeMarathonRule,
        BadgeKeys.hundredHours => l10n.badgeHundredHoursRule,
        _ => throw ArgumentError.value(key, 'key', 'Bilinmeyen rozet anahtarı'),
      };
}

/// Prototip `badgeData()` (design/FocusSayac Prototip v2.dc.html satır 485-495)
/// ile birebir ikon/renk ve sıra — sıra grid yerleşimini belirler. Ad ve kural
/// metinleri ARB'de ([BadgeDefinition.name] / [BadgeDefinition.rule]).
const List<BadgeDefinition> kBadgeCatalog = <BadgeDefinition>[
  BadgeDefinition(
    key: BadgeKeys.firstSpark,
    icon: PhosphorIconsFill.sparkle,
    tint: BadgeTint.ember,
  ),
  BadgeDefinition(
    key: BadgeKeys.focusTorch,
    icon: PhosphorIconsFill.flame,
    tint: BadgeTint.ember,
  ),
  BadgeDefinition(
    key: BadgeKeys.morningStar,
    icon: PhosphorIconsFill.sunHorizon,
    tint: BadgeTint.mint,
  ),
  BadgeDefinition(
    key: BadgeKeys.nightWatch,
    icon: PhosphorIconsDuotone.moonStars,
    tint: BadgeTint.sky,
  ),
  BadgeDefinition(
    key: BadgeKeys.weeklyStreak,
    icon: PhosphorIconsDuotone.calendarCheck,
    tint: BadgeTint.accent,
  ),
  BadgeDefinition(
    key: BadgeKeys.marathon,
    icon: PhosphorIconsDuotone.personSimpleRun,
    tint: BadgeTint.rose,
  ),
  BadgeDefinition(
    key: BadgeKeys.hundredHours,
    icon: PhosphorIconsDuotone.trophy,
    tint: BadgeTint.accent,
  ),
];

BadgeDefinition badgeByKey(String key) => kBadgeCatalog.firstWhere((BadgeDefinition b) => b.key == key);
