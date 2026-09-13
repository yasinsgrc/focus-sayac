import 'dart:async';

import 'package:drift/drift.dart' show Value;
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
/// (`first_session_invite_test.dart` ile aynı gerekçe).
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
  // (`countdown_glow_test.dart`'ta belgelenen tuzak). Üç durum — hedefe
  // giderken, hedef tamamlanınca, hedef kapalı — bu yüzden tek akışta
  // geziliyor; ayar akışı (`watchSettings`) canlı olduğu için ekran her
  // yazımda kendiliğinden yeniden çiziliyor.
  testWidgets('haftalık hedef satırı: ilerleme, tamamlanma ve kapalı hâl',
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
      // Oran tween'i `AppMotion.slow` (420ms), o yüzden cömert pompalanıyor.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    // Haftalık pencerede 2 saat: 60 + 60 dk, ikisi de kayan yedi günün içinde.
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 1, minutes: 60),
      _focus(daysAgo: 2, minutes: 60),
    ]);
    await settle();

    // --- 1. Hedefe giderken: varsayılan 300 dk = 5 sa ------------------------
    expect(find.text('BU HAFTA'), findsOneWidget);
    expect(find.text('2sa / 5sa'), findsOneWidget);
    expect(find.byKey(kWeeklyGoalProgressKey), findsOneWidget);
    expect(find.text('Hedef tamam'), findsNothing);
    // Ekran okuyucu kısaltmayı değil sözü duyuyor.
    expect(
      find.bySemanticsLabel('Bu hafta 2 saat, haftalık hedef 5 saat'),
      findsOneWidget,
    );

    final LinearProgressIndicator bar =
        tester.widget<LinearProgressIndicator>(find.byKey(kWeeklyGoalProgressKey));
    // 120 / 300 = 0.4 — tween yerleştikten sonra.
    expect(bar.value, closeTo(0.4, 0.001));

    // --- 2. Hedef tamamlanınca ----------------------------------------------
    // Hedef 2 saate indiriliyor: biriken emek tam karşılıyor, yani sınır dahil
    // "ulaşıldı" olmalı.
    await tester.runAsync(() async {
      await database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(120)),
      );
    });
    await settle();

    expect(find.text('Hedef tamam'), findsOneWidget);
    expect(find.text('2sa / 2sa'), findsNothing);
    expect(
      find.bySemanticsLabel('Bu hafta 2 saat, haftalık hedef tamamlandı'),
      findsOneWidget,
    );
    expect(
      tester.widget<LinearProgressIndicator>(find.byKey(kWeeklyGoalProgressKey)).value,
      closeTo(1, 0.001),
    );

    // --- 3. Hedef kapalı -----------------------------------------------------
    // 0 = kapalı: satırın tamamı ağaçtan çıkıyor, "0 saat hedef" gibi bir
    // cümle kurulmuyor.
    await tester.runAsync(() async {
      await database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(0)),
      );
    });
    await settle();

    expect(find.byKey(kWeeklyGoalProgressKey), findsNothing);
    expect(find.text('BU HAFTA'), findsNothing);
    expect(find.text('Hedef tamam'), findsNothing);
    // Kartın geri kalanı yerinde — gizlenen yalnızca hedef satırı.
    expect(find.text('BUGÜN'), findsOneWidget);

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
