import 'package:flutter/foundation.dart';

/// AdMob reklam birimi kimlikleri (SPEC.md §7.1/§7.2).
///
/// Varsayılanlar Google'ın **resmî test** birimleridir — `AndroidManifest.xml`
/// içindeki `APPLICATION_ID` ile aynı gerekçe: gerçek AdMob hesabı henüz
/// açılmadı ve test birimleri olmadan geliştirme koşumları politika ihlali
/// sayılan "kendi reklamına tıklama" trafiği üretirdi. Gerçek birimler
/// `ExamSourceService.remoteOverrideUrl` ile aynı kalıpta, `--dart-define`
/// ile verilir (`DECISIONS.md` "Faz 11"); kod değişikliği gerekmez.
abstract final class AdUnitIds {
  static const String bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  static const String bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  static const String interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: _interstitialAndroidTest,
  );

  static const String interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  /// `Platform.isIOS` yerine [defaultTargetPlatform]: `dart:io` testlerin
  /// koştuğu masaüstü ana makinede yanlış dalı seçerdi.
  static String get banner =>
      defaultTargetPlatform == TargetPlatform.iOS ? bannerIos : bannerAndroid;

  /// Odaq'ın gerçek "Döngü sonu" geçiş reklamı birimi (AdMob). Yalnızca
  /// release derlemesinde kullanılır; debug/profil test birimiyle kalır.
  static const String interstitialAndroidProduction = 'ca-app-pub-7880867934531229/7676652252';

  static String get interstitial {
    if (defaultTargetPlatform == TargetPlatform.iOS) return interstitialIos;
    // `--dart-define` ile verilen değer her zaman öncelikli.
    if (interstitialAndroid != _interstitialAndroidTest) return interstitialAndroid;
    return kReleaseMode ? interstitialAndroidProduction : interstitialAndroid;
  }

  static const String _interstitialAndroidTest = 'ca-app-pub-3940256099942544/1033173712';
}
