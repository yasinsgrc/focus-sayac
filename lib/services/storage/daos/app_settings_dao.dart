import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'app_settings_dao.g.dart';

/// `AppSettings` tek satırlık tablosu için sorgu/komutlar. Satır her zaman
/// `id = 0` — `onCreate` migration bunu bir kez yazar (SPEC.md §4).
@DriftAccessor(tables: <Type>[AppSettingsTable])
class AppSettingsDao extends DatabaseAccessor<AppDatabase> with _$AppSettingsDaoMixin {
  AppSettingsDao(super.db);

  Stream<AppSettingsTableData> watchSettings() {
    return (select(appSettingsTable)..where((AppSettingsTable s) => s.id.equals(0))).watchSingle();
  }

  Future<AppSettingsTableData> getSettings() {
    return (select(appSettingsTable)..where((AppSettingsTable s) => s.id.equals(0))).getSingle();
  }

  Future<void> updateSettings(AppSettingsTableCompanion changes) {
    return (update(appSettingsTable)..where((AppSettingsTable s) => s.id.equals(0))).write(changes);
  }

  /// `Exam.isActive` bayrağıyla senkron: aktif sınav değiştiğinde
  /// `ExamDao.setActiveExam` ile birlikte çağrılır.
  Future<void> setActiveExam(int examId) {
    return updateSettings(AppSettingsTableCompanion(activeExamId: Value<int?>(examId)));
  }
}
