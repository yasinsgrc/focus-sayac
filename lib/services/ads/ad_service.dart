import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_unit_ids.dart';

/// `AppSettings.isPremium`in, `services/ads`ın depolama katmanına bağlanmadan
/// okunma yolu — `NotificationPreferencesReader` ile aynı gerekçe ve kalıp:
/// eşleme tek yerde, `main.dart`ta yapılır. Her istek anında yeniden okunur
/// (satın alma sonrası servisi haberdar edecek ayrı bir yol gerekmesin diye).
typedef PremiumStatusReader = Future<bool> Function();

/// UMP onayının "reklam isteyebilir miyim" cevabı — `ConsentService.canRequestAds`.
/// Fonksiyon olarak alınıyor ki [AdService] testlerinde UMP eklentisinin kanalı
/// olmadan da kapı davranışı doğrulanabilsin.
typedef ConsentStatusReader = Future<bool> Function();

/// SPEC.md §7'nin tek reklam kapısı. `main.dart` gerçek [AdService] örneğiyle
/// geçersiz kılar; testler [AdService.disabled] ile —
/// `notificationServiceProvider`/`consentServiceProvider` ile aynı DI kalıbı
/// (SPEC §1 "singleton servisler yasak").
final Provider<AdService> adServiceProvider = Provider<AdService>((Ref ref) {
  throw UnimplementedError('adServiceProvider main.dart içinde override edilmeli.');
});

/// **Her** reklam isteğinin geçtiği tek kapı (SPEC.md §7 DoD: "Ekran 03'te
/// hiçbir reklam isteği atılmıyor", "`isPremium == true` iken hiçbir reklam
/// isteği atılmıyor"). Kapıyı çağıranlara dağıtmak yerine burada tutmak,
/// `NotificationService`in bildirim anahtarını tek noktada uygulamasıyla aynı
/// gerekçe: iki çağıran (banner yuvası, `InterstitialManager`) var ve birinde
/// kontrolü unutmak sessizce politika/DoD ihlali olurdu.
///
/// SDK'ya dokunan üç metot ([requestBanner], [requestInterstitial],
/// [requestBannerSize]) kapının **arkasında** ve ayrı duruyor: testler bunları
/// override edip "istek atıldı mı" sayabiliyor, böylece kapının kendisi
/// (premium/onay/`disabled`) gerçek koduyla doğrulanıyor.
class AdService {
  AdService({
    required PremiumStatusReader readIsPremium,
    required ConsentStatusReader readConsentAllowsAds,
  })  : _readIsPremium = readIsPremium,
        _readConsentAllowsAds = readConsentAllowsAds,
        _enabled = true;

  /// Tüm çağrıları no-op yapar ve [canRequestAds]i her zaman `false` döndürür
  /// — `NotificationService.disabled` / `ConsentService.disabled` ile aynı
  /// kalıp (widget testlerinde AdMob kanalı yok).
  AdService.disabled()
      : _readIsPremium = _alwaysFalse,
        _readConsentAllowsAds = _alwaysFalse,
        _enabled = false;

  static Future<bool> _alwaysFalse() async => false;

  /// Interstitial yüklemesi bu süre içinde sonuçlanmazsa vazgeçilir: SDK geri
  /// çağrısı hiç gelmezse mola başlangıcı sonsuza kadar bekleyen bir
  /// `Future`da asılı kalırdı.
  static const Duration interstitialLoadTimeout = Duration(seconds: 10);

  final PremiumStatusReader _readIsPremium;
  final ConsentStatusReader _readConsentAllowsAds;
  final bool _enabled;
  bool _initialized = false;

  /// `main.dart` açılışta bir kez çağırır. Onay durumundan bağımsız: SDK'yı
  /// başlatmak reklam **istemek** değildir, istek kapısı [canRequestAds].
  Future<void> initialize() async {
    if (!_enabled || _initialized) return;
    _initialized = true;
    await _guarded(() => MobileAds.instance.initialize());
  }

  /// Reklam isteğinin ön koşulu. Sıra bilinçli: premium kontrolü onaydan
  /// **önce** — premium kullanıcı için UMP'ye hiç sormaya gerek yok.
  Future<bool> canRequestAds() async {
    if (!_enabled) return false;
    if (await _readIsPremium()) return false;
    return _readConsentAllowsAds();
  }

  /// Ekran 02/06'nın banner yuvası için `AnchoredAdaptiveBannerAdSize`
  /// (SPEC §7.1). Kapının arkasında: boyut sorgusu reklam isteği değil ama
  /// premium/onaysız kullanıcıda yapılmasının da anlamı yok.
  Future<AdSize?> resolveBannerSize(int widthDp) async {
    if (!await canRequestAds()) return null;
    return requestBannerSize(widthDp);
  }

  /// Yüklemeyi başlatır ve `BannerAd`i döndürür — sonuç [onLoaded]/[onFailed]
  /// ile bildirilir. Kapı kapalıysa **hiçbir istek atılmaz** ve `null` döner.
  Future<BannerAd?> loadBanner({
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    if (!await canRequestAds()) return null;
    return requestBanner(size: size, onLoaded: onLoaded, onFailed: onFailed);
  }

  /// Yükleyip gösterir; gösterildiyse `true`. Ne zaman çağrılacağının kuralı
  /// burada değil `InterstitialManager`'da (SPEC §7.2 "kurallar tek yerde").
  Future<bool> showInterstitial() async {
    if (!await canRequestAds()) return false;
    return requestInterstitial();
  }

  @protected
  @visibleForTesting
  Future<AdSize?> requestBannerSize(int widthDp) {
    return _guarded<AdSize?>(() => AdSize.getLargeAnchoredAdaptiveBannerAdSize(widthDp));
  }

  @protected
  @visibleForTesting
  Future<BannerAd?> requestBanner({
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    final BannerAd ad = BannerAd(
      size: size,
      adUnitId: AdUnitIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => onLoaded(),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          onFailed();
        },
      ),
    );
    final bool? started = await _guarded(() async {
      await ad.load();
      return true;
    });
    if (started == null) {
      // Kanal yoksa/patladıysa `onAdFailedToLoad` hiç gelmez; yuva aynı
      // yükseklikte boş kalsın diye başarısızlığı burada bildiriyoruz.
      await ad.dispose();
      onFailed();
      return null;
    }
    return ad;
  }

  @protected
  @visibleForTesting
  Future<bool> requestInterstitial() async {
    final Completer<InterstitialAd?> loaded = Completer<InterstitialAd?>();
    final bool? started = await _guarded(() async {
      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) => loaded.complete(ad),
          onAdFailedToLoad: (LoadAdError error) => loaded.complete(null),
        ),
      );
      return true;
    });
    if (started == null) return false;
    final InterstitialAd? ad =
        await loaded.future.timeout(interstitialLoadTimeout, onTimeout: () => null);
    if (ad == null) return false;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) => ad.dispose(),
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) => ad.dispose(),
    );
    final bool? shown = await _guarded(() async {
      await ad.show();
      return true;
    });
    return shown != null;
  }

  /// Reklam, uygulamanın işleyişi için kritik değil: kanal hatası da eksik
  /// eklenti de (testler, kanalsız koşumlar) sessizce "reklam yok"a düşer —
  /// `AppReviewService._guarded` ile aynı gerekçe.
  Future<T?> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
