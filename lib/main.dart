import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/time/app_day.dart';
import 'domain/streak/streak_calculator.dart';
import 'services/notifications/notification_service.dart';
import 'services/storage/app_database.dart';
import 'services/storage/exam_source_service.dart';
import 'services/storage/storage_enums.dart';
import 'services/storage/storage_providers.dart';

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
  final NotificationService notificationService = NotificationService(
    readPreferences: () => _readNotificationPreferences(database),
  );
  // SPEC.md Ekran 01: POST_NOTIFICATIONS → SCHEDULE_EXACT_ALARM izinleri de
  // burada istenir. Onboarding ekranının kendisi (Faz 10) henüz yok; izin
  // reddedilse de uygulama tam çalışmaya devam eder (SPEC DoD) — Faz 10
  // aynı servisi tekrar kullanacak (Faz 6 kararı, DECISIONS.md).
  await notificationService.initialize();
  unawaited(_rescheduleStreakRiskReminder(database, notificationService));
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const FocusSayacApp(),
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
      title: 'FocusSayaç',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
