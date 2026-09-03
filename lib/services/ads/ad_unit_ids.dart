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
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  static const String interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  /// `Platform.isIOS` yerine [defaultTargetPlatform]: `dart:io` testlerin
  /// koştuğu masaüstü ana makinede yanlış dalı seçerdi.
  static String get banner =>
      defaultTargetPlatform == TargetPlatform.iOS ? bannerIos : bannerAndroid;

  static String get interstitial =>
      defaultTargetPlatform == TargetPlatform.iOS ? interstitialIos : interstitialAndroid;
}
