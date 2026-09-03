import 'package:drift/drift.dart';

import 'storage_enums.dart';

/// Sınav kaydı — kullanıcı sınavı, uzak override veya yerel seed'den gelir.
/// SPEC.md §4 `Exam` şeması.
class Exams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get subtitle => text().nullable()();
  DateTimeColumn get dateUtc => dateTime()();

  /// "HH:mm" biçiminde saat — `drift` yerel bir `TimeOfDay` türü sunmuyor.
  TextColumn get timeOfDay => text()();
  TextColumn get accentRole => textEnum<ExamAccentRole>()();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();

  /// Yerel seed ve uzak override JSON'undaki kararlı anahtar (ör. `yks`).
  /// Uzak override preset'leri bu anahtarla eşler — sınavın adı değişse bile
  /// aynı satır güncellenir. Kullanıcı sınavlarında `null`.
  TextColumn get presetKey => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  TextColumn get source => textEnum<ExamSourceType>()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
}

/// Tek bir pomodoro/mola seansı. SPEC.md §4 `PomodoroSession` şeması.
class PomodoroSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId => integer().nullable().references(Exams, #id)();
  TextColumn get type => textEnum<SessionType>()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get plannedDurationSec => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get breakExtensions => integer().withDefault(const Constant(0))();
}

/// Açılmış rozetler. Yalnızca açılan rozet için satır yazılır — statik
/// rozet kataloğu (ad/kural) koddadır (SPEC.md §5.4), burada saklanmaz.
class UserBadges extends Table {
  TextColumn get badgeKey => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{badgeKey};
}

/// Tek satırlık ayar tablosu. SPEC.md §4 `AppSettings` şeması.
class AppSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get focusMinutes => integer().withDefault(const Constant(25))();
  IntColumn get shortBreakMinutes => integer().withDefault(const Constant(5))();
  IntColumn get longBreakMinutes => integer().withDefault(const Constant(15))();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get hapticEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  IntColumn get selectedTemplateIndex => integer().withDefault(const Constant(0))();
  IntColumn get activeExamId => integer().nullable().references(Exams, #id)();
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get streakReminderEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
