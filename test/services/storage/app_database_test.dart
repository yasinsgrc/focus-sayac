import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('onCreate seeding', () {
    test('inserts exactly the preset exams from assets/data/exam_dates.json', () async {
      final List<Exam> presets = await db.examDao.getPresetExams();
      expect(presets, hasLength(4));
      expect(presets.every((Exam e) => e.source == ExamSourceType.seed), isTrue);
      expect(presets.every((Exam e) => e.isPreset), isTrue);
    });

    test('marks exactly one exam active and mirrors it in AppSettings', () async {
      final List<Exam> presets = await db.examDao.getPresetExams();
      final List<Exam> activeOnes = presets.where((Exam e) => e.isActive).toList();
      expect(activeOnes, hasLength(1));

      final AppSettingsTableData settings = await db.appSettingsDao.getSettings();
      expect(settings.activeExamId, activeOnes.single.id);
    });

    test('writes default AppSettings row with SPEC.md §4 defaults', () async {
      final AppSettingsTableData settings = await db.appSettingsDao.getSettings();
      expect(settings.focusMinutes, 25);
      expect(settings.shortBreakMinutes, 5);
      expect(settings.longBreakMinutes, 15);
      expect(settings.isPremium, isFalse);
      expect(settings.onboardingCompleted, isFalse);
      // `NotificationPreferences.allEnabled()` (ayar okunamayan bağlamların
      // yedeği) bu üç varsayılanla aynı olmak zorunda — biri değişirse
      // bildirimler sessizce yedeğe göre davranmaya başlar.
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.soundEnabled, isTrue);
      expect(settings.streakReminderEnabled, isTrue);
    });
  });

  group('ExamDao', () {
    test('insertUserExam is tagged as user source and outranks presets in ordering', () async {
      final int userExamId = await db.examDao.insertUserExam(
        name: 'Deneme Sınavı',
        subtitle: null,
        dateUtc: DateTime.utc(2027, 1, 1),
        timeOfDay: '09:00',
        accentRole: ExamAccentRole.rose,
      );

      final List<Exam> all = await db.examDao.watchAllExams().first;
      expect(all.first.id, userExamId);
      expect(all.first.source, ExamSourceType.user);
    });

    test('setActiveExam flips isActive on exactly one row and syncs AppSettings', () async {
      final List<Exam> presets = await db.examDao.getPresetExams();
      final Exam target = presets.last;

      await db.examDao.setActiveExam(target.id);
      await db.appSettingsDao.setActiveExam(target.id);

      final Exam? active = await db.examDao.getActiveExam();
      expect(active?.id, target.id);

      final AppSettingsTableData settings = await db.appSettingsDao.getSettings();
      expect(settings.activeExamId, target.id);
    });

    test('upsertPresetExam updates an existing preset by name instead of duplicating it', () async {
      final List<Exam> before = await db.examDao.getPresetExams();
      final Exam target = before.first;

      await db.examDao.upsertPresetExam(
        name: target.name,
        subtitle: 'Güncellenmiş alt başlık',
        dateUtc: DateTime.utc(2028, 3, 3),
        timeOfDay: '11:30',
        accentRole: ExamAccentRole.sky,
        verifiedAt: DateTime.utc(2027, 1, 1),
      );

      final List<Exam> after = await db.examDao.getPresetExams();
      expect(after, hasLength(before.length));
      final Exam updated = after.firstWhere((Exam e) => e.name == target.name);
      expect(updated.subtitle, 'Güncellenmiş alt başlık');
      expect(updated.source, ExamSourceType.remote);
    });
  });

  group('PomodoroSessionDao', () {
    test('startSession then finishSession(completed: true) round-trips', () async {
      final DateTime startedAt = DateTime.utc(2026, 8, 22, 10);
      final int id = await db.pomodoroSessionDao.startSession(
        examId: null,
        type: SessionType.focus,
        startedAt: startedAt,
        plannedDurationSec: 25 * 60,
      );

      final bool ok = await db.pomodoroSessionDao.finishSession(
        id: id,
        completed: true,
        endedAt: startedAt.add(const Duration(minutes: 25)),
      );
      expect(ok, isTrue);

      final List<PomodoroSession> focusSessions =
          await db.pomodoroSessionDao.getAllCompletedFocusSessions();
      expect(focusSessions, hasLength(1));
      expect(focusSessions.single.completed, isTrue);
    });

    test('cancelled session (completed: false) is excluded from completed-focus query', () async {
      final int id = await db.pomodoroSessionDao.startSession(
        examId: null,
        type: SessionType.focus,
        startedAt: DateTime.utc(2026, 8, 22, 10),
        plannedDurationSec: 25 * 60,
      );
      await db.pomodoroSessionDao.finishSession(
        id: id,
        completed: false,
        endedAt: DateTime.utc(2026, 8, 22, 10, 5),
      );

      final List<PomodoroSession> focusSessions =
          await db.pomodoroSessionDao.getAllCompletedFocusSessions();
      expect(focusSessions, isEmpty);
    });

    test('incrementBreakExtension increments the counter', () async {
      final int id = await db.pomodoroSessionDao.startSession(
        examId: null,
        type: SessionType.shortBreak,
        startedAt: DateTime.utc(2026, 8, 22, 10),
        plannedDurationSec: 5 * 60,
      );

      await db.pomodoroSessionDao.incrementBreakExtension(id);
      await db.pomodoroSessionDao.incrementBreakExtension(id);

      final List<PomodoroSession> all = await db.pomodoroSessionDao.watchAllSessions().first;
      expect(all.single.breakExtensions, 2);
    });
  });

  group('UserBadgeDao', () {
    test('unlockBadge is idempotent for the same badgeKey', () async {
      await db.userBadgeDao.unlockBadge(badgeKey: 'first_spark', unlockedAt: DateTime.utc(2026, 8, 22));
      await db.userBadgeDao.unlockBadge(badgeKey: 'first_spark', unlockedAt: DateTime.utc(2026, 8, 23));

      final List<UserBadge> badges = await db.userBadgeDao.getUnlockedBadges();
      expect(badges, hasLength(1));
      expect(badges.single.unlockedAt, DateTime.utc(2026, 8, 22));
    });
  });

  group('AppSettingsDao', () {
    test('updateSettings persists a partial change', () async {
      await db.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(focusMinutes: Value<int>(50)),
      );
      final AppSettingsTableData settings = await db.appSettingsDao.getSettings();
      expect(settings.focusMinutes, 50);
      expect(settings.shortBreakMinutes, 5);
    });
  });
}
