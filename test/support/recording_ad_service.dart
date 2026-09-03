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
  }) : super(
          readIsPremium: (() async => isPremium),
          readConsentAllowsAds: (() async => consentAllowsAds),
        );

  /// `AdSize.getLargeAnchoredAdaptiveBannerAdSize` yerine dönen boyut. `null`
  /// bırakılırsa yuva prototipin 320×50'sine düşer (gerçek kanalın cevapsız
  /// kaldığı hâl).
  final AdSize? resolvedBannerSize;

  final bool interstitialSucceeds;

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
    // yuvanın "yüklenemedi" dalı zaten aynı yüksekliği korumak zorunda.
    onFailed();
    return null;
  }

  @override
  Future<bool> requestInterstitial() async {
    interstitialRequests++;
    return interstitialSucceeds;
  }
}
