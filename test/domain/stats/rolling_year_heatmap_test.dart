import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/stats/monthly_heatmap.dart';
import 'package:focussayac/domain/stats/rolling_year_heatmap.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Testlerin sabit "şimdi"si: 17 Eylül 2026, 15:00 TSİ → uygulama günü
/// 2026-09-17, bir **perşembe**. O haftanın pazartesisi 14 Eylül 2026, yani
/// pencere 22 Eylül 2025 (pazartesi) – 20 Eylül 2026 (pazar) arası.
final DateTime _nowUtc = DateTime.utc(2026, 9, 17, 12);

/// Pencerenin iki ucu ve bugün — testlerin hepsi bunlara göre konuşuyor.
final DateTime _windowStart = DateTime.utc(2025, 9, 22);
final DateTime _windowEnd = DateTime.utc(2026, 9, 20);
final DateTime _today = DateTime.utc(2026, 9, 17);

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

/// [day] bir uygulama günü anahtarı; seans o günün 12:00 UTC'sinde (15:00 TSİ)
/// başlıyor, yani 04:00 sınırından uzakta.
PomodoroSession _on(
  DateTime day, {
  int minutes = 25,
  bool completed = true,
  SessionType type = SessionType.focus,
}) =>
    _session(
      startedAt: day.add(const Duration(hours: 12)),
      minutes: minutes,
      completed: completed,
      type: type,
    );

RollingYearHeatmap _year(List<PomodoroSession> sessions, {DateTime? nowUtc}) =>
    calculateRollingYearHeatmap(sessions: sessions, nowUtc: nowUtc ?? _nowUtc);

HeatmapDay _day(RollingYearHeatmap year, DateTime dayKey) =>
    year.days.firstWhere((HeatmapDay d) => d.dayKey == dayKey);

