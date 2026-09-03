import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/stats/focus_stats.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Testlerin sabit "şimdi"si: 10 Mart 2026, 15:00 TSİ → uygulama günü
/// 2026-03-10 (Salı).
final DateTime _nowUtc = DateTime.utc(2026, 3, 10, 12);
final DateTime _today = DateTime.utc(2026, 3, 10);

int _id = 0;

PomodoroSession _session({
  required DateTime startedAt,
  bool completed = true,
  int minutes = 25,
  SessionType type = SessionType.focus,
}) {
  return PomodoroSession(
    id: ++_id,
    type: type,
    startedAt: startedAt,
    plannedDurationSec: minutes * 60,
    completed: completed,
    breakExtensions: 0,
  );
}

FocusStats _stats(List<PomodoroSession> sessions) =>
    calculateFocusStats(sessions: sessions, nowUtc: _nowUtc);

void main() {
  group('boş veri', () {
    test('hiçbir sayı uydurulmuyor, hafta yine 7 gün', () {
      final FocusStats stats = _stats(const <PomodoroSession>[]);

      expect(stats.cumulativeSeconds, 0);
      expect(stats.dailyAverageSeconds, 0);
      expect(stats.longestStreak, 0);
      // Oran tanımsız — `%0` göstermek "4 seansın 0'ını bitirdin" demek olurdu.
      expect(stats.completionPercent, isNull);
      expect(stats.productiveWindow, isNull);
      expect(stats.lastWeek, hasLength(kStatsWeekLength));
      expect(stats.lastWeek.every((DailyFocus d) => d.minutes == 0), isTrue);
      expect(stats.lastWeek.last.dayKey, _today);
    });
  });

  group('tek gün', () {
    test('aynı günün seansları toplanıyor, ortalama 7 güne bölünüyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 3, 10, 7), minutes: 25),
        _session(startedAt: DateTime.utc(2026, 3, 10, 9), minutes: 35),
      ]);

      expect(stats.cumulativeSeconds, 60 * 60);
      expect(stats.lastWeek.last.minutes, 60);
      expect(stats.lastWeek.sublist(0, 6).every((DailyFocus d) => d.minutes == 0), isTrue);
      // 3600 sn / 7 gün — boş günler de paydada.
      expect(stats.dailyAverageSeconds, 3600 ~/ 7);
      expect(stats.longestStreak, 1);
    });
  });

  group('hafta sınırı', () {
    test('6 gün önce haftada, 7 gün önce yalnızca kümülatifte', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 3, 4, 9), minutes: 30), // 6 gün önce
        _session(startedAt: DateTime.utc(2026, 3, 3, 9), minutes: 40), // 7 gün önce
      ]);

      expect(stats.lastWeek.first.dayKey, DateTime.utc(2026, 3, 4));
      expect(stats.lastWeek.first.minutes, 30);
      expect(stats.lastWeek.map((DailyFocus d) => d.minutes).reduce((int a, int b) => a + b), 30);
      // Kümülatif toplam pencereyle sınırlı değil.
      expect(stats.cumulativeSeconds, 70 * 60);
      expect(stats.dailyAverageSeconds, (30 * 60) ~/ 7);
    });
  });

  group('gün sınırı 04:00 TSİ', () {
    test('03:59 önceki güne, 04:00 o güne yazılıyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 3, 10, 0, 59), minutes: 10), // 03:59 TSİ
        _session(startedAt: DateTime.utc(2026, 3, 10, 1), minutes: 20), // 04:00 TSİ
      ]);

      final DailyFocus yesterday = stats.lastWeek[kStatsWeekLength - 2];
      expect(yesterday.dayKey, DateTime.utc(2026, 3, 9));
      expect(yesterday.minutes, 10);
      expect(stats.lastWeek.last.minutes, 20);
    });
  });

  group('tamamlanma oranı', () {
    test('iptal edilen seanslar paydada, kümülatif sürede değil', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 3, 10, 7)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 8)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 9)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 10), completed: false),
      ]);

      expect(stats.completionPercent, 75);
      expect(stats.cumulativeSeconds, 3 * 25 * 60);
    });

    test('mola seansları hiçbir hesaba girmiyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 3, 10, 7), minutes: 25),
        _session(startedAt: DateTime.utc(2026, 3, 10, 8), minutes: 5, type: SessionType.shortBreak),
        _session(
          startedAt: DateTime.utc(2026, 3, 10, 9),
          minutes: 15,
          type: SessionType.longBreak,
          completed: false,
        ),
      ]);

      expect(stats.cumulativeSeconds, 25 * 60);
      expect(stats.lastWeek.last.minutes, 25);
      expect(stats.completionPercent, 100);
    });
  });

  group('en verimli aralık', () {
    test('eşiğin altındaki kovalar aralık sayılmıyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        // 20:00 TSİ'de yalnızca 2 seans — `kProductiveWindowMinSessions` = 3.
        _session(startedAt: DateTime.utc(2026, 3, 9, 17)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 17)),
      ]);

      expect(stats.productiveWindow, isNull);
    });

    test('tamamlanma oranı en yüksek kova İstanbul duvar saatiyle dönüyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        // 20:00–22:00 TSİ: 4 seansın 3'ü tamam → %75.
        _session(startedAt: DateTime.utc(2026, 3, 9, 17)),
        _session(startedAt: DateTime.utc(2026, 3, 9, 18)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 17)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 18), completed: false),
        // 08:00–10:00 TSİ: 3 seansın 3'ü tamam → %100.
        _session(startedAt: DateTime.utc(2026, 3, 8, 5, 30)),
        _session(startedAt: DateTime.utc(2026, 3, 9, 6)),
        _session(startedAt: DateTime.utc(2026, 3, 10, 6, 45)),
      ]);

      expect(stats.productiveWindow, isNotNull);
      expect(stats.productiveWindow!.startHour, 8);
      expect(stats.productiveWindow!.endHour, 10);
      expect(stats.productiveWindow!.completionPercent, 100);
    });
  });

  group('en uzun seri', () {
    test('geçmişte kırılmış seri de sayılıyor', () {
      final FocusStats stats = _stats(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 2, 1, 9)),
        _session(startedAt: DateTime.utc(2026, 2, 2, 9)),
        _session(startedAt: DateTime.utc(2026, 2, 3, 9)),
        // Boşluk — seri kırılıyor.
        _session(startedAt: DateTime.utc(2026, 3, 10, 9)),
      ]);

      expect(stats.longestStreak, 3);
    });
  });
}
