import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/services/ads/interstitial_manager.dart';
import 'package:focussayac/services/remote/remote_flags.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

import '../../support/recording_ad_service.dart';

/// Sabit bir "şimdi": 180 sn kuralı testin gerçek saatine bağlı kalmasın.
final DateTime _now = DateTime.utc(2026, 3, 1, 20);

Future<void> _completeFocusSessions(AppDatabase database, int count) async {
  for (int i = 0; i < count; i++) {
    final DateTime startedAt = _now.subtract(Duration(minutes: 30 * (count - i)));
    final int id = await database.pomodoroSessionDao.startSession(
      examId: null,
      type: SessionType.focus,
      startedAt: startedAt,
      plannedDurationSec: 25 * 60,
    );
    await database.pomodoroSessionDao.finishSession(
      id: id,
      completed: true,
      endedAt: startedAt.add(const Duration(minutes: 25)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences prefs;

  InterstitialManager managerWith(RecordingAdService adService) {
    return InterstitialManager(
      adService: adService,
      prefs: prefs,
      sessionDao: database.pomodoroSessionDao,
      flags: RemoteFlags(prefs),
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await database.close();
  });

  // SPEC.md §7.2: "3 tamamlanan pomodoroda 1".
  test('ilk iki molada gösterilmiyor, 3. tamamlanan pomodoroda gösteriliyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 1);
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);

    await _completeFocusSessions(database, 1);
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);

    await _completeFocusSessions(database, 1);
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isTrue);
    expect(adService.interstitialRequests, 1);
  });

  // SPEC.md §7.2: "iki gösterim arası min. 180 sn".
  test('180 sn dolmadan ikinci gösterim yok, dolduktan sonra var', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 3);
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isTrue);

    await _completeFocusSessions(database, 3);
    final DateTime tooSoon = _now.add(const Duration(seconds: 179));
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: tooSoon), isFalse);
    expect(adService.interstitialRequests, 1);

    final DateTime later = _now.add(const Duration(seconds: 181));
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: later), isTrue);
    expect(adService.interstitialRequests, 2);
  });

  // SPEC.md §7.2: "Rozet açılışının üstüne asla binmez".
  test('aynı tamamlanışta rozet açıldıysa gösterilmiyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 3);

    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: true, now: _now), isFalse);
    expect(adService.totalRequests, 0);
    // Bastırma pencereyi de harcamamalı: rozetsiz bir sonraki mola gösterebilmeli.
    expect(prefs.getString(InterstitialManager.lastShownPrefsKey), isNull);
  });

  // SPEC.md §7.2: "`RemoteFlags.interstitialEnabled` ile kapatılabilir".
  test('uzak bayrak kapalıyken hiçbir istek atılmıyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);
    await RemoteFlags(prefs).setInterstitialEnabled(false);

    await _completeFocusSessions(database, 3);

    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);
    expect(adService.totalRequests, 0);
  });

  // SPEC.md §10 DoD: "`isPremium` iken hiçbir reklam isteği atılmıyor".
  test('premium kullanıcıda hiçbir istek atılmıyor', () async {
    final RecordingAdService adService = RecordingAdService(isPremium: true);
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 3);

    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);
    expect(adService.totalRequests, 0);
  });

  test('gösterilemeyen reklam 180 sn penceresini harcamıyor', () async {
    final RecordingAdService adService = RecordingAdService(interstitialSucceeds: false);
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 3);
    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);
    expect(adService.interstitialRequests, 1);
    expect(prefs.getString(InterstitialManager.lastShownPrefsKey), isNull);
  });

  test('tamamlanmamış odak seansları sayıya girmiyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    await _completeFocusSessions(database, 2);
    final int cancelled = await database.pomodoroSessionDao.startSession(
      examId: null,
      type: SessionType.focus,
      startedAt: _now.subtract(const Duration(minutes: 10)),
      plannedDurationSec: 25 * 60,
    );
    await database.pomodoroSessionDao.finishSession(id: cancelled, completed: false, endedAt: _now);

    expect(await manager.maybeShowOnBreakStart(badgeUnlocked: false, now: _now), isFalse);
    expect(adService.totalRequests, 0);
  });
}
