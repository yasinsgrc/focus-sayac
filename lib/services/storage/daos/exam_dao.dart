import 'package:drift/drift.dart';

import '../app_database.dart';
import '../storage_enums.dart';
import '../tables.dart';

part 'exam_dao.g.dart';

/// `Exam` tablosu için sorgu/komutlar. SPEC.md §4: kullanıcı sınavı her
/// zaman preset'lerden önce sıralanır ("kullanıcı sınavı her zaman
/// preset'lerden önceliklidir").
@DriftAccessor(tables: <Type>[Exams])
class ExamDao extends DatabaseAccessor<AppDatabase> with _$ExamDaoMixin {
  ExamDao(super.db);

  Stream<List<Exam>> watchAllExams() {
    return (select(exams)
          ..orderBy(<OrderClauseGenerator<Exams>>[
            (Exams e) => OrderingTerm(expression: e.isPreset),
            (Exams e) => OrderingTerm(expression: e.dateUtc),
          ]))
        .watch();
  }

  Future<Exam?> getActiveExam() {
    return (select(exams)..where((Exams e) => e.isActive.equals(true))).getSingleOrNull();
  }

  Stream<Exam?> watchActiveExam() {
    return (select(exams)..where((Exams e) => e.isActive.equals(true))).watchSingleOrNull();
  }

  Future<Exam?> getExamById(int id) {
    return (select(exams)..where((Exams e) => e.id.equals(id))).getSingleOrNull();
  }

  Future<List<Exam>> getPresetExams() {
    return (select(exams)..where((Exams e) => e.isPreset.equals(true))).get();
  }

  Future<Exam?> getPresetExamByKey(String key) {
    return (select(exams)
          ..where((Exams e) => e.isPreset.equals(true) & e.presetKey.equals(key)))
        .getSingleOrNull();
  }

  /// Şema v1'den gelen preset satırlarına anahtarlarını yazar (`AppDatabase`
  /// migration'ı seed dosyasından okuduğu ad → anahtar eşlemesini geçirir).
  /// Anahtarı zaten dolu satırlara dokunulmaz.
  Future<void> backfillPresetKeys(Map<String, String> keysByName) async {
    for (final MapEntry<String, String> entry in keysByName.entries) {
      await (update(exams)
            ..where((Exams e) =>
                e.isPreset.equals(true) & e.name.equals(entry.key) & e.presetKey.isNull()))
          .write(ExamsCompanion(presetKey: Value<String?>(entry.value)));
    }
  }

  Future<int> insertUserExam({
    required String name,
    required String? subtitle,
    required DateTime dateUtc,
    required String timeOfDay,
    required ExamAccentRole accentRole,
  }) {
    return into(exams).insert(
      ExamsCompanion.insert(
        name: name,
        subtitle: Value<String?>(subtitle),
        dateUtc: dateUtc,
        timeOfDay: timeOfDay,
        accentRole: accentRole,
        isPreset: const Value<bool>(false),
        source: ExamSourceType.user,
        verifiedAt: const Value<DateTime?>(null),
      ),
    );
  }

  /// Uzak override'ın bir preset satırını güncellemesi ya da yeni bir preset
  /// eklemesi için tek giriş noktası — `ExamSourceService` bunu çağırır.
  /// Eşleme `key` üzerinden yapılır: uzak JSON sınavın adını değiştirdiğinde
  /// ikinci bir satır açılmaz, mevcut satırın adı güncellenir.
  Future<void> upsertPresetExam({
    required String key,
    required String name,
    required String? subtitle,
    required DateTime dateUtc,
    required String timeOfDay,
    required ExamAccentRole accentRole,
    required DateTime verifiedAt,
  }) async {
    final Exam? existing = await getPresetExamByKey(key);
    if (existing == null) {
      await into(exams).insert(
        ExamsCompanion.insert(
          name: name,
          subtitle: Value<String?>(subtitle),
          dateUtc: dateUtc,
          timeOfDay: timeOfDay,
          accentRole: accentRole,
          isPreset: const Value<bool>(true),
          presetKey: Value<String?>(key),
          source: ExamSourceType.remote,
          verifiedAt: Value<DateTime?>(verifiedAt),
        ),
      );
      return;
    }
    await (update(exams)..where((Exams e) => e.id.equals(existing.id))).write(
      ExamsCompanion(
        name: Value<String>(name),
        subtitle: Value<String?>(subtitle),
        dateUtc: Value<DateTime>(dateUtc),
        timeOfDay: Value<String>(timeOfDay),
        accentRole: Value<ExamAccentRole>(accentRole),
        source: const Value<ExamSourceType>(ExamSourceType.remote),
        verifiedAt: Value<DateTime?>(verifiedAt),
      ),
    );
  }

  /// Seçili sınavı değiştirir: hedef satır `isActive = true`, diğer tüm
  /// satırlar `isActive = false` olur. `AppSettings.activeExamId` ile
  /// senkron tutulması `AppSettingsDao.setActiveExam`'in sorumluluğu.
  Future<void> setActiveExam(int examId) async {
    await transaction(() async {
      await update(exams).write(const ExamsCompanion(isActive: Value<bool>(false)));
      await (update(exams)..where((Exams e) => e.id.equals(examId)))
          .write(const ExamsCompanion(isActive: Value<bool>(true)));
    });
  }

  /// Hiçbir sınavı aktif bırakmaz — sınav tarihi geçtiğinde (Ekran 08)
  /// kullanıcı yeni hedefini seçene kadar geri sayımın "hedef seçilmedi"
  /// durumuna düşmesi için. Satırlar silinmez, yalnızca bayrak düşer.
  Future<void> clearActiveExam() async {
    await update(exams).write(const ExamsCompanion(isActive: Value<bool>(false)));
  }
}
