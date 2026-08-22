import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import '../../services/storage/storage_providers.dart';
import '../streak/streak_calculator.dart';

/// Tüm seans kayıtları — Ekran 02'nin "bugün" kartı ve seri, bu tek akıştan
/// istemci tarafında türetilir (kişisel cihaz verisi küçük; ekstra bir
/// aralık-sorgusu akışı eklemek yerine bu daha basit — SPEC §2 "Basitlik").
final StreamProvider<List<PomodoroSession>> allSessionsProvider =
    StreamProvider<List<PomodoroSession>>((Ref ref) {
  return ref.watch(pomodoroSessionDaoProvider).watchAllSessions();
});

/// Bugünkü (04:00 TSİ sınırlı) tamamlanmış odak seansı sayısı ve toplam
/// planlanan süresi (saniye). Tamamlanan bir seans planlanan süresini
/// tam olarak çalıştığı için toplam süre `plannedDurationSec` üzerinden
/// hesaplanır (SPEC §5.1: kalan süre hiçbir zaman azalan sayaçtan okunmaz).
class TodayFocusStats {
  const TodayFocusStats({required this.completedCount, required this.totalSeconds});

  final int completedCount;
  final int totalSeconds;
}

final Provider<TodayFocusStats> todayFocusStatsProvider = Provider<TodayFocusStats>((Ref ref) {
  final List<PomodoroSession> sessions = ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  final DateTime today = currentAppDayKey(DateTime.now().toUtc());

  int completedCount = 0;
  int totalSeconds = 0;
  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) {
      continue;
    }
    if (appDayKey(session.startedAt) != today) {
      continue;
    }
    completedCount += 1;
    totalSeconds += session.plannedDurationSec;
  }
  return TodayFocusStats(completedCount: completedCount, totalSeconds: totalSeconds);
});

/// Güncel seri — tamamlanmış odak seanslarının `startedAt`'lerinden
/// `calculateStreak` ile türetilir.
final Provider<int> streakProvider = Provider<int>((Ref ref) {
  final List<PomodoroSession> sessions = ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  final List<DateTime> completedFocusStarts = sessions
      .where((PomodoroSession s) => s.completed && s.type == SessionType.focus)
      .map((PomodoroSession s) => s.startedAt)
      .toList(growable: false);
  return calculateStreak(
    completedFocusStartedAtUtc: completedFocusStarts,
    nowUtc: DateTime.now().toUtc(),
  );
});
