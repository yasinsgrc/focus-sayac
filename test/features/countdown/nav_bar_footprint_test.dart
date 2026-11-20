import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/widgets/bottom_nav_bar.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/ads/banner_ad_slot.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

int _id = 0;

PomodoroSession _focus({required int daysAgo, required int minutes}) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
  );
}

void main() {
  // ROADMAP madde 36 — madde 29'un Ekran 06'da düzeltip Ekran 02'de açık
  // bıraktığı kusur: alt gezinme çubuğunun payı `BannerAdSlot`ın
  // `bottomMargin`ine bağlıydı ve yuva reklam **hiç istenmediğinde** (premium
  // ya da UMP onayı yok) tamamen kapanıp payı da götürüyordu. Düzeltmeden önce
  // ölçülen fark −82px: ODAKLAN'ın tamamı opak çubuğun arkasındaydı ve
  // kaydırarak kurtarılamıyordu.
  //
  // **Tek `testWidgets`, tek `pumpWidget`:** aynı dosyada ikinci bir test — ve
  // hatta aynı testte ikinci bir `pumpWidget` — drift göçünü yarıda bırakıyor,
  // ekran `CircularProgressIndicator`da donuyor ve koşum 10 dakikada zaman
  // aşımına düşüyor. Bu dosyanın ilk iki hâli sırayla tam olarak buna düştü;
  // tuzak `countdown_glow_test.dart` ve `weekly_goal_row_test.dart`te de
  // belgeli.
  testWidgets('reklam istenmezken ODAKLAN alt çubuğun arkasında kalmıyor',
      (WidgetTester tester) async {
    // 390x640: madde 24'ün ölçtüğü 390x844'ten kısa bir gövde. Kusur ancak
    // içerik ekrandan uzunken — yani kaydırma gerçekten devreye girince —
    // görünüyor; uzun ekranda altta zaten boşluk kalıyor.
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    // Veritabanı sahte zaman kuşağının **dışında** kuruluyor: fake-time altında
    // açılan `NativeDatabase` göçü bitiremiyor ve ekran veriye hiç ulaşamıyor.
    late final AppDatabase database;
    await tester.runAsync(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // ignore: close_sinks — sahibi aşağıdaki tear-down.
    final StreamController<List<PomodoroSession>> sessions =
        StreamController<List<PomodoroSession>>();
    addTearDown(sessions.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Kusurun koşulu: `canRequestAds()` her zaman false → yuva
          // `SizedBox.shrink()`e iniyor ve eski kodda payı da götürüyordu.
          adServiceProvider.overrideWithValue(AdService.disabled()),
          notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
          allSessionsProvider.overrideWith((Ref ref) => sessions.stream),
        ],
        child: const FocusSayacApp(),
      ),
    );

    // Kartın en uzun hâli çizilsin: tamamlanmış seans olunca döngü noktaları,
    // ilerleme çubuğu ve haftalık hedef satırı da ağaca giriyor.
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 1, minutes: 60),
      _focus(daysAgo: 2, minutes: 60),
    ]);

    Future<void> settle() async {
      await tester.pump();
      // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor
      // (`weekly_goal_row_test.dart` ile aynı gerekçe).
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await settle();

    final Finder scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget,
        reason: 'Ekran 02 çizilmedi — gövde yerine yükleniyor hâli kaldıysa '
            'aşağıdaki iddialar boşa koşar');

    // Kaydırmayı sonuna kadar götür: kusur tam olarak "sonuna gelindiğinde ne
    // görünüyor" sorusu. Büyük ofset kendiliğinden azami menzile kırpılıyor.
    await tester.drag(scrollView, const Offset(0, -2000));
    await settle();

    // Testin boşa koşmasına karşı: içerik sığsaydı kaydırma hiç devreye girmez,
    // CTA da zaten çubuğun çok üstünde kalırdı ve asıl iddia kusuru göremezdi.
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(of: scrollView, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0),
        reason: 'gövde bu ekranda kaymıyor — kusurun koşulu kurulmadı');

    // Asıl iddia: kaydırmanın sonunda ekranın birincil eylemi çubuğun üstünde.
    final double gap = tester.getRect(find.byType(BottomNavBar)).top -
        tester.getRect(find.byKey(kFocusCtaKey)).bottom;
    expect(gap, greaterThanOrEqualTo(0),
        reason: 'ODAKLAN kaydırmanın sonunda alt çubuğun arkasında kalıyor');

    // Karşı kontrol — kusurun **mekanizması**: pay yuvaya geri bağlanırsa
    // reklam kapalıyken yine yok olur. Reklamın istendiği hâl ayrıca
    // ölçülmüyor; orada yuva kendi yüksekliğini de eklediği için ayrılan alan
    // yalnızca **artıyor**, yani bu iddiayı geçen yerleşim orada da geçiyor.
    // (Ayrı bir `pumpWidget` yukarıdaki drift tuzağını tetikliyor.)
    final BannerAdSlot slot = tester.widget<BannerAdSlot>(find.byType(BannerAdSlot));
    expect(slot.bottomMargin, 0,
        reason: 'çubuğun payı yuvaya değil yerleşime ait olmalı');

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
