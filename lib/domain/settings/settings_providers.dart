import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
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

/// Açılışta senkron okunan tema tercihi. `appSettingsProvider` bir akış;
/// ilk değerini yayınlayana kadar geçen karelerde uygulama bir temayla
/// çizilmek zorunda ve yanlış olanı seçmek gözle görülür bir sıçrama yaratır.
/// `main.dart` bunu `launchSettings` ile override ediyor
/// (`onboardingCompletedAtLaunchProvider` ile aynı gerekçe).
///
/// Fırlatmak yerine `system`'e düşüyor: kolon varsayılanıyla aynı değer, yani
/// override edilmese bile kullanıcıların çoğunda doğru; yalnızca açık/koyu'yu
/// elle seçmiş biri tek karelik bir sapma görür. Bu sayede ekranları izole
/// eden testlerin bu sağlayıcıyı tanıması gerekmiyor.
final Provider<AppThemeMode> themeModeAtLaunchProvider = Provider<AppThemeMode>((Ref ref) {
  return AppThemeMode.system;
});

/// Depolama enum'unu Flutter'ın [ThemeMode]'una çeviren tek yer. Akış bir
/// değer yayınladıktan sonra ayar canlı izleniyor — Ekran 07'de tema
/// değiştirildiğinde uygulama anında yeniden çiziliyor.
final Provider<ThemeMode> themeModeProvider = Provider<ThemeMode>((Ref ref) {
  final AppThemeMode mode =
      ref.watch(appSettingsProvider).value?.themeMode ?? ref.watch(themeModeAtLaunchProvider);
  return switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
});
