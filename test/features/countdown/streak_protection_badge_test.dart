import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
/// olacak şekilde kaldırır: seri hesabı yine üretimdeki `calculateStreakStatus`
/// üzerinden geçiyor, yalnızca girdisi kontrollü.
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

  // Yayın (`broadcast`) denetleyicisi değil: Riverpod akışa ilk kareden sonra
  // abone oluyor ve yayın denetleyicisi dinleyicisiz eklenen olayı düşürüyor —
  // seans listesi hiç ulaşmadığı için seri sıfır görünürdü.
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

/// Rozetin opaklık katmanı — alev de sayı da bunun içinde.
double _badgeOpacity(WidgetTester tester) {
  final Finder fade = find.ancestor(
    of: find.byIcon(PhosphorIconsFill.flame),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(fade.first).opacity;
}

void main() {
  // Bu dosyada tek bir test var: aynı isolate'teki ikinci testte drift göçü
  // tamamlanmadan kalıyor ve Ekran 02 aktif sınavsız çiziliyor
  // (`countdown_glow_test.dart`'ta belgelenen tuzak).
  testWidgets('kaçırılan gün seriyi kırmıyor; alev soluklaşıp geri parlıyor',
      (WidgetTester tester) async {
    // Dün boş, ondan öncesi dolu → haftalık telafi hakkı devrede.
    final List<PomodoroSession> protectedHistory = <PomodoroSession>[
      _focusDaysAgo(2),
      _focusDaysAgo(3),
      _focusDaysAgo(4),
    ];
    // ignore: close_sinks — sahibi `_pumpCountdown`'ın tear-down'ı.
    final StreamController<List<PomodoroSession>> sessions =
        await _pumpCountdown(tester, sessions: protectedHistory);
    // Rozetin metni `RollingNumber` içinde karakter karakter parçalandığı için
    // okunabilir tek bütün, anlamsal etiket.
    // `addTearDown` ile bırakılamıyor: çerçeve "tutamak sızdı" kontrolünü
    // tear-down'lardan **önce** yapıyor.
    final SemanticsHandle semantics = tester.ensureSemantics();

    // Seri 0'a düşmedi: rozet ağaçta ve gerçekten çalışılmış gün sayısını
    // gösteriyor (telafi günü sayıya eklenmiyor).
    expect(find.bySemanticsLabel('3 gün seri, korumada'), findsOneWidget);
    // Alev sönmedi, yalnızca soluklaştı.
    expect(find.byIcon(PhosphorIconsFill.flame), findsOneWidget);
    expect(_badgeOpacity(tester), lessThan(1));
    expect(_badgeOpacity(tester), greaterThan(0));
    expect(find.textContaining('seri korumada'), findsOneWidget);

    // Bugünkü tek pomodoro seriyi geri kazandırıyor.
    sessions.add(<PomodoroSession>[...protectedHistory, _focusDaysAgo(0)]);
    await tester.pump();
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.bySemanticsLabel('4 gün seri'), findsOneWidget);
    expect(_badgeOpacity(tester), 1);
    expect(find.textContaining('seri korumada'), findsNothing);

    semantics.dispose();
    // Denetleyici burada **kapatılmıyor**: `close()` ancak `done` olayı
    // aboneye ulaşınca tamamlanıyor, test gövdesinin sahte zaman kipinde ise
    // o olay pompalanmadan gelmiyor — bekleyiş kilitleniyordu. Kapatma
    // `_pumpCountdown`'daki tear-down'da, gerçek zamanda yapılıyor.
    // Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
