import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/services/ads/interstitial_manager.dart';
import 'package:focussayac/services/remote/remote_flags.dart';

import '../../support/recording_ad_service.dart';

/// Sabit bir "şimdi" (yerel saat): günlük tavan ve 180 sn kuralı testin
/// gerçek saatine bağlı kalmasın.
final DateTime _now = DateTime(2026, 3, 1, 20);

/// Gerçek akışın sırası: mola başlarken ön yükleme, mola bitince gösterim.
/// Ön yükleme SDK yüklemesini beklemeden döndüğü için arada olay kuyruğu
/// boşaltılıyor.
Future<bool> _closeCycle(
  InterstitialManager manager, {
  required bool otherPromptShown,
  required DateTime now,
  bool canShowNow = true,
}) async {
  await manager.preloadForCycleEnd(now: now);
  await pumpEventQueue();
  return manager.maybeShowOnCycleComplete(
    otherPromptShown: otherPromptShown,
    canShowNow: () => canShowNow,
    now: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  InterstitialManager managerWith(RecordingAdService adService) {
    return InterstitialManager(
      adService: adService,
      prefs: prefs,
      flags: RemoteFlags(prefs),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  test('günde en çok 2 gösterim, ayrı döngülerde', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now), isTrue);
    final DateTime second = _now.add(const Duration(minutes: 30));
    expect(await _closeCycle(manager, otherPromptShown: false, now: second), isTrue);
    final DateTime third = _now.add(const Duration(minutes: 60));
    expect(await _closeCycle(manager, otherPromptShown: false, now: third), isFalse);
    expect(adService.interstitialShows, 2);
  });

  test('tavan dolunca o gün ön yükleme de yapılmıyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    await _closeCycle(manager, otherPromptShown: false, now: _now);
    await _closeCycle(manager, otherPromptShown: false, now: _now.add(const Duration(minutes: 30)));
    final int requests = adService.totalRequests;

    await manager.preloadForCycleEnd(now: _now.add(const Duration(minutes: 60)));
    expect(adService.totalRequests, requests);
  });

  test('sayaç gece 00:00da sıfırlanıyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);
    final DateTime lateNight = DateTime(2026, 3, 1, 23, 50);

    expect(await _closeCycle(manager, otherPromptShown: false, now: lateNight.subtract(const Duration(hours: 1))), isTrue);
    expect(await _closeCycle(manager, otherPromptShown: false, now: lateNight), isTrue);
    expect(await _closeCycle(manager, otherPromptShown: false, now: DateTime(2026, 3, 1, 23, 59, 59)), isFalse);
    expect(await _closeCycle(manager, otherPromptShown: false, now: DateTime(2026, 3, 2, 0, 1)), isTrue);
    expect(adService.interstitialShows, 3);
  });

  // SPEC.md §7.2: "iki gösterim arası min. 180 sn".
  test('180 sn dolmadan ikinci gösterim yok, dolduktan sonra var', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now), isTrue);

    final DateTime tooSoon = _now.add(const Duration(seconds: 179));
    expect(await _closeCycle(manager, otherPromptShown: false, now: tooSoon), isFalse);
    expect(adService.interstitialShows, 1);

    final DateTime later = _now.add(const Duration(seconds: 181));
    expect(await _closeCycle(manager, otherPromptShown: false, now: later), isTrue);
    expect(adService.interstitialShows, 2);
  });

  // SPEC.md §7.2: "başka bir tam ekran istemin üstüne asla binmez". Yeni
  // tetikleme anında (döngü kapanışı) bu istem değerlendirme istemi: ikisi de
  // 3. tamamlanan seansta düşüyor ve üst üste binerlerdi.
  test('aynı anda değerlendirme istemi çıktıysa gösterilmiyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: true, now: _now), isFalse);
    expect(adService.interstitialShows, 0);
    // Bastırma pencereyi de harcamamalı: bir sonraki döngü gösterebilmeli.
    expect(prefs.getString(InterstitialManager.lastShownPrefsKey), isNull);
  });

  // SPEC.md §7.2: "`RemoteFlags.interstitialEnabled` ile kapatılabilir".
  test('uzak bayrak kapalıyken hiçbir istek atılmıyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);
    await RemoteFlags(prefs).setInterstitialEnabled(false);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now), isFalse);
    expect(adService.totalRequests, 0);
  });

  // SPEC.md §10 DoD: "`isPremium` iken hiçbir reklam isteği atılmıyor".
  test('premium kullanıcıda hiçbir istek atılmıyor', () async {
    final RecordingAdService adService = RecordingAdService(isPremium: true);
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now), isFalse);
    expect(adService.totalRequests, 0);
  });

  test('gösterilemeyen reklam 180 sn penceresini harcamıyor', () async {
    final RecordingAdService adService = RecordingAdService(interstitialSucceeds: false);
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now), isFalse);
    expect(adService.interstitialRequests, 1);
    expect(adService.interstitialShows, 0);
    expect(prefs.getString(InterstitialManager.lastShownPrefsKey), isNull);
  });

  // İnceleme H2: gösterim anında yükleme yok — yüklenmemiş reklam o döngüde
  // hiç çıkmıyor, geç yüklenip yanlış ekrana düşemiyor.
  test('molada ön yükleme yapılmadıysa kapanışta istek de gösterim de yok', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    expect(
      await manager.maybeShowOnCycleComplete(otherPromptShown: false, canShowNow: () => true, now: _now),
      isFalse,
    );
    expect(adService.totalRequests, 0);
  });

  // İnceleme H2: kapanışla gösterim arasında yeni odak başladıysa reklam odak
  // ekranının üstüne düşmüyor (SPEC §7) ve pencere harcanmıyor.
  test('gösterim anında faz idle değilse gösterilmiyor', () async {
    final RecordingAdService adService = RecordingAdService();
    final InterstitialManager manager = managerWith(adService);

    expect(await _closeCycle(manager, otherPromptShown: false, now: _now, canShowNow: false), isFalse);
    expect(adService.interstitialShows, 0);
    expect(prefs.getString(InterstitialManager.lastShownPrefsKey), isNull);
  });
}