void main() {
  group('pencerenin şekli', () {
    test('364 gün, pazartesiyle başlıyor, haftanın pazarıyla bitiyor', () {
      final RollingYearHeatmap year = _year(const <PomodoroSession>[]);

      // 52 hafta × 7 gün. Şerit sütun sütun çiziliyor, o yüzden uzunluk
      // yedinin tam katı olmak zorunda.
      expect(kRollingYearWeeks, 52);
      expect(year.days, hasLength(364));
      expect(year.days.first.dayKey, _windowStart);
      expect(year.days.first.dayKey.weekday, DateTime.monday);
      expect(year.days.last.dayKey, _windowEnd);
      expect(year.days.last.dayKey.weekday, DateTime.sunday);
    });

    test('günler kesintisiz ve sıralı — şeridin sütunları kaymıyor', () {
      final RollingYearHeatmap year = _year(const <PomodoroSession>[]);

      for (int i = 1; i < year.days.length; i++) {
        expect(
          year.days[i].dayKey.difference(year.days[i - 1].dayKey).inDays,
          1,
          reason: '$i. gün bir öncekinden tam bir gün sonra olmalı',
        );
      }
    });

    test('bugünden sonrası gelecek, bugün ve öncesi değil', () {
      final RollingYearHeatmap year = _year(const <PomodoroSession>[]);

      expect(_day(year, _today).isFuture, isFalse);
      expect(_day(year, _today.subtract(const Duration(days: 1))).isFuture, isFalse);
      expect(_day(year, _today.add(const Duration(days: 1))).isFuture, isTrue);
      expect(_day(year, _windowEnd).isFuture, isTrue);

      // Perşembeden pazara: yalnızca cuma/cumartesi/pazar gelecek.
      expect(year.days.where((HeatmapDay d) => d.isFuture), hasLength(3));
    });
  });

  group('pencerenin sol kenarı', () {
    test('tam 52 hafta öncesi içeride, bir gün öncesi dışarıda', () {
      final RollingYearHeatmap year = _year(<PomodoroSession>[
        _on(_windowStart, minutes: 30),
        _on(_windowStart.subtract(const Duration(days: 1)), minutes: 90),
      ]);

      expect(_day(year, _windowStart).minutes, 30);
      expect(year.totalMinutes, 30, reason: 'pencere dışındaki 90 dk sayılmamalı');
      expect(year.activeDays, 1);
      expect(
        year.days.any((HeatmapDay d) => d.dayKey == _windowStart.subtract(const Duration(days: 1))),
        isFalse,
      );
    });
  });

  group('hangi seanslar sayılıyor', () {
    test('yalnızca tamamlanmış odak seansı', () {
      final RollingYearHeatmap year = _year(<PomodoroSession>[
        _on(_today, minutes: 25),
        _on(_today, minutes: 40, completed: false),
        _on(_today, minutes: 15, type: SessionType.shortBreak),
      ]);

      expect(_day(year, _today).minutes, 25);
      expect(year.totalMinutes, 25);
      expect(year.activeDays, 1);
    });

    test('aynı günün seansları toplanıyor', () {
      final RollingYearHeatmap year = _year(<PomodoroSession>[
        _on(_today, minutes: 25),
        _on(_today, minutes: 35),
      ]);

      expect(_day(year, _today).minutes, 60);
      expect(year.activeDays, 1);
    });

    test('03:30 TSİ\'de başlayan seans bir önceki güne düşüyor', () {
      // 04:00 TSİ = 01:00 UTC. 00:30 UTC = 03:30 TSİ, yani hâlâ dünün günü.
      final RollingYearHeatmap year = _year(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 9, 17, 0, 30), minutes: 50),
      ]);

      expect(_day(year, DateTime.utc(2026, 9, 16)).minutes, 50);
      expect(_day(year, _today).minutes, 0);
    });
  });

  group('seviyeler aylık ızgarayla aynı ölçekten', () {
    test('aynı dakika aynı seviyeyi veriyor', () {
      final RollingYearHeatmap year = _year(<PomodoroSession>[
        _on(_today.subtract(const Duration(days: 4)), minutes: 10),
        _on(_today.subtract(const Duration(days: 3)), minutes: 25),
        _on(_today.subtract(const Duration(days: 2)), minutes: 50),
        _on(_today.subtract(const Duration(days: 1)), minutes: 90),
      ]);

      // Eşikler `heatmap_scale.dart`ta tek yerde; şerit kendi takımını
      // kurmuyor, çünkü karttaki tek efsane ikisine birden hizmet ediyor.
      expect(_day(year, _today.subtract(const Duration(days: 4))).level, heatmapLevel(10));
      expect(_day(year, _today.subtract(const Duration(days: 3))).level, heatmapLevel(25));
      expect(_day(year, _today.subtract(const Duration(days: 2))).level, heatmapLevel(50));
      expect(_day(year, _today.subtract(const Duration(days: 1))).level, heatmapLevel(90));
      expect(_day(year, _today.subtract(const Duration(days: 1))).level, kHeatmapLevels);
    });
  });

  group('boş pencere', () {
    test('şerit yine tam, hiçbir sayı uydurulmuyor', () {
      final RollingYearHeatmap year = _year(const <PomodoroSession>[]);

      expect(year.isEmpty, isTrue);
      expect(year.totalMinutes, 0);
      expect(year.activeDays, 0);
      expect(year.days, hasLength(364));
      expect(year.days.every((HeatmapDay d) => d.minutes == 0 && d.level == 0), isTrue);
    });

    test('dolu pencerede isEmpty false', () {
      final RollingYearHeatmap year = _year(<PomodoroSession>[_on(_today, minutes: 25)]);

      expect(year.isEmpty, isFalse);
    });
  });

  group('pencere hafta hafta kayıyor', () {
    test('aynı haftanın ertesi gününde pencere sabit', () {
      // 18 Eylül 2026 hâlâ aynı haftanın günü (cuma), yani pencere kaymıyor —
      // şerit hafta hafta ilerliyor, gün gün değil.
      final RollingYearHeatmap tomorrow =
          _year(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 9, 18, 12));

      expect(tomorrow.days.first.dayKey, _windowStart);
      expect(tomorrow.days.last.dayKey, _windowEnd);
      expect(tomorrow.days.where((HeatmapDay d) => d.isFuture), hasLength(2));
    });

    test('haftaya geçince pencere tam bir hafta ilerliyor', () {
      // 21 Eylül 2026 pazartesi: yeni haftanın ilk günü.
      final RollingYearHeatmap nextWeek =
          _year(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 9, 21, 12));

      expect(nextWeek.days.first.dayKey, _windowStart.add(const Duration(days: 7)));
      expect(nextWeek.days.last.dayKey, _windowEnd.add(const Duration(days: 7)));
      expect(nextWeek.days.first.dayKey.weekday, DateTime.monday);
      // Pazartesi günü haftanın altı günü henüz yaşanmamış.
      expect(nextWeek.days.where((HeatmapDay d) => d.isFuture), hasLength(6));
    });
  });
}
