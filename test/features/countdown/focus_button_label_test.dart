import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Ekran 02'yi, `AppSettings.focusMinutes` verilen değere ayarlanmış bir
/// veritabanıyla ayağa kaldırır. `updateSettings` await edildiği için
/// `onCreate` (varsayılan ayar satırı + sınav tohumlaması) bu noktada
/// tamamlanmış olur.
Future<void> _pumpCountdown(WidgetTester tester, {required int focusMinutes}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  await database.appSettingsDao.updateSettings(
    AppSettingsTableCompanion(focusMinutes: Value<int>(focusMinutes)),
  );

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
      ],
      child: const FocusSayacApp(),
    ),
  );
  // `pumpAndSettle` kullanılmıyor: halkanın `repeat()` animasyonu hiç "settle"
  // olmaz (widget_test.dart'taki aynı gerekçe) — DB tohumlama + stream yayını
  // için birkaç kare pompalanıyor.
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekranın `Timer.periodic` tikleyicisini durdurur (widget_test.dart'taki
/// drift kapatma gerekçesinin aynısı geçerli: `database.close()` çağrılmıyor).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // SPEC.md DoD "demo sayıları kodda olmayacak": buton metnindeki süre
  // `AppSettings.focusMinutes`ten gelir. Varsayılanla (25) test etmek sabit
  // yazılmış bir metni de geçireceği için kasten farklı bir değer kullanılıyor.
  testWidgets('odak butonu süreyi ayardan okur', (WidgetTester tester) async {
    await _pumpCountdown(tester, focusMinutes: 40);

    expect(find.text('40 DAKİKA ODAKLAN'), findsOneWidget);
    expect(find.text('25 DAKİKA ODAKLAN'), findsNothing);

    await _disposeTree(tester);
  });
}
