# Dönüş yolu — uygulama planı

> **Ajan işçiler için:** ZORUNLU ALT BECERİ: bu planı görev görev uygulamak için
> `superpowers:subagent-driven-development` (önerilen) veya
> `superpowers:executing-plans` kullan. Adımlar takip için onay kutusu
> (`- [ ]`) söz dizimiyle yazıldı.

**Tasarım belgesi:** `docs/superpowers/specs/2026-09-17-donus-yolu-design.md`
**Yol haritası:** ROADMAP madde 26.

**Hedef:** Üç gün odaklanmayan kullanıcıya tek bir dönüş bildirimi gönder,
döndüğünde Ekran 02'de onu suçlamayan — kaybedileni değil korunanı söyleyen —
bir karşılama satırıyla karşıla.

**Mimari:** Saf bir hesaplayıcı (`comeback_status.dart`) hem bildirimi hem
şeridi besler; durum saklanmaz, tamamlanmış odak seanslarının geçmişinden
türetilir. Bildirim mevcut "iptal et → kapılar → kur" kalıbını kullanır, tek
farkı hedefin ileride olması. Şerit `BUGÜN` kartına `_WeeklyGoalRow` ile aynı
biçimde eklenir.

**Teknoloji:** Flutter, Riverpod (`Provider`), drift (göç **yok**),
`flutter_local_notifications` + `timezone`, ARB/`gen-l10n`, `flutter_test`.

---

## Tasarımdan iki sapma (bilerek)

1. **`calculateComebackStatus` imzası** spec'te `(completedFocusCount,
   lastCompletedFocusUtc)` idi; planda `List<DateTime>
   completedFocusStartedAtUtc` alıyor. Gerekçe: `calculateStreakStatus` ile
   birebir aynı imza, üç çağıranın (sağlayıcı, `main.dart`, denetleyici) hiçbiri
   "sonuncuyu bul" mantığını kopyalamıyor. DAO listesinin sıralı olduğuna dair
   bir garanti de yok, en büyük zaman damgası hesaplayıcının içinde bulunuyor.
2. **Şeridin yeri:** `BUGÜN` kartının içinde, haftalık hedef satırının hemen
   üstünde. Spec "seri satırının üstüne" diyordu; seri rozeti halkanın içinde
   duruyor ve ona dokunulmuyor — şerit kartın son bloğundan önce geliyor,
   `_WeeklyGoalRow` ile aynı ayırıcı kalıbıyla.

---

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| **Yeni** `lib/domain/streak/comeback_status.dart` | Saf hesaplayıcı: yokluk gün sayısı, şerit görünür mü, bildirim anı |
| **Yeni** `test/domain/streak/comeback_status_test.dart` | Hesaplayıcının tüm kenarları |
| `lib/l10n/app_tr.arb` | Beş yeni anahtar |
| `lib/services/notifications/notification_service.dart` | `rescheduleComebackReminder` + yeni id sabiti |
| `test/services/notifications/notification_service_test.dart` | Kurulum/iptal/kapı testleri |
| `lib/main.dart` | Açılış değerlendirme noktası |
| `lib/domain/pomodoro/pomodoro_controller.dart` | Odak tamamlanışı değerlendirme noktası |
| `test/domain/pomodoro/pomodoro_controller_test.dart` | Tamamlanışta yeniden kuruluyor |
| `lib/domain/pomodoro/pomodoro_stats_providers.dart` | `comebackStatusProvider` |
| `lib/features/countdown/countdown_screen.dart` | `_ComebackRow` + kartın içine bağlama |
| **Yeni** `test/features/countdown/comeback_row_test.dart` | Şerit görünür/görünmez + ekran okuyucu |
| `ROADMAP.md`, `DECISIONS.md` | Kapanış kaydı |

---

## Görev 1: Saf hesaplayıcı

**Dosyalar:**
- Oluştur: `lib/domain/streak/comeback_status.dart`
- Test: `test/domain/streak/comeback_status_test.dart`

- [ ] **Adım 1: Başarısız testi yaz**

`test/domain/streak/comeback_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/streak/comeback_status.dart';

