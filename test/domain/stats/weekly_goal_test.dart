import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/time/app_day.dart';
import 'package:focussayac/domain/stats/weekly_goal.dart';
import 'package:focussayac/domain/stats/weekly_summary.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

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

DateTime _midday(int year, int month, int day) => DateTime.utc(year, month, day, 10);

void main() {
  group('WeeklyGoalProgress', () {
    test('hedefin yarısında oran 0.5, kalan süre yarım hedef', () {
      const WeeklyGoalProgress progress =
          WeeklyGoalProgress(goalSeconds: 300 * 60, focusedSeconds: 150 * 60);

      expect(progress.ratio, 0.5);
      expect(progress.remainingSeconds, 150 * 60);
      expect(progress.isReached, isFalse);
      expect(progress.isOff, isFalse);
    });

    test('hedef tam karşılandığında açılıyor — sınır dahil', () {
      const WeeklyGoalProgress justUnder =
          WeeklyGoalProgress(goalSeconds: 300 * 60, focusedSeconds: 300 * 60 - 1);
      const WeeklyGoalProgress exact =
          WeeklyGoalProgress(goalSeconds: 300 * 60, focusedSeconds: 300 * 60);

      expect(justUnder.isReached, isFalse);
      expect(exact.isReached, isTrue);
      expect(exact.ratio, 1);
      expect(exact.remainingSeconds, 0);
    });

    test('hedefi aşan kullanıcıda oran 1e kırpılıyor, kalan negatife düşmüyor', () {
      const WeeklyGoalProgress progress =
          WeeklyGoalProgress(goalSeconds: 300 * 60, focusedSeconds: 900 * 60);

      // Kırpılmasaydı çubuk kendi rayını taşardı.
      expect(progress.ratio, 1);
      expect(progress.remainingSeconds, 0);
      expect(progress.isReached, isTrue);
    });

    test('hedef 0 iken kapalı: oran 0, hiçbir zaman "ulaşıldı" değil', () {
      const WeeklyGoalProgress progress =
          WeeklyGoalProgress(goalSeconds: 0, focusedSeconds: 120 * 60);

      expect(progress.isOff, isTrue);
      expect(progress.ratio, 0);
      expect(progress.remainingSeconds, 0);
      // Kapalı hedef "tamamlandı" saymıyor: Ekran 02'de satır hiç çizilmiyor,
      // çizilseydi kullanıcının koymadığı bir hedefi kutlardı.
      expect(progress.isReached, isFalse);
    });

    test('hiç odak yokken oran 0 ama kapalı değil', () {
      const WeeklyGoalProgress progress =
          WeeklyGoalProgress(goalSeconds: 300 * 60, focusedSeconds: 0);

      expect(progress.isOff, isFalse);
      expect(progress.ratio, 0);
      expect(progress.remainingSeconds, 300 * 60);
      expect(progress.isReached, isFalse);
    });

    test('eşit değerler == ile eşleşiyor (Riverpod gereksiz çizimi elesin)', () {
      const WeeklyGoalProgress a = WeeklyGoalProgress(goalSeconds: 300, focusedSeconds: 60);
      const WeeklyGoalProgress b = WeeklyGoalProgress(goalSeconds: 300, focusedSeconds: 60);
      const WeeklyGoalProgress c = WeeklyGoalProgress(goalSeconds: 300, focusedSeconds: 61);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  // ROADMAP madde 24'ün kabul kriteri: "hafta sınırı `weekly_summary.dart` ile
  // aynı". Hedef kendi pencere hesabını kurmuyor, `calculateWeeklySummary`nin
  // saniyesini tüketiyor — bu testler o bağın kopmasını engelliyor.
  group('hafta sınırı weekly_summary ile aynı', () {
    // 2026-06-14 bir pazar. Pencere: 8–14 Haziran.
    final DateTime weekEnd = appDayKey(_midday(2026, 6, 14));

    test('pencere içindeki seanslar iki tarafta da aynı saniyeyi veriyor', () {
      final List<PomodoroSession> sessions = <PomodoroSession>[
        _session(startedAt: _midday(2026, 6, 14), minutes: 25),
        _session(startedAt: _midday(2026, 6, 10), minutes: 50),
      ];

      final WeeklySummary summary =
          calculateWeeklySummary(sessions: sessions, weekEndDayKey: weekEnd);
      final WeeklyGoalProgress progress = WeeklyGoalProgress(
        goalSeconds: 300 * 60,
        focusedSeconds: summary.seconds,
      );

      expect(progress.focusedSeconds, summary.seconds);
      expect(progress.focusedSeconds, 75 * 60);
    });

    test('pencerenin dışındaki seans ikisini de aynı anda etkilemiyor', () {
      // 7 Haziran, yani kayan yedi günün bir gün dışında.
      final List<PomodoroSession> sessions = <PomodoroSession>[
        _session(startedAt: _midday(2026, 6, 7), minutes: 90),
      ];

      final WeeklySummary summary =
          calculateWeeklySummary(sessions: sessions, weekEndDayKey: weekEnd);
      final WeeklyGoalProgress progress = WeeklyGoalProgress(
        goalSeconds: 300 * 60,
        focusedSeconds: summary.seconds,
      );

      expect(summary.seconds, 0);
      expect(progress.focusedSeconds, 0);
      expect(progress.ratio, 0);
      // Takvim haftası kullanılsaydı 7 Haziran (pazar) ayrı bir haftaya
      // düşerdi ve iki yüzey farklı sayı gösterirdi.
      expect(summary.previousSeconds, 90 * 60);
    });
  });
}
