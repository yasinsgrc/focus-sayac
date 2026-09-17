# Dönüş yolu — tasarım

ROADMAP madde 26. Üç gün odaklanmayan kullanıcıyı geri çağıran tek bir bildirim
ve döndüğünde onu suçlamayan bir karşılama satırı.

## Sorun

Seri koparsa kullanıcıyı geri çağıran ya da karşılayan hiçbir an yok. Seri
koruma mekaniği (SPEC §5.3) var ama kullanıcıya bunu söyleyen bir yüzey yok:
döndüğünde onu bir sıfır tablosu karşılıyor. `comeback` / `winback` / `dormant`
/ `absent` — hiçbiri kodda geçmiyor.

Söylenecek olumlu bir gerçek zaten elde: meşale kademesi (madde 23,
`flame_tier.dart`) **asla küçülmüyor** ve kümülatif saat duruyor. Seri kırılsa
da bunlar yerinde. Dönüş anının söylemesi gereken şey bu.

## Tetikleyici — neden ileriye kurulmak zorunda

Mevcut iki zamanlanmış bildirim (seri riski 21:00, haftalık özet pazar 20:00)
aynı kalıbı kullanıyor: geleceğe dönük arka plan işi yok (SPEC §1 backend/cloud
sync'i yasaklıyor), bildirim her **yeniden değerlendirme noktasında** —
uygulama açılışı (`main.dart`) ve her odak tamamlanışı
(`pomodoro_controller.dart`) — iptal edilip yeniden kuruluyor.

Yokluk bildirimi bu kalıbı bir noktada zorluyor: tanımı gereği kullanıcı
uygulamayı **açmazken** düşmesi gerekiyor. Yani son değerlendirme noktasında
ileriye kurulmalı ve kullanıcı döndüğünde iptal edilmeli. Altyapı değişikliği
gerekmiyor — `_zonedSchedule` zaten ileri tarihli tek seferlik kurulum yapıyor;
değişen tek şey hedef anın bugünün içinde değil üç gün sonrasında olması.

Seri riski hatırlatmasıyla çakışmıyor: o, seri ≥1 iken ve yalnızca uygulamanın
açıldığı gün kuruluyor. Üç günlük yoklukta seri çoktan kırılmış olur (koruma
yedi günde bir tek boşluğu affeder), dolayısıyla iki bildirim ardışık iki hâl,
rakip değil.

## Saf katman — `lib/domain/streak/comeback_status.dart`

`streak_calculator.dart` ile aynı felsefe: **durum saklanmıyor, geçmişten
türetiliyor.** Aynı veri her zaman aynı sonucu verir; "gösterildi mi" bayrağı,
yeni kalıcı alan, drift göçü yok.

```dart
class ComebackStatus {
  final int absentDays;           // son tamamlanmış odaktan bu yana uygulama günü
  final bool welcomeDue;          // karşılama şeridi görünür mü
  final DateTime? reminderAtUtc;  // bildirim anı; null = kurma
}

ComebackStatus calculateComebackStatus({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
});
```

İmza `calculateStreakStatus` ile birebir aynı: üç çağıranın (sağlayıcı,
`main.dart`, denetleyici) hiçbiri "sonuncu seansı bul" mantığını kopyalamıyor
ve DAO listesinin sıralı geldiği varsayılmıyor — en büyük zaman damgası
hesaplayıcının içinde bulunuyor.

Kurallar:

1. Liste `kComebackMinCompletedFocusSessions`'tan (= 3) kısaysa →
   `ComebackStatus.none`: ne şerit ne
   bildirim. Eşik `AppReviewService.minCompletedFocusSessions` ile aynı sayı ve
   aynı gerekçe — uygulamayı bir kez deneyip bırakana geri çağrı göndermek,
   ürünün kaçındığı "seni geri istiyoruz" tonuna kayar.
2. `absentDays = currentAppDayKey(nowUtc) − appDayKey(en son seans)`,
   gün cinsinden. Gün sınırı 04:00 TSİ — §5.3'ün kullandığı `app_day.dart`'ın
   aynısı, ikinci bir gün tanımı kurulmuyor.
3. `welcomeDue = absentDays >= kComebackAbsentDays` (= 3).
4. `reminderAtUtc` = *son seans günü + 3*, saat **21:00 TSİ** (seri riskiyle
   aynı saat sabiti). Hesaplanan an `nowUtc`'den önceyse `null`.

Dördüncü kuralın sonucu önemli: bildirim penceresi **tek gün**. On gün yok olan
kullanıcı için hedef an çoktan geçmiştir, `null` döner ve yeni bir bildirim
kurulmaz — kullanıcı bir odak seansı tamamlayana kadar da kurulmaz. Yokluk
uzadıkça bildirim biriktiren bir winback dizisi bilinçli olarak kapsam dışı.

## Bildirim — `NotificationService.rescheduleComebackReminder`

Mevcut iki metodun kalıbı birebir: **önce iptal, sonra kapılar, sonra kur.**

```dart
Future<void> rescheduleComebackReminder({
  required DateTime? reminderAtUtc,
  required int cumulativeFocusSeconds,
});
```

- İptal kapılardan önce (`rescheduleStreakRiskReminder` ile aynı gerekçe: ayar
  kapatıldıktan sonraki ilk çağrı önceden kurulmuş bildirimi de temizler).
- Kapılar sırasıyla: `notificationsEnabled` → `streakReminderEnabled` →
  `reminderAtUtc != null` → hedef an gelecekte.
- Kanal: mevcut `streakRisk` kanalı (ve sessiz eşi). Ayrı kanal açmak,
  kullanıcının Android ayarlarında kapattığı "seri hatırlatmaları"
  kategorisini ikiye böler.
- Yeni id sabiti `_comebackNotificationId`.
- Metin korunanı söyler, kaybedileni değil: başlık **"Ateşin sönmedi"**, gövde
  *"{kademe} kademen ve {süre} yerinde duruyor. Bir pomodoro yeniden yakar."*
  Kademe adı `flameTierFor(cumulativeFocusSeconds).tier.name(l10n)`
  (`Kıvılcım`…`Güneş`), süre mevcut `spellFocusDuration` ile.

Çağıranlar, diğer iki bildirimle aynı iki nokta:

- `main.dart` açılışta (Riverpod ağacı kurulmadan, veritabanından doğrudan
  okuyarak — `_rescheduleStreakRiskReminder` ile aynı gerekçe),
- `pomodoro_controller.dart` her odak tamamlanışında.

### Ayar kapısı — neden yeni anahtar yok

`streakReminderEnabled` paylaşılıyor. İkisi de aynı sözü veriyor: seri ve
alışkanlık hatırlatması. Günlük hatırlatmayı kapatan kullanıcının üç gün sonra
rahatsız edilmek istediğini varsaymak için bir sebep yok. Bedeli de gerçek:
ayrı anahtar = drift v6 göçü + Ekran 07'de dördüncü satır + ARB + test.
Ayarın mevcut metni ("Seri hatırlatması") bu kapsamı taşıyor.

## Ekran 02 — karşılama şeridi

`_CountdownBody` içinde yeni `_ComebackRow`. Madde 24'te eklenen
`_WeeklyGoalRow` ile aynı yerleşim ve aynı `RiseIn` girişi; gövde zaten
kaydırılabilir.

- Görünürlük: yeni `comebackStatusProvider`
  (`pomodoro_stats_providers.dart`, `allSessionsProvider` üzerinden türetilmiş)
  `welcomeDue` derse.
- Yerleşim: `BUGÜN` kartının içinde, haftalık hedef satırının hemen üstünde
  (`_WeeklyGoalRow` ile aynı ayırıcı kalıbı). Halkanın içindeki seri rozetine
  **dokunulmuyor**: kırık seri zaten görünürken şerit tek olumlu gerçeği
  ekliyor, veriyi gizlemek yerine bağlamını veriyor.
- Metin: `TEKRAR HOŞ GELDİN` kicker'ı + *"Ocak kademen ve 47 saat yerinde
  duruyor."* Kademe ve süre bildirimle **aynı kaynaktan** gelir: kümülatif
  odak saniyesi → `flameTierFor(...)` + `spellFocusDuration(...)`. İki yüzey
  aynı anda farklı sayı söyleyemez.
- Kapanışı da veriden gelir: ilk odak seansı tamamlandığı anda `absentDays`
  sıfırlanır, şerit kendiliğinden gider. Kapatma butonu ve "gösterildi"
  bayrağı yok.
- Ekran okuyucu karşılığı ayrı bir `Semantics` etiketiyle verilir (kicker +
  gövde tek cümle olarak okunur).

## Kapsam dışı

- **Winback dizisi** (3. gün, 7. gün, 14. gün). Tek bildirim, tek pencere;
  birikmiş bildirim kuyruğu ürünün tonuna aykırı.
- **Tam ekran dönüş hâli.** Dönen kullanıcının önüne yeni bir rota ve kapatma
  adımı koyar; "bir pomodoro"ya giden yolu uzatır.
- **Pazar özetinin dönüş metnine geçmesi.** Ayrı bildirim, ayrı karar.

## Testler

| Dosya | Ne çivileniyor |
|---|---|
| `test/domain/streak/comeback_status_test.dart` | 3 seans eşiği (2 seansta `none`), 2 gün yoklukta şerit yok / 3 günde var, 04:00 gün sınırı kenarı, 10 gün yoklukta `reminderAtUtc == null`, hiç seans yokken `none` |
| `test/services/notifications/notification_service_test.dart` | ileri tarihli kurulum, `reminderAtUtc == null` iken yalnızca iptal, `streakReminderEnabled` kapalıyken kurulmuyor, `notificationsEnabled` kapalıyken kurulmuyor |
| `test/domain/pomodoro/pomodoro_controller_test.dart` | odak tamamlanışında yeniden kuruluyor |
| Ekran 02 widget testi | şerit `welcomeDue` iken görünür, değilken yok; `find.bySemanticsLabel` ile ekran okuyucu karşılığı |

## Yeni ARB anahtarları

| Anahtar | Değer |
|---|---|
| `countdownComebackKicker` | `TEKRAR HOŞ GELDİN` |
| `countdownComebackBody` | `{tier} kademen ve {duration} yerinde duruyor.` |
| `countdownComebackSemantics` | `Tekrar hoş geldin. {tier} kademen ve {duration} yerinde duruyor.` |
| `notificationComebackTitle` | `Ateşin sönmedi` |
| `notificationComebackBody` | `{tier} kademen ve {duration} yerinde duruyor. Bir pomodoro yeniden yakar.` |

## Kabul (ROADMAP madde 26)

- [ ] Hareketsizlik eşiği (3 uygulama günü) aşılınca bildirim planlanıyor.
- [ ] Odak seansı tamamlanınca planlanmış bildirim iptal edilip ileriye
      yeniden kuruluyor.
- [ ] Dönüş şeridi testle çivilenmiş; kademe ve kümülatif saat doğru.
- [ ] Üç seanstan az yapmış kullanıcıya ne bildirim ne şerit gidiyor.
- [ ] `flutter analyze` 0/0, `flutter test` yeşil.
