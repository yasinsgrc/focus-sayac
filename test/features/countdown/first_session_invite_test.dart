import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

int _id = 0;

/// [daysAgo] gün önce tamamlanmış bir odak seansı. Tam 24 saatlik adımlar
/// kullanıldığı için testin çalıştığı saat 04:00 TSİ sınırının hangi
/// tarafında olursa olsun gün ofsetleri aynı kalıyor.
PomodoroSession _focusDaysAgo(int daysAgo) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
    plannedDurationSec: 25 * 60,
    completed: true,
    breakExtensions: 0,
  );
}

/// Ekran 02'yi gerçek sınav veritabanıyla, ama seans akışı testin elinde
/// olacak şekilde kaldırır (`streak_protection_badge_test.dart` ile aynı
/// kurulum; oradaki `broadcast` ve `close()` tuzakları da aynen geçerli).
Future<StreamController<List<PomodoroSession>>> _pumpCountdown(
  WidgetTester tester, {
  required List<PomodoroSession> sessions,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final StreamController<List<PomodoroSession>> controller =
      StreamController<List<PomodoroSession>>();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
        allSessionsProvider.overrideWith((Ref ref) => controller.stream),
      ],
      child: const FocusSayacApp(),
    ),
  );
  controller.add(sessions);
  await tester.pump();
  // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor
  // (`countdown_glow_test.dart`'taki gerekçe).
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return controller;
}

void main() {
  // Tek test: aynı isolate'teki ikinci testte drift göçü tamamlanmadan kalıyor
  // (`countdown_glow_test.dart`'ta belgelenen tuzak).
  testWidgets('gün boşken kart eksik değil kazanç gösteriyor',
      (WidgetTester tester) async {
    // Dün ve öncesi dolu, bugün henüz boş → seri 3, koruma devrede değil.
    final List<PomodoroSession> history = <PomodoroSession>[
      _focusDaysAgo(1),
      _focusDaysAgo(2),
      _focusDaysAgo(3),
    ];
    // ignore: close_sinks — sahibi `_pumpCountdown`'ın tear-down'ı.
    final StreamController<List<PomodoroSession>> sessions =
        await _pumpCountdown(tester, sessions: history);

    // Vaat ileriye bakıyor: bugünkü seans seriyi bir gün ileri taşıyor.
    expect(
      find.textContaining('Bugünkü ilk seansın seni 4 günlük seriye taşır.'),
      findsOneWidget,
    );
    // Eksik bildiren ikili ağaçta yok: ne 0/4 noktaları ne de %0 çubuğu.
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // Bugünkü ilk pomodoro tamamlanınca ilerleme gerçek bir sayı oluyor;
    // davet yerini ona bırakıyor.
    sessions.add(<PomodoroSession>[...history, _focusDaysAgo(0)]);
    await tester.pump();
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('Bugünkü ilk seansın'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
