import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/badges/badge_definition.dart';
import 'package:focussayac/domain/badges/badge_rules.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

int _id = 0;

/// Seansı **TSİ duvar saatiyle** kurar. Rozet sınırlarının hepsi duvar
/// saatinde tanımlı (08:00 öncesi, 23:00 sonrası, 04:00 gün kesimi), depolama
/// ise UTC — testin okunur kalması için çeviri tek yerde.
PomodoroSession _at(
  int year,
  int month,
  int day,
  int hour, [
  int minute = 0,
  int minutes = 25,
]) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.utc(year, month, day, hour, minute).subtract(const Duration(hours: 3)),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
  );
}

/// Aynı uygulama gününe [count] seans — hepsi 09:00'dan itibaren, gün
/// sınırlarına (04:00 / 08:00 / 23:00) hiç değmeyen saatlerde.
List<PomodoroSession> _sameDay(int day, int count, {int minutes = 25}) {
  return <PomodoroSession>[
    for (int i = 0; i < count; i++) _at(2026, 3, day, 9 + i, 0, minutes),
  ];
}

Set<String> _earned(List<PomodoroSession> sessions) =>
    evaluateEarnedBadgeKeys(completedFocusSessions: sessions);

void main() {
  group('İlk Kıvılcım', () {
    test('geçmiş boşken hiçbir rozet açılmıyor', () {
      expect(_earned(const <PomodoroSession>[]), isEmpty);
    });

    test('tek tamamlanmış seans yalnızca İlk Kıvılcım\'ı açıyor', () {
      expect(_earned(<PomodoroSession>[_at(2026, 3, 10, 10)]), <String>{BadgeKeys.firstSpark});
    });
  });

  group('Odak Meşalesi — aynı günde 4 seans', () {
    test('3 seans yetmiyor, 4. açıyor', () {
      expect(_earned(_sameDay(10, 3)), isNot(contains(BadgeKeys.focusTorch)));
      expect(_earned(_sameDay(10, 4)), contains(BadgeKeys.focusTorch));
    });

    test('4 seans ayrı günlere dağılırsa açılmıyor', () {
      expect(
        _earned(<PomodoroSession>[
          ..._sameDay(8, 2),
          ..._sameDay(9, 2),
        ]),
        isNot(contains(BadgeKeys.focusTorch)),
      );
    });

    test('03:59\'daki 4. seans hâlâ önceki günün hanesine yazılıyor', () {
      // SPEC.md §5.3: uygulama günü 04:00 TSİ'de kapanır.
      expect(
        _earned(<PomodoroSession>[..._sameDay(10, 3), _at(2026, 3, 11, 3, 59)]),
        contains(BadgeKeys.focusTorch),
      );
      // Karşı kontrol: bir dakika sonrası yeni gün, sayaç 3'te kalıyor.
      expect(
        _earned(<PomodoroSession>[..._sameDay(10, 3), _at(2026, 3, 11, 4)]),
        isNot(contains(BadgeKeys.focusTorch)),
      );
    });
  });

  group('Sabah Yıldızı — 08:00 öncesi', () {
    test('07:59 açıyor, 08:00 açmıyor', () {
      expect(_earned(<PomodoroSession>[_at(2026, 3, 10, 7, 59)]), contains(BadgeKeys.morningStar));
      expect(
        _earned(<PomodoroSession>[_at(2026, 3, 10, 8)]),
        isNot(contains(BadgeKeys.morningStar)),
      );
    });

    test('04:00 (günün ilk dakikası) da sabah sayılıyor', () {
      expect(_earned(<PomodoroSession>[_at(2026, 3, 10, 4)]), contains(BadgeKeys.morningStar));
    });
  });

  group('Gece Nöbeti — 23:00 sonrası', () {
    test('22:59 açmıyor, 23:00 açıyor', () {
      expect(
        _earned(<PomodoroSession>[_at(2026, 3, 10, 22, 59)]),
        isNot(contains(BadgeKeys.nightWatch)),
      );
      expect(_earned(<PomodoroSession>[_at(2026, 3, 10, 23)]), contains(BadgeKeys.nightWatch));
    });

    test('00:30 gece nöbeti değil — kural gün anahtarına değil duvar saatine bakıyor', () {
      // 00:30 hâlâ önceki uygulama gününe ait ama duvar saati 23:00'ün altında.
      final Set<String> earned = _earned(<PomodoroSession>[_at(2026, 3, 10, 0, 30)]);
      expect(earned, isNot(contains(BadgeKeys.nightWatch)));
      expect(earned, contains(BadgeKeys.morningStar));
    });
  });

  group('Haftalık Seri — 7 ardışık gün', () {
    test('6 gün yetmiyor, 7. gün açıyor', () {
      final List<PomodoroSession> sixDays = <PomodoroSession>[
        for (int day = 1; day <= 6; day++) _at(2026, 3, day, 10),
      ];
      expect(_earned(sixDays), isNot(contains(BadgeKeys.weeklyStreak)));
      expect(
        _earned(<PomodoroSession>[...sixDays, _at(2026, 3, 7, 10)]),
        contains(BadgeKeys.weeklyStreak),
      );
    });

    test('seri sonradan kırılsa da rozet açık kalıyor', () {
      // Rozetler geri alınmaz (SPEC.md §5.4) — kural tüm zamanların en uzun
      // serisine bakıyor, o anki canlı seriye değil.
      expect(
        _earned(<PomodoroSession>[
          for (int day = 1; day <= 7; day++) _at(2026, 3, day, 10),
          _at(2026, 3, 25, 10),
        ]),
        contains(BadgeKeys.weeklyStreak),
      );
    });

    test('bir gün atlanınca 7\'ye ulaşılmıyor', () {
      expect(
        _earned(<PomodoroSession>[
          for (int day = 1; day <= 4; day++) _at(2026, 3, day, 10),
          for (int day = 6; day <= 9; day++) _at(2026, 3, day, 10),
        ]),
        isNot(contains(BadgeKeys.weeklyStreak)),
      );
    });
  });

  group('Maraton — aynı günde 8 seans', () {
    test('7 seans yetmiyor, 8. açıyor', () {
      expect(_earned(_sameDay(10, 7)), isNot(contains(BadgeKeys.marathon)));
      final Set<String> earned = _earned(_sameDay(10, 8));
      expect(earned, contains(BadgeKeys.marathon));
      // 8 seans 4'lük eşiği de kapsıyor.
      expect(earned, contains(BadgeKeys.focusTorch));
    });
  });

  group('100 Saat Kulübü', () {
    test('99sa 59dk kapalı, 100sa açık', () {
      // Toplam **planlanan** süreye bakılıyor; 60 dakikalık seanslarla sayıyoruz.
      final List<PomodoroSession> ninetyNine = <PomodoroSession>[
        for (int i = 0; i < 99; i++) _at(2026, 3, 1 + i ~/ 3, 9 + i % 3, 0, 60),
        _at(2026, 5, 1, 10, 0, 59),
      ];
      expect(_earned(ninetyNine), isNot(contains(BadgeKeys.hundredHours)));
      expect(
        _earned(<PomodoroSession>[...ninetyNine, _at(2026, 5, 1, 12, 0, 1)]),
        contains(BadgeKeys.hundredHours),
      );
    });
  });

  test('yedi rozetin tamamı tek geçmişten açılabiliyor', () {
    final List<PomodoroSession> history = <PomodoroSession>[
      // 30 ardışık gün × 8 seans × 25 dk = tam 100 saat.
      for (int day = 1; day <= 30; day++) ..._sameDay(day, 8),
      _at(2026, 3, 5, 7),
      _at(2026, 3, 5, 23, 30),
    ];

    expect(
      _earned(history),
      kBadgeCatalog.map((BadgeDefinition b) => b.key).toSet(),
    );
  });
}
