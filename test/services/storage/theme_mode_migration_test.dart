import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Faz 17 `theme_mode` kolonunu ekleyip şemayı v3'e çıkardı. Cihazdaki temiz
/// kurulum `onCreate`ten geçiyor, yani **yükseltme** yolu orada hiç
/// çalışmıyor — güncelleme alan mevcut kullanıcıların tek yolu ise bu.
/// Test v2 şemasını elle kurup veritabanını açıyor ve migration'ın hem
/// çalıştığını hem de eldeki veriyi bozmadığını doğruluyor.
void main() {
  /// v2'deki `app_settings_table` — `theme_mode` yok, gerisi bugünküyle aynı.
  const String createV2Settings = '''
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
      PRIMARY KEY (id)
    )
  ''';

  AppDatabase openUpgradedFromV2() {
    final NativeDatabase executor = NativeDatabase.memory(
      setup: (Database raw) {
        raw
          ..execute(createV2Settings)
          // Kullanicinin v2'de biriktirdigi ayarlar: migration bunlari
          // korumali, yalnizca yeni kolonu eklemeli.
          ..execute(
            'INSERT INTO app_settings_table '
            '(id, focus_minutes, notifications_enabled, onboarding_completed) '
            'VALUES (0, 40, 0, 1)',
          )
          // drift yukseltmeye yalnizca `user_version` daha kucukse giriyor.
          ..execute('PRAGMA user_version = 2');
      },
    );
    return AppDatabase.forTesting(executor);
  }

  test('v2 kurulumu v3e yükselince theme_mode system olarak geliyor', () async {
    final AppDatabase database = openUpgradedFromV2();
    addTearDown(database.close);

    final AppSettingsTableData settings = await database.appSettingsDao.getSettings();

    expect(settings.themeMode, AppThemeMode.system);
    // Yükseltmeden önceki değerler yerinde: kolon eklemek satırı sıfırlamıyor.
    expect(settings.focusMinutes, 40);
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.onboardingCompleted, isTrue);
  });

  test('yükseltilmiş veritabanına tema yazılabiliyor', () async {
    final AppDatabase database = openUpgradedFromV2();
    addTearDown(database.close);

    await database.appSettingsDao.updateSettings(
      const AppSettingsTableCompanion(themeMode: Value<AppThemeMode>(AppThemeMode.dark)),
    );

    expect((await database.appSettingsDao.getSettings()).themeMode, AppThemeMode.dark);
  });
}
