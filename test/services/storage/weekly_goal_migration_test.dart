import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:focussayac/services/storage/app_database.dart';

/// ROADMAP madde 24 `weekly_goal_minutes` kolonunu ekleyip şemayı v5'e çıkardı.
/// Temiz kurulum `onCreate`ten geçiyor, yani **yükseltme** yolu orada hiç
/// çalışmıyor; güncelleme alan mevcut kullanıcıların tek yolu bu.
/// `weekly_summary_migration_test.dart` ile aynı kalıp.
void main() {
  /// v4'teki `app_settings_table` — `weekly_goal_minutes` yok, gerisi
  /// bugünküyle aynı.
  const String createV4Settings = '''
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
      PRIMARY KEY (id)
    )
  ''';

  AppDatabase openUpgradedFromV4() {
    final NativeDatabase executor = NativeDatabase.memory(
      setup: (Database raw) {
        raw
          ..execute(createV4Settings)
          // Kullanicinin v4'te biriktirdigi ayarlar: migration bunlari
          // korumali, yalnizca yeni kolonu eklemeli.
          ..execute(
            'INSERT INTO app_settings_table '
            '(id, focus_minutes, weekly_summary_enabled, onboarding_completed) '
            'VALUES (0, 45, 0, 1)',
          )
          // drift yukseltmeye yalnizca `user_version` daha kucukse giriyor.
          ..execute('PRAGMA user_version = 4');
      },
    );
    return AppDatabase.forTesting(executor);
  }

  test('v4 kurulumu v5e yükselince haftalık hedef 5 saatte açık geliyor', () async {
    final AppDatabase database = openUpgradedFromV4();
    addTearDown(database.close);

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();

    // Kolon varsayılanı 300 dk: güncelleme alan kullanıcı hedefi açık buluyor,
    // kapatma yolu Ekran 07'de (slider 0 = kapalı).
    expect(settings.weeklyGoalMinutes, 300);
    // Yükseltmeden önceki değerler yerinde: kolon eklemek satırı sıfırlamıyor.
    expect(settings.focusMinutes, 45);
    expect(settings.weeklySummaryEnabled, isFalse);
    expect(settings.onboardingCompleted, isTrue);
  });

  test('yükseltilmiş veritabanına haftalık hedef yazılabiliyor, 0 dahil', () async {
    final AppDatabase database = openUpgradedFromV4();
    addTearDown(database.close);

    await database.appSettingsDao.updateSettings(
      const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(10 * 60)),
    );
    expect((await database.appSettingsDao.getSettings()).weeklyGoalMinutes, 600);

    // 0 geçerli bir değer (hedef kapalı), varsayılana geri düşmüyor.
    await database.appSettingsDao.updateSettings(
      const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(0)),
    );

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();
    expect(settings.weeklyGoalMinutes, 0);
    // Komşu ayar etkilenmiyor.
    expect(settings.focusMinutes, 45);
  });
}
