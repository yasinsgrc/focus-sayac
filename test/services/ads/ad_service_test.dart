import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:focussayac/services/ads/ad_service.dart';

import '../../support/recording_ad_service.dart';

/// Her giriş noktasını bir kez çağırıp kaç istek atıldığını ölçer — SPEC.md §7
/// DoD'unun "hiçbir reklam isteği atılmıyor" maddeleri sayının **0** olmasını
/// istiyor.
Future<int> _requestsAfterEveryEntryPoint(RecordingAdService service) async {
  await service.resolveBannerSize(360);
  await service.loadBanner(size: AdSize.banner, onLoaded: () {}, onFailed: () {});
  await service.showInterstitial();
  return service.totalRequests;
}

void main() {
  group('AdService kapısı', () {
    test('onay varsa ve premium değilse istek atılır', () async {
      final RecordingAdService service = RecordingAdService();

      expect(await service.canRequestAds(), isTrue);
      expect(await _requestsAfterEveryEntryPoint(service), 3);
      expect(service.bannerSizeRequests, 1);
      expect(service.bannerRequests, 1);
      expect(service.interstitialRequests, 1);
    });

    // SPEC.md §10 DoD: "`isPremium` iken hiçbir reklam isteği atılmıyor".
    test('isPremium iken hiçbir istek atılmıyor', () async {
      final RecordingAdService service = RecordingAdService(isPremium: true);

      expect(await service.canRequestAds(), isFalse);
      expect(await _requestsAfterEveryEntryPoint(service), 0);
    });

    // UMP onayı olmadan reklam istemek yasal bir ihlal; bilinmeyen durum da
    // (kanal hatası → `ConsentService.canRequestAds` false) aynı dala düşer.
    test('UMP onayı yokken hiçbir istek atılmıyor', () async {
      final RecordingAdService service = RecordingAdService(consentAllowsAds: false);

      expect(await service.canRequestAds(), isFalse);
      expect(await _requestsAfterEveryEntryPoint(service), 0);
    });

    test('premium kontrolü onaydan önce: premium kullanıcıda UMP hiç sorulmuyor', () async {
      int consentReads = 0;
      final AdService service = AdService(
        readIsPremium: () async => true,
        readConsentAllowsAds: () async {
          consentReads++;
          return true;
        },
      );

      expect(await service.canRequestAds(), isFalse);
      expect(consentReads, 0);
    });

    test('disabled her koşulda kapalı', () async {
      final AdService service = AdService.disabled();

      expect(await service.canRequestAds(), isFalse);
      // Kapı kapalıyken SDK'ya hiç gidilmediği için bu çağrılar kanalsız
      // koşumda da patlamıyor; dönen değerler "reklam yok" anlamına geliyor.
      expect(await service.resolveBannerSize(360), isNull);
      expect(
        await service.loadBanner(size: AdSize.banner, onLoaded: () {}, onFailed: () {}),
        isNull,
      );
      expect(await service.showInterstitial(), isFalse);
    });
  });
}
