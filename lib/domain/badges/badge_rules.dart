import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../streak/streak_calculator.dart';
import 'badge_definition.dart';

/// Bir rozetin o anki ilerlemesi — [current] ve [target] aynı birimde
/// (pomodoro sayısı, gün, saat). Hangi birim olduğunu rozetin kural metni
/// söylüyor, bu yüzden sayaç kartta çıplak duruyor: "61/100".
class BadgeProgress {
  const BadgeProgress({required this.current, required this.target});

  final int current;
  final int target;

  /// Rozetin açılmış OLMASI GEREKTİĞİ koşul. "Açıldı" kaydı DB'de duruyor
  /// (`UserBadges`); burası yalnızca kuralın kendisi.
  bool get earned => current >= target;

  /// Halka ve sayaç yalnızca **sayılabilir** rozetlerde çizilir. Hedefi 1 olan
  /// rozetlerde ("08:00 öncesi bir seans") "0/1" bir ilerleme değil, kuralın
  /// daha kötü yazılmış hâli olurdu.
  bool get isCountable => target > 1;

  /// 0–1. Hedefi aşan değerlerde (bir günde 4 yerine 9 seans) taşmıyor.
  double get ratio => (current / target).clamp(0.0, 1.0);
}

/// SPEC.md §5.4 — saf fonksiyon, IO yok. Tamamlanmış odak seansı geçmişinin
/// tamamına bakıp **kataloğun her rozeti için** ilerlemeyi döndürür; kazanılmış
/// rozetler bunun süzülmüş hâli ([evaluateEarnedBadgeKeys]). Eşiklerin tek
/// yerde olması şart: kilitli kartın halkası dolduğu anda rozetin açılması
/// gerekiyor, iki ayrı eşik listesi er geç birbirinden sapardı.
///
/// Geçmiş boşken de tam harita dönüyor (hepsi 0/hedef) — Ekran 04 ilk açılışta
/// merdiveni boş halkalarla çizebilsin diye.
Map<String, BadgeProgress> evaluateBadgeProgress({
  required List<PomodoroSession> completedFocusSessions,
}) {
  final Map<DateTime, int> countByDay = <DateTime, int>{};
  int totalPlannedSeconds = 0;
  bool hasMorningSession = false;
  bool hasNightSession = false;

  for (final PomodoroSession session in completedFocusSessions) {
    final DateTime day = appDayKey(session.startedAt);
    countByDay[day] = (countByDay[day] ?? 0) + 1;
    totalPlannedSeconds += session.plannedDurationSec;

    final DateTime wallClock = toIstanbulWallClock(session.startedAt);
    final int minuteOfDay = wallClock.hour * 60 + wallClock.minute;
    if (minuteOfDay < 8 * 60) {
      hasMorningSession = true;
    }
    if (minuteOfDay >= 23 * 60) {
      hasNightSession = true;
    }
  }

  final int maxPerDay = countByDay.values.fold(0, (int a, int b) => a > b ? a : b);
  final int longestStreak = calculateLongestStreak(
    completedFocusStartedAtUtc: completedFocusSessions.map((PomodoroSession s) => s.startedAt).toList(growable: false),
  );

  // Saat merdiveni tam saate yuvarlanıyor (aşağı): 99sa 59dk hâlâ "99/100".
  // Eşik karşılaştırması bundan etkilenmiyor — `floor(sn/3600) >= 100` ile
  // `sn >= 100*3600` aynı kümeyi veriyor.
  final int totalHours = totalPlannedSeconds ~/ 3600;

  return <String, BadgeProgress>{
    BadgeKeys.firstSpark: BadgeProgress(current: completedFocusSessions.length, target: 1),
    BadgeKeys.focusTorch: BadgeProgress(current: maxPerDay, target: 4),
    BadgeKeys.morningStar: BadgeProgress(current: hasMorningSession ? 1 : 0, target: 1),
    BadgeKeys.nightWatch: BadgeProgress(current: hasNightSession ? 1 : 0, target: 1),
    BadgeKeys.weeklyStreak: BadgeProgress(current: longestStreak, target: 7),
    BadgeKeys.marathon: BadgeProgress(current: maxPerDay, target: 8),
    BadgeKeys.tenHours: BadgeProgress(current: totalHours, target: 10),
    BadgeKeys.fiftyHours: BadgeProgress(current: totalHours, target: 50),
    BadgeKeys.hundredHours: BadgeProgress(current: totalHours, target: 100),
    BadgeKeys.twoFiftyHours: BadgeProgress(current: totalHours, target: 250),
  };
}

/// O an kazanılmış OLMASI GEREKEN rozet anahtarları (idempotent, geriye dönük
/// yeniden hesaplanabilir). Rozetler yalnızca başarıyla açılır, hiçbir zaman
/// geri alınmaz — bu yüzden "Haftalık Seri" gibi kurallar da tüm zamanların en
/// iyisine bakar ([calculateLongestStreak]), o anki canlı seriye değil.
Set<String> evaluateEarnedBadgeKeys({required List<PomodoroSession> completedFocusSessions}) {
  final Map<String, BadgeProgress> progress =
      evaluateBadgeProgress(completedFocusSessions: completedFocusSessions);
  return <String>{
    for (final MapEntry<String, BadgeProgress> entry in progress.entries)
      if (entry.value.earned) entry.key,
  };
}
