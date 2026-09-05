import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/l10n_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/time/app_day.dart';
import 'domain/settings/settings_providers.dart';
import 'domain/streak/streak_calculator.dart';
import 'l10n/gen/app_localizations.dart';
import 'services/ads/ad_service.dart';
import 'services/consent/consent_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/storage/app_database.dart';
import 'services/storage/exam_source_service.dart';
import 'services/storage/storage_enums.dart';
import 'services/storage/storage_providers.dart';
import 'services/widgets/home_widget_sync.dart';
import 'services/widgets/widget_launch_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ekran 02/08/11'in Türkçe tarih biçimleri (`DateFormat('d MMMM y', 'tr')`)
  // için gerekli — olmadan 'tr' locale verisi eksik hatası fırlatır.
  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // SPEC.md §4: uzak override sessizce dener, hata/URL boşsa yerel seed
  // korunur — açılışı bloklamadan arka planda tetiklenir.
  unawaited(
    ExamSourceService(database: database, prefs: prefs).syncIfNeeded(),
  );
  // Bildirim metinleri de ARB'den (SPEC.md Ekran 12 "metinler birebir ARB'ye").
  // Servisin bağlamı yok, bu yüzden `AppLocalizations` örneği kurulumda
  // veriliyor — `appLocalizationsProvider` ile aynı kaynak.
  final AppLocalizations l10n = lookupAppLocalizations(kAppLocale);
  final NotificationService notificationService = NotificationService(
    l10n: l10n,
    readPreferences: () => _readNotificationPreferences(database),
  );
  // Yalnızca platform kanalını açar. İzinler (POST_NOTIFICATIONS →
  // SCHEDULE_EXACT_ALARM) artık burada değil, Ekran 01'in "İZİN VER VE BAŞLA"
  // dokunuşuyla isteniyor: açılışta bağlamsız bir sistem diyaloğu açmak
  // SPEC.md Ekran 01'in anlattığı gerekçeyi atlıyordu. Ekran 01 aynı servisi
  // tekrar kullanıyor (Faz 6 kararı, DECISIONS.md).
  await notificationService.initialize();
  unawaited(_rescheduleStreakRiskReminder(database, notificationService));
  // SPEC.md §7: UMP onayı Ekran 01'de toplanıyor, reklam isteğinin kapısı
  // `AdService.canRequestAds` (onay + `isPremium`). SDK'nın başlatılması
  // reklam istemek değil, o yüzden açılışta ve onaydan bağımsız yapılıyor;
  // ilk istek her hâlükârda kapıdan geçiyor.
  final ConsentService consentService = ConsentService();
  final AdService adService = AdService(
    readIsPremium: () async => (await database.appSettingsDao.getSettings()).isPremium,
    readConsentAllowsAds: consentService.canRequestAds,
  );
  unawaited(adService.initialize());
  // Başlangıç rotasının (Ekran 01 mi Ekran 02 mi) senkron bilmesi gereken tek
  // değer; `appSettingsDaoProvider` yerine `database` doğrudan okunuyor çünkü
  // Riverpod ağacı henüz kurulmadı (`_rescheduleStreakRiskReminder` ile aynı
  // gerekçe).
  final AppSettingsTableData launchSettings = await database.appSettingsDao.getSettings();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notificationService),
        consentServiceProvider.overrideWithValue(consentService),
        adServiceProvider.overrideWithValue(adService),
        onboardingCompletedAtLaunchProvider.overrideWithValue(launchSettings.onboardingCompleted),
        themeModeAtLaunchProvider.overrideWithValue(launchSettings.themeMode),
      ],
      // Ana ekran widgetlari iki gorunmez kabuk kullaniyor (Faz 16):
      // `HomeWidgetSyncScope` anlik goruntuyu paylasilan depoya yazar,
      // `WidgetLaunchScope` widget dokunuslarini rotalara cevirir. Ikisi de
      // `ProviderScope` altinda, `MaterialApp`in ustunde duruyor: yonlendirici
      // saglayicisina erisip hicbir sey cizmiyorlar.
      child: const HomeWidgetSyncScope(
        child: WidgetLaunchScope(
          child: FocusSayacApp(),
        ),
      ),
    ),
  );
}

/// `AppSettings` → [NotificationPreferences] eşlemesinin tek yeri. Servis
/// depolama katmanına bağlanmasın diye `AppSettingsTableData`yı burada
/// çeviriyoruz (SPEC.md Ekran 07 anahtarları). Riverpod ağacı kurulmadan
/// önce de gerekli olduğu için `appSettingsDaoProvider` yerine `database`
/// doğrudan okunuyor — `_rescheduleStreakRiskReminder` ile aynı gerekçe.
Future<NotificationPreferences> _readNotificationPreferences(AppDatabase database) async {
  final AppSettingsTableData settings = await database.appSettingsDao.getSettings();
  return NotificationPreferences(
    notificationsEnabled: settings.notificationsEnabled,
    soundEnabled: settings.soundEnabled,
    streakReminderEnabled: settings.streakReminderEnabled,
  );
}

/// SPEC.md Ekran 12 "seri riski" — açılışta bugünün durumunu hesaplayıp
/// [NotificationService.rescheduleStreakRiskReminder]'ı tetikler. Riverpod
/// ağacı henüz kurulmadığı için `PomodoroSessionDao` doğrudan okunur, aynı
/// hesap `pomodoro_stats_providers.dart`'ın `todayFocusStatsProvider`/
/// `streakProvider`'ıyla birebir aynı (Faz 6 kararı).
Future<void> _rescheduleStreakRiskReminder(AppDatabase database, NotificationService notificationService) async {
  final List<PomodoroSession> sessions = await database.pomodoroSessionDao.watchAllSessions().first;
  final DateTime nowUtc = DateTime.now().toUtc();
  final DateTime today = currentAppDayKey(nowUtc);
  final List<DateTime> completedFocusStarts = <DateTime>[];
  bool completedToday = false;
  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) continue;
    completedFocusStarts.add(session.startedAt);
    if (appDayKey(session.startedAt) == today) completedToday = true;
  }
  final int streak = calculateStreak(completedFocusStartedAtUtc: completedFocusStarts, nowUtc: nowUtc);
  await notificationService.rescheduleStreakRiskReminder(completedToday: completedToday, streak: streak);
}

class FocusSayacApp extends ConsumerWidget {
  const FocusSayacApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      // `theme` Material'ın açık yuvası, `darkTheme` koyu yuvası — isimlendirme
      // framework'ten geliyor. Uygulamanın tasarım referansı olan koyu tema
      // `darkTheme`e, Faz 17'de eklenen açık tema `theme`e gidiyor.
      theme: buildAppLightTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ref.watch(themeModeProvider),
      // Tek dil sabitleniyor: cihaz Türkçe değilken de uygulama Türkçe kalır
      // (ARB'de yalnızca `tr` var). Delegeler Material'ın kendi metinlerini
      // (tarih/saat seçici, `showDatePicker`) de Türkçeye çeviriyor.
      locale: kAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
