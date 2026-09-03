import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/features/stats/stats_screen.dart';
import 'package:focussayac/features/stats/widgets/weekly_focus_bar_painter.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Gerekçe için bkz. `test/features/settings/settings_screen_test.dart` —
/// drift sorguları gerçek zamanda, widget ağacı sahte saatte ilerliyor.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<T> _read<T>(WidgetTester tester, Future<T> Function() query) async {
  return (await tester.runAsync(query)) as T;
}

Future<AppDatabase> _newDatabase(WidgetTester tester) {
  return _read(tester, () async {
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    return database;
  });
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _appWith(AppDatabase database, SharedPreferences prefs, Widget home) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
      onboardingCompletedAtLaunchProvider.overrideWithValue(true),
    ],
    child: home,
  );
}

/// Bugüne (`DateTime.now()`) düşen bir odak seansı yazar — ekranın "bugün"
/// sütunu ve kümülatif toplamı bu kayıtlardan türer.
Future<void> _addFocusSession(
  WidgetTester tester,
  AppDatabase database, {
  required int minutes,
  required bool completed,
}) {
  return _read(tester, () async {
    final DateTime startedAt = DateTime.now().toUtc();
    final int id = await database.pomodoroSessionDao.startSession(
      examId: null,
      type: SessionType.focus,
      startedAt: startedAt,
      plannedDurationSec: minutes * 60,
    );
    await database.pomodoroSessionDao.finishSession(
      id: id,
      completed: completed,
      endedAt: startedAt.add(Duration(minutes: minutes)),
    );
  });
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  group('formatBarValue', () {
    test('prototipin sütun etiketi biçimi', () {
      expect(formatBarValue(0), '—');
      expect(formatBarValue(50), '0s 50');
      expect(formatBarValue(95), '1s 35');
      expect(formatBarValue(120), '2s');
    });
  });

  testWidgets('alt çubuktaki grafik sekmesi istatistik ekranını açıyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_appWith(database, prefs, const FocusSayacApp()));
    await _settle(tester);
    expect(find.text('GÜN KALDI'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsRegular.chartBar));
    // Ekran 02'nin sonsuz-tekrarlı halka animasyonu `pumpAndSettle`i engelliyor.
    await _settle(tester, rounds: 8);

    expect(find.text('TOPLAM ODAK'), findsOneWidget);
    // Ekran 06 açıkken aktif hap "VERİLER" yuvasına geçiyor (prototip v2 281).
    expect(find.text('VERİLER'), findsOneWidget);
    expect(find.text('SAYAÇ'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('sayılar seans kayıtlarından geliyor, prototipin demo değerleri yok',
      (WidgetTester tester) async {
    _usePhoneSurface(tester);
    final AppDatabase database = await _newDatabase(tester);
    // 3 tamamlanmış saat + 1 iptal → 3 SAAT, %75, 1 günlük seri.
    for (int i = 0; i < 3; i++) {
      await _addFocusSession(tester, database, minutes: 60, completed: true);
    }
    await _addFocusSession(tester, database, minutes: 60, completed: false);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWith(database, prefs, MaterialApp(theme: buildAppTheme(), home: const StatsScreen())),
    );
    await _settle(tester);

    expect(find.text('3 SAAT'), findsOneWidget);
    // 180 dk / 7 gün = 25 dk (tam sayı bölümü).
    expect(find.text('Son 7 gün · günlük ortalama 25 dk'), findsOneWidget);
    expect(find.text('1 GÜN'), findsOneWidget);
    expect(find.text('%75'), findsOneWidget);
    // Dört seans da aynı saat kovasında → aralık satırı görünür.
    expect(find.textContaining('tamamlanma %75.'), findsOneWidget);

    // SPEC DoD: demo sayılarının hiçbiri kodda yok.
    expect(find.text('42 SAAT'), findsNothing);
    expect(find.text('11 GÜN'), findsNothing);
    expect(find.text('%86'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('veri yokken sıfırlar gösteriliyor, verimli aralık satırı çizilmiyor',
      (WidgetTester tester) async {
    _usePhoneSurface(tester);
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWith(database, prefs, MaterialApp(theme: buildAppTheme(), home: const StatsScreen())),
    );
    await _settle(tester);

    expect(find.text('0 DAKİKA'), findsOneWidget);
    expect(find.text('0 GÜN'), findsOneWidget);
    // Hiç seans yokken oran tanımsız — `%0` yanıltıcı olurdu.
    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('En verimli aralığın'), findsNothing);

    await _disposeTree(tester);
  });
}
