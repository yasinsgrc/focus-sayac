import 'dart:convert';

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
/// mola)". Odak/mola süreleri varsayılan olarak 0 saniyeye ayarlanır ki
/// `tick()` gerçek `DateTime.now()` ile hemen tamamlanma üretsin — controller
/// gerçek duvar saatini kullanıyor (SPEC §5.1), sahte bir `Clock` enjeksiyonu
/// yok. Molada kalmayı gerektiren testler [shortBreakMinutes]'ı sıfırdan
/// büyük verir; yoksa `tick()` dolan molayı da aynı çağrıda kapatır.
Future<ProviderContainer> _buildContainer({
  int focusMinutes = 0,
  int shortBreakMinutes = 0,
  int longBreakMinutes = 0,
  NotificationService? notifications,
}) async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(notifications ?? NotificationService.disabled()),
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
    AppSettingsTableCompanion(
      focusMinutes: Value<int>(focusMinutes),
      shortBreakMinutes: Value<int>(shortBreakMinutes),
      longBreakMinutes: Value<int>(longBreakMinutes),
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

/// Platform kanalı açmayan ([NotificationService.disabled] gibi) ama mola
/// bitiş bildiriminin ne zaman kurulduğunu/iptal edildiğini kaydeden sahte.
class _RecordingNotifications extends NotificationService {
  _RecordingNotifications() : super.disabled();

  final List<({DateTime endAtUtc, int breakMinutes})> breakEndSchedules =
      <({DateTime endAtUtc, int breakMinutes})>[];
  int breakEndCancels = 0;

  @override
  Future<void> scheduleBreakEnd({required DateTime endAtUtc, required int breakMinutes}) async {
    breakEndSchedules.add((endAtUtc: endAtUtc, breakMinutes: breakMinutes));
  }

  @override
  Future<void> cancelBreakEnd() async {
    breakEndCancels++;
  }
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

      // Odak da mola da planned=0s olduğu için ikisinin de bitiş anı çoktan
      // geçmiş sayılır; `tick()` dolan fazları zincirleyerek kapattığından
      // tek çağrıda odak → mola → idle tamamlanır.
      await controller.tick();
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
    final ProviderContainer container = await _buildContainer(shortBreakMinutes: 5);
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

  test('mola başlarken bitiş bildirimi molanın planlanan bitiş anına kurulur', () async {
    // Regresyon: yalnızca odak bitişi zamanlanıyordu; molada telefonu bırakan
    // kullanıcıya molanın bittiği hiç haber verilmiyordu.
    final _RecordingNotifications notifications = _RecordingNotifications();
    final ProviderContainer container =
        await _buildContainer(shortBreakMinutes: 5, notifications: notifications);
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.tick(); // -> breakRunning

    final PomodoroBreakRunning breakPhase =
        container.read(pomodoroControllerProvider) as PomodoroBreakRunning;
    expect(notifications.breakEndSchedules, hasLength(1));
    expect(
      notifications.breakEndSchedules.single.endAtUtc
          .isAtSameMomentAs(breakPhase.startedAtUtc.add(const Duration(minutes: 5))),
      isTrue,
    );
    expect(notifications.breakEndSchedules.single.breakMinutes, 5);
  });

  test('extendBreak mola bitiş bildirimini yeni bitiş anına taşır', () async {
    final _RecordingNotifications notifications = _RecordingNotifications();
    final ProviderContainer container =
        await _buildContainer(shortBreakMinutes: 5, notifications: notifications);
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.tick(); // -> breakRunning
    final PomodoroBreakRunning before =
        container.read(pomodoroControllerProvider) as PomodoroBreakRunning;

    await controller.extendBreak();

    expect(notifications.breakEndSchedules, hasLength(2));
    expect(
      notifications.breakEndSchedules.last.endAtUtc
          .isAtSameMomentAs(before.startedAtUtc.add(const Duration(minutes: 10))),
      isTrue,
    );
    expect(notifications.breakEndSchedules.last.breakMinutes, 10);
  });

  test('mola kapandığında bitiş bildirimi iptal edilir', () async {
    final _RecordingNotifications notifications = _RecordingNotifications();
    final ProviderContainer container =
        await _buildContainer(shortBreakMinutes: 5, notifications: notifications);
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    await controller.tick(); // -> breakRunning
    expect(notifications.breakEndCancels, 0);

    await controller.endBreakEarly();

    expect(notifications.breakEndCancels, 1);
  });

  test('endBreakEarly closes the break as completed:false and returns to idle', () async {
    final ProviderContainer container = await _buildContainer(shortBreakMinutes: 5);
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

  test('odak, tikin geldiği an değil planlanan bitiş anıyla kapanır ve mola oradan başlar', () async {
    final ProviderContainer container = await _buildContainer(shortBreakMinutes: 5);
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    await controller.startFocus();
    final PomodoroFocusRunning focus = container.read(pomodoroControllerProvider) as PomodoroFocusRunning;
    final DateTime focusEndUtc = focus.startedAtUtc.add(Duration(seconds: focus.plannedDurationSec));

    await controller.tick();

    final PomodoroPhase phase = container.read(pomodoroControllerProvider);
    expect(phase, isA<PomodoroBreakRunning>());
    final PomodoroBreakRunning breakPhase = phase as PomodoroBreakRunning;
    expect(breakPhase.isLong, isFalse);
    expect(breakPhase.startedAtUtc, focusEndUtc);

    final List<PomodoroSession> sessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;
    final PomodoroSession focusRow = sessions.firstWhere((PomodoroSession s) => s.type == SessionType.focus);
    expect(focusRow.completed, isTrue);
    expect(focusRow.completedAt!.isAtSameMomentAs(focusEndUtc), isTrue);
  });

  test('arka planda dolan odak+mola, ilk tikte gerçek bitiş anlarıyla kapanır', () async {
    // Regresyon: tikleyici arka planda iptal edildiği için 25 dk'lık odak
    // dolarken hiç tik gelmiyordu; kullanıcı 40 dk sonra döndüğünde seans
    // "dönüş anı" ile kapanıyor ve mola sıfırdan başlıyordu.
    final ProviderContainer container = await _buildContainer(shortBreakMinutes: 5);
    addTearDown(container.dispose);

    // Drift `dateTime()` sütunları saniye hassasiyetinde saklandığı için
    // tohum zamanı tam saniyeye yuvarlanıyor.
    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime startedAtUtc = DateTime.fromMillisecondsSinceEpoch(
      (nowUtc.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    ).subtract(const Duration(minutes: 40));
    const int focusSec = 25 * 60;

    final int sessionId = await container.read(pomodoroSessionDaoProvider).startSession(
          examId: null,
          type: SessionType.focus,
          startedAt: startedAtUtc,
          plannedDurationSec: focusSec,
        );
    await container.read(sharedPreferencesProvider).setString(
          kPomodoroPhasePrefsKey,
          jsonEncode(<String, Object?>{
            'type': 'focusRunning',
            'sessionId': sessionId,
            'examId': null,
            'startedAtUtc': startedAtUtc.toIso8601String(),
            'plannedDurationSec': focusSec,
            'cyclePosition': 1,
          }),
        );

    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);
    expect(container.read(pomodoroControllerProvider), isA<PomodoroFocusRunning>());

    await controller.tick();

    // Odak 25. dakikada, mola da onun 5 dk sonrasında dolmuş; ikisi de aynı
    // tikte kapanıp idle'a inilir.
    expect(container.read(pomodoroControllerProvider), isA<PomodoroIdle>());

    final DateTime focusEndUtc = startedAtUtc.add(const Duration(seconds: focusSec));
    final DateTime breakEndUtc = focusEndUtc.add(const Duration(minutes: 5));
    final List<PomodoroSession> sessions =
        await container.read(pomodoroSessionDaoProvider).watchAllSessions().first;

    final PomodoroSession focusRow = sessions.firstWhere((PomodoroSession s) => s.type == SessionType.focus);
    expect(focusRow.completed, isTrue);
    expect(focusRow.completedAt!.isAtSameMomentAs(focusEndUtc), isTrue);

    final PomodoroSession breakRow = sessions.firstWhere((PomodoroSession s) => s.type == SessionType.shortBreak);
    expect(breakRow.completed, isTrue);
    expect(breakRow.startedAt.isAtSameMomentAs(focusEndUtc), isTrue);
    expect(breakRow.completedAt!.isAtSameMomentAs(breakEndUtc), isTrue);
  });
}
