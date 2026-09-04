import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/time/duration_formatter.dart';

/// `(saat, dakika)` çiftini tek satırda okunur biçimde karşılaştırmak için.
Matcher _parts({required int hours, required int minutes}) {
  return isA<FocusDurationParts>()
      .having((FocusDurationParts p) => p.hours, 'hours', hours)
      .having((FocusDurationParts p) => p.minutes, 'minutes', minutes);
}

void main() {
  group('sıfır ve altı', () {
    test('0 saniye', () {
      expect(formatFocusDuration(0), _parts(hours: 0, minutes: 0));
    });

    test('59 saniye hâlâ 0 dk — yukarı yuvarlanmıyor', () {
      // Yuvarlama olsaydı hiç odaklanmamış bir kullanıcı "1 DK" görürdü.
      expect(formatFocusDuration(59), _parts(hours: 0, minutes: 0));
    });

    test('negatif süre 0\'a kırpılıyor', () {
      // Cihaz saati geriye alındığında negatif fark hesaplanabiliyor
      // (SPEC.md §5.1); ekranda "-1 SA" çıkmamalı.
      expect(formatFocusDuration(-1), _parts(hours: 0, minutes: 0));
      expect(formatFocusDuration(-3600), _parts(hours: 0, minutes: 0));
    });
  });

  group('dakika', () {
    test('60 saniye tam 1 dk', () {
      expect(formatFocusDuration(60), _parts(hours: 0, minutes: 1));
    });

    test('119 saniye hâlâ 1 dk', () {
      expect(formatFocusDuration(119), _parts(hours: 0, minutes: 1));
    });

    test('3599 saniye 0 sa 59 dk — saate terfi etmiyor', () {
      expect(formatFocusDuration(3599), _parts(hours: 0, minutes: 59));
    });
  });

  group('saat', () {
    test('3600 saniye 1 sa 0 dk', () {
      expect(formatFocusDuration(3600), _parts(hours: 1, minutes: 0));
    });

    test('1 sa 15 dk', () {
      expect(formatFocusDuration(3600 + 15 * 60), _parts(hours: 1, minutes: 15));
    });

    test('artan saniyeler dakikaya karışmıyor', () {
      expect(formatFocusDuration(3600 + 15 * 60 + 59), _parts(hours: 1, minutes: 15));
    });
  });

  group('99+ saat', () {
    test('99 sa 59 dk', () {
      expect(formatFocusDuration(99 * 3600 + 59 * 60), _parts(hours: 99, minutes: 59));
    });

    test('100 saat üç haneye taşıyor — üst sınır yok', () {
      expect(formatFocusDuration(100 * 3600), _parts(hours: 100, minutes: 0));
    });

    test('999 sa 59 dk', () {
      expect(formatFocusDuration(999 * 3600 + 59 * 60), _parts(hours: 999, minutes: 59));
    });
  });
}
