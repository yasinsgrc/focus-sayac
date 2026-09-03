import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/storage/app_database.dart';
import '../../services/storage/daos/pomodoro_session_dao.dart';
import '../../services/storage/storage_providers.dart';

final Provider<AppReviewService> appReviewServiceProvider = Provider<AppReviewService>((Ref ref) {
  return AppReviewService(
    prefs: ref.watch(sharedPreferencesProvider),
    sessionDao: ref.watch(pomodoroSessionDaoProvider),
  );
});

/// SPEC.md Ekran 07 "Uygulamayı Değerlendir (`in_app_review`, 3. tamamlanan
/// seanstan sonra bir kez)".
///
/// İki ayrı giriş var ve bilinçli olarak farklı API'ler kullanıyorlar:
/// [requestIfEligible] uygulamanın kendiliğinden gösterdiği istem
/// (`requestReview` — Play'in kendi kotasına tabi, sessizce hiçbir şey
/// göstermeyebilir), [openStoreListing] ise ayarlardaki satıra dokunan
/// kullanıcının açık isteği. Açık istekte `requestReview` kullanılsaydı
/// kullanıcı dokunduğu hâlde çoğu zaman hiçbir şey görmezdi.
class AppReviewService {
  AppReviewService({
    required SharedPreferences prefs,
    required PomodoroSessionDao sessionDao,
    InAppReview? review,
  })  : _prefs = prefs,
        _sessionDao = sessionDao,
        _review = review ?? InAppReview.instance;

  /// İstemin bir kez gösterildiğini işaretleyen anahtar. "Verileri sıfırla"
  /// bu anahtarı **silmez**: sıfırlama ilerlemeyi siler, kullanıcıyı ikinci
  /// kez değerlendirmeye davet etme hakkını değil.
  static const String requestedPrefsKey = 'in_app_review_requested_v1';

  /// SPEC "3. tamamlanan seanstan sonra" — eşik tamamlanmış **odak** seansı.
  static const int minCompletedFocusSessions = 3;

  final SharedPreferences _prefs;
  final PomodoroSessionDao _sessionDao;
  final InAppReview _review;

  /// Bir odak-mola döngüsü kapanıp uygulama `idle`'a döndüğünde çağrılır
  /// (`PomodoroController._completeBreak`) — kullanıcının hiçbir sayaca
  /// bakmadığı tek an. Odak ya da mola sürerken istem göstermek, SPEC §7.2'nin
  /// interstitial kuralıyla aynı gerekçeyle (ekrandaki işin üstüne binmemek)
  /// yapılmıyor.
  Future<void> requestIfEligible() async {
    if (_prefs.getBool(requestedPrefsKey) ?? false) return;
    final List<PomodoroSession> completed = await _sessionDao.getAllCompletedFocusSessions();
    if (completed.length < minCompletedFocusSessions) return;
    if (!await _isAvailable()) return;
    // Bayrak istemden **önce** yazılıyor: `requestReview` kotaya takılıp
    // hiçbir şey göstermese de tekrar denemek istemiyoruz (Play istemi
    // gösterip göstermediğini bildirmiyor, tekrar çağırmak yalnızca aynı
    // sessiz sonucu üretirdi).
    await _prefs.setBool(requestedPrefsKey, true);
    await _guarded(_review.requestReview);
  }

  /// Ayarlardaki "Uygulamayı değerlendir" satırı. Mağaza sayfası açılabildiyse
  /// `true` döner; çağıran ekran `false` durumunda kullanıcıya geri bildirim
  /// gösterir (açık bir dokunuşun sessizce yutulmaması için).
  Future<bool> openStoreListing() => _guarded(_review.openStoreListing);

  Future<bool> _isAvailable() async {
    try {
      return await _review.isAvailable();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Testler ve eklenti kanalı olmayan koşumlar. Değerlendirme istemi
      // uygulamanın işleyişi için kritik değil, sessizce atlanır.
      return false;
    }
  }

  Future<bool> _guarded(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
