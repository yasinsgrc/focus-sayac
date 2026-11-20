import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:focussayac/services/ads/ad_service.dart';

/// Reklam **isteklerini** sayan [AdService]. Yalnızca SDK'ya dokunan üç seam
/// metodu override ediyor; kapının kendisi (`canRequestAds`, premium/onay
/// sırası, `loadBanner`/`showInterstitial` içindeki kısa devreler) gerçek
/// koduyla koşuyor. SPEC.md §7 DoD'unun iki maddesi ("Ekran 03'te hiçbir
/// reklam isteği atılmıyor", "`isPremium` iken hiçbir reklam isteği
/// atılmıyor") ancak böyle doğrulanabiliyor: `AdService.disabled()` ile
/// ölçülen "istek yok" sonucu kapıyı değil kapalı servisi doğrulardı.
class RecordingAdService extends AdService {
  RecordingAdService({
    bool isPremium = false,
    bool consentAllowsAds = true,
    this.resolvedBannerSize,
    this.interstitialSucceeds = true,
    this.bannerLoads = false,
  }) : super(
          readIsPremium: (() async => isPremium),
          readConsentAllowsAds: (() async => consentAllowsAds),
        );

  /// `AdSize.getLargeAnchoredAdaptiveBannerAdSize` yerine dönen boyut. `null`
  /// bırakılırsa yuva prototipin 320×50'sine düşer (gerçek kanalın cevapsız
  /// kaldığı hâl).
  final AdSize? resolvedBannerSize;

  final bool interstitialSucceeds;

  /// `true` ise banner yüklenmiş sayılır (`onLoaded`); varsayılan hâl
  /// çevrimdışı/yükleme hatası (`onFailed`).
  final bool bannerLoads;

  int bannerSizeRequests = 0;
  int bannerRequests = 0;
  int interstitialRequests = 0;

  int get totalRequests => bannerSizeRequests + bannerRequests + interstitialRequests;

  @override
  Future<AdSize?> requestBannerSize(int widthDp) async {
    bannerSizeRequests++;
    return resolvedBannerSize;
  }

  @override
  Future<BannerAd?> requestBanner({
    required AdSize size,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    bannerRequests++;
    // Gerçek `BannerAd` widget testinde platform görünümü olmadan çizilemez;
    // `null` dönüyor, yuva yine de yüklenmiş hâlin yüksekliğini alıyor.
    bannerLoads ? onLoaded() : onFailed();
    return null;
  }

  /// Ekrana çıkan interstitial sayısı. [interstitialRequests] **yüklemeleri**
  /// sayar (ağ isteği); gösterim ayrı, çünkü yükleme moladayken yapılıyor.
  int interstitialShows = 0;

  @override
  Future<bool> loadInterstitial() async {
    interstitialRequests++;
    return interstitialSucceeds;
  }

  @override
  Future<bool> presentInterstitial() async {
    interstitialShows++;
    return true;
  }

  @override
  void discardInterstitial() {}
}
