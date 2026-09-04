import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/domain/widgets/home_widget_snapshot.dart';

/// Kotlin tarafinin (FocusWidgetSnapshot.kt) okudugu sozlesmenin testi.
/// Anahtar adlari ve deger turleri degisirse widget sessizce bos cizer -
/// bu test o sessizligi bozar.
void main() {
  final DateTime updatedAt = DateTime.utc(2026, 6, 1, 12);
  const Color accent = Color(0xFFFFB03A);
  const List<int> week = <int>[0, 25, 50, 25, 75, 100, 75];

  HomeWidgetSnapshot snapshotWith({DateTime? targetUtc}) {
    return HomeWidgetSnapshot(
      examName: 'YKS 2026',
      examSubtitle: 'Temel Yeterlilik',
      targetUtc: targetUtc ?? DateTime.utc(2026, 6, 20, 10),
      accentColor: accent,
      streak: 12,
      todayMinutes: 75,
      weeklyMinutes: week,
      sessionActive: false,
      updatedAtUtc: updatedAt,
    );
  }

  group('payload', () {
    test('sozlesmedeki her anahtari yazar', () {
      final Map<String, Object> payload = snapshotWith().toPayload();
      expect(payload.keys.toSet(), HomeWidgetSnapshot.payloadKeys.toSet());
    });

    test('yalnizca platform kanalinin destekledigi turleri yazar', () {
      final Map<String, Object> payload = snapshotWith().toPayload();
      for (final MapEntry<String, Object> entry in payload.entries) {
        expect(
          entry.value,
          anyOf(isA<String>(), isA<int>(), isA<bool>(), isA<double>()),
          reason: '${entry.key} desteklenmeyen bir tur tasiyor',
        );
      }
    });

    test('hedefi kalan gun olarak degil, zaman damgasi olarak yazar', () {
      // Widget bayatlamasin diye gun sayisi Kotlin tarafinda hesaplaniyor;
      // Dart yalnizca hedef ani gonderir.
      final Map<String, Object> payload = snapshotWith().toPayload();
      expect(
        payload[HomeWidgetSnapshot.keyTargetUtcMillis],
        DateTime.utc(2026, 6, 20, 10).millisecondsSinceEpoch,
      );
    });

    test('haftalik dakikalari virgulle birlestirir', () {
      final Map<String, Object> payload = snapshotWith().toPayload();
      expect(payload[HomeWidgetSnapshot.keyWeeklyMinutes], '0,25,50,25,75,100,75');
    });

    test('accent rengini Color.parseColor bicimine cevirir', () {
      final Map<String, Object> payload = snapshotWith().toPayload();
      expect(payload[HomeWidgetSnapshot.keyAccentHex], '#FFFFB03A');
    });
  });

  group('sinav secilmemis durumu', () {
    final HomeWidgetSnapshot empty = HomeWidgetSnapshot.noExam(
      streak: 3,
      todayMinutes: 0,
      weeklyMinutes: week,
      sessionActive: false,
      updatedAtUtc: updatedAt,
    );

    test('hasActiveExam false', () {
      expect(empty.hasActiveExam, isFalse);
      expect(empty.toPayload()[HomeWidgetSnapshot.keyHasActiveExam], isFalse);
    });

    test('sinav alanlari bos dize olur, null degil', () {
      // Kotlin tarafi bu anahtarlari String bekliyor; null yazmak
      // SharedPreferences uzerinde anahtari tamamen silerdi.
      final Map<String, Object> payload = empty.toPayload();
      expect(payload[HomeWidgetSnapshot.keyExamName], '');
      expect(payload[HomeWidgetSnapshot.keyAccentHex], '');
      expect(payload[HomeWidgetSnapshot.keyTargetUtcMillis], 0);
    });

    test('sinav yokken bile seri ve haftalik veri tasinir', () {
      // Seri widgeti sinav secilmemisken de anlamli kalmali.
      final Map<String, Object> payload = empty.toPayload();
      expect(payload[HomeWidgetSnapshot.keyStreak], 3);
      expect(payload[HomeWidgetSnapshot.keyWeeklyMinutes], '0,25,50,25,75,100,75');
    });
  });

  test('haftalik liste yedi elemanli olmak zorunda', () {
    expect(
      () => HomeWidgetSnapshot.noExam(
        streak: 0,
        todayMinutes: 0,
        weeklyMinutes: const <int>[1, 2, 3],
        sessionActive: false,
        updatedAtUtc: updatedAt,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('gecmis tarihli sinav da yazilir, kirpilmaz', () {
    // Sayaci sifirlamak Kotlin tarafinin isi (state = EXPIRED); Dart
    // hedefi oldugu gibi gonderir, yoksa "sinav gecti" durumu ayirt
    // edilemezdi.
    final DateTime past = DateTime.utc(2020, 1, 1);
    final Map<String, Object> payload = snapshotWith(targetUtc: past).toPayload();
    expect(payload[HomeWidgetSnapshot.keyTargetUtcMillis], past.millisecondsSinceEpoch);
    expect(payload[HomeWidgetSnapshot.keyHasActiveExam], isTrue);
  });
}
