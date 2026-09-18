import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// ROADMAP madde 30 iki kolon ekleyip şemayı v6'ya çıkardı: seansın dersi
/// (`pomodoro_sessions.subject_key`) ve hapın yapışkan seçimi
/// (`app_settings_table.active_subject_key`). Temiz kurulum `onCreate`ten
/// geçiyor, yani **yükseltme** yolu orada hiç çalışmıyor.
/// `weekly_goal_migration_test.dart` ile aynı kalıp, tek farkı iki tabloya
/// birden dokunması.
void main() {
  /// v5'teki `app_settings_table` — `active_subject_key` yok.
  const String createV5Settings = '''
    CREATE TABLE app_settings_table (
      id INTEGER NOT NULL DEFAULT 0,
      focus_minutes INTEGER NOT NULL DEFAULT 25,
      short_break_minutes INTEGER NOT NULL DEFAULT 5,
      long_break_minutes INTEGER NOT NULL DEFAULT 15,
      notifications_enabled INTEGER NOT NULL DEFAULT 1,
      sound_enabled INTEGER NOT NULL DEFAULT 1,
      haptic_enabled INTEGER NOT NULL DEFAULT 1,
      is_premium INTEGER NOT NULL DEFAULT 0,
      selected_template_index INTEGER NOT NULL DEFAULT 0,
      active_exam_id INTEGER,
      onboarding_completed INTEGER NOT NULL DEFAULT 0,
      streak_reminder_enabled INTEGER NOT NULL DEFAULT 1,
      weekly_summary_enabled INTEGER NOT NULL DEFAULT 1,
      theme_mode TEXT NOT NULL DEFAULT 'system',
      weekly_goal_minutes INTEGER NOT NULL DEFAULT 300,
      PRIMARY KEY (id)
    )
  ''';

  /// v5'teki `pomodoro_sessions` — `subject_key` yok.
  ///
  /// Tarihler `TEXT`: `build.yaml`'daki `store_date_time_values_as_text`
  /// (SPEC.md §5.1 "tüm hesap UTC") epoch-int yerine ISO-8601 metin yazıyor.
  /// Kurgu bunu taklit etmek zorunda — drift okurken değerin sonuna `Z`
  /// ekleyip `DateTime.parse` çağırıyor.
  const String createV5Sessions = '''
    CREATE TABLE pomodoro_sessions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      exam_id INTEGER,
      type TEXT NOT NULL,
      started_at TEXT NOT NULL,
      completed_at TEXT,
      planned_duration_sec INTEGER NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      break_extensions INTEGER NOT NULL DEFAULT 0
    )
  ''';

  AppDatabase openUpgradedFromV5() {
    final NativeDatabase executor = NativeDatabase.memory(
      setup: (Database raw) {
        raw
          ..execute(createV5Settings)
          ..execute(createV5Sessions)
          ..execute(
            'INSERT INTO app_settings_table '
            '(id, focus_minutes, weekly_goal_minutes, onboarding_completed) '
            'VALUES (0, 45, 600, 1)',
          )
          // Kullanicinin v5'te biriktirdigi iki seans: 25 dakikalik tamamlanmis
          // odak ve 5 dakikalik mola.
          ..execute(
            'INSERT INTO pomodoro_sessions '
            '(type, started_at, planned_duration_sec, completed) '
            "VALUES ('focus', '2026-09-15T12:00:00.000000', 1500, 1)",
          )
          ..execute(
            'INSERT INTO pomodoro_sessions '
            '(type, started_at, planned_duration_sec, completed) '
            "VALUES ('shortBreak', '2026-09-15T12:25:00.000000', 300, 1)",
          )
          // drift yukseltmeye yalnizca `user_version` daha kucukse giriyor.
          ..execute('PRAGMA user_version = 5');
      },
    );
    return AppDatabase.forTesting(executor);
  }

  test('v5 kurulumu v6ya yükselince eski seanslar dersiz kalıyor', () async {
    final AppDatabase database = openUpgradedFromV5();
    addTearDown(database.close);

    final List<PomodoroSession> sessions = await database.select(database.pomodoroSessions).get();

    expect(sessions.length, 2);
    // Kolon varsayılansız nullable: geçmişe bir ders atamak veri uydurmak
    // olurdu, `null` = belirtilmemiş ve ekranlarda kendi dilimi var.
    expect(sessions.every((PomodoroSession s) => s.subjectKey == null), isTrue);
    // Yükseltmeden önceki değerler yerinde.
    expect(sessions.first.plannedDurationSec, 1500);
    expect(sessions.first.completed, isTrue);
  });

  test('v5 kurulumu v6ya yükselince hap boş açılıyor, komşu ayarlar duruyor', () async {
    final AppDatabase database = openUpgradedFromV5();
    addTearDown(database.close);

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();

    expect(settings.activeSubjectKey, isNull);
    expect(settings.focusMinutes, 45);
    expect(settings.weeklyGoalMinutes, 600);
    expect(settings.onboardingCompleted, isTrue);
  });

  test('yükseltilmiş veritabanına ders yazılabiliyor ve temizlenebiliyor', () async {
    final AppDatabase database = openUpgradedFromV5();
    addTearDown(database.close);

    await database.appSettingsDao.setActiveSubject('chemistry');
    expect((await database.appSettingsDao.getSettings()).activeSubjectKey, 'chemistry');

    final int id = await database.pomodoroSessionDao.startSession(
      examId: null,
      type: SessionType.focus,
      startedAt: DateTime.utc(2026, 9, 17, 12),
      plannedDurationSec: 1500,
      subjectKey: 'chemistry',
    );
    final List<PomodoroSession> all = await database.select(database.pomodoroSessions).get();
    expect(all.firstWhere((PomodoroSession s) => s.id == id).subjectKey, 'chemistry');

    // "Ders belirtme" çıkışı: `null` geçerli bir değer, ayrı bir temizleme
    // metodu yok.
    await database.appSettingsDao.setActiveSubject(null);
    expect((await database.appSettingsDao.getSettings()).activeSubjectKey, isNull);
  });
}
