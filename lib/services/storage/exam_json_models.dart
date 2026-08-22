import 'storage_enums.dart';

/// `assets/data/exam_dates.json` ve uzak override JSON'unun ortak satır
/// biçimi. SPEC.md §4: "Her kayıtta `source` + `verifiedAt`."
class ExamJsonEntry {
  const ExamJsonEntry({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.dateUtc,
    required this.timeOfDay,
    required this.accentRole,
    required this.verifiedAt,
  });

  factory ExamJsonEntry.fromJson(Map<String, Object?> json) {
    return ExamJsonEntry(
      key: json['key']! as String,
      name: json['name']! as String,
      subtitle: json['subtitle'] as String?,
      dateUtc: DateTime.parse(json['dateUtc']! as String).toUtc(),
      timeOfDay: json['timeOfDay']! as String,
      accentRole: ExamAccentRole.values.byName(json['accentRole']! as String),
      verifiedAt: DateTime.parse(json['verifiedAt']! as String).toUtc(),
    );
  }

  /// Uzak override ile yerel seed'i eşlemek için kararlı anahtar (ör. `yks`).
  /// Kullanıcı sınavlarında karşılığı yok — yalnızca preset'ler bu anahtarla eşleşir.
  final String key;
  final String name;
  final String? subtitle;
  final DateTime dateUtc;
  final String timeOfDay;
  final ExamAccentRole accentRole;
  final DateTime verifiedAt;
}

/// `{"_note": "...", "exams": [...]}` biçimindeki gövdeyi çözer. `_note`
/// yalnızca insan-okur belge amaçlı, modele taşınmaz.
List<ExamJsonEntry> parseExamJsonPayload(Map<String, Object?> payload) {
  final List<Object?> rawExams = payload['exams']! as List<Object?>;
  return rawExams
      .map((Object? e) => ExamJsonEntry.fromJson(e! as Map<String, Object?>))
      .toList(growable: false);
}
