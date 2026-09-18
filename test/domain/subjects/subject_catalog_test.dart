import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/subjects/subject_catalog.dart';

import '../../support/localized_test_app.dart';

/// ROADMAP madde 30 — ders katalogu. Anahtarlar DB'de metin olarak saklandığı
/// için bu testin asıl işi onları çivilemek: bir kez yayınlanan anahtar
/// değiştiğinde kullanıcının geçmişi başka bir derse kayar.
void main() {
  test('katalog anahtarları sabit ve sınavlar arasında paylaşılıyor', () {
    // YKS'nin ve LGS'nin "Matematik"i aynı anahtar: sınav değiştiren
    // kullanıcının geçmişi tek derste toplanıyor.
    expect(kSubjectCatalogs['yks']!.first, 'math');
    expect(kSubjectCatalogs['lgs']!.first, 'math');
    expect(kSubjectCatalogs['kpss_lisans']!.first, 'math');
    expect(kSubjectCatalogs['ales'], <String>['quantitative', 'verbal']);

    // Sınav anahtarları seed dosyasındaki `key` alanlarıyla birebir.
    expect(kSubjectCatalogs.keys, containsAll(<String>['yks', 'lgs', 'kpss_lisans', 'ales']));
  });

  test('her katalogda anahtarlar benzersiz', () {
    for (final MapEntry<String, List<String>> entry in kSubjectCatalogs.entries) {
      expect(entry.value.toSet().length, entry.value.length, reason: entry.key);
    }
    expect(kGeneralSubjectCatalog.toSet().length, kGeneralSubjectCatalog.length);
  });

  test('her anahtarın ARB karşılığı var', () {
    final Set<String> all = <String>{
      for (final List<String> catalog in kSubjectCatalogs.values) ...catalog,
      ...kGeneralSubjectCatalog,
    };
    for (final String key in all) {
      final String name = subjectName(testL10n, key);
      expect(name, isNotEmpty, reason: key);
      // ARB'de karşılığı olmayan anahtar sessizce "Belirtilmemiş"e düşerdi;
      // katalogdaki bir ders için bu bir hata.
      expect(name, isNot('Belirtilmemiş'), reason: key);
    }
  });

  test('tanınmayan anahtar ve null belirtilmemiş metnine düşüyor', () {
    // Eski bir sürümden kalmış anahtar tüm istatistik ekranını patlatmamalı.
    expect(subjectName(testL10n, 'eski_ders'), 'Belirtilmemiş');
    expect(subjectName(testL10n, null), 'Belirtilmemiş');
  });

  test('preset olmayan sınav genel katalogu alıyor', () {
    expect(subjectsForExam('yks').length, 11);
    // Kullanıcının kendi sınavı (presetKey null) ve ileride gelebilecek
    // tanınmayan bir preset: alt sayfa boş açılmıyor.
    expect(subjectsForExam(null), kGeneralSubjectCatalog);
    expect(subjectsForExam('bilinmeyen'), kGeneralSubjectCatalog);
  });

  test('resolveActiveSubject seçimi katalogda doğruluyor', () {
    final List<String> yks = subjectsForExam('yks');
    final List<String> lgs = subjectsForExam('lgs');

    expect(resolveActiveSubject(SubjectKeys.chemistry, yks), SubjectKeys.chemistry);
    // LGS katalogunda kimya yok: seans yanlış bir derse değil, dersiz yazılıyor.
    expect(resolveActiveSubject(SubjectKeys.chemistry, lgs), isNull);
    expect(resolveActiveSubject(null, yks), isNull);
    // Ayar sıfırlanmadığı için sınav geri değişince ders geri geliyor.
    expect(resolveActiveSubject(SubjectKeys.chemistry, yks), SubjectKeys.chemistry);
  });
}
