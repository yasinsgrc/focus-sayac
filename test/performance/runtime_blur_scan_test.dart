import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SPEC.md §6 kural 1-3, kaynak taramasıyla. Bu üç kural "şu kod hiç
/// yazılmasın" biçiminde: aurora zeminleri çalışma zamanında blur'lanmasın,
/// `backdrop-filter` kartları `BackdropFilter`la yapılmasın. Bir widget testi
/// yalnızca o an çizilen ağacı görebildiği için kuralı ekran ekran değil
/// kaynağın tamamında doğrulamak gerekiyor — ROADMAP madde 7'nin "kodda
/// hard-coded Türkçe metin yok" grep taramasıyla aynı yaklaşım.
///
/// Yasak olan runtime blur; `BoxShadow.blurRadius` değil (o tek geçişte çizilen
/// bir gölge, her karede yeniden rasterize edilen bir filtre katmanı değil).
const List<String> _forbiddenTokens = <String>[
  'BackdropFilter',
  'ImageFiltered',
  'ImageFilter.blur',
];

/// Satır içi `//` ve `///` yorumları atılıyor: SPEC kararlarının gerekçeleri bu
/// adları zaten anıyor (ör. `onboarding_screen.dart`ın aurora notu) ve bir
/// yasağı anlatan yorum, yasağın ihlali değil. Depoda `/* */` kullanılmıyor.
final RegExp _lineComment = RegExp('//.*\$');

void main() {
  test('lib/ içinde çalışma zamanı blur kullanılmıyor (SPEC §6 kural 1-3)', () {
    final List<File> dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList();

    // Yanlış çalışma dizininde boş bir listeyle "geçmesin".
    expect(dartFiles.length, greaterThan(20), reason: 'tarama lib/ ağacını bulamadı');

    final List<String> offenders = <String>[];
    for (final File file in dartFiles) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String code = lines[i].replaceAll(_lineComment, '');
        for (final String token in _forbiddenTokens) {
          if (code.contains(token)) {
            offenders.add('${file.path}:${i + 1} → $token');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: "SPEC §6: runtime blur yerine gradyan/önceden blur'lanmış zemin");
  });
}
