import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_phase.dart';
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/features/focus_session/widgets/session_ring_painter.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Fazı testin sürdüğü controller: gerçek `PomodoroController` geçişleri DB ve
/// bildirim yan etkileriyle birlikte yapıyor, oysa buradaki soru yalnızca
/// **ekranın** faz geçişine nasıl tepki verdiği.
class _ScriptedPomodoroController extends PomodoroController {
  _ScriptedPomodoroController(this._initialPhase);

  final PomodoroPhase _initialPhase;

  @override
  PomodoroPhase build() => _initialPhase;

  @override
  Future<void> tick() async {}

  void moveTo(PomodoroPhase phase) => state = phase;
}

/// `focus_session_screen_test.dart`taki aynı stub: ekran ağaca girer girmez
/// `WakelockPlus.enable()` çağırıyor, gerçek eklenti testte kayıtlı değil.
void _stubWakelockChannel() {
  const String channel = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    channel,
    (ByteData? message) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel, null),
  );
}

PomodoroPhase _focusRunning() => PomodoroPhase.focusRunning(
      sessionId: 1,
      examId: null,
      startedAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 12, seconds: 30)),
      plannedDurationSec: 25 * 60,
      cyclePosition: 1,
    );

PomodoroPhase _breakRunning() => PomodoroPhase.breakRunning(
      sessionId: 2,
      examId: null,
      isLong: false,
      startedAtUtc: DateTime.now().toUtc(),
      plannedDurationSec: 5 * 60,
      cyclePosition: 1,
      extensionsUsed: 0,
    );

Future<_ScriptedPomodoroController> _pumpFocusSession(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final _ScriptedPomodoroController controller = _ScriptedPomodoroController(_focusRunning());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
        pomodoroControllerProvider.overrideWith(() => controller),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Halkanın ilk yerleşmesi bitsin (`SettlingProgress`), ölçümler ondan sonra.
  await tester.pump(AppMotion.slow);
  expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);
  return controller;
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

SessionRingPainter _ringPainter(WidgetTester tester) {
  final CustomPaint ring = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint, skipOffstage: false))
      .firstWhere((CustomPaint paint) => paint.painter is SessionRingPainter);
  return ring.painter! as SessionRingPainter;
}

/// Mola gövdesinin işareti — Ekran 09'un 64px kahve ikonu.
Finder get _breakBody => find.byIcon(PhosphorIconsDuotone.coffee, skipOffstage: false);

void main() {
  // ROADMAP madde 19: 25 dakika bitiyordu ve ekran öylece mola gövdesine
  // geçiyordu. Artık dolu halka bir kez közden naneye dönüyor, mola ondan
  // sonra geliyor.
  testWidgets('odak doğal bitişinde halka bir kez naneye dönüyor', (WidgetTester tester) async {
    final _ScriptedPomodoroController controller = await _pumpFocusSession(tester);

    controller.moveTo(_breakRunning());
    await tester.pump();

    expect(_breakBody, findsNothing, reason: 'mola gövdesi geçiş bitmeden gelmiyor');
    final SessionRingPainter atStart = _ringPainter(tester);
    expect(atStart.progress, 1, reason: 'seans doldu, halka tam');
    final List<Color> startColors = atStart.gradientColors!;

    await tester.pump(AppMotion.slow ~/ 2);
    expect(_ringPainter(tester).gradientColors, isNot(startColors), reason: 'renk akıyor');
    expect(_breakBody, findsNothing);

    await tester.pump(AppMotion.slow);
    await tester.pump();
    expect(_breakBody, findsOneWidget, reason: 'pencere kapanınca mola gövdesi geliyor');

    await _disposeTree(tester);
  });

  // Karşı kontrol: duraklatma bir tamamlanma değil. Halka duraklatılmış hâline
  // (düz renk, kendi oranı) aynı karede geçmeli.
  testWidgets('duraklatmada tamamlanma animasyonu çalışmıyor', (WidgetTester tester) async {
    final _ScriptedPomodoroController controller = await _pumpFocusSession(tester);

    controller.moveTo(
      PomodoroPhase.focusPaused(
        sessionId: 1,
        examId: null,
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 12, seconds: 30)),
        plannedDurationSec: 25 * 60,
        cyclePosition: 1,
        remainingAtPause: const Duration(minutes: 12, seconds: 30),
      ),
    );
    await tester.pump();

    final SessionRingPainter painter = _ringPainter(tester);
    expect(painter.solidColor, isNotNull);
    expect(painter.gradientColors, isNull);
    expect(painter.progress, lessThan(1));

    await _disposeTree(tester);
  });

  // Karşı kontrol: iptal (Ekran 10 onayı) `idle`'a gidiyor — kutlanacak bir
  // şey yok, ekran hiç bekletilmeden kapanıyor.
  testWidgets('iptalde tamamlanma animasyonu çalışmıyor', (WidgetTester tester) async {
    final _ScriptedPomodoroController controller = await _pumpFocusSession(tester);

    controller.moveTo(const PomodoroPhase.idle());
    await tester.pump();

    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsNothing, reason: 'ekran kapandı');

    await _disposeTree(tester);
  });

  // SPEC.md §6.4 regresyonu: tamamlanma hareketi seans **bittiği anda**
  // çalışıyor. Süren seans boyunca halkanın rengi kıpırdamamalı — yoksa 25
  // dakika boyunca kare üreten bir tween eklemiş olurduk.
  testWidgets('seans sürerken halkanın rengi kıpırdamıyor', (WidgetTester tester) async {
    await _pumpFocusSession(tester);

    final List<Color> before = _ringPainter(tester).gradientColors!;
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(_ringPainter(tester).gradientColors, before);
      expect(_ringPainter(tester).progress, lessThan(1));
    }

    await _disposeTree(tester);
  });

  testWidgets('hareketi azalt açıkken mola gövdesi ilk karede geliyor', (WidgetTester tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final _ScriptedPomodoroController controller = await _pumpFocusSession(tester);

    controller.moveTo(_breakRunning());
    await tester.pump();
    expect(_breakBody, findsOneWidget);

    await _disposeTree(tester);
  });
}
