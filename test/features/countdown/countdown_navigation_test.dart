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
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// `FocusSessionScreen` ağaca girer girmez `WakelockPlus.enable()` çağırıyor.
/// Testte gerçek eklenti kayıtlı olmadığı için pigeon kanalı cevapsız kalıyor
/// ve `PlatformException(channel-error)` fırlatıyor — çağrı `unawaited`
/// olduğundan bu, testi düşüren yakalanmamış asenkron hataya dönüşüyor.
/// Boş bir başarı cevabı (`[null]`, pigeon'un `isNullValid: true` beklediği
/// biçim) stub'lanıyor. Kanal adı pigeon'un ürettiği sabittir.
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

/// Uygulamayı gerçek router'ıyla ayağa kaldırır. `pumpAndSettle`
/// kullanılmıyor: geri sayım halkasının `repeat()` animasyonu hiç "settle"
/// olmaz (widget_test.dart'taki aynı gerekçe), bunun yerine DB tohumlama +
/// stream yayını ve bekleyen `postFrameCallback`ler için birkaç kare
/// pompalanıyor.
Future<void> _pumpApp(WidgetTester tester, {Map<String, Object> initialPrefs = const <String, Object>{}}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(initialPrefs);
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        // Faz 10: test edilen akış Ekran 02'den başlıyor — onboarding'i
        // tamamlamış kullanıcının açılışı.
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur
/// (widget_test.dart'taki drift kapatma gerekçesinin aynısı geçerli).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"25 DAKİKA ODAKLAN" yığına tek bir FocusSessionScreen ekler', (WidgetTester tester) async {
    await _pumpApp(tester);
    expect(find.text('25 DAKİKA ODAKLAN'), findsOneWidget);

    await tester.tap(find.text('25 DAKİKA ODAKLAN'));
    // Buton `startFocus()`ü await ediyor (DB yazımı + bildirim); ardından
    // gelen `push` bir sonraki karede işleniyor.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Regresyon: buton `push` ederken `CountdownScreen`in "aktif seans
    // kurtarma" bloğu da faz değişimini görüp ikinci bir push planlıyordu.
    // İki kopya olduğunda seans bitişindeki tek `pop()` yalnızca üsttekini
    // kapatıyor, kullanıcı boş (PomodoroIdle → SizedBox.shrink) bir odak
    // ekranında kalıyordu.
    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);

    await _disposeTree(tester);
  });

  // Yukarıdaki regresyonun düzeltmesi kurtarma yönlendirmesini `build()`ten
  // `initState()`e taşıdı — SPEC.md DoD "Uygulama öldürülüp açıldığında aktif
  // seans kurtarılıyor" davranışının hâlâ çalıştığı burada doğrulanıyor.
  testWidgets('soğuk başlangıçta kurtarılan aktif seans odak ekranını bir kez açar', (WidgetTester tester) async {
    final String persistedPhase = jsonEncode(<String, Object?>{
      'type': 'focusRunning',
      'sessionId': 1,
      'examId': null,
      // Yeni başlamış bir seans: `tick()` onu anında tamamlayıp idle'a
      // düşürmesin diye planlanan süre tam olarak duruyor.
      'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'plannedDurationSec': 25 * 60,
      'cyclePosition': 1,
    });

    await _pumpApp(tester, initialPrefs: <String, Object>{kPomodoroPhasePrefsKey: persistedPhase});

    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);

    await _disposeTree(tester);
  });
}
