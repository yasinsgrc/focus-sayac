import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/l10n/l10n_providers.dart';
import '../../l10n/gen/app_localizations.dart';

/// SPEC.md §3 Ekran 12'nin tek sahibi olan Riverpod sağlayıcı. `main.dart`
/// gerçek [NotificationService] örneğiyle geçersiz kılar; SPEC §1'in
/// "singleton servisler yasak" kuralı gereği elle yazılmış statik bir
/// singleton yerine `appDatabaseProvider`/`sharedPreferencesProvider` ile
/// aynı DI kalıbı kullanılıyor (Faz 6 kararı).
final Provider<NotificationService> notificationServiceProvider = Provider<NotificationService>((Ref ref) {
  throw UnimplementedError('notificationServiceProvider main.dart içinde override edilmeli.');
});

/// `AppSettings`in bildirim gönderimini etkileyen alanlarının, depolama
/// katmanından bağımsız görünümü (SPEC.md §4 / Ekran 07). `AppSettingsTableData`
/// doğrudan kullanılmıyor ki `services/notifications` `services/storage`'a
/// bağlanmasın; eşleme tek yerde, `main.dart`'ta yapılır.
class NotificationPreferences {
  const NotificationPreferences({
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.streakReminderEnabled,
  });

  /// Ayar okuyamayan bağlamlar (testler, [NotificationService.disabled]) için
  /// varsayılan — `AppSettingsTable`ın kolon varsayılanlarıyla aynı.
  const NotificationPreferences.allEnabled()
      : notificationsEnabled = true,
        soundEnabled = true,
        streakReminderEnabled = true;

  /// Ana anahtar: kapalıyken hiçbir bildirim **gönderilmez** (iptaller yine
  /// çalışır, bkz. [NotificationService]).
  final bool notificationsEnabled;
  final bool soundEnabled;

  /// Yalnızca "seri riski" tipini kapatır; diğer üç tip açık kalır.
  final bool streakReminderEnabled;
}

/// Her gönderim anında güncel ayarları okur. `AppSettings` tek satırlık bir
/// tablo olduğu için okuma ucuz; anlık görüntüyü serviste önbelleğe almak
/// yerine her çağrıda okumak, ayar değiştiğinde servisi haberdar edecek ayrı
/// bir senkronizasyon yolu gerekmemesini sağlıyor.
typedef NotificationPreferencesReader = Future<NotificationPreferences> Function();

/// SPEC.md Ekran 12'nin dört bildirim tipi: seans bitişi, seri riski, rozet,
/// kalıcı ("Odak · n. pomodoro"). Gerçek platform kanalını yalnızca
/// [NotificationService.new] açar; [NotificationService.disabled] (testler
/// için) tüm çağrıları no-op yapar — `AppDatabase.forTesting` ile aynı kalıp.
///
/// SPEC.md Ekran 07'nin "Bildirimler"/"Ses" anahtarları ve
/// `streakReminderEnabled` burada, tek noktada uygulanır — çağıranların her
/// birinde ayrı ayrı değil (`PomodoroController`, `BadgeUnlockService` ve
/// `main.dart` üç ayrı çağıran; kontrolü onlara dağıtmak birinin
/// unutulmasına açık kapı bırakırdı).
///
/// **İptaller bilinçli olarak kapıdan muaf:** kullanıcı seans sürerken
/// bildirimleri kapatırsa, o seansın bekleyen/kalıcı kaydını temizleyecek
/// olan yine `cancel*` çağrılarıdır — onları da kapatmak, kapatma anında
/// ekranda duran kalıcı bildirimi kalıcı olarak orada bırakırdı.
class NotificationService {
  NotificationService({required AppLocalizations l10n, NotificationPreferencesReader? readPreferences})
      : _l10n = l10n,
        _plugin = FlutterLocalNotificationsPlugin(),
        _readPreferences = readPreferences ?? _allEnabled;

  NotificationService.disabled({AppLocalizations? l10n, NotificationPreferencesReader? readPreferences})
      : _l10n = l10n ?? _fallbackL10n,
        _plugin = null,
        _readPreferences = readPreferences ?? _allEnabled;

  static Future<NotificationPreferences> _allEnabled() async => const NotificationPreferences.allEnabled();

