import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote/remote_flags.dart';
import '../storage/storage_providers.dart';
import 'ad_service.dart';

final Provider<InterstitialManager> interstitialManagerProvider =
    Provider<InterstitialManager>((Ref ref) {
  return InterstitialManager(
    adService: ref.watch(adServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    flags: ref.watch(remoteFlagsProvider),
  );
});

/// SPEC.md §7.2: interstitial kurallarının **tek** yeri. Kuralları çağırana
/// (şu an tek çağıran `PomodoroController._completeBreak`) dağıtmamak bilinçli
/// — "günde 2" ile "180 sn" birbirinden bağımsız iki sayaç ve ikisini iki ayrı
/// yerde tutmak, ileride ikinci bir tetik noktası eklendiğinde sessizce iki
/// kat reklam demek olurdu.
class InterstitialManager {
  InterstitialManager({
    required AdService adService,
    required SharedPreferences prefs,
    required RemoteFlags flags,
  })  : _adService = adService,
        _prefs = prefs,
        _flags = flags;

  /// Yerel takvim günü başına en çok gösterim. Sayaç gece 00:00'da (cihaz
  /// saatiyle) sıfırlanır. İki gösterim ayrı döngü kapanışlarına düşer —
  /// arka arkaya interstitial AdMob politikasına aykırı.
  static const int maxShowsPerDay = 2;

  /// Bugün kaç kez gösterildiği, `yyyy-mm-dd|sayı` biçiminde (yerel tarih).
  static const String dailyCountPrefsKey = 'interstitial_daily_count_v1';

  /// "İki gösterim arası min. 180 sn" (SPEC §7.2).
  static const Duration minIntervalBetweenShows = Duration(seconds: 180);

  /// Son gösterim anı — ISO-8601 UTC. Süreç ömrü boyunca değil kalıcı
  /// tutuluyor: uygulama öldürülüp hemen açılırsa 180 sn kuralı yine geçerli.
  /// "Verileri sıfırla" bu anahtarı silmez (sıfırlama ilerlemeyi siler,
  /// reklam sıklığını değil — `AppReviewService.requestedPrefsKey` ile aynı
  /// gerekçe).
  static const String lastShownPrefsKey = 'interstitial_last_shown_utc_v1';

  final AdService _adService;
  final SharedPreferences _prefs;
  final RemoteFlags _flags;

  /// Odak–mola **döngüsü kapanıp** uygulama `idle`'a döndüğünde çağrılır
  /// (`PomodoroController._completeBreak`). Eskiden mola başlangıcındaydı;
  /// oradan alındı çünkü ürünün korumayı vaat ettiği tek an — odak ritüelinin
  /// molası — kesiliyordu. Yeni an, kullanıcının zaten geri sayıma döndüğü ve
  /// hiçbir sayaca bakmadığı an: `AppReviewService.requestIfEligible` ile aynı
  /// gerekçe, aynı yer.
  ///
  /// [otherPromptShown] aynı anda başka bir tam ekran istem çıktığını söyler
  /// ve gösterimi bastırır. Yeni anda bu istem **değerlendirme istemi**: o da
  /// 3. tamamlanan odak seansında düşüyor, yani sıklık kuralıyla birebir aynı
  /// tamamlanışa denk geliyordu. Kutlama (rozet/seri) artık ayrı bir an —
  /// molanın **başında** sunuluyor, burada değil — bu yüzden ayrı bir bastırma
  /// koşulu gerekmiyor.
  ///
  /// Gösterildiyse `true`.
  ///
  /// [canShowNow] gösterimden hemen önce sorulur: döngü kapanışıyla gösterim
  /// arasındaki okumalar sürerken kullanıcı yeni bir odak başlatmış olabilir
  /// ve reklam odak ekranının üstüne düşmemeli (SPEC §7, inceleme H2).
  /// Reklam burada **yüklenmez**; [preloadForCycleEnd] molada yüklemiş
  /// olmalı, hazır değilse bu döngü reklamsız geçer.
  Future<bool> maybeShowOnCycleComplete({
    required bool otherPromptShown,
    required bool Function() canShowNow,
    DateTime? now,
  }) async {
    if (otherPromptShown) return false;
    if (!await _cycleEndIsEligible(now)) return false;

    final DateTime nowUtc = (now ?? DateTime.now()).toUtc();
    final String? lastShownIso = _prefs.getString(lastShownPrefsKey);
    if (lastShownIso != null) {
      final DateTime lastShown = DateTime.parse(lastShownIso);
      if (nowUtc.difference(lastShown) < minIntervalBetweenShows) return false;
    }

    if (!canShowNow()) return false;
    final bool shown = await _adService.showInterstitialIfReady();
    // Damga yalnızca gerçekten gösterildiyse atılıyor: yükleyemediğimiz bir
    // reklam 180 sn'lik pencereyi harcamamalı.
    if (shown) {
      await _prefs.setString(lastShownPrefsKey, nowUtc.toIso8601String());
      final DateTime local = now ?? DateTime.now();
      await _prefs.setString(dailyCountPrefsKey, '${_dayKey(local)}|${_shownToday(local) + 1}');
    }
    return shown;
  }

  /// Mola başlarken (`PomodoroController._completeFocus`) çağrılır: bu
  /// molanın kapanışı gösterim anı olacaksa reklamı **şimdiden**, arka planda
  /// yükler. Mola ekranında reklam gösterilmiyor, yalnızca yükleniyor.
  Future<void> preloadForCycleEnd({DateTime? now}) async {
    if (!await _cycleEndIsEligible(now)) return;
    await _adService.preloadInterstitial();
  }

  /// Uzak bayrak, reklam kapısı ve günlük tavan. Kapı tavandan **önce**:
  /// premium/onaysız kullanıcıda hiçbir istek atılmıyor (SPEC §7 DoD).
  Future<bool> _cycleEndIsEligible(DateTime? now) async {
    if (!_flags.interstitialEnabled) return false;
    if (!await _adService.canRequestAds()) return false;
    return _shownToday(now ?? DateTime.now()) < maxShowsPerDay;
  }

  int _shownToday(DateTime now) {
    final String? raw = _prefs.getString(dailyCountPrefsKey);
    if (raw == null) return 0;
    final List<String> parts = raw.split('|');
    if (parts.length != 2 || parts[0] != _dayKey(now)) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  static String _dayKey(DateTime t) {
    final DateTime l = t.toLocal();
    return '${l.year}-${l.month}-${l.day}';
  }
}
