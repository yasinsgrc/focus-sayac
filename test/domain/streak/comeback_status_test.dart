import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/streak/comeback_status.dart';

/// 04:00 TSİ = 01:00 UTC. Testler gün sınırını bu iki komşu damgayla yokluyor:
/// 00:30 UTC (03:30 TSİ) bir önceki uygulama gününe, 01:30 UTC (04:30 TSİ)
/// yenisine aittir.
DateTime _utc(int year, int month, int day, [int hour = 12, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

void main() {
  group('calculateComebackStatus', () {
    test('hiç tamamlanmış seans yoksa ne şerit ne bildirim', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: const <DateTime>[],
        nowUtc: _utc(2026, 9, 17),
      );

      expect(status, ComebackStatus.none);
    });

    test('üç seanstan az yapan kullanıcı kapsam dışı', () {
      // İki seans, sonuncusu on gün önce: eşik dolmuş ama kullanıcı henüz
      // uygulamayı deneme aşamasında.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 6),
          _utc(2026, 9, 7),
        ],
        nowUtc: _utc(2026, 9, 17),
      );

      expect(status, ComebackStatus.none);
    });

    test('bugün çalışan kullanıcıda şerit yok, bildirim üç gün ileriye kurulu', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 15),
          _utc(2026, 9, 16),
          _utc(2026, 9, 17, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 0);
      expect(status.welcomeDue, isFalse);
      // 17 + 3 = 20 Eylül, 21:00 TSİ = 18:00 UTC.
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 20, 18));
    });

    test('iki gün yoklukta şerit hâlâ yok', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 13),
          _utc(2026, 9, 14),
          _utc(2026, 9, 15, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 2);
      expect(status.welcomeDue, isFalse);
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 18, 18));
    });

    test('üç gün yoklukta şerit açılıyor, bildirim bugünün 21:00 TSİ anına kurulu', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
          _utc(2026, 9, 14, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 3);
      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });

    test('pencere geçtiyse bildirim kurulmuyor ama şerit duruyor', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
          _utc(2026, 9, 14, 10),
        ],
        // Aynı gün, 19:00 UTC: hedef an (18:00 UTC) geride kaldı.
        nowUtc: _utc(2026, 9, 17, 19),
      );

      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, isNull);
    });

    test('uzun yoklukta bildirim birikmiyor — pencere tek gün', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 3),
          _utc(2026, 9, 4),
          _utc(2026, 9, 5, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 12);
      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, isNull);
    });

    test('gün sınırı 04:00: 03:30 TSİ bir önceki güne yazılıyor', () {
      // Son seans 14 Eylül 00:30 UTC = 03:30 TSİ → uygulama günü 13 Eylül.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 11),
          _utc(2026, 9, 12),
          _utc(2026, 9, 14, 0, 30),
        ],
        // 17 Eylül 01:30 UTC = 04:30 TSİ → uygulama günü 17 Eylül.
        nowUtc: _utc(2026, 9, 17, 1, 30),
      );

      expect(status.absentDays, 4);
      expect(status.welcomeDue, isTrue);
      // 13 + 3 = 16 Eylül 18:00 UTC, çoktan geçti.
      expect(status.reminderAtUtc, isNull);
    });

    test('gün sınırı 04:00: bir saat sonrası aynı günü değiştiriyor', () {
      // Son seans 14 Eylül 01:30 UTC = 04:30 TSİ → uygulama günü 14 Eylül.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 11),
          _utc(2026, 9, 12),
          _utc(2026, 9, 14, 1, 30),
        ],
        nowUtc: _utc(2026, 9, 17, 1, 30),
      );

      expect(status.absentDays, 3);
      expect(status.welcomeDue, isTrue);
      // 14 + 3 = 17 Eylül 18:00 UTC, henüz gelmedi.
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });

    test('sonuncu seans listenin sırasından bağımsız bulunuyor', () {
      final ComebackStatus shuffled = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 14, 10),
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(shuffled.absentDays, 3);
      expect(shuffled.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });
  });
}