  /// [NotificationService.disabled] hiçbir şey göndermediği için metinlere de
  /// ihtiyacı yok; yine de alan `late` olmasın diye uygulamanın tek diliyle
  /// dolduruluyor (testlerin her `disabled()` çağrısına ARB örneği taşımasına
  /// gerek kalmıyor).
  static final AppLocalizations _fallbackL10n = lookupAppLocalizations(kAppLocale);

  /// SPEC.md Ekran 12: dört bildirim metni **birebir** ARB'den. Servisin
  /// `BuildContext`i yok (bildirim ekran açık değilken de kuruluyor), bu yüzden
  /// örnek kurulumda veriliyor — `core/l10n/l10n_providers.dart` ile aynı kaynak.
  final AppLocalizations _l10n;
  final FlutterLocalNotificationsPlugin? _plugin;
  final NotificationPreferencesReader _readPreferences;
  tz.Location? _istanbul;

  static const int _sessionEndNotificationId = 1001;
  static const int _ongoingFocusNotificationId = 1002;
  static const int _streakRiskNotificationId = 1003;
  static const int _breakEndNotificationId = 1004;

  /// SPEC.md Ekran 07 "Ses" anahtarının Android karşılığı. Bir kanalın ses
  /// ayarı **oluşturulduktan sonra değiştirilemez** (Android 8+: kanal
  /// ayarları kullanıcıya aittir, uygulama `playSound`'u sonradan
  /// güncelleyemez). Bu yüzden aynı kanalın `playSound: false` ikizi ayrı bir
  /// kanal kimliğiyle tanımlanıyor ve gönderim anında ayara göre biri
  /// seçiliyor; tek kanalda bayrağı çevirmek ilk kurulumdan sonra hiçbir
  /// etki yaratmazdı. "Kalıcı" bildirimin zaten sesi yok (SPEC Ekran 12),
  /// bu yüzden onun sessiz ikizi yok.
  /// Kanal kimlikleri kullanıcıya görünmez ve **değiştirilmemeli** (Android
  /// kanalı ilk oluşturulduğu kimlikle tanır); ad/açıklama ise Android'in
  /// bildirim ayarlarında görünen kullanıcı metni, o yüzden ARB'den geliyor.
  /// `const` olamamalarının tek sebebi bu — davranışları değişmedi.
  AndroidNotificationDetails get _sessionEndAndroidDetails => AndroidNotificationDetails(
        'session_end',
        _l10n.notificationChannelSessionEndName,
        channelDescription: _l10n.notificationChannelSessionEndDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  AndroidNotificationDetails get _sessionEndSilentAndroidDetails => AndroidNotificationDetails(
        'session_end_silent',
        _l10n.notificationChannelSessionEndSilentName,
        channelDescription: _l10n.notificationChannelSessionEndSilentDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
      );

  AndroidNotificationDetails get _ongoingAndroidDetails => AndroidNotificationDetails(
        'ongoing_focus',
        _l10n.notificationChannelOngoingName,
        channelDescription: _l10n.notificationChannelOngoingDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        playSound: false,
        enableVibration: false,
      );

  AndroidNotificationDetails get _streakRiskAndroidDetails => AndroidNotificationDetails(
        'streak_risk',
        _l10n.notificationChannelStreakRiskName,
        channelDescription: _l10n.notificationChannelStreakRiskDescription,
      );

  AndroidNotificationDetails get _streakRiskSilentAndroidDetails => AndroidNotificationDetails(
        'streak_risk_silent',
        _l10n.notificationChannelStreakRiskSilentName,
        channelDescription: _l10n.notificationChannelStreakRiskSilentDescription,
        playSound: false,
      );

  AndroidNotificationDetails get _badgeAndroidDetails => AndroidNotificationDetails(
        'badge_unlocked',
        _l10n.notificationChannelBadgeName,
        channelDescription: _l10n.notificationChannelBadgeDescription,
      );

  AndroidNotificationDetails get _badgeSilentAndroidDetails => AndroidNotificationDetails(
        'badge_unlocked_silent',
        _l10n.notificationChannelBadgeSilentName,
        channelDescription: _l10n.notificationChannelBadgeSilentDescription,
        playSound: false,
      );

  /// `timezone` veritabanını yükler ve platform kanalını başlatır. İzin
  /// **istemez**: açılışta hiçbir bağlam vermeden sistem diyaloğu açmak,
  /// SPEC.md Ekran 01'in işi olan "neden gerekli" anlatısını atlıyordu. İzin
  /// isteği [requestPermissions]'a ayrıldı ve onboarding'den tetikleniyor
  /// (Faz 10, "aynı servis tekrar kullanılacak" — Faz 6 kararı). Kanal
  /// başlatma açılışta kalıyor: kurulmuş bildirimlerin iptali izinden
  /// bağımsız çalışmalı.
  Future<void> initialize() async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    tz_data.initializeTimeZones();
    _istanbul = tz.getLocation('Europe/Istanbul');
    // Görsel Kimlik 04: durum çubuğu ikonu tek renk + alfa olmak zorunda.
    // `@mipmap/ic_launcher` tam renkli olduğu için Android onu düz beyaz bir
    // lekeye indirgiyordu; `ic_notification` işaretin siluetini taşıyor.
    // Buradaki değer varsayılan: `AndroidNotificationDetails`lerin hiçbiri
    // `icon:` geçmiyor, hepsi bunu miras alıyor.
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    await plugin.initialize(settings: const InitializationSettings(android: androidInit));
  }

