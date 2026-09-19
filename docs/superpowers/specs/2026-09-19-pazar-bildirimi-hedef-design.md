# Pazar bildirimi haftalık hedefi söylüyor — tasarım

ROADMAP madde 42. Madde 24'ün kapsam dışı bıraktığı iş: haftalık hedef
uygulamanın üç yüzeyinde duruyor ama haftayı **kapatan** cümlede yok.

## Sorun

`NotificationService.rescheduleWeeklySummary` pazar 20:00 için dört gövdeden
birini kuruyor — ilk hafta / arttı / azaldı / aynı — ve hiçbiri hedefe
değinmiyor. Metodun imzasında hedef diye bir şey yok (`seconds`,
`previousSeconds`), yani kullanıcının koyduğu hedef bildirime hiç ulaşmıyor.

Oysa hedef başka her yerde duruyor: Ekran 07'nin slider'ı, Ekran 02'nin `BUGÜN`
kartındaki çubuk, ana ekran widget'ının emek yayı (madde 41). Haftayı kapatan
bildirim, o haftanın asıl sorusuna cevap vermeyen tek yüzey. Hedefini tutturan
kullanıcı da tutturamayan da aynı cümleyi alıyor.

## Madde 24'ün iki uyarısı

Madde 24 bu işi kapsam dışı bırakırken iki riski işaret etmişti:

1. **Dört varyantı sekize çıkarmak.** Hedef durumunu kıyas cümlesinin yanına
   ikinci bir cümle olarak eklemek, her varyantı ikiye böler.
2. **Yüzde dili.** `weekly_summary.dart` bilerek yüzde değil **fark** tutuyor
   ("geçen haftadan +40 dk"); "hedefinin %80'i" o kararla çelişir.

Maddenin asıl işi bu yüzden metin değil, kural.

## Kararlar

### 1. Hedef yalnızca **tutturulunca** konuşuyor — dört varyant beşe çıkıyor

Kural tek cümle: **hedef karşılandıysa gövde hedef cümlesidir, kıyas cümlesinin
yerine.** Karşılanmadıysa bugünkü dört gövde aynen kalır.

Çarpım olmuyor çünkü hedef cümlesi mevcut varyantların *yanına* eklenmiyor,
*yerine* geçiyor: 4 → 5.

**Neden yerine, yanına değil.** Hedefin tutması o haftanın daha büyük haberi;
"haftalık hedefin tamam — ayrıca geçen haftadan 40dk fazla" iki övgüyü üst üste
koyup tonu şişiriyor. Bir bildirim gövdesinin taşıyabileceği tek bir haber var.

**Neden eksiklik konuşmuyor.** Simetrik bir kural ("tutmadıysa hedefine X
kaldı") ilk bakışta daha bütün görünüyor, ve bildirimin saati bunu destekliyor:
20:00 TSİ'de pencere henüz kapanmamış (uygulama günü ertesi 04:00'te biter), o
yüzden kalan süre gerçekten kapatılabilir bir sayı — gönderim saatinin gerekçesi
zaten bu (`kWeeklySummaryHour`: "özeti gördükten sonra o akşam hâlâ bir pomodoro
vakti kalsın"). Yine de reddedildi:

- Aynı kural, 20sa hedefin 1sa'sinde duran kullanıcıya "hedefine 19sa kaldı"
  derdi. Haftayı **kapatan** bildirimde kapatılamaz bir eksiği okumak, ürünün
  kaçındığı ölçen ton.
- Eşik koymak (kalan ≤ bir odak seansı) bunu çözerdi ama maddenin kapsam dışı
  notu "hedef dolmadığında ayrı bir hatırlatma bildirimi"ni zaten dışarıda
  bırakmış. Eksikliği konuşan her cümle o bildirimin kılık değiştirmiş hâli;
  kararı ona ait olduğu maddede vermek doğru.
- Bu karar o bildirimin önünü kapatmıyor: ileride gelirse bunun yerine değil
  yanına gelir, çünkü bu madde yalnızca "tuttu" hâlini sahipleniyor.

Yüzde hiç girmiyor: cümlede ne oran var ne de hedefin kendi sayısı.

### 2. "Tutturuldu" kararı `WeeklyGoalProgress`ten okunuyor

Bildirim kendi `>=` karşılaştırmasını yazmıyor; `goalSeconds` ve
`focusedSeconds` ile bir `WeeklyGoalProgress` kurup `isReached` soruyor. Madde
24 iki kararı o sınıfa gömmüştü ve ikisi de bildirim için de geçerli:

- Sınır **dahil** — hedefi tam karşılayan hafta tamamlanmış sayılır.
- Hedef kapalıyken (`goalSeconds <= 0`) hiçbir zaman ulaşılmış olmuyor, yani
  hedefi kapalı kullanıcı bugünkü dört varyantta kalıyor.

Elle yazılmış ikinci bir karşılaştırma bu iki kararı sessizce ayırabilirdi:
Ekran 02'nin çubuğu "tamam" derken bildirimin "geçen haftadan fazla" demesi.

**Katman sınırı çiğnenmiyor.** `services/notifications` bilerek
`services/storage`e bağlanmıyor (`NotificationPreferences`in var oluş sebebi
bu), ama saf `domain` yapraklarına bağlanıyor — `domain/time/duration_formatter`
ve `domain/flame/flame_tier` zaten import edilmiş durumda.
`domain/stats/weekly_goal.dart` hiçbir şey import etmiyor, aynı sınıftan bir
yaprak.

### 3. Hedef, saniyesiyle aynı yoldan geliyor

`rescheduleWeeklySummary` yeni bir `goalSeconds` parametresi alıyor. İki çağıran
da onu zaten ellerinde olan ayardan veriyor:

- `main.dart` — açılışta ayarları DAO'dan okuyor (seans listesini de orada
  okuyor, ikinci bir kapı açılmıyor).
