import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/stats/monthly_heatmap.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Testlerin sabit "şimdi"si: 17 Eylül 2026, 15:00 TSİ → uygulama günü
/// 2026-09-17. Eylül 30 günlük ve ayın 1'i **salı**, yani `leadingBlanks = 1`.
final DateTime _nowUtc = DateTime.utc(2026, 9, 17, 12);

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

/// [day] Eylül 2026'nın günü; saat 12:00 UTC = 15:00 TSİ, yani gün sınırından
/// uzak.
PomodoroSession _september(int day, {int minutes = 25, bool completed = true}) =>
    _session(startedAt: DateTime.utc(2026, 9, day, 12), minutes: minutes, completed: completed);

MonthlyHeatmap _heatmap(List<PomodoroSession> sessions, {DateTime? nowUtc, int monthOffset = 0}) =>
    calculateMonthlyHeatmap(
      sessions: sessions,
      nowUtc: nowUtc ?? _nowUtc,
      monthOffset: monthOffset,
    );

/// Izgaradaki belirli bir günün hücresi.
HeatmapDay _day(MonthlyHeatmap heatmap, int day) =>
    heatmap.days.firstWhere((HeatmapDay d) => d.dayKey.day == day);

void main() {
  group('boş ay', () {
    test('ızgara yine ayın tamamı, hiçbir sayı uydurulmuyor', () {
      final MonthlyHeatmap heatmap = _heatmap(const <PomodoroSession>[]);

      expect(heatmap.isEmpty, isTrue);
      expect(heatmap.totalMinutes, 0);
      expect(heatmap.activeDays, 0);
      // Kart boş ayda da çiziliyor (ROADMAP madde 29 kabul ölçütü): 30 hücre.
      expect(heatmap.days, hasLength(30));
      expect(heatmap.days.every((HeatmapDay d) => d.minutes == 0 && d.level == 0), isTrue);
      expect(heatmap.days.first.dayKey, DateTime.utc(2026, 9, 1));
      expect(heatmap.days.last.dayKey, DateTime.utc(2026, 9, 30));
    });
  });

  group('kısmi ay', () {
    test('günler toplanıyor, yalnızca dolu günler sayılıyor', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        _september(2, minutes: 25),
        _september(2, minutes: 35), // aynı gün → 60 dk
        _september(9, minutes: 100),
        _september(16, minutes: 10),
      ]);

      expect(heatmap.isEmpty, isFalse);
      expect(heatmap.totalMinutes, 170);
      expect(heatmap.activeDays, 3);
      expect(_day(heatmap, 2).minutes, 60);
      expect(_day(heatmap, 9).minutes, 100);
      expect(_day(heatmap, 16).minutes, 10);
      expect(_day(heatmap, 3).minutes, 0);
    });

    test('iptal edilen odaklar ve molalar ızgaraya girmiyor', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        _september(5, minutes: 25),
        _september(5, minutes: 40, completed: false),
        _session(
          startedAt: DateTime.utc(2026, 9, 5, 13),
          minutes: 15,
          type: SessionType.longBreak,
        ),
        _session(
          startedAt: DateTime.utc(2026, 9, 6, 12),
          minutes: 5,
          type: SessionType.shortBreak,
        ),
      ]);

      expect(_day(heatmap, 5).minutes, 25);
      expect(_day(heatmap, 6).minutes, 0);
      expect(heatmap.totalMinutes, 25);
      expect(heatmap.activeDays, 1);
    });

    test('başka ayların seansları bu ayın ızgarasına girmiyor', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        _session(startedAt: DateTime.utc(2026, 8, 31, 12), minutes: 90),
        _session(startedAt: DateTime.utc(2026, 10, 1, 12), minutes: 90),
        _september(10, minutes: 30),
      ]);

      expect(heatmap.totalMinutes, 30);
      expect(heatmap.activeDays, 1);
      expect(heatmap.days, hasLength(30));
    });
  });

  group('yoğun ay', () {
    test('her günü dolu ay eksiksiz çiziliyor', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        for (int day = 1; day <= 30; day++) _september(day, minutes: 120),
      ]);

      expect(heatmap.days, hasLength(30));
      expect(heatmap.activeDays, 30);
      expect(heatmap.totalMinutes, 30 * 120);
      expect(heatmap.days.every((HeatmapDay d) => d.level == kHeatmapLevels), isTrue);
    });
  });

  group('seviye eşikleri', () {
    test('ton sayısı eşik sayısıyla aynı', () {
      // İki sabit ayrı yazıldı (`kHeatmapLevels` `const` kalabilsin diye);
      // ilişkiyi bu test tutuyor.
      expect(kHeatmapLevelThresholds, hasLength(kHeatmapLevels));
    });

    test('eşikler mutlak: 0 / 1 / 25 / 50 / 90 kenarları', () {
      // Her gün ayrı bir dakika değeri taşıyor; tablo tek bir ızgaradan okunuyor.
      const Map<int, int> minutesByDay = <int, int>{
        1: 0,
        2: 1,
        3: 24,
        4: 25,
        5: 49,
        6: 50,
        7: 89,
        8: 90,
        9: 600,
      };
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        for (final MapEntry<int, int> entry in minutesByDay.entries)
          if (entry.value > 0) _september(entry.key, minutes: entry.value),
      ]);

      expect(_day(heatmap, 1).level, 0);
      expect(_day(heatmap, 2).level, 1);
      expect(_day(heatmap, 3).level, 1);
      expect(_day(heatmap, 4).level, 2);
      expect(_day(heatmap, 5).level, 2);
      expect(_day(heatmap, 6).level, 3);
      expect(_day(heatmap, 7).level, 3);
      expect(_day(heatmap, 8).level, 4);
      // Tavan aşılmıyor: 10 saatlik gün de en üst seviye.
      expect(_day(heatmap, 9).level, kHeatmapLevels);
    });

    test('ayın en yoğun günü ölçeği değiştirmiyor', () {
      // Tek günü 5 dakika olan ay: o gün **en koyu** ton olmamalı, yoksa ızgara
      // kullanıcının verisi hakkında yanlış bir şey söylerdi.
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        _september(4, minutes: 5),
      ]);

      expect(_day(heatmap, 4).level, 1);
    });
  });

  group('takvim yerleşimi', () {
    test('ayın 1\'i salı olduğunda bir hücre boşluk bırakılıyor', () {
      expect(DateTime.utc(2026, 9, 1).weekday, DateTime.tuesday);

      expect(_heatmap(const <PomodoroSession>[]).leadingBlanks, 1);
    });

    test('ayın 1\'i pazartesi olduğunda boşluk yok', () {
      // 1 Haziran 2026 pazartesi, ay 30 günlük.
      expect(DateTime.utc(2026, 6, 1).weekday, DateTime.monday);

      final MonthlyHeatmap heatmap =
          _heatmap(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 6, 15, 12));

      expect(heatmap.leadingBlanks, 0);
      expect(heatmap.days, hasLength(30));
    });

    test('ayın 1\'i pazar olduğunda altı hücre boşluk bırakılıyor', () {
      // 1 Mart 2026 pazar, ay 31 günlük — hafta pazartesiyle başlıyor.
      expect(DateTime.utc(2026, 3, 1).weekday, DateTime.sunday);

      final MonthlyHeatmap heatmap =
          _heatmap(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 3, 15, 12));

      expect(heatmap.leadingBlanks, 6);
      expect(heatmap.days, hasLength(31));
    });

    test('şubat 28 hücre', () {
      final MonthlyHeatmap heatmap =
          _heatmap(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 2, 15, 12));

      expect(heatmap.days, hasLength(28));
      expect(heatmap.days.last.dayKey, DateTime.utc(2026, 2, 28));
    });
  });

  group('gelecek günler', () {
    test('bugünden sonrası gelecek, bugün ve öncesi değil', () {
      final MonthlyHeatmap heatmap = _heatmap(const <PomodoroSession>[]);

      expect(_day(heatmap, 16).isFuture, isFalse);
      expect(_day(heatmap, 17).isFuture, isFalse);
      expect(_day(heatmap, 18).isFuture, isTrue);
      expect(_day(heatmap, 30).isFuture, isTrue);
      // 17 Eylül dahil 17 gün yaşandı, 13 gün gelecek.
      expect(heatmap.days.where((HeatmapDay d) => d.isFuture), hasLength(13));
    });

    test('geçmiş bir ayda hiçbir gün gelecek değil', () {
      final MonthlyHeatmap heatmap =
          _heatmap(const <PomodoroSession>[], nowUtc: DateTime.utc(2026, 3, 31, 12));

      expect(heatmap.days.any((HeatmapDay d) => d.isFuture), isFalse);
    });
  });

  group('gün sınırı 04:00 TSİ', () {
    test('1 Eylül 03:30 TSİ ağustosa, 04:30 TSİ eylüle yazılıyor', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
        // 00:30 UTC = 03:30 TSİ → uygulama günü 31 Ağustos.
        _session(startedAt: DateTime.utc(2026, 9, 1, 0, 30), minutes: 40),
        // 01:30 UTC = 04:30 TSİ → uygulama günü 1 Eylül.
        _session(startedAt: DateTime.utc(2026, 9, 1, 1, 30), minutes: 30),
      ]);

      expect(_day(heatmap, 1).minutes, 30);
      expect(heatmap.totalMinutes, 30);
    });

    test('1 Eylül 03:00 TSİ\'de açılan uygulama hâlâ ağustosu gösteriyor', () {
      final MonthlyHeatmap heatmap = _heatmap(
        <PomodoroSession>[_session(startedAt: DateTime.utc(2026, 8, 20, 12), minutes: 45)],
        // 00:00 UTC = 03:00 TSİ → uygulama günü 31 Ağustos.
        nowUtc: DateTime.utc(2026, 9, 1),
      );

      expect(heatmap.days, hasLength(31));
      expect(heatmap.days.first.dayKey, DateTime.utc(2026, 8, 1));
      expect(heatmap.totalMinutes, 45);
      // 1 Ağustos 2026 cumartesi → beş hücre boşluk.
      expect(DateTime.utc(2026, 8, 1).weekday, DateTime.saturday);
      expect(heatmap.leadingBlanks, 5);
      // Ayın son günü "bugün": hiçbir gün gelecek değil.
      expect(heatmap.days.any((HeatmapDay d) => d.isFuture), isFalse);
    });
  });

  group('ay gezinme (madde 35)', () {
    test('bu ay: pencere eylülde, ileri gidilecek ay yok', () {
      final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[_september(10)]);

      expect(heatmap.month, DateTime.utc(2026, 9, 1));
      expect(heatmap.isCurrentMonth, isTrue);
      expect(heatmap.hasLater, isFalse);
    });

    test('bir ay geri: pencere ağustosa kayıyor, yerleşim o ayın 1\'ine göre', () {
      final MonthlyHeatmap heatmap = _heatmap(
        <PomodoroSession>[
          _session(startedAt: DateTime.utc(2026, 8, 3, 12), minutes: 45),
          _september(10, minutes: 120),
        ],
        monthOffset: -1,
      );

      expect(heatmap.month, DateTime.utc(2026, 8, 1));
      expect(heatmap.isCurrentMonth, isFalse);
      expect(heatmap.hasLater, isTrue);
      expect(heatmap.days, hasLength(31));
      expect(heatmap.days.first.dayKey, DateTime.utc(2026, 8, 1));
      // 1 Ağustos 2026 cumartesi → beş hücre boşluk.
      expect(heatmap.leadingBlanks, 5);
      // Eylülün seansı ağustosun toplamına girmiyor.
      expect(heatmap.totalMinutes, 45);
      expect(_day(heatmap, 3).minutes, 45);
    });

    test('geçmiş ayın hiçbir günü gelecek değil: ızgara ay sonuna kadar dolu', () {
      final MonthlyHeatmap heatmap = _heatmap(const <PomodoroSession>[], monthOffset: -1);

      expect(heatmap.days.any((HeatmapDay d) => d.isFuture), isFalse);
      expect(heatmap.days.last.dayKey, DateTime.utc(2026, 8, 31));
    });

    test('yıl sınırı: ocakta bir ay geri gitmek geçen yılın aralığı', () {
      final MonthlyHeatmap heatmap = _heatmap(
        <PomodoroSession>[_session(startedAt: DateTime.utc(2025, 12, 24, 12), minutes: 60)],
        nowUtc: DateTime.utc(2026, 1, 10, 12),
        monthOffset: -1,
      );

      expect(heatmap.month, DateTime.utc(2025, 12, 1));
      expect(heatmap.days, hasLength(31));
      // 1 Aralık 2025 pazartesi → boşluk yok.
      expect(DateTime.utc(2025, 12, 1).weekday, DateTime.monday);
      expect(heatmap.leadingBlanks, 0);
      expect(heatmap.totalMinutes, 60);
    });

    group('hasEarlier', () {
      test('yalnızca bu ayın seansları varken geri gidilecek ay yok', () {
        expect(_heatmap(<PomodoroSession>[_september(10)]).hasEarlier, isFalse);
      });

      test('önceki bir ayda tamamlanmış odak varsa geri gidiliyor', () {
        final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
          _session(startedAt: DateTime.utc(2026, 5, 3, 12), minutes: 30),
          _september(10),
        ]);

        expect(heatmap.hasEarlier, isTrue);
      });

      test('ölçüt ızgaranınkiyle aynı: iptal ve mola geri oku açmıyor', () {
        // Ağustosta yalnızca yarım kalmış bir odak ve bir mola var; geri
        // gidilse boş bir ızgara görünürdü.
        final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
          _session(startedAt: DateTime.utc(2026, 8, 3, 12), minutes: 40, completed: false),
          _session(
            startedAt: DateTime.utc(2026, 8, 4, 12),
            minutes: 15,
            type: SessionType.longBreak,
          ),
          _september(10),
        ]);

        expect(heatmap.hasEarlier, isFalse);
      });

      test('geçmiş aya gidildiğinde ölçüt o ayın başına göre', () {
        final List<PomodoroSession> sessions = <PomodoroSession>[
          _session(startedAt: DateTime.utc(2026, 8, 3, 12), minutes: 45),
        ];

        // Ağustostayken daha eski bir seans yok → geri ok kapalı.
        expect(_heatmap(sessions, monthOffset: -1).hasEarlier, isFalse);
        // Eylüldeyken ağustosun seansı geri oku açıyor.
        expect(_heatmap(sessions).hasEarlier, isTrue);
      });

      test('gün sınırı 04:00 TSİ burada da geçerli', () {
        // 00:30 UTC = 03:30 TSİ → uygulama günü 31 Ağustos, yani eylülden önce.
        final MonthlyHeatmap heatmap = _heatmap(<PomodoroSession>[
          _session(startedAt: DateTime.utc(2026, 9, 1, 0, 30), minutes: 40),
        ]);

        expect(heatmap.hasEarlier, isTrue);
      });
    });
  });
}
