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
import 'package:focussayac/features/countdown/widgets/countdown_ring_painter.dart';
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

/// Ekranda tek bir geri sayım halkası var; testler yayların oranını doğrudan
/// painter'dan okuyor — `Canvas`a çizilen yayı piksel piksel doğrulamak yerine
/// painter'ın **sözleşmesini** çiviliyoruz (`countdown_glow_test.dart` ile aynı
/// finder kalıbı).
CountdownRingPainter _ring(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is CountdownRingPainter,
    ),
  );
  return paint.painter! as CountdownRingPainter;
}

void main() {
  // Tek test: aynı isolate'teki ikinci testte drift göçü tamamlanmadan kalıyor
  // (`countdown_glow_test.dart`'ta belgelenen tuzak). Üç durum — hedefe
  // giderken, hedef dolunca, hedef kapalı — tek akışta geziliyor.
  testWidgets('emek yayı: haftalık hedefi izliyor, zaman yayına dokunmuyor',
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
      // İki oran da `AppMotion.slow` (420ms) ile akıyor, cömert pompalanıyor.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    // Haftalık pencerede 2 saat; ikisi de kayan yedi günün içinde.
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 1, minutes: 60),
      _focus(daysAgo: 2, minutes: 60),
    ]);
    await settle();

    // --- 1. Hedefe giderken: varsayılan 300 dk = 5 sa ------------------------
    // 120 / 300 = 0.4 — `_WeeklyGoalRow`un çubuğuyla **aynı** sayı; halka ile
    // kartın satırı aynı kaynaktan besleniyor, ayrışamazlar.
    expect(_ring(tester).effortRatio, closeTo(0.4, 0.001));
    expect(_ring(tester).effortReached, isFalse);

    // Zaman ekseni bu maddede değişmiyor: emek yayı onun **yanına** geliyor.
    final double timeRatio = _ring(tester).progressRatio;

    // --- 2. Hedef dolunca ----------------------------------------------------
    // Hedef 2 saate indiriliyor: biriken emek tam karşılıyor, sınır dahil.
    await tester.runAsync(() async {
      await database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(120)),
      );
    });
    await settle();

    expect(_ring(tester).effortRatio, closeTo(1, 0.001));
    // Ton közden naneye dönüyor — uygulamanın tamamlanma dili
    // (`_WeeklyGoalRow` ile aynı).
    expect(_ring(tester).effortReached, isTrue);
    expect(_ring(tester).progressRatio, closeTo(timeRatio, 0.001));

    // --- 3. Hedef kapalı -----------------------------------------------------
    // 0 = kapalı: yay hiç çizilmiyor. `0.0` değil **`null`** — sıfır dolu bir
    // yay "hedefinin %0'ındasın" der, oysa kullanıcının hedefi yok.
    await tester.runAsync(() async {
      await database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(weeklyGoalMinutes: Value<int>(0)),
      );
    });
    await settle();

    expect(_ring(tester).effortRatio, isNull);
    expect(_ring(tester).effortReached, isFalse);
    // Zaman yayı hedef kapalıyken de yerinde: halka boşalmıyor.
    expect(_ring(tester).progressRatio, closeTo(timeRatio, 0.001));

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