  /// SPEC.md Ekran 01 "İZİN VER VE BAŞLA": `POST_NOTIFICATIONS` →
  /// `SCHEDULE_EXACT_ALARM` **sırayla**. İkisi de reddedilse uygulama tam
  /// çalışmaya devam ettiği için (SPEC DoD) dönüş değeri yok — çağıran akış
  /// sonuca göre dallanmıyor, yalnızca sırayı bekliyor.
  Future<void> requestPermissions() async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    final AndroidFlutterLocalNotificationsPlugin? android = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  tz.Location get _location => _istanbul ?? (_istanbul = tz.getLocation('Europe/Istanbul'));

  /// Gönderim kapısı: ana anahtar kapalıysa `null` döner ve çağıran metot
  /// hiçbir şey göndermeden çıkar. Açıksa dönen [NotificationPreferences]
  /// hangi kanalın (sesli/sessiz) kullanılacağını da belirler.
  Future<NotificationPreferences?> _allowedPreferences() async {
    final NotificationPreferences preferences = await _readPreferences();
    return preferences.notificationsEnabled ? preferences : null;
  }

  /// Zamanlanan üç bildirimin tek çıkışı. Kesin alarm (`exactAllowWhileIdle`)
  /// Android 12+'ta `SCHEDULE_EXACT_ALARM` izni ister; izin verilmemişse
  /// eklenti `PlatformException(exact_alarms_not_permitted)` **fırlatır**.
  ///
  /// Bu hata çağıranlara sızmamalı: SPEC.md Ekran 01 "ikisi de reddedilse
  /// uygulama tam çalışmaya devam eder" diyor, oysa fırlayan hata
  /// `PomodoroController.startFocus`/`_completeFocus`'u ortasından kesiyordu —
  /// odak tamamlanışında rozet değerlendirmesi (`BadgeUnlockService`), haptik
  /// ve interstitial hiç çalışmıyordu. Kapıyı burada, tek noktada tutmak
  /// üç çağıranın her birine ayrı `try` dağıtmaktan güvenli (ana anahtar ve
  /// sesli/sessiz kanal seçimi de aynı gerekçeyle burada).
  ///
  /// Sessizce yutmak yerine kesin olmayan moda düşülüyor: `inexact` alarm izin
  /// istemiyor, bildirim yine geliyor — yalnızca Android'in takdirine bağlı
  /// bir gecikmeyle. Bildirimi tümden atmak, izni vermeyen kullanıcıyı
  /// seansın bittiğinden habersiz bırakırdı.
  Future<void> _zonedSchedule(
    FlutterLocalNotificationsPlugin plugin, {
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
  }) async {
    try {
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') rethrow;
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

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
    final NotificationPreferences? preferences = await _allowedPreferences();
    if (preferences == null) return;
    await _zonedSchedule(
      plugin,
      id: _sessionEndNotificationId,
      title: _l10n.notificationSessionEndTitle,
      body: _l10n.notificationSessionEndBody(focusMinutes, breakMinutes),
      scheduledDate: tz.TZDateTime.from(endAtUtc, _location),
      notificationDetails: NotificationDetails(
        android: preferences.soundEnabled ? _sessionEndAndroidDetails : _sessionEndSilentAndroidDetails,
      ),
    );
  }

  Future<void> cancelFocusSessionEnd() async {
    await _plugin?.cancel(id: _sessionEndNotificationId);
  }

  /// SPEC.md Ekran 12 "Seans bitişi" tipinin mola karşılığı — mola da bir
  /// `PomodoroSession` olduğu için ayrı bir beşinci tip değil, aynı kanaldan
  /// (yalnızca farklı `id`, ki odak bitişi bildirimi ile birbirlerini
  /// ezmesinler) gönderilir. Mola başında kurulur ve her "5 dk ekle"de yeni
  /// bitiş anına taşınır; uygulama arka plandayken molanın bittiğini haber
  /// veren tek mekanizma budur (ekranın tikleyicisi arka planda duruyor).
  Future<void> scheduleBreakEnd({
    required DateTime endAtUtc,
    required int breakMinutes,
  }) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    final NotificationPreferences? preferences = await _allowedPreferences();
    if (preferences == null) return;
    await _zonedSchedule(
      plugin,
      id: _breakEndNotificationId,
      title: _l10n.notificationBreakEndTitle,
      body: _l10n.notificationBreakEndBody(breakMinutes),
      scheduledDate: tz.TZDateTime.from(endAtUtc, _location),
      notificationDetails: NotificationDetails(
        android: preferences.soundEnabled ? _sessionEndAndroidDetails : _sessionEndSilentAndroidDetails,
      ),
    );
  }

