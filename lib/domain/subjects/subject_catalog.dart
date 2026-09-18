import '../../l10n/gen/app_localizations.dart';

/// `PomodoroSession.subjectKey` / `AppSettings.activeSubjectKey` değerleri —
/// bir kez yayınlandıktan sonra değiştirilmemeli (DB'de metin olarak
/// saklanıyor, `BadgeKeys` ve `SessionType` ile aynı kısıt).
///
/// Anahtarlar sınavlar arasında **paylaşılıyor**: YKS'nin ve LGS'nin
/// "Matematik"i aynı [math]. Sınav değiştiren kullanıcının geçmişi tek bir
/// derste toplanıyor ve ARB tek bir ad taşıyor.
abstract final class SubjectKeys {
  static const String math = 'math';
  static const String geometry = 'geometry';
  static const String turkish = 'turkish';
  static const String physics = 'physics';
  static const String chemistry = 'chemistry';
  static const String biology = 'biology';
  static const String history = 'history';
  static const String geography = 'geography';
  static const String philosophy = 'philosophy';
  static const String religion = 'religion';
  static const String foreignLanguage = 'foreign_language';
  static const String science = 'science';
  static const String socialScience = 'social_science';
  static const String revolutionHistory = 'revolution_history';
  static const String citizenship = 'citizenship';
  static const String currentAffairs = 'current_affairs';
  static const String quantitative = 'quantitative';
  static const String verbal = 'verbal';
}

/// Preset'i olmayan sınavların (kullanıcının kendi eklediği sınav) ve aktif
/// sınav yokken hapın kullandığı liste.
///
/// Kullanıcı kendi sınavını ekleyebiliyor (`add_exam_screen.dart`) ve o sınavın
/// ders listesi bilinemez; boş liste göstermek hapı ölü bir düğmeye çevirirdi.
const List<String> kGeneralSubjectCatalog = <String>[
  SubjectKeys.math,
  SubjectKeys.turkish,
  SubjectKeys.science,
  SubjectKeys.socialScience,
  SubjectKeys.foreignLanguage,
];

/// `Exam.presetKey` → ders anahtarları. Sıra **sabit**: dağılım kartı kendi
/// sırasını süreden türetiyor ama alt sayfa her açılışta aynı sırayı
/// göstermek zorunda.
///
/// Anahtarlar `assets/data/exam_dates.json`'daki `key` alanlarıyla birebir
/// (`yks`, `lgs`, `kpss_lisans`, `ales`) — uzak override sınavın adını
/// değiştirse bile katalog aynı satıra bağlı kalıyor.
const Map<String, List<String>> kSubjectCatalogs = <String, List<String>>{
  'yks': <String>[
    SubjectKeys.math,
    SubjectKeys.geometry,
    SubjectKeys.turkish,
    SubjectKeys.physics,
    SubjectKeys.chemistry,
    SubjectKeys.biology,
    SubjectKeys.history,
    SubjectKeys.geography,
    SubjectKeys.philosophy,
    SubjectKeys.religion,
    SubjectKeys.foreignLanguage,
  ],
  'lgs': <String>[
    SubjectKeys.math,
    SubjectKeys.turkish,
    SubjectKeys.science,
    SubjectKeys.revolutionHistory,
    SubjectKeys.religion,
    SubjectKeys.foreignLanguage,
  ],
  'kpss_lisans': <String>[
    SubjectKeys.math,
    SubjectKeys.turkish,
    SubjectKeys.history,
    SubjectKeys.geography,
    SubjectKeys.citizenship,
    SubjectKeys.currentAffairs,
  ],
  'ales': <String>[
    SubjectKeys.quantitative,
    SubjectKeys.verbal,
  ],
};

/// Aktif sınavın ders listesi. [presetKey] `null` (kullanıcı sınavı) ya da
/// tanınmayan bir anahtarsa genel katalog döner — uzak override ileride yeni
/// bir preset getirirse uygulama boş bir alt sayfa açmıyor.
List<String> subjectsForExam(String? presetKey) =>
    kSubjectCatalogs[presetKey] ?? kGeneralSubjectCatalog;

/// Ayardaki dersi **okuma anında** doğrular: [catalog]da yoksa `null`.
///
/// Sınav değişince ayar sıfırlanmıyor (bkz. `AppSettingsTable.activeSubjectKey`):
/// YKS'de Kimya seçip LGS'ye bakan kullanıcı YKS'ye dönünce dersini geri
/// buluyor. Aradaki LGS seansları ise dersiz yazılıyor, yanlış bir derse değil.
String? resolveActiveSubject(String? key, List<String> catalog) =>
    key != null && catalog.contains(key) ? key : null;

/// Ders adı ARB'den (`BadgeDefinition.name` ile aynı gerekçe: katalog `const`
/// kalsın, metin çalışma zamanında gelsin).
///
/// Tanınmayan anahtar fırlatmıyor, "belirtilmemiş" metnine düşüyor: DB'de eski
/// bir sürümden kalmış bir anahtar tüm istatistik ekranını patlatmamalı. `null`
/// zaten dersi belirtilmemiş seansın kendisi.
String subjectName(AppLocalizations l10n, String? key) => switch (key) {
      SubjectKeys.math => l10n.subjectMath,
      SubjectKeys.geometry => l10n.subjectGeometry,
      SubjectKeys.turkish => l10n.subjectTurkish,
      SubjectKeys.physics => l10n.subjectPhysics,
      SubjectKeys.chemistry => l10n.subjectChemistry,
      SubjectKeys.biology => l10n.subjectBiology,
      SubjectKeys.history => l10n.subjectHistory,
      SubjectKeys.geography => l10n.subjectGeography,
      SubjectKeys.philosophy => l10n.subjectPhilosophy,
      SubjectKeys.religion => l10n.subjectReligion,
      SubjectKeys.foreignLanguage => l10n.subjectForeignLanguage,
      SubjectKeys.science => l10n.subjectScience,
      SubjectKeys.socialScience => l10n.subjectSocialScience,
      SubjectKeys.revolutionHistory => l10n.subjectRevolutionHistory,
      SubjectKeys.citizenship => l10n.subjectCitizenship,
      SubjectKeys.currentAffairs => l10n.subjectCurrentAffairs,
      SubjectKeys.quantitative => l10n.subjectQuantitative,
      SubjectKeys.verbal => l10n.subjectVerbal,
      _ => l10n.subjectUnspecified,
    };
