import 'package:drift/drift.dart';

import '../app_database.dart';
import '../storage_enums.dart';
import '../tables.dart';

part 'pomodoro_session_dao.g.dart';

/// `PomodoroSession` tablosu için sorgu/komutlar. Kalan süre asla bu
/// tablodan azalan bir sayaç olarak okunmaz (SPEC.md §5.1) — yalnızca
/// `startedAt`/`plannedDurationSec` üzerinden hesaplanır; bu DAO ham
/// kayıtları tutar.
@DriftAccessor(tables: <Type>[PomodoroSessions])
class PomodoroSessionDao extends DatabaseAccessor<AppDatabase> with _$PomodoroSessionDaoMixin {
  PomodoroSessionDao(super.db);

  Future<int> startSession({
    required int? examId,
    required SessionType type,
    required DateTime startedAt,
    required int plannedDurationSec,
  }) {
    return into(pomodoroSessions).insert(
      PomodoroSessionsCompanion.insert(
        examId: Value<int?>(examId),
        type: type,
        startedAt: startedAt,
        plannedDurationSec: plannedDurationSec,
      ),
    );
  }

  /// Seans bitişini yazar. `completed = true` başarıyla tamamlanan, `false`
  /// erken iptal edilen seanslar içindir (SPEC.md Ekran 10).
  Future<bool> finishSession({
    required int id,
    required bool completed,
    required DateTime endedAt,
  }) async {
    final int rows = await (update(pomodoroSessions)..where((PomodoroSessions s) => s.id.equals(id)))
        .write(
      PomodoroSessionsCompanion(
        completed: Value<bool>(completed),
        completedAt: Value<DateTime?>(endedAt),
      ),
    );
    return rows > 0;
  }

  Future<bool> incrementBreakExtension(int id) async {
    final PomodoroSession? session =
        await (select(pomodoroSessions)..where((PomodoroSessions s) => s.id.equals(id))).getSingleOrNull();
    if (session == null) {
      return false;
    }
    await (update(pomodoroSessions)..where((PomodoroSessions s) => s.id.equals(id))).write(
      PomodoroSessionsCompanion(breakExtensions: Value<int>(session.breakExtensions + 1)),
    );
    return true;
  }

  Stream<List<PomodoroSession>> watchAllSessions() => select(pomodoroSessions).watch();

  Future<List<PomodoroSession>> getSessionsBetween(DateTime startUtc, DateTime endUtc) {
    return (select(pomodoroSessions)
          ..where((PomodoroSessions s) => s.startedAt.isBetweenValues(startUtc, endUtc)))
        .get();
  }

  Future<List<PomodoroSession>> getAllCompletedFocusSessions() {
    return (select(pomodoroSessions)
          ..where((PomodoroSessions s) =>
              s.completed.equals(true) & s.type.equals(SessionType.focus.name)))
        .get();
  }
}