  Future<void> cancelBreakEnd() async {
    await _plugin?.cancel(id: _breakEndNotificationId);
  }

  /// SPEC.md Ekran 12 "Kalıcı" — `ongoing:true, autoCancel:false`. Canlı
  /// saniye güncellemesi yapılmaz (foreground service gerektirir, pil
  /// yakar — DECISIONS.md Faz 5/6 kararı); yalnızca döngü konumu değişince
  /// yeniden çağrılır.
  Future<void> showOngoingFocus({required int cyclePosition}) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    if (await _allowedPreferences() == null) return;
    await plugin.show(
      id: _ongoingFocusNotificationId,
      title: _l10n.notificationOngoingTitle(cyclePosition),
      notificationDetails: NotificationDetails(android: _ongoingAndroidDetails),
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
    // İptal kapıdan önce: bu metot her yeniden değerlendirme noktasında
    // çağrıldığı için, ayar kapatıldıktan sonraki ilk çağrı önceden kurulmuş
    // hatırlatmayı da temizlemiş olur.
    await plugin.cancel(id: _streakRiskNotificationId);
    final NotificationPreferences? preferences = await _allowedPreferences();
    if (preferences == null || !preferences.streakReminderEnabled) return;
    if (completedToday || streak < 1) return;
    final tz.TZDateTime now = tz.TZDateTime.now(_location);
    final tz.TZDateTime target = tz.TZDateTime(_location, now.year, now.month, now.day, 21);
    if (!target.isAfter(now)) return;
    await _zonedSchedule(
      plugin,
      id: _streakRiskNotificationId,
      title: _l10n.notificationStreakRiskTitle,
      body: _l10n.notificationStreakRiskBody(streak),
      scheduledDate: target,
      notificationDetails: NotificationDetails(
        android: preferences.soundEnabled ? _streakRiskAndroidDetails : _streakRiskSilentAndroidDetails,
      ),
    );
  }

  /// SPEC.md Ekran 12 "Rozet" — [ruleDescription] `badge_rules.dart`
  /// kataloğunun kural açıklaması (Faz 7'de bağlanacak, bu metot şimdiden
  /// hazır).
  Future<void> showBadgeUnlocked({required String name, required String ruleDescription}) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    final NotificationPreferences? preferences = await _allowedPreferences();
    if (preferences == null) return;
    await plugin.show(
      id: name.hashCode & 0x7fffffff,
      title: _l10n.notificationBadgeTitle(name),
      body: _l10n.notificationBadgeBody(ruleDescription),
      notificationDetails: NotificationDetails(
        android: preferences.soundEnabled ? _badgeAndroidDetails : _badgeSilentAndroidDetails,
      ),
    );
  }
}
