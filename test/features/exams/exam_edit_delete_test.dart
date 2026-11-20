import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

const String _userExamName = 'Ehliyet';

/// Ekran 02'yi kaldırır, aktif olmayan bir kullanıcı sınavı ekler ve sınav
/// seçiciyi açar. Geniş yüzey: testte gerçek font yok, form satırları dar
/// ekranda sahte taşma bildiriyor (bkz. `exam_name_length_test.dart`).
Future<(AppDatabase, String)> _openPicker(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late final AppDatabase database;
  late final SharedPreferences prefs;
  late final String activeName;
  await tester.runAsync(() async {
    await initializeDateFormatting('tr_TR');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    activeName = (await database.examDao.getActiveExam())!.name;
    await database.examDao.insertUserExam(
      name: _userExamName,
      subtitle: null,
      // TR 10:00 = UTC 07:00, `timeOfDay` ile tutarlı.
      dateUtc: () {
        final DateTime d = DateTime.now().toUtc().add(const Duration(days: 40));
        return DateTime.utc(d.year, d.month, d.day, 7);
      }(),
      timeOfDay: '10:00',
      accentRole: ExamAccentRole.mint,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

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
  await _settle(tester);

  await tester.tap(find.text(activeName).first);
  await _settle(tester);
  return (database, activeName);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> _openActions(WidgetTester tester) async {
  await tester.longPress(find.text(_userExamName));
  await _settle(tester);
}

void main() {
  testWidgets('özel sınava uzun basıp onaylayınca sınav siliniyor (H4)', (WidgetTester tester) async {
    final (AppDatabase database, _) = await _openPicker(tester);

    await _openActions(tester);
    await tester.tap(find.text('Sil'));
    await _settle(tester);
    expect(find.text('SINAV SİLİNECEK'), findsOneWidget);

    await tester.tap(find.text('Sınavı sil'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await _settle(tester);

    final List<Exam> exams =
        await tester.runAsync(() => database.select(database.exams).get()) ?? <Exam>[];
    expect(exams.where((Exam e) => e.name == _userExamName), isEmpty);

    await _disposeTree(tester);
  });

  testWidgets('silme onayında vazgeçince sınav kalıyor (H4)', (WidgetTester tester) async {
    await _openPicker(tester);

    await _openActions(tester);
    await tester.tap(find.text('Sil'));
    await _settle(tester);
    await tester.tap(find.text('VAZGEÇ'));
    await _settle(tester);

    expect(find.text('SINAV SİLİNECEK'), findsNothing);
    expect(find.text(_userExamName), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('Düzenle ekranı sınavın değerleriyle dolu açılıyor (H4)', (WidgetTester tester) async {
    await _openPicker(tester);

    await _openActions(tester);
    await tester.tap(find.text('Düzenle'));
    await _settle(tester);

    expect(find.text('SINAVI DÜZENLE'), findsOneWidget);
    final TextField nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller!.text, _userExamName);
    expect(find.text('10:00'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('hazır sınava uzun basmak menü açmıyor (H4)', (WidgetTester tester) async {
    final (_, String activeName) = await _openPicker(tester);

    // Aktif sınav bir preset; adı hem başlıkta hem listede geçiyor.
    await tester.longPress(find.text(activeName).last, warnIfMissed: false);
    await _settle(tester);

    expect(find.text('Düzenle'), findsNothing);

    await _disposeTree(tester);
  });
}
