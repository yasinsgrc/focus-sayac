import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_phase.dart';
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/features/focus_session/widgets/session_ring_painter.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Fazı sabit tutan ve `tick()` çağrılarını sayan sahte controller. İki işi
/// var: (1) ekran testin ortasında `idle`'a düşüp kendini kapatmasın,
/// (2) tikleyicinin gerçekten durup başladığı gözlemlenebilsin — gerçek
/// controller'da tik yan etkisiz kaldığı için dışarıdan görünmüyor.
class _CountingPomodoroController extends PomodoroController {
  _CountingPomodoroController(this._initialPhase);

  final PomodoroPhase _initialPhase;
  int tickCount = 0;

  @override
  PomodoroPhase build() => _initialPhase;

  @override
  Future<void> tick() async {
    tickCount++;
  }
}

/// `FocusSessionScreen` ağaca girer girmez `WakelockPlus.enable()` çağırıyor;
/// gerçek eklenti testte kayıtlı olmadığı için pigeon kanalı cevapsız kalıyor
/// ve `unawaited` çağrı yakalanmamış asenkron hataya dönüşüyor
/// (`countdown_navigation_test.dart`'taki aynı stub).
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

/// Uygulamayı gerçek router'ıyla ayağa kaldırır ve verilen fazla Ekran 03'e
/// gider: Ekran 02 açılışta `idle` olmayan fazı görüp odak ekranını `push`
/// ediyor (aktif seans kurtarma yolu). `pumpAndSettle` kullanılamıyor —
/// geri sayım halkasının `repeat()` animasyonu hiç durmuyor.
Future<_CountingPomodoroController> _pumpFocusSession(
  WidgetTester tester, {
  required PomodoroPhase phase,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final _CountingPomodoroController controller = _CountingPomodoroController(phase);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
  expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);
  return controller;
}

/// Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Sistem geri tuşu — `flutter/navigation` kanalının `popRoute` bildirimi,
/// gerçek cihazdaki yolun aynısı (`WidgetsBinding.handlePopRoute`).
Future<void> _pressSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (ByteData? _) {},
  );
}

SessionRingPainter _ringPainter(WidgetTester tester) {
  final CustomPaint ring = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint, skipOffstage: false))
      .firstWhere((CustomPaint paint) => paint.painter is SessionRingPainter);
  return ring.painter! as SessionRingPainter;
}

void main() {
  // Regresyon: halka bir dönem sabit `progress` ile çiziliyordu — dolan
  // süreyi göstermiyordu. Süresinin yarısı geçmiş bir odak fazı, halkanın
  // yarısı kadar dolu olmalı.
  testWidgets('odak halkası gerçek ilerlemeyi alıyor', (WidgetTester tester) async {
    await _pumpFocusSession(
      tester,
      phase: PomodoroPhase.focusRunning(
        sessionId: 1,
        examId: null,
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 12, seconds: 30)),
        plannedDurationSec: 25 * 60,
        cyclePosition: 1,
      ),
    );

    expect(_ringPainter(tester).progress, closeTo(0.5, 0.01));

    await _disposeTree(tester);
  });

  // Duraklatılmış faz ilerlemeyi "planlanan − duraklamadaki kalan" üzerinden
  // türetiyor; halka duraklatma anındaki doluluğunda kalmalı (gerçek zaman
  // akmaya devam ederken bile).
  testWidgets('duraklatılmış halka duraklama anındaki doluluğu koruyor', (WidgetTester tester) async {
    await _pumpFocusSession(
      tester,
      phase: PomodoroPhase.focusPaused(
        sessionId: 1,
        examId: null,
        startedAtUtc: DateTime.now().toUtc().subtract(const Duration(minutes: 20)),
        plannedDurationSec: 25 * 60,
        cyclePosition: 1,
        remainingAtPause: const Duration(minutes: 5),
      ),
    );

    final SessionRingPainter painter = _ringPainter(tester);
    expect(painter.progress, closeTo(0.8, 0.001));
    // Duraklatılmışken halka gradyan değil, düz renk (Ekran 03 "meşale soldu").
    expect(painter.gradientColors, isNull);
    expect(painter.solidColor, isNotNull);

    await _disposeTree(tester);
  });

  // Regresyon: tikleyici yalnızca `paused` durumunda durduruluyordu; iOS'ta
  // `inactive`te (uygulama değiştirici, gelen arama) ve pencere gizlendiğinde
  // (`hidden`) boşuna çalışmaya devam ediyordu. `resumed`de ise dönüş anında
  // bir "yakalama tiki" atılmalı — arka planda dolan faz orada kapanıyor.
  testWidgets('tikleyici resumed dışındaki durumlarda duruyor, dönüşte yakalama tiki atıyor',
      (WidgetTester tester) async {
    final _CountingPomodoroController controller = await _pumpFocusSession(
      tester,
      phase: PomodoroPhase.focusRunning(
        sessionId: 1,
        examId: null,
        startedAtUtc: DateTime.now().toUtc(),
        plannedDurationSec: 25 * 60,
        cyclePosition: 1,
      ),
    );

    final int beforeTicks = controller.tickCount;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.tickCount, beforeTicks + 2, reason: 'ön planda her saniye bir tik');

    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      final int stopped = controller.tickCount;
      await tester.pump(const Duration(seconds: 3));
      expect(controller.tickCount, stopped, reason: '$state durumunda tikleyici durmalı');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.tickCount, stopped + 1, reason: '$state → resumed dönüşünde yakalama tiki');
      await tester.pump(const Duration(seconds: 1));
      expect(controller.tickCount, stopped + 2, reason: 'dönüşte tikleyici yeniden kuruluyor');
    }

    await _disposeTree(tester);
  });

  // Geri tuşu seansı ekrandan düşürseydi Ekran 02'nin kurtarma yönlendirmesi
  // yalnızca `initState`te çalıştığı için süren seansa dönüş yolu kalmazdı.
  testWidgets('odak sürerken geri tuşu ekranı kapatmıyor, iptal onayını açıyor',
      (WidgetTester tester) async {
    await _pumpFocusSession(
      tester,
      phase: PomodoroPhase.focusRunning(
        sessionId: 1,
        examId: null,
        startedAtUtc: DateTime.now().toUtc(),
        plannedDurationSec: 25 * 60,
        cyclePosition: 1,
      ),
    );

    await _pressSystemBack(tester);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('SERİYİ KIRIYORSUN'), findsOneWidget);

    await _disposeTree(tester);
  });

  // Molanın kendi çıkışı var ("ODAĞA DÖN"); geri tuşu molayı da ekrandan
  // düşürmemeli, ama odak fazının iptal onayını da açmamalı.
  testWidgets('molada geri tuşu ekranı kapatmıyor', (WidgetTester tester) async {
    await _pumpFocusSession(
      tester,
      phase: PomodoroPhase.breakRunning(
        sessionId: 2,
        examId: null,
        isLong: false,
        startedAtUtc: DateTime.now().toUtc(),
        plannedDurationSec: 5 * 60,
        cyclePosition: 1,
        extensionsUsed: 0,
      ),
    );

    await _pressSystemBack(tester);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('SERİYİ KIRIYORSUN'), findsNothing);

    await _disposeTree(tester);
  });
}
