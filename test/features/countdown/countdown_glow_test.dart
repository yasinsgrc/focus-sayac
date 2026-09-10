import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/features/countdown/widgets/countdown_ring_painter.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// `FocusSessionScreen` ağaca girer girmez `WakelockPlus.enable()` çağırıyor;
/// gerçek eklenti testte kayıtlı olmadığı için pigeon kanalı cevapsız kalıyor
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

Future<void> _pumpApp(WidgetTester tester) async {
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
      ],
      child: const FocusSayacApp(),
    ),
  );
  await tester.pump();
  // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor
  // (`countdown_navigation_test.dart`'taki gerekçe).
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Bu dosyada **tek** test var ve bu bilerek: aynı isolate'teki ikinci testte
/// drift göçü tamamlanmadan kalıyor ve Ekran 02 aktif sınavsız çiziliyor
/// (`countdown_ticker_test.dart`'ta belgelenen tuzak) — o hâlde halka hiç
/// çizilmeyeceği için buradaki ölçüm anlamsızlaşırdı.
void main() {
  // Regresyon: mor hâle prototipten `top:60;left:-90` diye birebir alınmıştı.
  // O değerler 390px'lik mockup çerçevesine ve onun **çizilmeyen** 52px'lik
  // sahte durum çubuğuna göreydi, dolayısıyla gerçek cihazda parıltı halkanın
  // altına kayıyordu. Parıltı artık halkanın kendi `Stack`inde duruyor;
  // merkezleri hesapla değil tanım gereği aynı olmalı.
  testWidgets('mor hâle geri sayım halkasıyla eş merkezli', (WidgetTester tester) async {
    await _pumpApp(tester);

    final Finder ring = find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is CountdownRingPainter,
    );
    expect(ring, findsOneWidget);
    expect(find.byKey(kCountdownGlowKey), findsOneWidget);
    expect(tester.getCenter(find.byKey(kCountdownGlowKey)), tester.getCenter(ring));

    // Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
