import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/services/notifications/notification_service.dart';

import '../../support/localized_test_app.dart';

/// Eklentinin Android kanalı. Gerçek platform yok; kanal sahte bir işleyiciyle
/// dinleniyor ki servisin **hangi** çağrıyı yaptığı (ya da yapmadığı)
/// görülebilsin. `NotificationService.disabled()` bu testler için uygun değil:
/// o, kapıya hiç gelmeden her şeyi no-op yapıyor.
const MethodChannel _channel = MethodChannel('dexterous.com/flutter/local_notifications');

int _idOf(MethodCall call) {
  final Object? arguments = call.arguments;
  return arguments is Map<Object?, Object?> ? arguments['id']! as int : arguments! as int;
}

/// `zonedSchedule` çağrısının eklentiye geçirdiği `AndroidScheduleMode` adı —
/// kesin/kesin olmayan alarm ayrımını testten görebilmenin tek yolu.
String _scheduleModeOf(MethodCall call) {
  final Map<Object?, Object?> arguments = call.arguments as Map<Object?, Object?>;
  final Map<Object?, Object?> specifics = arguments['platformSpecifics']! as Map<Object?, Object?>;
  return specifics['scheduleMode']! as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  /// `SCHEDULE_EXACT_ALARM` verilmemiş bir cihazı taklit eder: Android 12+
  /// bu izin olmadan kesin alarm kurmayı `exact_alarms_not_permitted` ile
  /// reddeder.
  late bool exactAlarmsPermitted;

  setUp(() {
    exactAlarmsPermitted = true;
    // Eklenti platform uygulamasını `defaultTargetPlatform`a göre seçiyor;
    // test sürecinin işletim sistemi (Windows) yerine uygulamanın hedefi
    // sabitleniyor. `registerWith` normalde üretilen kayıt defterinin işi.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (MethodCall call) async {
        calls.add(call);
        if (call.method == 'zonedSchedule' &&
            !exactAlarmsPermitted &&
            _scheduleModeOf(call).startsWith('exact')) {
          throw PlatformException(
            code: 'exact_alarms_not_permitted',
            message: 'Exact alarms are not permitted',
          );
        }
        return call.method == 'initialize' ? true : null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<NotificationService> serviceWith({required bool notificationsEnabled}) async {
    final NotificationService service = NotificationService(
      l10n: testL10n,
      readPreferences: () async => NotificationPreferences(
        notificationsEnabled: notificationsEnabled,
        soundEnabled: true,
        streakReminderEnabled: true,
      ),
    );
    await service.initialize();
    calls.clear();
    return service;
  }

  Future<void> sendEverything(NotificationService service) async {
    await service.scheduleFocusSessionEnd(
      endAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      focusMinutes: 25,
      breakMinutes: 5,
    );
    await service.scheduleBreakEnd(
      endAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      breakMinutes: 5,
    );
    await service.showOngoingFocus(cyclePosition: 1);
    await service.showBadgeUnlocked(name: 'İlk Kıvılcım', ruleDescription: 'İlk pomodoro tamamlandı.');
    await service.rescheduleStreakRiskReminder(completedToday: false, streak: 3);
  }

  Iterable<MethodCall> sends() =>
      calls.where((MethodCall call) => call.method == 'show' || call.method == 'zonedSchedule');

  // SPEC.md Ekran 07 "Bildirimler" ana anahtarı. Kapı tek noktada
  // (`NotificationService`) uygulanıyor; çağıranların hiçbiri kontrol
  // yapmadığı için kapının kendisi test edilmeli.
  test('bildirimler kapalıyken hiçbir bildirim gönderilmiyor', () async {
    final NotificationService service = await serviceWith(notificationsEnabled: false);

    await sendEverything(service);

    expect(sends(), isEmpty);
  });

  // Aynı çağrılar anahtar açıkken gerçekten kanala iniyor — yukarıdaki testin
  // "hiçbir şey olmadı" sonucunun sahte olmadığını gösteren karşı kontrol.
  test('bildirimler açıkken dört tip de gönderiliyor', () async {
    final NotificationService service = await serviceWith(notificationsEnabled: true);

    await sendEverything(service);

    // Seans bitişi + mola bitişi. Seri riski (1003) bilinçli olarak
    // beklenmiyor: yalnızca o günün 21:00'i **henüz gelmediyse** kuruluyor,
    // testi çalıştırma saatine bağlamamak için kapsam dışı.
    expect(
      calls.where((MethodCall call) => call.method == 'zonedSchedule').map(_idOf),
      containsAll(<int>[1001, 1004]),
    );
    // kalıcı "Odak · n. pomodoro" + rozet
    expect(calls.where((MethodCall call) => call.method == 'show'), hasLength(2));
  });

  // İptaller bilinçli olarak kapıdan muaf: kullanıcı seans sürerken
  // bildirimleri kapatırsa, ekranda duran kalıcı bildirimi ve kurulmuş
  // zamanlamayı temizleyecek olan yine bu çağrılar.
  test('bildirimler kapalıyken iptaller yine çalışıyor', () async {
    final NotificationService service = await serviceWith(notificationsEnabled: false);

    await service.cancelFocusSessionEnd();
    await service.cancelOngoingFocus();
    await service.cancelBreakEnd();

    expect(
      calls.where((MethodCall call) => call.method == 'cancel').map(_idOf),
      <int>[1001, 1002, 1004],
    );
  });

  // SPEC.md Ekran 01: "İkisi de reddedilse uygulama tam çalışmaya devam
  // eder." `SCHEDULE_EXACT_ALARM` verilmemişken kesin alarm kurmak
  // `PlatformException(exact_alarms_not_permitted)` fırlatıyor ve bu hata,
  // çağıran akışı (`PomodoroController._completeFocus`) ortasından kesip
  // rozet açılışını hiç çalıştırmıyordu. Bildirim kurulamaması, seansın
  // domain sonuçlarını iptal edemez.
  test('kesin alarm izni yokken zamanlama patlamıyor, kesin olmayana düşüyor', () async {
    final NotificationService service = await serviceWith(notificationsEnabled: true);
    exactAlarmsPermitted = false;

    await service.scheduleFocusSessionEnd(
      endAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      focusMinutes: 25,
      breakMinutes: 5,
    );
    await service.scheduleBreakEnd(
      endAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      breakMinutes: 5,
    );

    final List<MethodCall> scheduled =
        calls.where((MethodCall call) => call.method == 'zonedSchedule').toList();
    // Her iki bildirim de önce kesin modda denenip, reddedilince kesin
    // olmayan modda yeniden kuruluyor: bildirim yine geliyor, yalnızca
    // Android'in takdirine bağlı bir gecikmeyle.
    expect(scheduled.map(_idOf), <int>[1001, 1001, 1004, 1004]);
    expect(
      scheduled.map(_scheduleModeOf),
      <String>[
        'exactAllowWhileIdle',
        'inexactAllowWhileIdle',
        'exactAllowWhileIdle',
        'inexactAllowWhileIdle',
      ],
    );
  });

  // `rescheduleStreakRiskReminder` iptali kapıdan **önce** yapıyor: ayar
  // kapatıldıktan sonraki ilk çağrı, önceden kurulmuş hatırlatmayı da
  // temizlemiş oluyor.
  test('seri riski hatırlatması kapalı ayarla da iptal ediliyor', () async {
    final NotificationService service = await serviceWith(notificationsEnabled: false);

    await service.rescheduleStreakRiskReminder(completedToday: false, streak: 3);

    expect(calls.where((MethodCall call) => call.method == 'cancel').map(_idOf), <int>[1003]);
    expect(sends(), isEmpty);
  });
}
