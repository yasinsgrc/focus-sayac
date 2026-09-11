import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/streak/streak_calculator.dart';

/// Testlerin sabit "şimdi"si: 10 Mart 2026, 15:00 TSİ → uygulama günü
/// 2026-03-10 (04:00 sınırının epey içinde, gün kaymaz).
final DateTime _nowUtc = DateTime.utc(2026, 3, 10, 12);

/// [daysAgo] gün önceki uygulama gününe düşen bir seans başlangıcı.
/// `0` = bugün, `1` = dün.
DateTime _dayAgo(int daysAgo) => _nowUtc.subtract(Duration(days: daysAgo));

/// Verilen gün ofsetlerinde birer tamamlanmış odak seansı olan bir geçmiş.
List<DateTime> _days(List<int> daysAgo) =>
    daysAgo.map(_dayAgo).toList(growable: false);

StreakStatus _status(List<int> daysAgo) => calculateStreakStatus(
      completedFocusStartedAtUtc: _days(daysAgo),
      nowUtc: _nowUtc,
    );

void main() {
  group('seri yoksa', () {
    test('hiç seans yoksa sıfır', () {
      final StreakStatus status = _status(<int>[]);

      expect(status.days, 0);
      expect(status.state, StreakState.none);
    });

    test('son seans üç gün öncesindeyse koruma da kurtaramaz', () {
      // Telafi hakkı yalnızca **dünü** kapatır; iki gün üst üste boşsa seri
      // gerçekten kırılmıştır.
      final StreakStatus status = _status(<int>[3, 4, 5]);

      expect(status.days, 0);
      expect(status.state, StreakState.none);
    });
  });

  group('canlı seri', () {
    test('bugün seans varsa seri bugünden sayılır', () {
      expect(_status(<int>[0, 1, 2]).days, 3);
      expect(_status(<int>[0, 1, 2]).state, StreakState.active);
    });

    test('bugün henüz boşsa dünkü seri canlı sayılır, hak harcanmaz', () {
      // Gün bitmedi: bugün bir "boşluk" değil, bu yüzden telafi hakkı hâlâ
      // cepte — dört gün önceki boşluğu kapatabiliyor.
      final StreakStatus status = _status(<int>[1, 2, 3, 5, 6]);

      expect(status.days, 5);
      expect(status.state, StreakState.active);
    });

    test('aynı gün içindeki birden çok seans seriyi bir kez sayar', () {
      final StreakStatus status = calculateStreakStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _nowUtc.subtract(const Duration(hours: 2)),
          _nowUtc.subtract(const Duration(hours: 5)),
        ],
        nowUtc: _nowUtc,
      );

      expect(status.days, 1);
    });
  });

  group('haftalık telafi hakkı — dün kaçırıldığında', () {
    test('seri kırılmıyor, korumaya alınıyor', () {
      // Dün boş: eski davranışta seri 0'a düşerdi.
      final StreakStatus status = _status(<int>[2, 3, 4, 5]);

      expect(status.days, 4);
      expect(status.state, StreakState.protected);
      expect(status.isProtected, isTrue);
    });

    test('koruma günü seriye eklenmez — kaçırılan gün griye düşer', () {
      // 4 gerçek gün + 1 telafi günü = yine 4; telafi günü sayılsaydı
      // kullanıcıya çalışmadığı bir gün satılmış olurdu.
      expect(_status(<int>[2, 3, 4, 5]).days, 4);
    });

    test('bugünkü tek pomodoro seriyi geri kazandırıyor', () {
      final StreakStatus status = _status(<int>[0, 2, 3, 4, 5]);

      expect(status.days, 5);
      expect(status.state, StreakState.active);
    });

    test('iki gün üst üste boşsa seri oradan kesiliyor', () {
      final StreakStatus status = _status(<int>[2, 4, 5, 6]);

      // Dünü telafi kapatıyor ama üç gün önceki boşluk aynı hafta içinde
      // ikinci hak demek — seri orada duruyor.
      expect(status.days, 1);
      expect(status.state, StreakState.protected);
    });
  });

  group('haftalık telafi hakkı — geçmişteki boşluklar', () {
    test('tek boşluk seriyi bölmüyor', () {
      final StreakStatus status = _status(<int>[0, 1, 2, 4, 5, 6, 7, 8, 9]);

      expect(status.days, 9);
      expect(status.state, StreakState.active);
    });

    test('aynı hafta içindeki ikinci boşluk seriyi kesiyor', () {
      final StreakStatus status = _status(<int>[0, 1, 3, 4, 6, 7]);

      // -2'deki boşluk telafiyle kapanıyor, -5'teki boşluk üç gün sonrasına
      // denk geldiği için hak henüz yenilenmemiş.
      expect(status.days, 4);
    });

    test('hak yedi günde bir yenileniyor', () {
      final StreakStatus status =
          _status(<int>[0, 1, 3, 4, 5, 6, 7, 8, 10, 11]);

      // Boşluklar -2 ve -9: aralarında tam yedi gün var, ikisi de kapanıyor.
      expect(status.days, 10);
    });

    test('korumadaki gün de haftalık hakkı harcıyor', () {
      final StreakStatus status = _status(<int>[2, 3, 5, 6]);

      // Dün (-1) telafiyle kapandı; -4'teki boşluk için hak kalmadı.
      expect(status.days, 2);
      expect(status.state, StreakState.protected);
    });

    test('telafi, kopuk geçmişe köprü kurmuyor', () {
      // Tek başına duran eski bir gün seriye eklenemez.
      expect(_status(<int>[0, 8]).days, 1);
    });
  });

  group('calculateStreak', () {
    test('durum nesnesinin gün sayısını döndürür', () {
      expect(
        calculateStreak(
          completedFocusStartedAtUtc: _days(<int>[2, 3, 4, 5]),
          nowUtc: _nowUtc,
        ),
        4,
      );
    });
  });

  group('calculateLongestStreak', () {
    test('telafi hakkı rozet kuralına karışmıyor', () {
      // SPEC.md §5.4 "7 gün üst üste" harfiyen geçerli: rozet, koruma
      // günleriyle şişirilemez.
      expect(
        calculateLongestStreak(
          completedFocusStartedAtUtc: _days(<int>[0, 1, 3, 4]),
        ),
        2,
      );
    });
  });
}
