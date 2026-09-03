import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/consent/consent_service.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// İzin isteğinin yapılıp yapılmadığını sayan servis. `disabled()` gövdesi
/// zaten no-op olduğu için sayaç dışında hiçbir şey değişmiyor — testte
/// gerçek platform kanalı yok.
class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService() : super.disabled();

  int permissionRequests = 0;

  @override
  Future<void> requestPermissions() async {
    permissionRequests++;
  }
}

class _RecordingConsentService extends ConsentService {
  _RecordingConsentService() : super.disabled();

  int consentRuns = 0;

  @override
  Future<void> gatherConsent() async {
    consentRuns++;
  }
}

/// `pumpAndSettle` hiçbir yerde kullanılamıyor: Ekran 01'in shimmer/dönüş,
/// Ekran 02'nin halka animasyonu `repeat()` ile sonsuz (widget_test.dart'taki
/// gerekçe). Yerine DB yazımı, stream yayını ve rota geçişi için sabit sayıda
/// kare pompalanıyor.
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  await tester.pump();
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<T> _read<T>(WidgetTester tester, Future<T> Function() query) async {
  return (await tester.runAsync(query)) as T;
}

class _Harness {
  _Harness({required this.database, required this.notifications, required this.consent});

  final AppDatabase database;
  final _RecordingNotificationService notifications;
  final _RecordingConsentService consent;
}

/// Uygulamayı gerçek router'ıyla ayağa kaldırır. [onboardingCompleted] açılış
/// anındaki bayrağı temsil eder — `main.dart` onu Riverpod ağacı kurulmadan
/// önce veritabanından okuyup override ediyor, test de aynısını yapıyor.
Future<_Harness> _pumpApp(WidgetTester tester, {required bool onboardingCompleted}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = await _read(tester, () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    // `onCreate` (4 preset sınav + varsayılan ayar satırı) burada tamamlanıyor.
    await db.appSettingsDao.updateSettings(
      AppSettingsTableCompanion(onboardingCompleted: Value<bool>(onboardingCompleted)),
    );
    return db;
  });

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final _RecordingNotificationService notifications = _RecordingNotificationService();
  final _RecordingConsentService consent = _RecordingConsentService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(notifications),
        consentServiceProvider.overrideWithValue(consent),
        onboardingCompletedAtLaunchProvider.overrideWithValue(onboardingCompleted),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await _settle(tester);
  return _Harness(database: database, notifications: notifications, consent: consent);
}

/// Ekran 02'nin `Timer.periodic` tikleyicisini ve tekrarlı animasyonları
/// ağaçtan kaldırır (`database.close()` çağrılmıyor — widget_test.dart'taki
/// drift gerekçesi).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ilk açılışta Ekran 01 gösteriliyor', (WidgetTester tester) async {
    await _pumpApp(tester, onboardingCompleted: false);

    expect(find.text('MEŞALE\nSENDE'), findsOneWidget);
    expect(find.text('İZİN VER VE BAŞLA'), findsOneWidget);
    expect(find.text('Şimdi değil'), findsOneWidget);
    // Prototipin sahte durum çubuğu çizilmiyor (SPEC.md Ekran 01).
    expect(find.text('9:41'), findsNothing);
    // Geri sayım henüz açılmadı.
    expect(find.text('GÜN KALDI'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('ikinci açılışta onboarding gösterilmiyor', (WidgetTester tester) async {
    await _pumpApp(tester, onboardingCompleted: true);

    expect(find.text('MEŞALE\nSENDE'), findsNothing);
    expect(find.text('GÜN KALDI'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('"İZİN VER VE BAŞLA" izinleri isteyip geri sayıma geçiyor', (WidgetTester tester) async {
    final _Harness harness = await _pumpApp(tester, onboardingCompleted: false);
    expect(harness.notifications.permissionRequests, 0);

    await tester.tap(find.text('İZİN VER VE BAŞLA'));
    await _settle(tester, rounds: 10);

    expect(harness.notifications.permissionRequests, 1);
    // SPEC Ekran 01: UMP onayı ilk reklam isteğinden önce, bu ekranda.
    expect(harness.consent.consentRuns, 1);
    expect(
      (await _read(tester, harness.database.appSettingsDao.getSettings)).onboardingCompleted,
      isTrue,
    );
    expect(find.text('GÜN KALDI'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('"Şimdi değil" izin istemeden geri sayıma geçiyor', (WidgetTester tester) async {
    final _Harness harness = await _pumpApp(tester, onboardingCompleted: false);

    await tester.tap(find.text('Şimdi değil'));
    await _settle(tester, rounds: 10);

    // SPEC DoD "İzinler reddedildiğinde uygulama tam çalışıyor": izin hiç
    // istenmeden geri sayım ekranı çalışır durumda açılıyor.
    expect(harness.notifications.permissionRequests, 0);
    // Onay akışı yine de çalışıyor — reklamın yasal ön koşulu, bildirim
    // izninin bir alt seçeneği değil.
    expect(harness.consent.consentRuns, 1);
    expect(
      (await _read(tester, harness.database.appSettingsDao.getSettings)).onboardingCompleted,
      isTrue,
    );
    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(find.text('25 DAKİKA ODAKLAN'), findsOneWidget);

    await _disposeTree(tester);
  });
}
