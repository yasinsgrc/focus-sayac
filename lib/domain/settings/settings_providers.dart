import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';

/// Tek satırlık `AppSettings` tablosunun canlı görünümü. Ayar yazıldığında
/// (Ekran 07) otomatik yeniden yayınlanır (drift `watchSingle`) — ayarı
/// gösteren ekranların ayrı bir yenileme yolu kurmasına gerek kalmıyor.
///
/// Ayarı yalnızca işlem anında bir kez okuyan çağıranlar (`PomodoroController`,
/// `BadgeUnlockService`) `appSettingsDaoProvider.getSettings()` kullanmaya
/// devam ediyor; bu akış, ayarı **ekranda** gösterenler için.
final StreamProvider<AppSettingsTableData> appSettingsProvider =
    StreamProvider<AppSettingsTableData>((Ref ref) {
  return ref.watch(appSettingsDaoProvider).watchSettings();
});

/// Ayarlardaki odak süresi (dakika). Akış ilk değerini yayınlamadan önce
/// `null` olur; burada varsayılana (25) düşülmüyor çünkü o değerin tek sahibi
/// `AppSettingsTable`ın kolon varsayılanı — süre bilinmiyorken çağıran sayıyı
/// hiç göstermemeli (SPEC.md DoD: demo sayıları kodda olmaz).
final Provider<int?> focusMinutesProvider = Provider<int?>((Ref ref) {
  return ref.watch(appSettingsProvider).value?.focusMinutes;
});
