import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/subjects/subject_catalog.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/features/countdown/widgets/subject_picker_sheet.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// ROADMAP madde 30 — Ekran 02'nin ders hapı ve alt sayfası.
///
/// Tek test: aynı isolate'teki ikinci testte drift göçü tamamlanmadan kalıyor
/// (`weekly_goal_row_test.dart`'ta belgelenen tuzak). Üç aşama — davet, seçim,
/// temizleme — bu yüzden tek akışta geziliyor; ayar akışı (`watchSettings`)
/// canlı olduğu için hap her yazımda kendiliğinden yeniden çiziliyor.
void main() {
  testWidgets('ders hapı: davet, seçim ve temizleme', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

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

    Future<void> settle() async {
      await tester.pump();
      // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await settle();

    // --- 1. Ders seçilmemişken hap bir davet ---------------------------------
    expect(find.byKey(kSubjectPillKey), findsOneWidget);
    expect(find.text('Ders seç'), findsOneWidget);
    expect(find.bySemanticsLabel('Seçili ders Ders seç. Değiştirmek için dokun.'), findsOneWidget);

    // --- 2. Alt sayfa aktif sınavın (YKS seed'i) katalogunu açıyor -----------
    await tester.tap(find.byKey(kSubjectPillKey));
    await settle();

    expect(find.text('DERS SEÇ'), findsOneWidget);
    expect(find.byKey(subjectChipKey(SubjectKeys.chemistry)), findsOneWidget);
    // YKS katalogunda olmayan ders alt sayfada da yok.
    expect(find.byKey(subjectChipKey(SubjectKeys.citizenship)), findsNothing);

    await tester.tap(find.byKey(subjectChipKey(SubjectKeys.chemistry)));
    await settle();

    // Seçim ayara yazıldı, hap kendiliğinden yenilendi ve alt sayfa kapandı.
    expect((await database.appSettingsDao.getSettings()).activeSubjectKey, 'chemistry');
    expect(find.text('DERS SEÇ'), findsNothing);
    expect(find.text('Kimya'), findsOneWidget);
    expect(find.text('Ders seç'), findsNothing);

    // --- 3. "Ders belirtme" seçimi kaldırıyor --------------------------------
    await tester.tap(find.byKey(kSubjectPillKey));
    await settle();
    await tester.tap(find.byKey(kSubjectClearKey));
    await settle();

    expect((await database.appSettingsDao.getSettings()).activeSubjectKey, equals(null));
    expect(find.text('Ders seç'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
