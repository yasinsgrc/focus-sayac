import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:focussayac/services/storage/app_database.dart';

/// Faz 18 `weekly_summary_enabled` kolonunu ekleyip şemayı v4'e çıkardı.
/// Cihazdaki temiz kurulum `onCreate`ten geçiyor, yani **yükseltme** yolu orada
/// hiç çalışmıyor — güncelleme alan mevcut kullanıcıların tek yolu ise bu.
/// `theme_mode_migration_test.dart` ile aynı kalıp: v3 şeması elle kurulup
/// veritabanı açılıyor.
void main() {
  /// v3'teki `app_settings_table` — `weekly_summary_enabled` yok, gerisi
  /// bugünküyle aynı.
  const String createV3Settings = '''
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
      theme_mode TEXT NOT NULL DEFAULT 'system',
      PRIMARY KEY (id)
    )
  ''';

  /// v6 göçü (ROADMAP madde 30) `pomodoro_sessions`a da kolon ekliyor, yani
  /// kurgu artık o tabloyu da kurmak zorunda — gerçek bir v3 veritabanında
  /// tablo v1'den beri duruyor. Sütunlar v1-v5 hâliyle: `subject_key` yok.
  const String createPreV6Sessions = '''
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

  AppDatabase openUpgradedFromV3() {
    final NativeDatabase executor = NativeDatabase.memory(
      setup: (Database raw) {
        raw
          ..execute(createV3Settings)
          ..execute(createPreV6Sessions)
          // Kullanicinin v3'te biriktirdigi ayarlar: migration bunlari
          // korumali, yalnizca yeni kolonu eklemeli.
          ..execute(
            'INSERT INTO app_settings_table '
            '(id, focus_minutes, streak_reminder_enabled, onboarding_completed) '
            'VALUES (0, 45, 0, 1)',
          )
          // drift yukseltmeye yalnizca `user_version` daha kucukse giriyor.
          ..execute('PRAGMA user_version = 3');
      },
    );
    return AppDatabase.forTesting(executor);
  }

  test('v3 kurulumu v4e yükselince haftalık kapanış açık geliyor', () async {
    final AppDatabase database = openUpgradedFromV3();
    addTearDown(database.close);

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();

    // Kolon varsayılanı `true`: güncelleme alan kullanıcı özeti açık buluyor,
    // kapatma yolu Ekran 07'de.
    expect(settings.weeklySummaryEnabled, isTrue);
    // Yükseltmeden önceki değerler yerinde: kolon eklemek satırı sıfırlamıyor.
    expect(settings.focusMinutes, 45);
    expect(settings.streakReminderEnabled, isFalse);
    expect(settings.onboardingCompleted, isTrue);
  });

  test('yükseltilmiş veritabanına haftalık kapanış yazılabiliyor', () async {
    final AppDatabase database = openUpgradedFromV3();
    addTearDown(database.close);

    await database.appSettingsDao.updateSettings(
      const AppSettingsTableCompanion(weeklySummaryEnabled: Value<bool>(false)),
    );

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();
    expect(settings.weeklySummaryEnabled, isFalse);
    // Komşu anahtar etkilenmiyor — iki tip kapısı birbirinden bağımsız.
    expect(settings.streakReminderEnabled, isFalse);
  });
}
