import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/storage_providers.dart';

final Provider<RemoteFlags> remoteFlagsProvider = Provider<RemoteFlags>((Ref ref) {
  return RemoteFlags(ref.watch(sharedPreferencesProvider));
});

/// SPEC.md §7.2'nin "`RemoteFlags.interstitialEnabled` ile kapatılabilir olsun
/// (varsayılan `true`)" gereği: interstitial'ı **yeni sürüm çıkmadan**
/// kapatabilmek için tek anahtar.
///
/// Henüz gerçek bir backend verilmedi (`ExamSourceService` ile aynı durum,
/// `DECISIONS.md` Faz 3). Bu yüzden değer `SharedPreferences`ta tutuluyor:
/// uzak yapılandırma bağlandığında yazacağı yer burasıdır ve okuyan taraf
/// (`InterstitialManager`) değişmez. Anahtar hiç yazılmamışken derleme
/// zamanı varsayılanı geçerlidir; acil bir kapatma için `--dart-define`
/// yeterli, kod değişikliği gerekmez.
class RemoteFlags {
  RemoteFlags(this._prefs);

  static const String interstitialEnabledPrefsKey = 'remote_flag_interstitial_enabled_v1';

  static const bool interstitialEnabledDefault =
      bool.fromEnvironment('INTERSTITIAL_ENABLED', defaultValue: true);

  final SharedPreferences _prefs;

  bool get interstitialEnabled =>
      _prefs.getBool(interstitialEnabledPrefsKey) ?? interstitialEnabledDefault;

  Future<void> setInterstitialEnabled(bool value) {
    return _prefs.setBool(interstitialEnabledPrefsKey, value);
  }
}