/// 04:00 TSİ = 01:00 UTC. Testler gün sınırını bu iki komşu damgayla
/// yokluyor: 00:30 UTC (03:30 TSİ) bir önceki uygulama gününe, 01:30 UTC
/// (04:30 TSİ) yenisine aittir.
DateTime _utc(int year, int month, int day, [int hour = 12, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute);

void main() {
  group('calculateComebackStatus', () {
    test('hiç tamamlanmış seans yoksa ne şerit ne bildirim', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: const <DateTime>[],
        nowUtc: _utc(2026, 9, 17),
      );

      expect(status, ComebackStatus.none);
    });

    test('üç seanstan az yapan kullanıcı kapsam dışı', () {
      // İki seans, sonuncusu on gün önce: eşik dolmuş ama kullanıcı henüz
      // uygulamayı deneme aşamasında.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 6),
          _utc(2026, 9, 7),
        ],
        nowUtc: _utc(2026, 9, 17),
      );

      expect(status, ComebackStatus.none);
    });

    test('bugün çalışan kullanıcıda şerit yok, bildirim üç gün ileriye kurulu', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 15),
          _utc(2026, 9, 16),
          _utc(2026, 9, 17, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 0);
      expect(status.welcomeDue, isFalse);
      // 17 + 3 = 20 Eylül, 21:00 TSİ = 18:00 UTC.
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 20, 18));
    });

    test('iki gün yoklukta şerit hâlâ yok', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 13),
          _utc(2026, 9, 14),
          _utc(2026, 9, 15, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 2);
      expect(status.welcomeDue, isFalse);
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 18, 18));
    });

    test('üç gün yoklukta şerit açılıyor, bildirim bugünün 21:00 TSİ anına kurulu', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
          _utc(2026, 9, 14, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 3);
      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });

    test('pencere geçtiyse bildirim kurulmuyor ama şerit duruyor', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
          _utc(2026, 9, 14, 10),
        ],
        // Aynı gün, 19:00 UTC: hedef an (18:00 UTC) geride kaldı.
        nowUtc: _utc(2026, 9, 17, 19),
      );

      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, isNull);
    });

    test('uzun yoklukta bildirim birikmiyor — pencere tek gün', () {
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 3),
          _utc(2026, 9, 4),
          _utc(2026, 9, 5, 10),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(status.absentDays, 12);
      expect(status.welcomeDue, isTrue);
      expect(status.reminderAtUtc, isNull);
    });

    test('gün sınırı 04:00: 03:30 TSİ bir önceki güne yazılıyor', () {
      // Son seans 14 Eylül 00:30 UTC = 03:30 TSİ → uygulama günü 13 Eylül.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 11),
          _utc(2026, 9, 12),
          _utc(2026, 9, 14, 0, 30),
        ],
        // 17 Eylül 01:30 UTC = 04:30 TSİ → uygulama günü 17 Eylül.
        nowUtc: _utc(2026, 9, 17, 1, 30),
      );

      expect(status.absentDays, 4);
      expect(status.welcomeDue, isTrue);
      // 13 + 3 = 16 Eylül 18:00 UTC, çoktan geçti.
      expect(status.reminderAtUtc, isNull);
    });

    test('gün sınırı 04:00: bir saat sonrası aynı günü değiştiriyor', () {
      // Son seans 14 Eylül 01:30 UTC = 04:30 TSİ → uygulama günü 14 Eylül.
      final ComebackStatus status = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 11),
          _utc(2026, 9, 12),
          _utc(2026, 9, 14, 1, 30),
        ],
        nowUtc: _utc(2026, 9, 17, 1, 30),
      );

      expect(status.absentDays, 3);
      expect(status.welcomeDue, isTrue);
      // 14 + 3 = 17 Eylül 18:00 UTC, henüz gelmedi.
      expect(status.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });

    test('sonuncu seans listenin sırasından bağımsız bulunuyor', () {
      final ComebackStatus shuffled = calculateComebackStatus(
        completedFocusStartedAtUtc: <DateTime>[
          _utc(2026, 9, 14, 10),
          _utc(2026, 9, 12),
          _utc(2026, 9, 13),
        ],
        nowUtc: _utc(2026, 9, 17, 11),
      );

      expect(shuffled.absentDays, 3);
      expect(shuffled.reminderAtUtc, DateTime.utc(2026, 9, 17, 18));
    });
  });
}
```

- [ ] **Adım 2: Testin başarısız olduğunu doğrula**

Çalıştır: `flutter test test/domain/streak/comeback_status_test.dart`
Beklenen: DERLENMİYOR — `Target of URI doesn't exist: 'package:focussayac/domain/streak/comeback_status.dart'`

- [ ] **Adım 3: En küçük uygulamayı yaz**

`lib/domain/streak/comeback_status.dart`:

