import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/features/settings/settings_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// `testWidgets` gövdesi sahte bir saat altında koşuyor; drift sorguları ve
/// `onCreate`in `rootBundle` okuması ise **gerçek** zamanda tamamlanıyor.
/// `pump` yalnızca sahte saati ilerlettiği için tek başına yeterli değil:
/// gerçek işlerin ilerlemesi `runAsync` penceresi gerektiriyor, ardından
/// gelen kare yeni durumu çiziyor.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Veritabanı okumaları da aynı nedenle gerçek zaman penceresinde yapılıyor.
Future<T> _read<T>(WidgetTester tester, Future<T> Function() query) async {
  return (await tester.runAsync(query)) as T;
}

Future<AppDatabase> _newDatabase(WidgetTester tester) {
  return _read(tester, () async {
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    // `onCreate` (4 preset sınav + varsayılan ayar satırı) burada tetiklenip
    // tamamlanıyor, böylece ekran ilk karesinde hazır veriyle karşılaşıyor.
    await database.appSettingsDao.getSettings();
    return database;
  });
}

Widget _appWith(AppDatabase database, SharedPreferences prefs, Widget home) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
    ],
    child: home,
  );
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Ekran 07'yi tek başına (router olmadan) ayağa kaldırır.
Future<AppDatabase> _pumpSettings(WidgetTester tester) async {
  _usePhoneSurface(tester);
  final AppDatabase database = await _newDatabase(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    _appWith(database, prefs, MaterialApp(theme: buildAppTheme(), home: const SettingsScreen())),
  );
  await _settle(tester);
  return database;
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// `watchAllSessions().first` yerine tek atışlık sorgu — akışın ilk yayınını
/// beklemek yerine doğrudan sorgulamak, testi sahte saate bağımlı olmaktan
/// çıkarıyor.
Future<List<PomodoroSession>> _allSessions(WidgetTester tester, AppDatabase database) {
  return _read(
    tester,
    () => database.pomodoroSessionDao.getSessionsBetween(DateTime.utc(2000), DateTime.utc(2100)),
  );
}

void main() {
  testWidgets('süre slider\'ı değişince ayar veritabanına yazılıyor', (WidgetTester tester) async {
    final AppDatabase database = await _pumpSettings(tester);

    expect(find.text('25 dk'), findsOneWidget);

    // Sürükleme jesti yerine `onChangeEnd` doğrudan çağrılıyor: test edilen
    // şey dokunmanın piksel matematiği değil, "parmak kalkınca ayar yazılıyor
    // mu" davranışı.
    final Slider focusSlider = tester.widget<Slider>(find.byType(Slider).first);
    focusSlider.onChangeEnd!(40);
    await _settle(tester);

    final AppSettingsTableData settings = await _read(tester, database.appSettingsDao.getSettings);
    expect(settings.focusMinutes, 40);
    // Diğer iki süre etkilenmemeli (her slider yalnızca kendi kolonunu yazar).
    expect(settings.shortBreakMinutes, 5);
    expect(settings.longBreakMinutes, 15);
    expect(find.text('40 dk'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('slider sınırları SPEC\'teki aralıklar', (WidgetTester tester) async {
    await _pumpSettings(tester);

    final List<Slider> sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders, hasLength(3));
    expect(sliders[0].min, kFocusMinutesMin.toDouble());
    expect(sliders[0].max, kFocusMinutesMax.toDouble());
    for (final Slider breakSlider in sliders.sublist(1)) {
      expect(breakSlider.min, kBreakMinutesMin.toDouble());
      expect(breakSlider.max, kBreakMinutesMax.toDouble());
    }

    await _disposeTree(tester);
  });

  testWidgets('bildirim anahtarı kapatılınca ayar yazılıyor', (WidgetTester tester) async {
    final AppDatabase database = await _pumpSettings(tester);

    expect(
      (await _read(tester, database.appSettingsDao.getSettings)).notificationsEnabled,
      isTrue,
    );

    await tester.tap(find.text('Bildirimler'));
    await _settle(tester);

    final AppSettingsTableData settings = await _read(tester, database.appSettingsDao.getSettings);
    expect(settings.notificationsEnabled, isFalse);
    // Diğer anahtarlar aynı dokunuştan etkilenmiyor.
    expect(settings.soundEnabled, isTrue);
    expect(settings.hapticEnabled, isTrue);
    // Satırın değeri de yeni durumu gösteriyor.
    expect(find.text('Kapalı'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('verileri sıfırla onaylanınca geçmiş ve rozetler siliniyor, sınavlar kalıyor',
      (WidgetTester tester) async {
    final AppDatabase database = await _pumpSettings(tester);

    await _read(tester, () async {
      await database.pomodoroSessionDao.startSession(
        examId: null,
        type: SessionType.focus,
        startedAt: DateTime.utc(2026, 1, 1, 9),
        plannedDurationSec: 25 * 60,
      );
      await database.userBadgeDao.unlockBadge(
        badgeKey: 'first_focus',
        unlockedAt: DateTime.utc(2026, 1, 1, 9, 25),
      );
    });
    final int examCountBefore = (await _read(tester, database.examDao.getPresetExams)).length;
    expect(examCountBefore, greaterThan(0));

    // Satır listenin sonunda, telefon yüzeyinde kaydırmadan görünmüyor.
    final Finder resetRow = find.text('Verileri sıfırla');
    await tester.ensureVisible(resetRow);
    await tester.pumpAndSettle();

    // Onay verilmeden hiçbir şey silinmemeli — önce vazgeçiliyor.
    await tester.tap(resetRow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('VAZGEÇ'));
    await tester.pumpAndSettle();
    expect(await _allSessions(tester, database), hasLength(1));

    await tester.ensureVisible(resetRow);
    await tester.pumpAndSettle();
    await tester.tap(resetRow);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Verileri sıfırla')),
    );
    await _settle(tester);

    expect(await _allSessions(tester, database), isEmpty);
    expect(await _read(tester, database.userBadgeDao.getUnlockedBadges), isEmpty);
    // SPEC: sıfırlama ilerlemeyi siler, sınavları ve ayarları değil.
    expect(await _read(tester, database.examDao.getPresetExams), hasLength(examCountBefore));
    expect((await _read(tester, database.appSettingsDao.getSettings)).focusMinutes, 25);

    await _disposeTree(tester);
  });

  testWidgets('alt çubuktaki dişli sekmesi ayarlar ekranını açıyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_appWith(database, prefs, const FocusSayacApp()));
    await _settle(tester);
    expect(find.text('GÜN KALDI'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsRegular.gear));
    // Ekran 02'nin sonsuz-tekrarlı halka animasyonu yüzünden `pumpAndSettle`
    // kullanılamıyor (widget_test.dart'taki gerekçe); rota geçişi + ayar
    // akışının ilk yayını için birkaç tur pompalanıyor.
    await _settle(tester, rounds: 8);

    expect(find.text('AYARLAR'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('ayarlar ekranı seçili sınavın adını gösteriyor', (WidgetTester tester) async {
    final AppDatabase database = await _pumpSettings(tester);

    final Exam? active = await _read(tester, database.examDao.getActiveExam);
    await _settle(tester);

    expect(active, isNotNull);
    expect(find.text(active!.name), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('kayıtlı süreler ekranda okunuyor', (WidgetTester tester) async {
    // SPEC DoD "demo sayıları kodda yok": ekran kolon varsayılanını değil,
    // kayıtlı değeri göstermeli — bu yüzden varsayılandan farklı yazılıyor.
    _usePhoneSurface(tester);
    final AppDatabase database = await _newDatabase(tester);
    await _read(
      tester,
      () => database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(focusMinutes: Value<int>(50), shortBreakMinutes: Value<int>(7)),
      ),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWith(database, prefs, MaterialApp(theme: buildAppTheme(), home: const SettingsScreen())),
    );
    await _settle(tester);

    expect(find.text('50 dk'), findsOneWidget);
    expect(find.text('7 dk'), findsOneWidget);
    expect(find.text('25 dk'), findsNothing);

    await _disposeTree(tester);
  });
}
