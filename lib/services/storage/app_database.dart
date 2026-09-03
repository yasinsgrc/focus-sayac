import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'daos/app_settings_dao.dart';
import 'daos/exam_dao.dart';
import 'daos/pomodoro_session_dao.dart';
import 'daos/user_badge_dao.dart';
import 'exam_json_models.dart';
import 'storage_enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Yerel seed dosyasının asset yolu — SPEC.md §4, "assets/data/exam_dates.json".
const String kExamSeedAssetPath = 'assets/data/exam_dates.json';

/// Uygulamanın tek `drift` veritabanı. `NativeDatabase` elle açılır —
/// `drift_flutter` paketi kullanılmıyor (Faz 1 `DECISIONS.md` kararı: sürüm
/// çakışması). Bağlantı `sqlite3_flutter_libs` + `path_provider` ile kurulur.
@DriftDatabase(
  tables: <Type>[Exams, PomodoroSessions, UserBadges, AppSettingsTable],
  daos: <Type>[ExamDao, PomodoroSessionDao, UserBadgeDao, AppSettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedInitialData(this);
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(exams, exams.presetKey);
            await _backfillPresetKeys(this);
          }
        },
      );
}

/// v1'de yazılmış preset satırlarının `presetKey`'i boştur; anahtar
/// doldurulmazsa ilk uzak override her sınav için ikinci bir satır açar.
/// Seed dosyasındaki ad → anahtar eşlemesiyle bir kez doldurulur.
Future<void> _backfillPresetKeys(AppDatabase db) async {
  final String raw = await rootBundle.loadString(kExamSeedAssetPath);
  final Map<String, Object?> payload = jsonDecode(raw) as Map<String, Object?>;
  final Map<String, String> keysByName = <String, String>{
    for (final ExamJsonEntry entry in parseExamJsonPayload(payload)) entry.name: entry.key,
  };
  await db.examDao.backfillPresetKeys(keysByName);
}

/// İlk kurulumda 4 preset sınav + varsayılan `AppSettings` satırını yazar
/// (SPEC.md §8 Faz 3). Sınav içeriği `assets/data/exam_dates.json`'dan
/// okunur — tarihler koda gömülmez (SPEC.md §4). `ExamSourceService`
/// uygulama her açılışında bunun üzerine uzak override'ı dener.
Future<void> _seedInitialData(AppDatabase db) async {
  final String raw = await rootBundle.loadString(kExamSeedAssetPath);
  final Map<String, Object?> payload = jsonDecode(raw) as Map<String, Object?>;
  final List<ExamJsonEntry> entries = parseExamJsonPayload(payload);

  final List<int> insertedIds = <int>[];
  for (final ExamJsonEntry entry in entries) {
    final int id = await db.into(db.exams).insert(
          ExamsCompanion.insert(
            name: entry.name,
            subtitle: Value<String?>(entry.subtitle),
            dateUtc: entry.dateUtc,
            timeOfDay: entry.timeOfDay,
            accentRole: entry.accentRole,
            isPreset: const Value<bool>(true),
            presetKey: Value<String?>(entry.key),
            isActive: Value<bool>(insertedIds.isEmpty),
            source: ExamSourceType.seed,
            verifiedAt: Value<DateTime?>(entry.verifiedAt),
          ),
        );
    insertedIds.add(id);
  }

  await db.into(db.appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          id: const Value<int>(0),
          activeExamId: Value<int?>(insertedIds.isEmpty ? null : insertedIds.first),
        ),
      );
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'focussayac.sqlite'));
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    return NativeDatabase.createInBackground(file);
  });
}
