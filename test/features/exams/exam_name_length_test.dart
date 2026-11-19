import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/icons/app_icons.dart';
import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/features/exams/add_exam_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

const String _longName = 'Tıpta Uzmanlık Sınavı 2. Dönem Ek Oturum';

/// Ekran 02'yi gerçek telefon genişliğinde (390) kaldırır. [activeExamName]
/// verilirse aktif sınavın adı ona çevriliyor — sınır gelmeden önce
/// kaydedilmiş uzun bir adın durumu.
Future<void> _pumpCountdown(
  WidgetTester tester, {
  String? activeExamName,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late final AppDatabase database;
  late final SharedPreferences prefs;
  await tester.runAsync(() async {
    await initializeDateFormatting('tr_TR');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    // `onCreate` tohumlaması gerçek zamanda bitsin (sahte zamanda açılmıyor).
    await database.select(database.exams).get();
    if (activeExamName != null) {
      await (database.update(database.exams)..where(($ExamsTable t) => t.isActive.equals(true)))
          .write(ExamsCompanion(name: Value<String>(activeExamName)));
    }
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
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // H5: ad `Row` içinde `Flexible`/`ellipsis` olmadan duruyordu; uzun ad
  // sarı-siyah taşma şeridi veriyordu.
  testWidgets('uzun sınav adı geri sayım başlığını taşırmıyor', (WidgetTester tester) async {
    await _pumpCountdown(tester, activeExamName: _longName);

    expect(tester.takeException(), isNull);
    final Text title = tester.widget<Text>(find.text(_longName));
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.maxLines, 1);

    await _disposeTree(tester);
  });

  testWidgets('sınav adı alanı $kExamNameMaxLength karakterde duruyor', (WidgetTester tester) async {
    // Geniş yüzey: testte gerçek font yok, her karakter font boyu kadar kare
    // çiziliyor ve form satırları 390'da sahte taşma bildiriyor
    // (`no_active_exam_test.dart`teki gerekçe). Ölçülen şey uzunluk sınırı.
    await _pumpCountdown(tester, width: 700);

    await tester.tap(find.byIcon(AppIconsRegular.plus).first);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.enterText(find.byType(TextField).first, _longName);
    await tester.pump();

    final TextField field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text.length, kExamNameMaxLength);

    await _disposeTree(tester);
  });
}
