import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_phase.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPEC.md §9 "Widget: faz geçişleri (odak → mola → odak → 4. sonrası uzun
/// mola)". Odak/mola süreleri 0 saniyeye ayarlanır ki `tick()` gerçek
/// `DateTime.now()` ile hemen tamamlanma üretsin — controller gerçek duvar
/// saatini kullanıyor (SPEC §5.1), sahte bir `Clock` enjeksiyonu yok.
Future<ProviderContainer> _buildContainer() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
    ],
  );
  await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
  // `container.read()` tek başına akışın ilk değerini garanti tetiklemiyor
  // (gözlemlendi: `AsyncLoading` içinde asılı kalıyor) — `fireImmediately`
  // ile bir dinleyici eklemek `StreamProvider`ın abonelik/ilk yayın
  // döngüsünü gerçekten başlatıyor.
  container.listen(
    allSessionsProvider,
    (AsyncValue<List<PomodoroSession>>? previous, AsyncValue<List<PomodoroSession>> next) {},
    fireImmediately: true,
  );
  await _waitForSessionCount(container, 0);
  await db.appSettingsDao.updateSettings(
    const AppSettingsTableCompanion(
      focusMinutes: Value<int>(0),
      shortBreakMinutes: Value<int>(0),
      longBreakMinutes: Value<int>(0),
    ),
  );
  return container;
}

/// `todayFocusStatsProvider`in bağlı olduğu `allSessionsProvider`
/// (Riverpod `StreamProvider`) drift'in `.watch()` yayınını asenkron olarak
/// alır — bir sonraki `startFocus()` çağrısının döngü konumunu doğru
/// hesaplaması için o akışın yeni satırı görmüş olması gerekiyor. Sabit bir
/// gecikme yerine gerçek satır sayısına ulaşana kadar yoklanıyor.
Future<void> _waitForSessionCount(ProviderContainer container, int expectedCount) async {
  for (int i = 0; i < 200; i++) {
    final List<PomodoroSession>? sessions = container.read(allSessionsProvider).value;
    if (sessions != null && sessions.length == expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('Timed out waiting for allSessionsProvider to report $expectedCount sessions.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startFocus begins cycle position 1 and writes a focus session row', () async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);

    await container.read(pomodoroControllerProvider.notifier).startFocus();
    final PomodoroPhase phase = container.read(pomodoroControllerProvider);

    expect(phase, isA<PomodoroFocusRunning>());
    expect((phase as PomodoroFocusRunning).cyclePosition, 1);

    final List<PomodoroSession> sessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
    expect(sessions, hasLength(1));
    expect(sessions.single.type, SessionType.focus);
    expect(sessions.single.completed, isFalse);
  });

  test('4 tamamlanan odak → uzun mola, sonraki odak döngü 1e döner', () async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    final List<int> observedCyclePositions = <int>[];
    for (int i = 0; i < 4; i++) {
      await _waitForSessionCount(container, i * 2);
      await controller.startFocus();
      final PomodoroPhase running = container.read(pomodoroControllerProvider);
      observedCyclePositions.add((running as PomodoroFocusRunning).cyclePosition);

      await controller.tick(); // planned=0s → anında tamamlanır, mola başlar
      final PomodoroPhase afterFocus = container.read(pomodoroControllerProvider);
      expect(afterFocus, isA<PomodoroBreakRunning>());
      if (i == 3) {
        expect((afterFocus as PomodoroBreakRunning).isLong, isTrue);
      } else {
        expect((afterFocus as PomodoroBreakRunning).isLong, isFalse);
      }

      await controller.tick(); // mola da planned=0s → anında tamamlanır, idle
      expect(container.read(pomodoroControllerProvider), isA<PomodoroIdle>());
    }
    await _waitForSessionCount(container, 8);

    expect(observedCyclePositions, <int>[1, 2, 3, 4]);

    final List<PomodoroSession> allSessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
    expect(allSessions.where((PomodoroSession s) => s.type == SessionType.focus && s.completed), hasLength(4));
    expect(allSessions.where((PomodoroSession s) => s.type == SessionType.longBreak && s.completed), hasLength(1));
    expect(allSessions.where((PomodoroSession s) => s.type == SessionType.shortBreak && s.completed), hasLength(3));
  });

  test('cancelFocusSession closes the session as completed:false and returns to idle', () async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.cancelFocusSession();

    expect(container.read(pomodoroControllerProvider), isA<PomodoroIdle>());
    final List<PomodoroSession> sessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
    expect(sessions.single.completed, isFalse);
  });

  test('extendBreak is capped at kMaxBreakExtensions', () async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.tick(); // -> breakRunning (planned=0s)

    await controller.extendBreak();
    await controller.extendBreak();
    await controller.extendBreak(); // 3. çağrı no-op olmalı

    final PomodoroPhase phase = container.read(pomodoroControllerProvider);
    expect(phase, isA<PomodoroBreakRunning>());
    expect((phase as PomodoroBreakRunning).extensionsUsed, kMaxBreakExtensions);
  });

  test('endBreakEarly closes the break as completed:false and returns to idle', () async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.tick(); // -> breakRunning
    await controller.endBreakEarly();

    expect(container.read(pomodoroControllerProvider), isA<PomodoroIdle>());
    final List<PomodoroSession> sessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
    final PomodoroSession breakSession = sessions.firstWhere((PomodoroSession s) => s.type == SessionType.shortBreak);
    expect(breakSession.completed, isFalse);
  });
}
