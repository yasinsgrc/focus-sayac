import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/features/stats/stats_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/ads/banner_ad_slot.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

import '../../support/recording_ad_service.dart';

/// Gerçek cihazlarda anchored adaptive banner çoğu telefonda 50 değil 90dp
/// dönüyor; yuvanın prototip yerleşimini taşırmadığı bu boyutla sınanıyor.
const AdSize _adaptiveSize = AdSize(width: 360, height: 90);

/// `countdown_navigation_test.dart`'taki aynı stub — Ekran 02 çizen her
/// testte wakelock pigeon kanalı cevapsız kalıyor.
void _stubWakelockChannel() {
  const String channel =
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    channel,
    (ByteData? message) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel, null),
  );
}

/// Gerekçe için bkz. `test/features/stats/stats_screen_test.dart` — drift
/// sorguları gerçek zamanda, widget ağacı sahte saatte ilerliyor.
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppDatabase> _newDatabase(WidgetTester tester, {bool premium = false}) async {
  return (await tester.runAsync(() async {
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    if (premium) {
      await database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(isPremium: Value<bool>(true)),
      );
    }
    return database;
  }))!;
}

Future<void> _pump(
  WidgetTester tester, {
  required AdService adService,
  required AppDatabase database,
  required Widget home,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(adService),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
      ],
      child: home,
    ),
  );
  await _settle(tester);
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // SPEC.md §7.1: banner yalnızca Ekran 02 ve Ekran 06.
  testWidgets('Ekran 02 banner istiyor ve adaptive yükseklik yerleşimi taşırmıyor',
      (WidgetTester tester) async {
    final RecordingAdService adService = RecordingAdService(resolvedBannerSize: _adaptiveSize);
    final AppDatabase database = await _newDatabase(tester);

    await _pump(tester, adService: adService, database: database, home: const FocusSayacApp());

    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(adService.bannerRequests, 1);
    // Yükseklik reklam gelmeden ayrılıyor: yüklenemeyen banner'da da yuva
    // aynı boyu koruyor (SPEC §7.1 "layout zıplamaz"). 88 alt gezinme
    // çubuğunun payı.
    expect(tester.getSize(find.byType(BannerAdSlot)).height, _adaptiveSize.height + 88);

    await _disposeTree(tester);
  });

  testWidgets('Ekran 06 banner istiyor', (WidgetTester tester) async {
    final RecordingAdService adService = RecordingAdService(resolvedBannerSize: _adaptiveSize);
    final AppDatabase database = await _newDatabase(tester);

    await _pump(
      tester,
      adService: adService,
      database: database,
      home: MaterialApp(theme: buildAppTheme(), home: const StatsScreen()),
    );

    expect(find.text('TOPLAM ODAK'), findsOneWidget);
    expect(adService.bannerRequests, 1);

    await _disposeTree(tester);
  });

  // SPEC.md §10 DoD: "`isPremium` iken hiçbir reklam isteği atılmıyor".
  testWidgets('premium kullanıcıda banner istenmiyor ve yuva kapanıyor',
      (WidgetTester tester) async {
    final RecordingAdService adService =
        RecordingAdService(isPremium: true, resolvedBannerSize: _adaptiveSize);
    final AppDatabase database = await _newDatabase(tester, premium: true);

    await _pump(tester, adService: adService, database: database, home: const FocusSayacApp());

    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(adService.totalRequests, 0);
    expect(tester.getSize(find.byType(BannerAdSlot)).height, 0);

    await _disposeTree(tester);
  });

  // Boyut sorgusu cevapsız kalırsa (kanal yok/hata) banner'dan vazgeçilmiyor;
  // prototipin 320×50'siyle isteniyor.
  testWidgets('adaptive boyut alınamazsa 320×50 ile isteniyor', (WidgetTester tester) async {
    final RecordingAdService adService = RecordingAdService();
    final AppDatabase database = await _newDatabase(tester);

    await _pump(
      tester,
      adService: adService,
      database: database,
      home: MaterialApp(theme: buildAppTheme(), home: const StatsScreen()),
    );

    expect(adService.bannerSizeRequests, 1);
    expect(adService.bannerRequests, 1);
    expect(tester.getSize(find.byType(BannerAdSlot)).height, kBannerSlotFallbackHeight + 88);

    await _disposeTree(tester);
  });
}
