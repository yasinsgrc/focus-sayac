import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/features/countdown/widgets/countdown_ring_painter.dart';
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

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

/// Drift sorguları gerçek zamanda, widget ağacı sahte saatte ilerliyor
/// (gerekçe: `test/features/stats/stats_screen_test.dart`). Tohumlama bu yüzden
/// `runAsync` içinde bitiriliyor — aksi hâlde bir isolate'teki **ikinci** testte
/// göç tamamlanmadan kalıyor ve Ekran 02 aktif sınavsız çiziliyor.
Future<AppDatabase> _newSeededDatabase(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    return database;
  }))!;
}

Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(WidgetTester tester, {Map<String, Object> initialPrefs = const <String, Object>{}}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = await _newSeededDatabase(tester);
  SharedPreferences.setMockInitialValues(initialPrefs);
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await tester.pump();
  // Ölçümden önce ağaç tamamen durulmalı: sınav akışı ilk değerini yayınlamalı
  // **ve** (varsa) odak rotasının geçişi bitmeli — opaklık ancak `completed`
  // durumunda geri geliyor, o ana kadar Ekran 02 görünür sayılır. Sonradan
  // gelecek her yayın, ölçtüğümüz "yeniden kurulmadı"yı boşa çıkarırdı.
  await _settle(tester);
}

/// Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Odak ekranı `push` edildikten sonra geri sayım rotası **kapalı** kalıyor;
/// `Overlay` onu `debugVisitOnstageChildren`da atladığı için buradaki bütün
/// aramalar `skipOffstage: false` olmak zorunda. `Finder` sonucunu içinde
/// önbelleklediği için de her ölçümde yenisi kuruluyor (paylaşılan bir örnek
/// ikinci testte ilk testin çöpe gitmiş ağacını döndürüyordu).
Finder get _countdown => find.byType(CountdownScreen, skipOffstage: false);

final RegExp _clockPattern = RegExp(r'^\d{2}:\d{2}:\d{2}$');

/// Ekran 02'nin `hh:mm:ss` sayacının **widget nesnesi**. Ölçüt metnin kendisi
/// olamıyor: `_nowUtc` gerçek duvar saatinden okunuyor, testin sahte saati
/// saatlerce ilerlese de o metin değişmeyebilir. Nesne kimliği ise doğrudan
/// aranan şeyi söylüyor — tik `_CountdownBody.build`i yeniden koşturdu mu?
Text _countdownClockWidget(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(of: _countdown, matching: find.byType(Text, skipOffstage: false), skipOffstage: false),
      )
      .firstWhere((Text text) => text.data != null && _clockPattern.hasMatch(text.data!));
}

/// Halkanın kesik çizgili çemberinin dönüşü — `_dashController`dan geliyor,
/// yani dekoratif animasyonun ilerleyip ilerlemediğini gösteriyor.
double _dashRotation(WidgetTester tester) {
  final CustomPaint ring = tester
      .widgetList<CustomPaint>(
        find.descendant(of: _countdown, matching: find.byType(CustomPaint, skipOffstage: false), skipOffstage: false),
      )
      .firstWhere((CustomPaint paint) => paint.painter is CountdownRingPainter);
  return (ring.painter! as CountdownRingPainter).dashRotation;
}

String _persistedFocusPhase() {
  return jsonEncode(<String, Object?>{
    'type': 'focusRunning',
    'sessionId': 1,
    'examId': null,
    // Yeni başlamış seans: `tick()` onu testin ortasında tamamlayıp idle'a
    // düşürmesin diye planlanan süre tam duruyor.
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'plannedDurationSec': 25 * 60,
    'cyclePosition': 1,
  });
}

void main() {
  // Aşağıdaki "donuyor" testinin boş yere geçmediğini gösteren karşı kontrol:
  // ekran öndeyken sayaç da halka da ilerliyor.
  testWidgets('Ekran 02 önde iken saniye sayacı ve dekoratif halka ilerliyor', (WidgetTester tester) async {
    await _pumpApp(tester);

    final Text clockBefore = _countdownClockWidget(tester);
    final double dashBefore = _dashRotation(tester);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(identical(_countdownClockWidget(tester), clockBefore), isFalse, reason: 'tik gövdeyi yeniden kurmalı');
    expect(_dashRotation(tester), isNot(dashBefore));

    await _disposeTree(tester);
  });

  // SPEC.md §6 kural 4 + §10 DoD "Odak seansında dekoratif animasyonlar
  // duruyor". Odak ekranı Ekran 02'nin **üstüne** `push` ediliyor, Ekran 02 de
  // yığında kalıyor. Halkanın `AnimationController`ı `Overlay`in `TickerMode`u
  // sayesinde zaten susuyordu; `Timer.periodic` ise `TickerMode`a bakmadığı
  // için kapalı rota, odak ekranı 60 fps çizerken saniyede bir yeniden build +
  // layout olmaya devam ediyordu.
  testWidgets('odak seansı sürerken Ekran 02 tikleyicisi ve halkası duruyor', (WidgetTester tester) async {
    await _pumpApp(tester, initialPrefs: <String, Object>{kPomodoroPhasePrefsKey: _persistedFocusPhase()});

    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);

    final Text clockWhenCovered = _countdownClockWidget(tester);
    final double dashWhenCovered = _dashRotation(tester);

    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    expect(
      identical(_countdownClockWidget(tester), clockWhenCovered),
      isTrue,
      reason: 'kapalı rotanın saniye tikleyicisi durmalı — gövde yeniden kurulmamalı',
    );
    expect(_dashRotation(tester), dashWhenCovered, reason: 'kapalı rotanın dekoratif halkası durmalı');

    await _disposeTree(tester);
  });
}
