import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../streak/streak_calculator.dart';
import 'badge_definition.dart';

/// SPEC.md §5.4 — saf fonksiyon, IO yok. Tamamlanmış odak seansı geçmişinin
/// tamamına bakıp o an kazanılmış OLMASI GEREKEN tüm rozet anahtarlarını
/// döndürür (idempotent, geriye dönük yeniden hesaplanabilir). Rozetler
/// yalnızca başarıyla açılır, hiçbir zaman geri alınmaz — bu yüzden
/// "Haftalık Seri" gibi kurallar da tüm zamanların en iyisine bakar
/// ([calculateLongestStreak]), o anki canlı seriye değil.
Set<String> evaluateEarnedBadgeKeys({required List<PomodoroSession> completedFocusSessions}) {
  if (completedFocusSessions.isEmpty) {
    return const <String>{};
  }

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

  final Set<String> earned = <String>{BadgeKeys.firstSpark};
  if (maxPerDay >= 4) earned.add(BadgeKeys.focusTorch);
  if (hasMorningSession) earned.add(BadgeKeys.morningStar);
  if (hasNightSession) earned.add(BadgeKeys.nightWatch);
  if (longestStreak >= 7) earned.add(BadgeKeys.weeklyStreak);
  if (maxPerDay >= 8) earned.add(BadgeKeys.marathon);
  if (totalPlannedSeconds >= 100 * 3600) earned.add(BadgeKeys.hundredHours);
  return earned;
}