```dart
import '../../core/time/app_day.dart';

/// Dönüş yolunun eşiği: bu kadar uygulama günü hiç odaklanılmadıysa kullanıcı
/// "dönmüş" sayılır (ROADMAP madde 26).
const int kComebackAbsentDays = 3;

/// Dönüş çağrısının kapsadığı en az seans sayısı.
/// `AppReviewService.minCompletedFocusSessions` ile **aynı sayı ve aynı
/// gerekçe**: uygulamayı bir kez deneyip bırakan kullanıcıya "geri dön"
/// demek, ürünün kaçındığı winback tonuna kayar.
const int kComebackMinCompletedFocusSessions = 3;

/// Bildirimin saati: 21:00 TSİ = 18:00 UTC (Türkiye 2016'dan beri sabit
/// UTC+3 — `app_day.dart` ile aynı varsayım). Seri riski hatırlatmasıyla
/// aynı saat; kullanıcı için tek bir "akşam hatırlatma saati" var.
const int kComebackReminderHourUtc = 18;

/// Yokluğun o anki hâli. Şerit ve bildirim **aynı** nesneden besleniyor, yani
/// ekranda görünenle bildirimin vaadi ayrışamaz.
class ComebackStatus {
  const ComebackStatus({
    required this.absentDays,
    required this.welcomeDue,
    required this.reminderAtUtc,
  });

  static const ComebackStatus none =
      ComebackStatus(absentDays: 0, welcomeDue: false, reminderAtUtc: null);

  /// Son tamamlanmış odak seansından bu yana geçen uygulama günü sayısı.
  final int absentDays;

  /// Ekran 02'nin karşılama şeridi görünsün mü.
  final bool welcomeDue;

  /// Dönüş bildiriminin kurulacağı an; `null` "kurma" demektir — ya eşik
  /// dolmamıştır ya da o günün penceresi geçmiştir.
  final DateTime? reminderAtUtc;

  /// Riverpod bu değeri `==` ile karşılaştırıp gereksiz yeniden çizimi eliyor
  /// (`StreakStatus` ile aynı gerekçe).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComebackStatus &&
          other.absentDays == absentDays &&
          other.welcomeDue == welcomeDue &&
          other.reminderAtUtc == reminderAtUtc;

  @override
  int get hashCode => Object.hash(absentDays, welcomeDue, reminderAtUtc);

  @override
  String toString() => 'ComebackStatus(absentDays: $absentDays, '
      'welcomeDue: $welcomeDue, reminderAtUtc: $reminderAtUtc)';
}

/// Dönüş hesaplayıcı — saf fonksiyon, IO yok; `streak_calculator.dart` ile
/// aynı imza ve aynı felsefe: saklanan bayrak yok, aynı geçmiş her zaman aynı
/// sonucu verir.
///
/// Bildirim penceresi **tek gün**: hedef an son seans gününün üç gün
/// sonrasının akşamıdır, kaçırılırsa ileriye taşınmaz. Yokluk uzadıkça
/// bildirim biriktiren bir winback dizisi bilinçli olarak kapsam dışı
/// (tasarım belgesi, "Kapsam dışı").
ComebackStatus calculateComebackStatus({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
}) {
  if (completedFocusStartedAtUtc.length < kComebackMinCompletedFocusSessions) {
    return ComebackStatus.none;
  }

  // Sonuncusu listenin sırasına güvenilmeden bulunuyor: DAO'nun sıralaması
  // bu hesabın sözleşmesi değil.
  DateTime last = completedFocusStartedAtUtc.first;
  for (final DateTime startedAt in completedFocusStartedAtUtc) {
    if (startedAt.isAfter(last)) last = startedAt;
  }

  final DateTime lastDay = appDayKey(last);
  final int absentDays = currentAppDayKey(nowUtc).difference(lastDay).inDays;
  final DateTime reminderAtUtc = lastDay
      .add(const Duration(days: kComebackAbsentDays))
      .add(const Duration(hours: kComebackReminderHourUtc));

  return ComebackStatus(
    absentDays: absentDays,
    welcomeDue: absentDays >= kComebackAbsentDays,
    reminderAtUtc: reminderAtUtc.isAfter(nowUtc) ? reminderAtUtc : null,
  );
}
```

- [ ] **Adım 4: Testin geçtiğini doğrula**

Çalıştır: `flutter test test/domain/streak/comeback_status_test.dart`
Beklenen: `+10: All tests passed!`

- [ ] **Adım 5: Commit**