- `PomodoroController._completeFocus` — `settings` o akışta **zaten** okunmuş
  (mola süresi için, `pomodoro_controller.dart`); değer aşağı taşınıyor, yeni
  sorgu yok.

Servisin ayarı kendisinin okuması reddedildi: `NotificationPreferences` dışındaki
her ayar çağıranın sorumluluğu, eşleme tek yerde kalıyor.

### 4. Cümle

```
Bu hafta {total} odaklandın — haftalık hedefin tamam.
```

Mevcut dört gövdenin kalıbını koruyor: aynı "Bu hafta {total} odaklandın" başı,
ardından tireyle ikinci yarı. Yani beşinci varyant yeni bir cümle biçimi
getirmiyor, var olan iskelete oturuyor.

"**Haftalık**" sıfatı burada var, Ekran 02'deki rozette (`Hedef tamam`) yok:
orada satırın kendisi `BU HAFTA` yazıyor ve çubuk yanında duruyor, bildirimde
ise cümle tek başına, bildirim gölgesinde okunuyor.

Hedefin sayısı cümlede geçmiyor — "5sa 20dk odaklandın, hedefin tamam" zaten
hedefin o sayının altında olduğunu söylüyor, ikinci bir süre okuması bildirimi
tabloya çevirirdi.

## Bayatlama

Bildirim kurulduğu **andaki** hedefle kuruluyor. Kullanıcı Ekran 07'de hedefi
yükseltip uygulamayı bir daha açmazsa ve o hafta hiç odak tamamlamazsa, önceden
kurulmuş "hedefin tamam" cümlesi eski hedefe ait olur.

Bu pencere yeni değil, mevcut mimarinin penceresi: Ekran 07 hiçbir ayar
yazısında bildirim yeniden kurmuyor — `notificationsEnabled`ı kapatmak bile
kurulmuş özeti açılışa ya da ilk odak tamamlanışına kadar iptal etmiyor. Yeniden
kurma noktaları uygulama açılışı ve her odak tamamlanışı; hedef de tam olarak bu
iki noktadan besleniyor, yani saniyeyle aynı tazelikte.

Ekran 07'yi üçüncü bir yeniden kurma noktası yapmak bu maddenin işi değil: üç
bildirimin (seri riski, haftalık kapanış, dönüş) hepsini ilgilendiren ayrı bir
karar.

## Testler

`test/services/notifications/notification_service_test.dart` içinde yeni bir
grup — gövde, sahte kanala inen `zonedSchedule` çağrısından okunuyor:

| # | İddia |
| --- | --- |
| 1 | Hedef tutunca gövde hedef cümlesi, kıyas cümlesi **yok** |
| 2 | Hedef tam karşılanınca da tutmuş sayılıyor (sınır dahil) |
| 3 | Hedef tutmayınca bugünkü kıyas cümlesi aynen kuruluyor |
| 4 | Hedef kapalıyken (`0`) hedef cümlesi hiç kurulmuyor |
| 5 | İlk hafta + hedef tuttu → hedef cümlesi (kıyassızlığın önüne geçiyor) |

## Koşum

```
flutter analyze && flutter test
```

## Kabul

Emülatörde hedefi karşılanmış bir hafta kurulup cihaz saati pazar 20:00'ye
getirilir; düşen bildirimin gövdesi hedef cümlesini söylüyor. Karşı kontrol:
hedef yükseltilip uygulama yeniden açıldığında aynı bildirim kıyas cümlesine
dönüyor.

## Kapsam dışı

- Hedef dolmadığında eksikliği söyleyen cümle ya da ayrı hatırlatma bildirimi
  (maddenin kendi kapsam dışı notu).
- Ekran 07'nin ayar yazılarını bildirim yeniden kurma noktası yapmak.
- Hedefin ana ekran widget'ında metne dönmesi (madde 41'in kapsam dışı notu).
