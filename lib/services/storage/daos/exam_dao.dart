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

  Future<Exam?> getPresetExamByName(String name) {
    return (select(exams)
          ..where((Exams e) => e.isPreset.equals(true) & e.name.equals(name)))
        .getSingleOrNull();
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
  Future<void> upsertPresetExam({
    required String name,
    required String? subtitle,
    required DateTime dateUtc,
    required String timeOfDay,
    required ExamAccentRole accentRole,
    required DateTime verifiedAt,
  }) async {
    final Exam? existing = await getPresetExamByName(name);
    if (existing == null) {
      await into(exams).insert(
        ExamsCompanion.insert(
          name: name,
          subtitle: Value<String?>(subtitle),
          dateUtc: dateUtc,
          timeOfDay: timeOfDay,
          accentRole: accentRole,
          isPreset: const Value<bool>(true),
          source: ExamSourceType.remote,
          verifiedAt: Value<DateTime?>(verifiedAt),
        ),
      );
      return;
    }
    await (update(exams)..where((Exams e) => e.id.equals(existing.id))).write(
      ExamsCompanion(
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
}
