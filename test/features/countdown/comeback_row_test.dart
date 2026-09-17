import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

int _id = 0;

/// [daysAgo] gün önce tamamlanmış, [minutes] dakikalık bir odak seansı.
/// Tam 24 saatlik adımlar 04:00 TSİ gün sınırından bağımsız kalıyor
/// (`weekly_goal_row_test.dart` ile aynı gerekçe).
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
  // Tek test: aynı isolate'teki ikinci testte drift göçü tamamlanmadan kalıyor
  // (`countdown_glow_test.dart`'ta belgelenen tuzak). Üç durum tek akışta
  // geziliyor; `allSessionsProvider` denetleyici üzerinden beslendiği için
  // ekran her yazımda kendiliğinden yeniden çiziliyor.
  testWidgets('dönüş şeridi: yoklukta görünür, eşiğin altında ve dönüşte yok',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
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
          adServiceProvider.overrideWithValue(AdService.disabled()),
          notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
          allSessionsProvider.overrideWith((Ref ref) => sessions.stream),
        ],
        child: const FocusSayacApp(),
      ),
    );

    Future<void> settle() async {
      await tester.pump();
      // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    // --- 1. Üç seans, sonuncusu dört gün önce: şerit açık --------------------
    // Kümülatif 3 saat (60+60+60 dk) → `kFlameTierLadder`ın K3 eşiği tam 3
    // saat, yani kademe "Kandil".
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 5, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsOneWidget);
    expect(find.text('TEKRAR HOŞ GELDİN'), findsOneWidget);
    expect(find.text('Kandil kademen ve 3 saat yerinde duruyor.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tekrar hoş geldin. Kandil kademen ve 3 saat yerinde duruyor.'),
      findsOneWidget,
    );

    // --- 2. İki seans: eşiğin altındaki kullanıcı kapsam dışı ---------------
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsNothing);
    expect(find.text('TEKRAR HOŞ GELDİN'), findsNothing);
    // Kartın geri kalanı yerinde — gizlenen yalnızca dönüş şeridi.
    expect(find.text('BUGÜN'), findsOneWidget);

    // --- 3. Kullanıcı bugün çalıştı: şerit kendiliğinden kapanıyor ----------
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 5, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
      _focus(daysAgo: 0, minutes: 25),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsNothing);
    expect(find.text('BUGÜN'), findsOneWidget);

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
