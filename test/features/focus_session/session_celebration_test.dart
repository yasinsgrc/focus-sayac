import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/badges/badge_definition.dart';
import 'package:focussayac/domain/celebration/session_celebration.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_phase.dart';
import 'package:focussayac/domain/story_card/story_card_text.dart';
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/features/focus_session/widgets/flame_tier_celebration_dialog.dart';
import 'package:focussayac/features/focus_session/widgets/streak_celebration_dialog.dart';
import 'package:focussayac/features/story_card/story_card_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Fazı testin sürdüğü controller (`session_completion_test.dart`taki aynı
/// kalıp): buradaki soru kutlamanın **ekranda açılıp açılmadığı**, gerçek faz
/// geçişinin yan etkileri değil.
class _ScriptedPomodoroController extends PomodoroController {
  @override
  PomodoroPhase build() => PomodoroPhase.breakRunning(
        sessionId: 1,
        examId: null,
        isLong: false,
        startedAtUtc: DateTime.now().toUtc(),
        plannedDurationSec: 5 * 60,
        cyclePosition: 1,
        extensionsUsed: 0,
      );

  @override
  Future<void> tick() async {}
}

/// Ekran ağaca girer girmez `WakelockPlus.enable()` çağırıyor, gerçek eklenti
/// testte kayıtlı değil.
void _stubWakelockChannel() {
  const String channel = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    channel,
    (ByteData? message) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, null),
  );
}

/// Kutlama mola gövdesinin üstünde açılıyor (odak bitti, faz artık mola).
Future<ProviderContainer> _pumpBreak(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
        pomodoroControllerProvider.overrideWith(_ScriptedPomodoroController.new),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);
  return ProviderScope.containerOf(tester.element(find.byType(FocusSessionScreen)));
}

