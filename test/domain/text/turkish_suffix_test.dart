import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/text/turkish_suffix.dart';

void main() {
  group('rakamla biten sözcükler', () {
    test('son basamağın okunuşuna göre ek seçiliyor', () {
      expect(dativeSuffix('YKS 2027'), "'ye"); // …yedi
      expect(dativeSuffix('KPSS 2026'), "'ya"); // …altı
      expect(dativeSuffix('1'), "'e"); // bir
      expect(dativeSuffix('3'), "'e"); // üç
      expect(dativeSuffix('9'), "'a"); // dokuz
      expect(dativeSuffix('12'), "'ye"); // iki
    });

    test('sıfırla biten sayılarda okunan basamak öne çıkıyor', () {
      expect(dativeSuffix('10'), "'a"); // on
      expect(dativeSuffix('20'), "'ye"); // yirmi
      expect(dativeSuffix('70'), "'e"); // yetmiş
      expect(dativeSuffix('100'), "'e"); // yüz
      expect(dativeSuffix('2000'), "'e"); // bin
      expect(dativeSuffix('2020'), "'ye"); // …yirmi
      expect(dativeSuffix('1200'), "'e"); // …yüz
      expect(dativeSuffix('0'), "'a"); // sıfır
    });
  });

  group('harfle biten sözcükler', () {
    test('son ünlünün kalın/ince uyumu', () {
      expect(dativeSuffix('Deneme'), "'ye"); // ince + ünlüyle biter
      expect(dativeSuffix('Matematik'), "'e");
      expect(dativeSuffix('Sınav'), "'a"); // kalın
      expect(dativeSuffix('Anka'), "'ya"); // kalın + ünlüyle biter
      expect(dativeSuffix('Bütünleme'), "'ye");
    });

    test('ünlüsüz kısaltmalar ince ek alıyor', () {
      expect(dativeSuffix('KPSS'), "'e");
      expect(dativeSuffix('DGS'), "'e");
    });

    test('büyük I ve İ Türkçe kurallarıyla okunuyor', () {
      // `TIP` → son ünlü `ı` (kalın); Dart'ın `toLowerCase()`i bunu `i`
      // yapıp ince ek verirdi.
      expect(dativeSuffix('TIP'), "'a");
      expect(dativeSuffix('İLK'), "'e");
    });
  });

  test('boş metin ince eke düşüyor', () {
    expect(dativeSuffix(''), "'e");
    expect(dativeSuffix('   '), "'e");
  });
}
