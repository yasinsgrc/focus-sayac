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

/// [count] saatlik geçmiş — günde üç adet 60 dakikalık seans. Saat merdiveni
/// kümülatif **planlanan** süreye baktığı için dağılımın önemi yok, toplamın
/// var; günler ardışık, saatler 09:00–11:00 (hiçbir gün/gece sınırına değmiyor).
List<PomodoroSession> _hours(int count) => <PomodoroSession>[
      for (int i = 0; i < count; i++) _at(2026, 3, 1 + i ~/ 3, 9 + i % 3, 0, 60),
    ];

Set<String> _earned(List<PomodoroSession> sessions) =>
    evaluateEarnedBadgeKeys(completedFocusSessions: sessions);

Map<String, BadgeProgress> _progress(List<PomodoroSession> sessions) =>
    evaluateBadgeProgress(completedFocusSessions: sessions);

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

  group('Saat merdiveni — 10/50/100/250', () {
    test('basamaklar sırayla açılıyor, biri açılırken üstü kapalı kalıyor', () {
      expect(_earned(_hours(9)), isNot(contains(BadgeKeys.tenHours)));

      final Set<String> atTen = _earned(_hours(10));
      expect(atTen, contains(BadgeKeys.tenHours));
      expect(atTen, isNot(contains(BadgeKeys.fiftyHours)));

      final Set<String> atFifty = _earned(_hours(50));
      expect(atFifty, containsAll(<String>[BadgeKeys.tenHours, BadgeKeys.fiftyHours]));
      expect(atFifty, isNot(contains(BadgeKeys.hundredHours)));

      expect(_earned(_hours(249)), isNot(contains(BadgeKeys.twoFiftyHours)));
      expect(
        _earned(_hours(250)),
        containsAll(<String>[
          BadgeKeys.tenHours,
          BadgeKeys.fiftyHours,
          BadgeKeys.hundredHours,
          BadgeKeys.twoFiftyHours,
        ]),
      );
    });
  });

  group('İlerleme', () {
    test('boş geçmişte katalog eksiksiz ve her rozet 0/hedef', () {
      final Map<String, BadgeProgress> progress = _progress(const <PomodoroSession>[]);

      // Ekran 04 kilitli kartların halkasını bu haritadan çiziyor: eksik bir
      // anahtar sessizce halkasız bir kart demek olurdu.
      expect(progress.keys.toSet(), kBadgeCatalog.map((BadgeDefinition b) => b.key).toSet());
      expect(progress.values.every((BadgeProgress p) => p.current == 0), isTrue);
      expect(progress.values.any((BadgeProgress p) => p.earned), isFalse);
    });

    test('61 saat "100 saat" rozetinde 61/100 okunuyor', () {
      final Map<String, BadgeProgress> progress = _progress(_hours(61));
      final BadgeProgress hundred = progress[BadgeKeys.hundredHours]!;

      expect(hundred.current, 61);
      expect(hundred.target, 100);
      expect(hundred.earned, isFalse);
      expect(hundred.ratio, closeTo(0.61, 0.0001));
      // Aynı saatler merdivenin bir üst basamağında daha uzak bir hedefe bakıyor.
      expect(progress[BadgeKeys.twoFiftyHours]!.target, 250);
    });

    test('tam saate yuvarlanıyor: 9sa 59dk hâlâ 9/10', () {
      final Map<String, BadgeProgress> progress = _progress(<PomodoroSession>[
        ..._hours(9),
        _at(2026, 5, 1, 10, 0, 59),
      ]);
      expect(progress[BadgeKeys.tenHours]!.current, 9);
      expect(progress[BadgeKeys.tenHours]!.earned, isFalse);
    });

    test('hedefi 1 olan rozetlerde sayaç çizilmiyor', () {
      final Map<String, BadgeProgress> progress = _progress(const <PomodoroSession>[]);
      expect(progress[BadgeKeys.morningStar]!.isCountable, isFalse);
      expect(progress[BadgeKeys.nightWatch]!.isCountable, isFalse);
      expect(progress[BadgeKeys.firstSpark]!.isCountable, isFalse);
      expect(progress[BadgeKeys.hundredHours]!.isCountable, isTrue);
      expect(progress[BadgeKeys.weeklyStreak]!.isCountable, isTrue);
    });

    test('hedefi aşan ilerlemede halka taşmıyor', () {
      // Tek günde 12 seans: Odak Meşalesi'nin hedefi 4, oran 1'de duruyor.
      final BadgeProgress torch = _progress(_sameDay(10, 12))[BadgeKeys.focusTorch]!;
      expect(torch.current, 12);
      expect(torch.ratio, 1.0);
    });

    test('açılmış rozet kümesi ilerlemenin süzülmüş hâli', () {
      // İki API'nin aynı geçmişte ayrışmaması, kilitli kartın halkası dolduğu
      // anda rozetin gerçekten açılmasının tek güvencesi.
      final List<PomodoroSession> history = <PomodoroSession>[..._hours(61), _at(2026, 3, 10, 7)];
      expect(
        _earned(history),
        <String>{
          for (final MapEntry<String, BadgeProgress> entry in _progress(history).entries)
            if (entry.value.earned) entry.key,
        },
      );
    });
  });

  test('kataloğun tamamı tek geçmişten açılabiliyor', () {
    final List<PomodoroSession> history = <PomodoroSession>[
      // 75 ardışık gün × 8 seans × 25 dk = tam 250 saat: merdivenin son
      // basamağı da dâhil her rozet aynı geçmişten açılıyor.
      for (int day = 1; day <= 75; day++) ..._sameDay(day, 8),
      _at(2026, 3, 5, 7),
      _at(2026, 3, 5, 23, 30),
    ];

    expect(
      _earned(history),
      kBadgeCatalog.map((BadgeDefinition b) => b.key).toSet(),
    );
  });
}