```bash
git add lib/domain/streak/comeback_status.dart test/domain/streak/comeback_status_test.dart
git commit -m "Donus durumu hesaplayicisi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 2: ARB anahtarları

**Dosyalar:**
- Değiştir: `lib/l10n/app_tr.arb`

Bu görevde test yok: ARB'nin kendisi veri, doğrulaması bir sonraki görevin
testlerinde (bildirim metni) ve Görev 6'da (şerit metni) yapılıyor.

- [ ] **Adım 1: Ekran 02 anahtarlarını ekle**

`lib/l10n/app_tr.arb` içinde `"countdownWeeklyGoalReachedSemantics"` bloğunun
**hemen ardına**:

```json
  "countdownComebackKicker": "TEKRAR HOŞ GELDİN",
  "countdownComebackBody": "{tier} kademen ve {duration} yerinde duruyor.",
  "@countdownComebackBody": {
    "description": "BUGÜN kartının dönüş şeridi (ROADMAP madde 26). Kaybedilen seriyi değil korunanı söylüyor; tier kademe adı (Kıvılcım…Güneş), duration uzun hâliyle yazılmış kümülatif odak süresi.",
    "placeholders": {
      "tier": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
  "countdownComebackSemantics": "Tekrar hoş geldin. {tier} kademen ve {duration} yerinde duruyor.",
  "@countdownComebackSemantics": {
    "description": "Ekran okuyucu karşılığı; kicker ve gövde tek cümle olarak okunuyor.",
    "placeholders": {
      "tier": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
```

- [ ] **Adım 2: Bildirim anahtarlarını ekle**

Aynı dosyada `"@notificationStreakRiskBody"` bloğunun **hemen ardına**:

```json
  "notificationComebackTitle": "Ateşin sönmedi",
  "notificationComebackBody": "{tier} kademen ve {duration} yerinde duruyor. Bir pomodoro yeniden yakar.",
  "@notificationComebackBody": {
    "description": "Dönüş bildirimi (ROADMAP madde 26). Seri kırılmış olabilir ama kademe küçülmez — cümle yalnızca korunanı söylüyor.",
    "placeholders": {
      "tier": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
```

- [ ] **Adım 3: Yerelleştirmeyi yeniden üret**

Çalıştır: `flutter gen-l10n`
Beklenen: hata yok. `lib/l10n/gen/app_localizations.dart` içinde beş yeni
getter oluşur (dizin `.gitignore`'da, commit'e girmez).

- [ ] **Adım 4: Derlemenin bozulmadığını doğrula**

Çalıştır: `flutter analyze`
Beklenen: `No issues found!`

- [ ] **Adım 5: Commit**

```bash
git add lib/l10n/app_tr.arb
git commit -m "Donus yolu ARB anahtarlari

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 3: Bildirim

**Dosyalar:**
- Değiştir: `lib/services/notifications/notification_service.dart`
- Test: `test/services/notifications/notification_service_test.dart`

- [ ] **Adım 1: Başarısız testi yaz**

`test/services/notifications/notification_service_test.dart` içindeki `main()`
fonksiyonunun sonuna ekle:

```dart
  group('dönüş bildirimi', () {
    /// Dönüş bildiriminin kapısı `streakReminderEnabled`; testler iki anahtarı
    /// ayrı ayrı çevirebilsin diye dosyanın `serviceWith` yardımcısı yerine
    /// bu yerel kurulum kullanılıyor.
    Future<NotificationService> comebackService({
      bool notificationsEnabled = true,
      bool streakReminderEnabled = true,
    }) async {
      final NotificationService service = NotificationService(
        l10n: testL10n,
        readPreferences: () async => NotificationPreferences(
          notificationsEnabled: notificationsEnabled,
          soundEnabled: true,
          streakReminderEnabled: streakReminderEnabled,
        ),
      );
      await service.initialize();
      calls.clear();
      return service;
    }

    test('ileri tarihli an için kuruluyor', () async {
      final NotificationService service = await comebackService();

      await service.rescheduleComebackReminder(
        reminderAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
        cumulativeFocusSeconds: 47 * 3600,
      );

      expect(
        calls.where((MethodCall c) => c.method == 'zonedSchedule'),
        hasLength(1),
      );
      // Kurulumdan önce her hâlde iptal ediliyor.
      expect(calls.first.method, 'cancel');
    });

    test('an null ise yalnızca iptal ediliyor', () async {
      final NotificationService service = await comebackService();

      await service.rescheduleComebackReminder(
        reminderAtUtc: null,
        cumulativeFocusSeconds: 47 * 3600,
      );

      expect(calls.map((MethodCall c) => c.method), <String>['cancel']);
    });

    test('seri hatırlatması kapalıyken kurulmuyor', () async {
      final NotificationService service =
          await comebackService(streakReminderEnabled: false);

      await service.rescheduleComebackReminder(
        reminderAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
        cumulativeFocusSeconds: 47 * 3600,
      );

      expect(calls.map((MethodCall c) => c.method), <String>['cancel']);
    });

    test('ana anahtar kapalıyken kurulmuyor', () async {
      final NotificationService service =
          await comebackService(notificationsEnabled: false);

      await service.rescheduleComebackReminder(
        reminderAtUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
        cumulativeFocusSeconds: 47 * 3600,
      );

      expect(calls.map((MethodCall c) => c.method), <String>['cancel']);
    });

    test('geçmiş bir an kurulmuyor', () async {
      final NotificationService service = await comebackService();

      await service.rescheduleComebackReminder(
        reminderAtUtc: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        cumulativeFocusSeconds: 47 * 3600,
      );

      expect(calls.map((MethodCall c) => c.method), <String>['cancel']);
    });
  });
```

- [ ] **Adım 2: Testin başarısız olduğunu doğrula**

Çalıştır: `flutter test test/services/notifications/notification_service_test.dart`
Beklenen: DERLENMİYOR — `The method 'rescheduleComebackReminder' isn't defined for the class 'NotificationService'`

- [ ] **Adım 3: Id sabitini ve import'u ekle**

`lib/services/notifications/notification_service.dart`, id sabitlerinin sonuna
(`_weeklySummaryNotificationId`in ardına):

```dart
  static const int _comebackNotificationId = 1006;
```

Dosyanın import bloğunda `import '../../domain/time/duration_formatter.dart';`
satırının **üstüne**:

```dart
// Dönüş bildirimi kademe adını Ekran 02'nin şeridiyle aynı kaynaktan kuruyor;
// `domain/flame` de `domain/time` gibi saf bir yaprak (yalnızca ARB'ye bağlı),
// o yüzden bu bağımlılık `NotificationPreferences`in `services/storage`den
// kaçındığı sınıfa girmiyor.
import '../../domain/flame/flame_tier.dart';
```

- [ ] **Adım 4: Metodu yaz**

`rescheduleStreakRiskReminder`ın **hemen ardına**:

```dart
  /// ROADMAP madde 26 "Dönüş yolu" — üç gün hiç odaklanmayan kullanıcıya tek
  /// bir çağrı. Diğer iki zamanlı bildirimden tek farkı hedefin bugünün içinde
  /// değil ileride olması: bu bildirim tanımı gereği kullanıcı uygulamayı
  /// **açmazken** düşmeli, o yüzden son değerlendirme noktasında önden kurulur
  /// ve kullanıcı dönüp bir odak tamamladığında yeniden hesaplanır.
  ///
  /// [reminderAtUtc] `calculateComebackStatus`tan gelir; `null` "kurma"
  /// demektir. Pencere tek gün olduğu için uzun yokluklarda bildirim
  /// birikmiyor.
  ///
  /// Kapı `streakReminderEnabled`: ikisi de aynı sözü veriyor (seri/alışkanlık
  /// hatırlatması) ve Android kanalı da ortak — ayrı kanal, kullanıcının
  /// kapattığı kategoriyi ikiye bölerdi.
  Future<void> rescheduleComebackReminder({
    required DateTime? reminderAtUtc,
    required int cumulativeFocusSeconds,
  }) async {
    final FlutterLocalNotificationsPlugin? plugin = _plugin;
    if (plugin == null) return;
    // İptal kapıdan önce (`rescheduleStreakRiskReminder` ile aynı gerekçe):
    // ayar kapatıldıktan sonraki ilk çağrı kurulmuş bildirimi de temizler.
    await plugin.cancel(id: _comebackNotificationId);
    final NotificationPreferences? preferences = await _allowedPreferences();
    if (preferences == null || !preferences.streakReminderEnabled) return;
    if (reminderAtUtc == null) return;
    final tz.TZDateTime target = tz.TZDateTime.from(reminderAtUtc, _location);
    if (!target.isAfter(tz.TZDateTime.now(_location))) return;

    final FlameTierStatus tierStatus = flameTierFor(cumulativeFocusSeconds);
    await _zonedSchedule(
      plugin,
      id: _comebackNotificationId,
      title: _l10n.notificationComebackTitle,
      body: _l10n.notificationComebackBody(
        tierStatus.tier.name(_l10n),
        spellFocusDuration(_l10n, cumulativeFocusSeconds),
      ),
      scheduledDate: target,
      notificationDetails: NotificationDetails(
        android: preferences.soundEnabled
            ? _streakRiskAndroidDetails
            : _streakRiskSilentAndroidDetails,
      ),
    );
  }
```

- [ ] **Adım 5: Testlerin geçtiğini doğrula**

Çalıştır: `flutter test test/services/notifications/notification_service_test.dart`
Beklenen: tüm testler geçiyor (mevcutlar + 5 yeni).

- [ ] **Adım 6: Commit**

```bash
git add lib/services/notifications/notification_service.dart test/services/notifications/notification_service_test.dart
git commit -m "Donus bildirimi ileriye kuruluyor

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 4: Değerlendirme noktaları (açılış + odak tamamlanışı)

**Dosyalar:**
- Değiştir: `lib/domain/pomodoro/pomodoro_controller.dart` (`_rescheduleWeeklySummary` çağrısı ve metodu civarı)
- Değiştir: `lib/main.dart` (`unawaited(_rescheduleWeeklySummary(...))` satırı ve dosya sonu)
- Test: `test/domain/pomodoro/pomodoro_controller_test.dart`

- [ ] **Adım 1: Başarısız testi yaz**

`test/domain/pomodoro/pomodoro_controller_test.dart` içindeki
`_RecordingNotifications` sınıfına (satır 80 civarı) `cancelBreakEnd`
override'ının ardına kayıt alanını ekle — dosyanın kayıt için kullandığı
record tipi kalıbıyla:

```dart
  final List<({DateTime? reminderAtUtc, int cumulativeFocusSeconds})> comebackCalls =
      <({DateTime? reminderAtUtc, int cumulativeFocusSeconds})>[];

  @override
  Future<void> rescheduleComebackReminder({
    required DateTime? reminderAtUtc,
    required int cumulativeFocusSeconds,
  }) async {
    comebackCalls.add(
      (reminderAtUtc: reminderAtUtc, cumulativeFocusSeconds: cumulativeFocusSeconds),
    );
  }
```

Ardından `main()` içine testi ekle:

```dart
  test('odak tamamlanışı dönüş bildirimini yeniden kuruyor', () async {
    final _RecordingNotifications notifications = _RecordingNotifications();
    final ProviderContainer container = await _buildContainer(notifications: notifications);
    addTearDown(container.dispose);
    final PomodoroController controller = container.read(pomodoroControllerProvider.notifier);

    // Üç tamamlanmış odak seansı: dönüş çağrısının eşiği
    // (`kComebackMinCompletedFocusSessions`) tam burada doluyor.
    for (int i = 0; i < 3; i++) {
      await _waitForSessionCount(container, i * 2);
      await controller.startFocus();
      // Odak da mola da planned=0s olduğu için tek `tick()` çağrısı
      // odak → mola → idle zincirini kapatıyor (bu dosyanın döngü testiyle
      // aynı kalıp).
      await controller.tick();
    }
    await _waitForSessionCount(container, 6);

    // Her odak tamamlanışında bir kez çağrılıyor.
    expect(notifications.comebackCalls, hasLength(3));
    // İlk iki çağrıda eşik henüz dolmamıştı: kurulacak bir an yok.
    expect(notifications.comebackCalls.first.reminderAtUtc, isNull);
    // Üçüncüsünde eşik dolu ve son seans bugün → hedef an üç gün ileride.
    final DateTime? last = notifications.comebackCalls.last.reminderAtUtc;
    expect(last, isNotNull);
    expect(last!.isAfter(DateTime.now().toUtc()), isTrue);
  });
```

- [ ] **Adım 2: Testin başarısız olduğunu doğrula**

Çalıştır: `flutter test test/domain/pomodoro/pomodoro_controller_test.dart`
Beklenen: DERLENMİYOR — sahte sınıftaki `@override` henüz var olmayan bir
metodu gösteriyor (`'rescheduleComebackReminder' isn't a valid override`).
Görev 3 tamamlandıysa derleme geçer ve test `comebackCalls` boş kaldığı için
FAIL eder.

- [ ] **Adım 3: Denetleyiciyi bağla**

`lib/domain/pomodoro/pomodoro_controller.dart`, `await _rescheduleWeeklySummary(completedFocus);`
satırının **hemen ardına**:

```dart
    await _rescheduleComebackReminder(completedFocus);
```

`_rescheduleWeeklySummary` metodunun ardına yeni metot:

```dart
  /// Dönüş bildirimini ileriye yeniden kurar (ROADMAP madde 26). Her odak
  /// tamamlanışında çağrılıyor: yokluk sayacı bu anla sıfırlandığı için hedef
  /// an da üç gün ileri kayıyor.
  Future<void> _rescheduleComebackReminder(List<PomodoroSession> completedFocus) async {
    final ComebackStatus comeback = calculateComebackStatus(
      completedFocusStartedAtUtc:
          completedFocus.map((PomodoroSession s) => s.startedAt).toList(growable: false),
      nowUtc: DateTime.now().toUtc(),
    );
    await _notifications.rescheduleComebackReminder(
      reminderAtUtc: comeback.reminderAtUtc,
      // `focus_stats.dart`'ın `cumulativeSeconds` kuralıyla birebir aynı:
      // tamamlanan seans planlanan süresini tam çalışmıştır.
      cumulativeFocusSeconds: completedFocus.fold<int>(
        0,
        (int sum, PomodoroSession s) => sum + s.plannedDurationSec,
      ),
    );
  }
```

Import ekle (dosyanın mevcut `domain/` import'larının arasına):

```dart
import '../streak/comeback_status.dart';
```

- [ ] **Adım 4: Testin geçtiğini doğrula**

Çalıştır: `flutter test test/domain/pomodoro/pomodoro_controller_test.dart`
Beklenen: tüm testler geçiyor.

- [ ] **Adım 5: Açılışı bağla**

`lib/main.dart`, `unawaited(_rescheduleWeeklySummary(database, notificationService));`
satırının ardına:

```dart
  unawaited(_rescheduleComebackReminder(database, notificationService));
```

Dosyanın sonuna:

```dart
/// Dönüş bildirimini açılışta kurar (ROADMAP madde 26) — `PomodoroController`
/// her odak tamamlanışında aynı işi tekrar yapıyor, bu çağrı uygulamayı açıp
/// hiç seans yapmayan günleri kapsıyor.
///
/// Riverpod ağacı kurulmadığı için DAO doğrudan okunuyor
/// (`_rescheduleStreakRiskReminder` ile aynı gerekçe).
Future<void> _rescheduleComebackReminder(
  AppDatabase database,
  NotificationService notificationService,
) async {
  final List<PomodoroSession> sessions = await database.pomodoroSessionDao.getAllCompletedFocusSessions();
  final ComebackStatus comeback = calculateComebackStatus(
    completedFocusStartedAtUtc:
        sessions.map((PomodoroSession s) => s.startedAt).toList(growable: false),
    nowUtc: DateTime.now().toUtc(),
  );
  await notificationService.rescheduleComebackReminder(
    reminderAtUtc: comeback.reminderAtUtc,
    cumulativeFocusSeconds: sessions.fold<int>(
      0,
      (int sum, PomodoroSession s) => sum + s.plannedDurationSec,
    ),
  );
}
```

Import ekle — biçimi dosyanın mevcut import bloğuna göre yaz:

```dart
import 'domain/streak/comeback_status.dart';
```

- [ ] **Adım 6: Derleme ve tüm testler**

Çalıştır: `flutter analyze`
Beklenen: `No issues found!`

Çalıştır: `flutter test`
Beklenen: tüm testler geçiyor.

- [ ] **Adım 7: Commit**

```bash
git add lib/main.dart lib/domain/pomodoro/pomodoro_controller.dart test/domain/pomodoro/pomodoro_controller_test.dart
git commit -m "Donus bildirimi acilista ve odak tamamlanisinda kuruluyor

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 5: Sağlayıcı

**Dosyalar:**
- Değiştir: `lib/domain/pomodoro/pomodoro_stats_providers.dart`

Ayrı test yok: sağlayıcının davranışı Görev 6'nın widget testinde uçtan uca
doğrulanıyor (hesaplayıcının kendi testleri Görev 1'de).

- [ ] **Adım 1: Sağlayıcıyı ekle**

Dosyanın sonuna:

```dart
/// Dönüş durumu (ROADMAP madde 26) — `streakStatusProvider` ile aynı akıştan
/// türetiliyor, yani Ekran 02'nin şeridi ile dönüş bildiriminin sayıları
/// birbirinden sapamaz.
final Provider<ComebackStatus> comebackStatusProvider = Provider<ComebackStatus>((Ref ref) {
  final List<PomodoroSession> sessions = ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  final List<DateTime> completedFocusStarts = sessions
      .where((PomodoroSession s) => s.completed && s.type == SessionType.focus)
      .map((PomodoroSession s) => s.startedAt)
      .toList(growable: false);
  return calculateComebackStatus(
    completedFocusStartedAtUtc: completedFocusStarts,
    nowUtc: DateTime.now().toUtc(),
  );
});
```

Import ekle:

```dart
import '../streak/comeback_status.dart';
```

- [ ] **Adım 2: Derlemeyi doğrula**

Çalıştır: `flutter analyze`
Beklenen: `No issues found!`

- [ ] **Adım 3: Commit**

```bash
git add lib/domain/pomodoro/pomodoro_stats_providers.dart
git commit -m "comebackStatusProvider

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 6: Ekran 02 karşılama şeridi

**Dosyalar:**
- Değiştir: `lib/features/countdown/countdown_screen.dart`
- Oluştur: `test/features/countdown/comeback_row_test.dart`

- [ ] **Adım 1: Başarısız testi yaz**

`test/features/countdown/comeback_row_test.dart`:

```dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

int _id = 0;

/// [daysAgo] gün önce tamamlanmış, [minutes] dakikalık bir odak seansı.
/// Tam 24 saatlik adımlar 04:00 TSİ gün sınırından bağımsız kalıyor
/// (`weekly_goal_row_test.dart` ile aynı gerekçe).
PomodoroSession _focus({required int daysAgo, required int minutes}) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
  );
}

void main() {
  // Tek test: aynı isolate'teki ikinci testte drift göçü tamamlanmadan kalıyor
  // (`countdown_glow_test.dart`'ta belgelenen tuzak). Üç durum tek akışta
  // geziliyor; `allSessionsProvider` denetleyici üzerinden beslendiği için
  // ekran her yazımda kendiliğinden yeniden çiziliyor.
  testWidgets('dönüş şeridi: yoklukta görünür, eşiğin altında ve dönüşte yok',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // ignore: close_sinks — sahibi aşağıdaki tear-down.
    final StreamController<List<PomodoroSession>> sessions =
        StreamController<List<PomodoroSession>>();
    addTearDown(sessions.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          adServiceProvider.overrideWithValue(AdService.disabled()),
          notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
          allSessionsProvider.overrideWith((Ref ref) => sessions.stream),
        ],
        child: const FocusSayacApp(),
      ),
    );

    Future<void> settle() async {
      await tester.pump();
      // `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor.
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    // --- 1. Üç seans, sonuncusu dört gün önce: şerit açık --------------------
    // Kümülatif 3 saat (60+60+60 dk) → en alt kademe.
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 5, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsOneWidget);
    expect(find.text('TEKRAR HOŞ GELDİN'), findsOneWidget);
    expect(find.text('Kıvılcım kademen ve 3 saat yerinde duruyor.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tekrar hoş geldin. Kıvılcım kademen ve 3 saat yerinde duruyor.'),
      findsOneWidget,
    );

    // --- 2. İki seans: eşiğin altındaki kullanıcı kapsam dışı ---------------
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsNothing);
    expect(find.text('TEKRAR HOŞ GELDİN'), findsNothing);
    // Kartın geri kalanı yerinde — gizlenen yalnızca dönüş şeridi.
    expect(find.text('BUGÜN'), findsOneWidget);

    // --- 3. Kullanıcı bugün çalıştı: şerit kendiliğinden kapanıyor ----------
    sessions.add(<PomodoroSession>[
      _focus(daysAgo: 6, minutes: 60),
      _focus(daysAgo: 5, minutes: 60),
      _focus(daysAgo: 4, minutes: 60),
      _focus(daysAgo: 0, minutes: 25),
    ]);
    await settle();

    expect(find.byKey(kComebackRowKey), findsNothing);
    expect(find.text('BUGÜN'), findsOneWidget);

    // Denetleyici burada **kapatılmıyor**: gerekçe
    // `streak_protection_badge_test.dart`'ta.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Adım 2: Testin başarısız olduğunu doğrula**

Çalıştır: `flutter test test/features/countdown/comeback_row_test.dart`
Beklenen: DERLENMİYOR — `Undefined name 'kComebackRowKey'`

- [ ] **Adım 3: Şerit bileşenini yaz**

`lib/features/countdown/countdown_screen.dart` dosyasının sonuna,
`_WeeklyGoalRow` sınıfının **ardına**:

```dart
/// Dönüş şeridi anahtarı — testler kartın hangi satırına baktığını bununla
/// söylüyor.
const Key kComebackRowKey = Key('comeback-row');

/// `BUGÜN` kartının dönüş satırı (ROADMAP madde 26).
///
/// Üç gün hiç odaklanmayan kullanıcı döndüğünde onu bir sıfır tablosu
/// karşılıyordu. Satır kaybedileni değil **korunanı** söylüyor: meşale kademesi
/// asla küçülmüyor ve kümülatif saat duruyor, yani seri kırılmış olsa bile
/// söylenecek doğru ve olumlu bir gerçek var.
///
/// Kapanışı da veriden geliyor: ilk odak tamamlandığı anda `absentDays`
/// sıfırlanır ve satır ağaçtan çıkar — "gösterildi mi" bayrağı, kapatma
/// butonu, yeni kalıcı alan yok.
class _ComebackRow extends StatelessWidget {
  const _ComebackRow({required this.cumulativeSeconds});

  /// Tüm zamanların tamamlanmış odak saniyesi (`FocusStats.cumulativeSeconds`).
  final int cumulativeSeconds;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Kademe ve süre bildirimle aynı kaynaktan: iki yüzey aynı anda farklı
    // sayı söyleyemez.
    final String tierName = flameTierFor(cumulativeSeconds).tier.name(l10n);
    final String spelled = spellFocusDuration(l10n, cumulativeSeconds);

    return Semantics(
      key: kComebackRowKey,
      container: true,
      excludeSemantics: true,
      label: l10n.countdownComebackSemantics(tierName, spelled),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.countdownComebackKicker,
            style: AppTypography.kicker(
                fontSize: AppTextSize.kicker, color: colors.neutral600),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.countdownComebackBody(tierName, spelled),
            style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.ember),
          ),
        ],
      ),
    );
  }
}
```

Import ekle (dosyanın `domain/` import'larının arasına, alfabetik sırayı koru):

```dart
import '../../domain/flame/flame_tier.dart';
import '../../domain/streak/comeback_status.dart';
```

- [ ] **Adım 4: Kartın içine bağla**

`_CountdownBody.build` başındaki `ref.watch` bloğunda, `weeklyGoal` satırının
ardına:

```dart
    final ComebackStatus comeback = ref.watch(comebackStatusProvider);
    final FocusStats focusStats = ref.watch(focusStatsProvider);
```

> `focusStatsProvider` `domain/stats/stats_providers.dart`ten geliyor ve dosyada
> bu import zaten var. `FocusStats` tipi çözülmezse
> `import '../../domain/stats/focus_stats.dart';` de ekle.

Haftalık hedef bloğunun (`if (!weeklyGoal.isOff) ...<Widget>[`) **hemen
üstüne**:

```dart
                                // Dönüş şeridi (ROADMAP madde 26): üç gün
                                // odaklanmayan kullanıcı döndüğünde kartın
                                // sıfırlarını okumadan önce korunanı görüyor.
                                if (comeback.welcomeDue) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Divider(height: 1, thickness: 1, color: colors.hairline),
                                  const SizedBox(height: 10),
                                  _ComebackRow(cumulativeSeconds: focusStats.cumulativeSeconds),
                                ],
```

- [ ] **Adım 5: Testin geçtiğini doğrula**

Çalıştır: `flutter test test/features/countdown/comeback_row_test.dart`
Beklenen: `+1: All tests passed!`

> Kademe adı ya da süre metni beklenenden farklı çıkarsa **testin beklentisini
> düzelt, ARB'yi değil**: 3 saatlik kümülatif `kFlameTierLadder`ın ilk
> basamağıdır, gerçek adı `lib/l10n/app_tr.arb`ın `flameTier1Name`
> anahtarından okunur.

- [ ] **Adım 6: Derleme ve tüm testler**

Çalıştır: `flutter analyze`
Beklenen: `No issues found!`

Çalıştır: `flutter test`
Beklenen: tüm testler geçiyor.

- [ ] **Adım 7: Commit**

```bash
git add lib/features/countdown/countdown_screen.dart test/features/countdown/comeback_row_test.dart
git commit -m "Ekran 02: donus karsilama seridi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Görev 7: Kayıtlar

**Dosyalar:**
- Değiştir: `ROADMAP.md`
- Değiştir: `DECISIONS.md`

- [ ] **Adım 1: ROADMAP madde 26'yı kapat**

`## 26. Dönüş yolu — 3 gün yokluk sonrası ⬜ başlanmadı` başlığını
`## 26. Dönüş yolu — 3 gün yokluk sonrası ✅ bitti` yap ve madde 24/25'in
kalıbıyla bir kapanış paragrafı ekle: geçen test sayısı, tasarım belgesinin
yolu (`docs/superpowers/specs/2026-09-17-donus-yolu-design.md`), alınan
kararlar ve **emülatör doğrulamasının yapılmadığı** (madde 25'te olduğu gibi
açık iş).

- [ ] **Adım 2: DECISIONS.md'ye kararları yaz**

"Madde 26 — Dönüş yolu" başlığıyla, gerekçeleriyle:

1. Bildirim neden **ileriye** kuruluyor (arka plan işi yok, SPEC §1).
2. Pencere neden **tek gün** (winback dizisi yok).
3. Eşik neden **3 tamamlanmış seans**
   (`AppReviewService.minCompletedFocusSessions` ile aynı sayı).
4. Ayar neden **paylaşılıyor** (`streakReminderEnabled`, ortak Android kanalı).
5. Şerit neden **bayraksız** (durum geçmişten türetiliyor).

- [ ] **Adım 3: Son doğrulama**

Çalıştır: `flutter analyze`
Beklenen: `No issues found!`

Çalıştır: `flutter test`
Beklenen: tüm testler geçiyor — sayıyı not al, ROADMAP'e yazılan sayı bu olmalı.

- [ ] **Adım 4: Commit**

```bash
git add ROADMAP.md DECISIONS.md
git commit -m "Donus yolu kararlari ve yol haritasi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Kabul (tasarım belgesiyle aynı liste)

- [ ] Hareketsizlik eşiği (3 uygulama günü) aşılınca bildirim planlanıyor.
- [ ] Odak seansı tamamlanınca planlanmış bildirim iptal edilip ileriye
      yeniden kuruluyor.
- [ ] Dönüş şeridi testle çivilenmiş; kademe ve kümülatif saat doğru.
- [ ] Üç seanstan az yapmış kullanıcıya ne bildirim ne şerit gidiyor.
- [ ] `flutter analyze` 0/0, `flutter test` yeşil.

## Açık iş (plan dışı)

Emülatör doğrulaması — madde 25'te olduğu gibi. Bildirimin gerçek cihazda üç
gün sonra düşmesi ancak cihaz saati ileri alınarak ya da eşik geçici olarak
düşürülerek gözlenebilir; bu planın kapsamında değil.
