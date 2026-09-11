import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/time/app_day.dart';
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

/// Uygulama günü 04:00 TSİ'de (01:00 UTC) başlıyor; bir günün **içinde** kalan
/// bir an için 10:00 UTC kullanılıyor (TSİ 13:00).
DateTime _midday(int year, int month, int day) => DateTime.utc(year, month, day, 10);

void main() {
  group('calculateWeeklySummary', () {
    // 2026-06-14 bir pazar. Pencere: 8–14 Haziran, önceki pencere: 1–7 Haziran.
    final DateTime weekEnd = appDayKey(_midday(2026, 6, 14));

    test('boş geçmişte iki pencere de sıfır ve isEmpty', () {
      final WeeklySummary summary =
          calculateWeeklySummary(sessions: const <PomodoroSession>[], weekEndDayKey: weekEnd);

      expect(summary.seconds, 0);
      expect(summary.previousSeconds, 0);
      expect(summary.isEmpty, isTrue);
      expect(summary.hasComparison, isFalse);
    });

    test('iki pencereyi ayırıp farkı veriyor', () {
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          // Bu hafta: 25 + 50 = 75 dk.
          _session(startedAt: _midday(2026, 6, 14), minutes: 25),
          _session(startedAt: _midday(2026, 6, 10), minutes: 50),
          // Geçen hafta: 35 dk.
          _session(startedAt: _midday(2026, 6, 3), minutes: 35),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 75 * 60);
      expect(summary.previousSeconds, 35 * 60);
      expect(summary.deltaSeconds, 40 * 60);
      expect(summary.hasComparison, isTrue);
      expect(summary.isEmpty, isFalse);
    });

    test('pencere sınırları: 7. gün içeride, 8. gün önceki pencerede', () {
      // 8 Haziran pencerenin ilk günü (14 − 6), 7 Haziran önceki pencerenin son
      // günü. Kayan yedi günün kapanış sınavı bu.
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          _session(startedAt: _midday(2026, 6, 8), minutes: 10),
          _session(startedAt: _midday(2026, 6, 7), minutes: 20),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 10 * 60);
      expect(summary.previousSeconds, 20 * 60);
    });

    test('iki pencereden de eski seanslar hiç sayılmıyor', () {
      // 1 Haziran önceki pencerenin ilk günü (14 − 13); 31 Mayıs dışarıda.
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          _session(startedAt: _midday(2026, 6, 1), minutes: 10),
          _session(startedAt: _midday(2026, 5, 31), minutes: 99),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 0);
      expect(summary.previousSeconds, 10 * 60);
    });

    test('pencerenin sonrasındaki günler sayılmıyor', () {
      // Özet ileri bir pazar için önceden kurulabiliyor; o pazardan sonraki bir
      // seans toplama girmemeli.
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          _session(startedAt: _midday(2026, 6, 15), minutes: 40),
          _session(startedAt: _midday(2026, 6, 14), minutes: 25),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 25 * 60);
    });

    test('yalnızca tamamlanmış odak seansları sayılıyor', () {
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          _session(startedAt: _midday(2026, 6, 12), minutes: 25),
          // İptal edilen odak: Ekran 10'dan çıkılan seans sayılmıyor.
          _session(startedAt: _midday(2026, 6, 12), minutes: 25, completed: false),
          // Molalar odak süresi değil.
          _session(startedAt: _midday(2026, 6, 12), minutes: 5, type: SessionType.shortBreak),
          _session(startedAt: _midday(2026, 6, 12), minutes: 15, type: SessionType.longBreak),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 25 * 60);
    });

    test('azalan hafta negatif fark veriyor', () {
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[
          _session(startedAt: _midday(2026, 6, 12), minutes: 25),
          _session(startedAt: _midday(2026, 6, 5), minutes: 75),
        ],
        weekEndDayKey: weekEnd,
      );

      expect(summary.deltaSeconds, -50 * 60);
      expect(summary.hasComparison, isTrue);
    });

    test('ilk haftada karşılaştırma kurulmuyor ama toplam duruyor', () {
      final WeeklySummary summary = calculateWeeklySummary(
        sessions: <PomodoroSession>[_session(startedAt: _midday(2026, 6, 12), minutes: 25)],
        weekEndDayKey: weekEnd,
      );

      expect(summary.seconds, 25 * 60);
      expect(summary.hasComparison, isFalse);
      expect(summary.isEmpty, isFalse);
    });
  });

  group('nextWeeklySummaryUtc', () {
    // 20:00 TSİ = 17:00 UTC (sabit UTC+3, `app_day.dart`).
    test('hafta ortasından önümüzdeki pazarı buluyor', () {
      // 2026-06-10 çarşamba, 09:00 UTC (12:00 TSİ).
      final DateTime sendAt = nextWeeklySummaryUtc(DateTime.utc(2026, 6, 10, 9));

      expect(sendAt, DateTime.utc(2026, 6, 14, 17));
      expect(toIstanbulWallClock(sendAt).weekday, DateTime.sunday);
      expect(toIstanbulWallClock(sendAt).hour, kWeeklySummaryHour);
    });

    test('pazar günü saatinden önce aynı günü veriyor', () {
      // Pazar 15:00 UTC = 18:00 TSİ, henüz 20:00 olmadı.
      expect(
        nextWeeklySummaryUtc(DateTime.utc(2026, 6, 14, 15)),
        DateTime.utc(2026, 6, 14, 17),
      );
    });

    test('pazar 20:00 geçtiyse gelecek pazara atlıyor', () {
      // Pazar 18:00 UTC = 21:00 TSİ.
      expect(
        nextWeeklySummaryUtc(DateTime.utc(2026, 6, 14, 18)),
        DateTime.utc(2026, 6, 21, 17),
      );
    });

    test('tam 20:00 anı geçmiş sayılıyor (bildirim iki kez kurulmasın)', () {
      expect(
        nextWeeklySummaryUtc(DateTime.utc(2026, 6, 14, 17)),
        DateTime.utc(2026, 6, 21, 17),
      );
    });

    test('pazartesi sabahı altı gün ileriye bakıyor', () {
      // 2026-06-15 pazartesi.
      expect(
        nextWeeklySummaryUtc(DateTime.utc(2026, 6, 15, 5)),
        DateTime.utc(2026, 6, 21, 17),
      );
    });
  });

  group('weeklySummaryWindowEnd', () {
    test('gönderim anının uygulama günü o pazarın kendisi', () {
      // 20:00 TSİ gün sınırının (04:00) üstünde, yani gün dönmüyor.
      expect(weeklySummaryWindowEnd(DateTime.utc(2026, 6, 14, 17)), DateTime.utc(2026, 6, 14));
    });

    test('zamanlama ve pencere aynı andan türüyor', () {
      // İkisinin ayrı zaman altyapılarından okunması 04:00 sınırının etrafında
      // sapmaya yol açardı; bu test o eşleşmeyi tutuyor.
      final DateTime sendAt = nextWeeklySummaryUtc(DateTime.utc(2026, 6, 10, 9));

      expect(weeklySummaryWindowEnd(sendAt), appDayKey(sendAt));
      expect(toIstanbulWallClock(sendAt).weekday, kWeeklySummaryWeekday);
    });
  });
}
