import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';
import 'package:focussayac/services/widgets/widget_launch_handler.dart';

/// Kotlin tarafinin `focussayac://widget/<yol>` bicimindeki dokunuslarini
/// `HomeWidget` eklentisi bir `EventChannel` (`home_widget/updates`) uzerinden
/// Dart'a tasiyor. Gercek eklenti testte kayitli olmadigi icin kanal burada
/// sahteleniyor: `onListen` cagrildiginda `_eventSink` yakalaniyor, testler
/// sonra bu sink'e dogrudan Uri string'i yazarak gercek bir widget dokunusunu
/// simule ediyor.
MockStreamHandlerEventSink? _eventSink;

void _stubHomeWidgetChannels() {
  const MethodChannel methodChannel = MethodChannel('home_widget');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    methodChannel,
    (MethodCall call) async {
      if (call.method == 'initiallyLaunchedFromHomeWidget') {
        // Soguk baslangicta widget uzerinden acilmadi: testler yalnizca
        // sicak dokunusu (`widgetClicked` akisi) kapsiyor.
        return null;
      }
      return null;
    },
  );

  const EventChannel eventChannel = EventChannel('home_widget/updates');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
    eventChannel,
    MockStreamHandler.inline(
      onListen: (Object? arguments, MockStreamHandlerEventSink events) {
        _eventSink = events;
      },
      onCancel: (Object? arguments) {
        _eventSink = null;
      },
    ),
  );

  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
    _eventSink = null;
  });
}

/// Uygulamayi gercek yonlendiricisi ve `WidgetLaunchScope` kabugu ile ayaga
/// kaldirir. `WidgetLaunchScope` normalde `main.dart`da `FocusSayacApp`in
/// disina sariliyor (Faz 16); testte de ayni saris tekrarlaniyor, yoksa
/// dokunus hic yakalanmaz.
Future<void> _pumpApp(WidgetTester tester) async {
  // Varsayilan test goruntu boyutu Ekran 02'nin govdesini tasiriyor
  // (`countdown_navigation_test.dart`daki ayni gerekce); asil ilgi konumuz
  // gezinme oldugu icin gercekci bir telefon boyutu yeterli.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  _stubHomeWidgetChannels();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(const <String, Object>{});
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
      child: const WidgetLaunchScope(child: FocusSayacApp()),
    ),
  );
  await tester.pump();
  // `WidgetLaunchScope` dinlemeyi ilk kareden sonra kuruyor
  // (`addPostFrameCallback`); dinleyici baglanana kadar birkac kare pompalanir.
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Kotlin'in gonderdigi Uri'yi dogrudan mock `EventChannel`a yazarak bir
/// widget dokunusunu simule eder.
Future<void> _tapWidgetUri(WidgetTester tester, Uri uri) async {
  expect(_eventSink, isNotNull, reason: 'WidgetLaunchScope akisa abone olmadi');
  _eventSink!.success(uri.toString());
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mesale widgetina dokunus rozetler ekranini aciyor', (WidgetTester tester) async {
    await _pumpApp(tester);
    expect(find.byType(CountdownScreen), findsOneWidget);

    // `/badges` taninmayan yol olarak kalirsa kullanici geri sayima duser —
    // widget'in vaat ettigi ekran acilmaz.
    await _tapWidgetUri(tester, Uri.parse('focussayac://widget/badges'));
    expect(find.byType(BadgesScreen), findsOneWidget);

    await _disposeTree(tester);
  });
}
