import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// SPEC.md §3 Ekran 12'nin tek sahibi olan Riverpod sağlayıcı. `main.dart`
/// gerçek [NotificationService] örneğiyle geçersiz kılar; SPEC §1'in
/// "singleton servisler yasak" kuralı gereği elle yazılmış statik bir
/// singleton yerine `appDatabaseProvider`/`sharedPreferencesProvider` ile
/// aynı DI kalıbı kullanılıyor (Faz 6 kararı).
final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>((Ref ref) {
  throw UnimplementedError('notificationServiceProvider main.dart içinde override edilmeli.');
});

/// SPEC.md Ekran 12'nin dört bildirim tipi: seans bitişi, seri riski, rozet,
/// kalıcı ("Odak · n. pomodoro"). Gerçek platform kanalını yalnızca
/// [NotificationService.new] açar; [NotificationService.disabled] (testler
/// için) tüm çağrıları no-op yapar — `AppDatabase.forTesting` ile aynı kalıp.
class NotificationService {
  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  NotificationService.disabled() : _plugin = null;

  final FlutterLocalNotificationsPlugin? _plugin;
  tz.Location? _istanbul;

  static const int _sessionEndNotificationId = 1001;
  static const int _ongoingFocusNotificationId = 1002;
  static const int _streakRiskNotificationId = 1003;

  static const AndroidNotificationDetails _sessionEndAndroidDetails = AndroidNotificationDetails(
    'session_end',
    'Seans bitişi',
    channelDescription: 'Odak süresi dolduğunda gönderilir.',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails _ongoingAndroidDetails = AndroidNotificationDetails(
    'ongoing_focus',
    'Odak sürüyor',
    channelDescription: 'Odak seansı sürerken gösterilen kalıcı bildirim.',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showWhen: false,
    playSound: false,
    enableVibration: false,
  );

  static const AndroidNotificationDetails _streakRiskAndroidDetails = AndroidNotificationDetails(
    'streak_risk',
    'Seri riski',
    channelDescription: 'Günlük seri kapanmadan önce gönderilen hatırlatma.',
  );

  static const AndroidNotificationDetails _badgeAndroidDetails = AndroidNotificationDetails(
    'badge_unlocked',
    'Yeni rozet',
    channelDescription: 'Bir rozet açıldığında gönderilir.',
  );

  /// `timezone` veritabanını yükler, platform kanalını başlatır ve SPEC.md
  /// Ekran 01 sırasıyla (`POST_NOTIFICATIONS` → `SCHEDULE_EXACT_ALARM`) izin
  /// ister. Ekran 01'in kendisi (onboarding UI) Faz 10'da geliyor; bu
  /// çağrı `main.dart`'ta açılışta tetiklenir — reddedilse de uygulama
  /// tam çalışmaya devam eder (SPEC DoD), Faz 10 aynı servisi tekrar
  /// kullanacak (Faz 6 kararı).
  Future<void> initialize() async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    tz_data.initializeTimeZones();
    _istanbul = tz.getLocation('Europe/Istanbul');
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(settings: const InitializationSettings(android: androidInit));
    final AndroidFlutterLocalNotificationsPlugin? android = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  tz.Location get _location => _istanbul ?? (_istanbul = tz.getLocation('Europe/Istanbul'));

  /// SPEC.md Ekran 12 "Seans bitişi" — seans başında kurulur, [endAtUtc]'de
  /// tetiklenir. Metindeki dakika sayıları demo veri değil, çağıranın
  /// geçtiği gerçek ayar değerleridir (SPEC DoD "demo sayılarının hiçbiri
  /// kodda yok").
  Future<void> scheduleFocusSessionEnd({
    required DateTime endAtUtc,
    required int focusMinutes,
    required int breakMinutes,
  }) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    await plugin.zonedSchedule(
      id: _sessionEndNotificationId,
      title: 'Seans tamamlandı',
      body: '$focusMinutes dakika odak bitti. Meşalen büyüdü — $breakMinutes dakika mola vakti.',
      scheduledDate: tz.TZDateTime.from(endAtUtc, _location),
      notificationDetails: const NotificationDetails(android: _sessionEndAndroidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelFocusSessionEnd() async {
    await _plugin?.cancel(id: _sessionEndNotificationId);
  }

  /// SPEC.md Ekran 12 "Kalıcı" — `ongoing:true, autoCancel:false`. Canlı
  /// saniye güncellemesi yapılmaz (foreground service gerektirir, pil
  /// yakar — DECISIONS.md Faz 5/6 kararı); yalnızca döngü konumu değişince
  /// yeniden çağrılır.
  Future<void> showOngoingFocus({required int cyclePosition}) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    await plugin.show(
      id: _ongoingFocusNotificationId,
      title: 'Odak · $cyclePosition. pomodoro',
      notificationDetails: const NotificationDetails(android: _ongoingAndroidDetails),
    );
  }

  Future<void> cancelOngoingFocus() async {
    await _plugin?.cancel(id: _ongoingFocusNotificationId);
  }

  /// SPEC.md Ekran 12 "Seri riski" — her gün 21:00 TSİ, yalnızca bugün
  /// tamamlanmış bir odak seansı yoksa **ve** güncel seri ≥1 ise. SPEC §1
  /// backend/cloud sync'i yasakladığı için koşul, geleceğe dönük tek bir
  /// arka plan işiyle değil, her yeniden değerlendirme noktasında (uygulama
  /// açılışı + her odak tamamlanışı) yeniden hesaplanıp o günün 21:00'i
  /// için tek seferlik kurulur/iptal edilir. Uygulama o gün hiç açılmazsa
  /// bildirim kurulmaz — yerel, arka planı olmayan bir zamanlayıcının doğal
  /// sınırı (Faz 6 kararı, DECISIONS.md).
  Future<void> rescheduleStreakRiskReminder({required bool completedToday, required int streak}) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    await plugin.cancel(id: _streakRiskNotificationId);
    if (completedToday || streak < 1) return;
    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    final tz.TZDateTime target = tz.TZDateTime(_location, now.year, now.month, now.day, 21);
    if (!target.isAfter(now)) return;
    await plugin.zonedSchedule(
      id: _streakRiskNotificationId,
      title: 'Serin risk altında',
      body: "$streak günlük seri için bugün 1 pomodoro yeter. Gün 04:00'te kapanıyor.",
      scheduledDate: target,
      notificationDetails: const NotificationDetails(android: _streakRiskAndroidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// SPEC.md Ekran 12 "Rozet" — [ruleDescription] `badge_rules.dart`
  /// kataloğunun kural açıklaması (Faz 7'de bağlanacak, bu metot şimdiden
  /// hazır).
  Future<void> showBadgeUnlocked({required String name, required String ruleDescription}) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    await plugin.show(
      id: name.hashCode & 0x7fffffff,
      title: 'Yeni rozet: $name',
      body: '$ruleDescription Başarı kartını paylaş.',
      notificationDetails: const NotificationDetails(android: _badgeAndroidDetails),
    );
  }
}
