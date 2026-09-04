import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SPEC.md §10 DoD: "Prototipteki demo sayılarının **hiçbiri** kodda yok
/// (132, 42, %86, 6, 3/7, 11)".
///
/// Prototipin altı demo değeri de bir **örneğin** sayısı: 132 gün kaldı,
/// 42 saat toplam odak, %86 tamamlanma, 6 günlük seri, 3/7 rozet, 11 günlük en
/// uzun seri. Uygulamada bunların hepsi kullanıcının kendi verisinden türüyor;
/// tasarımdan kopyalanmış bir tanesi bile ekrana kaçarsa kullanıcı kendisine
/// ait olmayan bir sayı görür. Bu, tek bir ekran testinin yakalayamayacağı bir
/// sınıf: hangi ekrana sızdığını önceden bilmediğimiz için kaynağın tamamı
/// taranıyor — ROADMAP madde 7'nin ("hard-coded Türkçe metin yok") ve madde
/// 8'in (`runtime_blur_scan_test.dart`) aynı yaklaşımı.
///
/// Tarama iki yüzeye bakıyor: Faz 13'ten beri kullanıcıya görünen her metnin
/// tek kaynağı ARB, Dart tarafında yalnızca geliştirici dizeleri kalıyor.
const List<String> _demoNumbers = <String>['132', '42', '86', '6', '11'];

/// Rozet sayacı prototipte `3/7` biçiminde. Rakam koşusu olarak ('3' ve '7')
/// ikisi de masum, o yüzden ayrıca birebir dizeyle aranıyor.
const String _demoBadgeCounter = '3/7';

/// Sayılar **rakam koşusu** olarak karşılaştırılıyor, alt dize olarak değil:
/// `1080 × 1920 PNG` içindeki `1080`in "8"i ya da AdMob test kimliğindeki
/// basamaklar demo sayı değil. Bu ayrım olmadan tarama tek haneli `6`yı
/// kullanılabilir biçimde kontrol edemezdi.
Set<String> _digitRuns(String value) {
  return RegExp(r'\d+').allMatches(value).map((RegExpMatch m) => m.group(0)!).toSet();
}

/// Satır içi `//` yorumları atılıyor: bir yasağı anlatan yorum (bu dosyanın
/// kendisi gibi) yasağın ihlali değil. Depoda `/* */` kullanılmıyor.
final RegExp _lineComment = RegExp('//.*\$');

/// Tek satırlık Dart dize sabitleri. Çok satırlı (`'''`) dize depoda yok.
final RegExp _stringLiteral = RegExp(r"'([^'\\\n]|\\.)*'" r'|"([^"\\\n]|\\.)*"');

List<File> _libDartFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      // Üretilen kod taranmıyor: `l10n/gen/` ARB'nin kendisinden türüyor
      // (aşağıdaki ARB testi zaten kaynağı tutuyor), `*.g.dart`/`*.freezed.dart`
      // ise drift/freezed çıktısı — üçü de elle yazılmıyor.
      .where((File file) =>
          !file.path.contains('l10n${Platform.pathSeparator}gen') &&
          !file.path.endsWith('.g.dart') &&
          !file.path.endsWith('.freezed.dart'))
      .toList();
}

void main() {
  test('ARB değerlerinde prototipin demo sayıları yok (SPEC §10 DoD)', () {
    final File arbFile = File('lib/l10n/app_tr.arb');
    expect(arbFile.existsSync(), isTrue, reason: 'tarama ARB dosyasını bulamadı');

    final Map<String, dynamic> arb =
        jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
    // Yanlış çalışma dizininde boş bir haritayla "geçmesin".
    expect(arb.length, greaterThan(100), reason: 'ARB beklenenden küçük okundu');

    final List<String> offenders = <String>[];
    arb.forEach((String key, dynamic value) {
      // `@key` girdileri placeholder tanımı; kullanıcıya çıkan metin değil.
      if (key.startsWith('@') || value is! String) return;

      final Set<String> runs = _digitRuns(value);
      for (final String demo in _demoNumbers) {
        if (runs.contains(demo)) {
          offenders.add('$key → "$value" içinde demo sayı $demo');
        }
      }
      if (value.contains(_demoBadgeCounter)) {
        offenders.add('$key → "$value" içinde demo rozet sayacı $_demoBadgeCounter');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: "kullanıcıya görünen sayılar ARB placeholder'ından gelmeli, "
          'prototipin demo değeri olarak yazılmamalı',
    );
  });

  test('lib/ dize sabitlerinde prototipin demo sayıları yok (SPEC §10 DoD)', () {
    final List<File> dartFiles = _libDartFiles();
    expect(dartFiles.length, greaterThan(20), reason: 'tarama lib/ ağacını bulamadı');

    final List<String> offenders = <String>[];
    for (final File file in dartFiles) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String code = lines[i].replaceAll(_lineComment, '');
        for (final RegExpMatch match in _stringLiteral.allMatches(code)) {
          final String literal = match.group(0)!;
          final Set<String> runs = _digitRuns(literal);
          for (final String demo in _demoNumbers) {
            if (runs.contains(demo)) {
              offenders.add('${file.path}:${i + 1} → $literal içinde demo sayı $demo');
            }
          }
          if (literal.contains(_demoBadgeCounter)) {
            offenders.add('${file.path}:${i + 1} → $literal içinde $_demoBadgeCounter');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'demo sayılar kullanıcı verisinden türemeli, dizeye gömülmemeli',
    );
  });

  test('tarama gerçekten yakalıyor (karşı kontrol)', () {
    // Taramanın kendisi bozulursa yukarıdaki iki test sessizce "geçer".
    // Prototipin demo satırları burada birebir sınanıyor.
    expect(_digitRuns('42 SAAT').contains('42'), isTrue);
    expect(_digitRuns('%86').contains('86'), isTrue);
    expect(_digitRuns('11 GÜN').contains('11'), isTrue);
    expect(_digitRuns('132').contains('132'), isTrue);
    expect(_digitRuns('6 gün seri').contains('6'), isTrue);
    expect('3/7'.contains(_demoBadgeCounter), isTrue);

    // Ve masum sayıları yakalamıyor: rakam koşusu, alt dize değil.
    expect(_digitRuns('1080 × 1920 PNG').contains('108'), isFalse);
    expect(_digitRuns('Kümülatif 100 saat odak').contains('6'), isFalse);
    expect(_digitRuns('Gün 04:00\'te başlar').contains('11'), isFalse);
  });
}