/// Kutlama, halkanın közden naneye döndüğü pencereden **sonra** açılıyor
/// (`_showCelebration`in gecikmesi); testler o pencereyi geçiyor.
Future<void> _settleCelebration(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppMotion.slow);
  await tester.pump(AppMotion.base);
  await tester.pump(AppMotion.entrance);
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // ROADMAP: "Paylaşım kartı ayrı bir ekranda, kullanıcının gidip araması
  // gerekiyor. Rozet açılışında / uzun seriden hemen sonra doğrudan önerin."
  // Rozet açılışı eskiden yalnızca bildirim gönderiyordu; uygulama içinde o an
  // hiç kutlanmıyordu.

  testWidgets('seri eşiği kutlaması mola gövdesinin üstünde açılıyor', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpBreak(tester);

    container.read(sessionCelebrationProvider.notifier).offer(const StreakCelebration(days: 7));
    await _settleCelebration(tester);

    expect(find.byKey(kStreakCelebrationHaloKey, skipOffstage: false), findsOneWidget);
    expect(find.text('7 GÜN'), findsOneWidget);
    // Kutlamanın tek işi paylaşımı o anda önermek.
    expect(find.text('BAŞARI KARTINI OLUŞTUR'), findsOneWidget);
    // Yuva boşaltıldı: ekran yeniden çizilince kutlama ikinci kez açılmamalı.
    expect(container.read(sessionCelebrationProvider), isNull);

    await _disposeTree(tester);
  });

  testWidgets('kutlamanın düğmesi SERİ şablonuyla başarı kartını açıyor', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpBreak(tester);

    container.read(sessionCelebrationProvider.notifier).offer(const StreakCelebration(days: 30));
    await _settleCelebration(tester);

    await tester.tap(find.text('BAŞARI KARTINI OLUŞTUR'));
    await tester.pump();
    await tester.pump(AppMotion.base);

    final Finder card = find.byType(StoryCardScreen, skipOffstage: false);
    expect(card, findsOneWidget);
    // "30 gün" diye kutlanıp bugünün saatini gösteren bir kart açmak tutarsız
    // olurdu; öneri kalıcı tercihe **yazılmıyor**, yalnızca bu açılışta geçerli.
    expect(tester.widget<StoryCardScreen>(card).initialTemplate, StoryCardTemplate.streak);

    await _disposeTree(tester);
  });

  testWidgets('rozet açılışı kutlama anında dialogu açıyor', (WidgetTester tester) async {
    final ProviderContainer container = await _pumpBreak(tester);

    container
        .read(sessionCelebrationProvider.notifier)
        .offer(const BadgeCelebration(<String>[BadgeKeys.firstSpark]));
    await _settleCelebration(tester);

    // Ekran 04'ün dialogu, "Açıldı · …" gövdesiyle (kilitli hâli değil).
    expect(find.text('İlk Kıvılcım'), findsOneWidget);
    expect(find.text('Açıldı · İlk tamamlanan pomodoro'), findsOneWidget);
    expect(find.text('BAŞARI KARTINI OLUŞTUR'), findsOneWidget);
    expect(container.read(sessionCelebrationProvider), isNull);

    await _disposeTree(tester);
  });

  // ROADMAP madde 34: kademe atlaması yalnızca rozetler ekranına girilirse
  // görülüyordu; kazanım anları kutlanırken kademe o listede yoktu.

  testWidgets('kademe atlaması kutlaması alevi yeni kademesinde gösteriyor',
      (WidgetTester tester) async {
    final ProviderContainer container = await _pumpBreak(tester);

    // K4 "Fener" — 10 saatlik eşik, merdivenin rozetle çakışan kademelerinden.
    final FlameTier tier = kFlameTierLadder.firstWhere((FlameTier t) => t.index == 4);
    container.read(sessionCelebrationProvider.notifier).offer(FlameTierCelebration(tier: tier));
    await _settleCelebration(tester);

    expect(find.byKey(kFlameTierCelebrationHaloKey, skipOffstage: false), findsOneWidget);
    expect(find.text('KADEME 4'), findsOneWidget);
    expect(find.text('Fener'), findsOneWidget);
    // Ödülün kendisi çiziliyor: dairenin içindeki alev **o** kademenin alevi.
    expect(tester.widget<FlameWidget>(find.byType(FlameWidget)).tier, same(tier));
    expect(find.text('BAŞARI KARTINI OLUŞTUR'), findsOneWidget);
    expect(container.read(sessionCelebrationProvider), isNull);

    await _disposeTree(tester);
  });

  testWidgets('kademe kutlamasının düğmesi şablon zorlamadan kartı açıyor',
      (WidgetTester tester) async {
    final ProviderContainer container = await _pumpBreak(tester);

    container.read(sessionCelebrationProvider.notifier).offer(
          FlameTierCelebration(tier: kFlameTierLadder.firstWhere((FlameTier t) => t.index == 2)),
        );
    await _settleCelebration(tester);

    await tester.tap(find.text('BAŞARI KARTINI OLUŞTUR'));
    await tester.pump();
    await tester.pump(AppMotion.base);

    final Finder card = find.byType(StoryCardScreen, skipOffstage: false);
    expect(card, findsOneWidget);
    // Kartın üç şablonundan hiçbiri kademeyi göstermiyor; seri kutlamasının
    // aksine önerilecek bir şablon yok, kullanıcının seçtiği kart açılıyor.
    expect(tester.widget<StoryCardScreen>(card).initialTemplate, equals(null));

    await _disposeTree(tester);
  });

  testWidgets('kutlama yokken dialog açılmıyor', (WidgetTester tester) async {
    // Karşı kontrol: yukarıdaki üç test yalnızca "dialog her zaman açık" olduğu
    // için de geçebilirdi.
    await _pumpBreak(tester);
    await _settleCelebration(tester);

    expect(find.byKey(kStreakCelebrationHaloKey, skipOffstage: false), findsNothing);
    expect(find.byKey(kFlameTierCelebrationHaloKey, skipOffstage: false), findsNothing);
    expect(find.text('BAŞARI KARTINI OLUŞTUR'), findsNothing);

    await _disposeTree(tester);
  });
}
