import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote/remote_flags.dart';
import '../storage/app_database.dart';
import '../storage/daos/pomodoro_session_dao.dart';
import '../storage/storage_providers.dart';
import 'ad_service.dart';

final Provider<InterstitialManager> interstitialManagerProvider =
    Provider<InterstitialManager>((Ref ref) {
  return InterstitialManager(
    adService: ref.watch(adServiceProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    sessionDao: ref.watch(pomodoroSessionDaoProvider),
    flags: ref.watch(remoteFlagsProvider),
  );
});

/// SPEC.md §7.2: interstitial kurallarının **tek** yeri. Kuralları çağırana
/// (şu an tek çağıran `PomodoroController._completeBreak`) dağıtmamak bilinçli
/// — "3'te 1" ile "180 sn" birbirinden bağımsız iki sayaç ve ikisini iki ayrı
/// yerde tutmak, ileride ikinci bir tetik noktası eklendiğinde sessizce iki
/// kat reklam demek olurdu.
class InterstitialManager {
  InterstitialManager({
    required AdService adService,
    required SharedPreferences prefs,
    required PomodoroSessionDao sessionDao,
    required RemoteFlags flags,
  })  : _adService = adService,
        _prefs = prefs,
        _sessionDao = sessionDao,
        _flags = flags;

  /// "3 tamamlanan pomodoroda 1" (SPEC §7.2).
  static const int showEveryNCompletedFocusSessions = 3;

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
  final PomodoroSessionDao _sessionDao;
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
  Future<bool> maybeShowOnCycleComplete({required bool otherPromptShown, DateTime? now}) async {
    if (otherPromptShown) return false;
    if (!_flags.interstitialEnabled) return false;
    // Kapı, sayaç okumalarından **önce**: premium/onaysız kullanıcıda hiçbir
    // istek atılmadığı gibi boşuna DB de okunmuyor (SPEC §7 DoD).
    if (!await _adService.canRequestAds()) return false;

    final List<PomodoroSession> completed = await _sessionDao.getAllCompletedFocusSessions();
    if (completed.isEmpty) return false;
    if (completed.length % showEveryNCompletedFocusSessions != 0) return false;

    final DateTime nowUtc = (now ?? DateTime.now()).toUtc();
    final String? lastShownIso = _prefs.getString(lastShownPrefsKey);
    if (lastShownIso != null) {
      final DateTime lastShown = DateTime.parse(lastShownIso);
      if (nowUtc.difference(lastShown) < minIntervalBetweenShows) return false;
    }

    final bool shown = await _adService.showInterstitial();
    // Damga yalnızca gerçekten gösterildiyse atılıyor: yükleyemediğimiz bir
    // reklam 180 sn'lik pencereyi harcamamalı.
    if (shown) await _prefs.setString(lastShownPrefsKey, nowUtc.toIso8601String());
    return shown;
  }
}
