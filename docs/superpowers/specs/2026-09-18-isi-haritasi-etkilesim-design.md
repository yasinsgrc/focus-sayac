# Isı haritasında ay gezinme + gün seçimi — tasarım

ROADMAP madde 35. Madde 29 aylık ısı haritasını getirdi ve üç şeyi açıkça
kapsam dışı bıraktı: **ay gezinme okları, hücreye dokunma, yıllık pencere**.
Bu madde ilk ikisini yapıyor; yıllık pencere yine dışarıda.

## Sorun

Izgara bugün sessiz bir görsel: 42 hücrenin hiçbiri dokunmayı karşılamıyor
(`DecoratedBox`) ve pencere **içinde bulunulan ay**a çivili
(`calculateMonthlyHeatmap` ayı `nowUtc`'den türetiyor, parametresi yok).

İki soru cevapsız kalıyor:

1. *"Geçen ay nasıldı?"* — ayın 2'sinde ızgarada iki hücre var, kullanıcının
   ritmi bir önceki ayda duruyor ve erişilemiyor.
2. *"Bu koyu kutu kaç dakikaydı?"* — rampa dört ton, tonun karşılığı yalnızca
   efsanedeki `az ▢▣▤▥ çok`. Kullanıcı 45 dakikalık günle 95 dakikalık günü
   ayırt edebiliyor ama ikisinin de sayısını göremiyor.

Veri zaten bellekte: `monthlyHeatmapProvider` `allSessionsProvider`ın tamamını
okuyor, yani geçmiş ay **ek sorgu değil, yalnızca başka bir pencere**.

## Karar 1 — Ay hesaplayıcının parametresi, ekranın durumu değil

`calculateMonthlyHeatmap` yeni bir parametre alıyor: `int monthOffset = 0`
(0 = bu ay, −1 = geçen ay). Ay yine uygulama gününden türüyor
(`currentAppDayKey`), yalnızca offset ekleniyor:
`DateTime.utc(today.year, today.month + monthOffset, 1)`. `DateTime.utc` ay
taşmasını kendisi normalize ediyor — ocakta −1, geçen yılın aralığı.

Alternatif, doğrudan `DateTime month` parametresi vermekti. Elendi: çağıran
o zaman "hangi gün tanımına göre ay?" sorusunu kendi cevaplamak zorunda kalır
ve 04:00 TSİ sınırı (SPEC §5.3) hesaplayıcının dışına sızardı. Offset ile ay
tanımı tek yerde kalıyor.

## Karar 2 — `isCurrentMonth` sessiz bir hatayı kapatıyor

`MonthlyHeatmap`'e dört alan giriyor:

| alan | ne için |
| --- | --- |
| `month` | başlığın kaynağı (ayın 1'i, UTC) |
| `isCurrentMonth` | bugünün çerçevesi ve `BU AY` başlığı |
| `hasEarlier` | geri okun etkinliği |
| `hasLater` | ileri okun etkinliği (`monthOffset < 0`) |

`isCurrentMonth` kozmetik değil. Karttaki `_todayIndex` "gelecek **olmayan**
son gün" diyor; geçmiş ayda hiçbir gün gelecek değil, yani ayın son gününe
ember çerçeve çizilirdi — kullanıcıya 31 Ağustos'u "bugün" diye gösteren bir
ızgara. Aynı kural ızgaranın nerede bittiğine de bağlı: "bugünün satırında
bitir" yalnızca içinde bulunulan ayın kuralı, geçmiş ay ayın son satırına
kadar çiziliyor.

`hasEarlier` **tamamlanmış odak seansına** bakıyor, ayın kendisine değil:
uygulamayı bu ay kuran kullanıcı geri okla boş aylarda kaybolmuyor. Ölçüt
ızgaranın ölçütüyle aynı (`completed && type == focus`), yani "geri gidince
bir şey göreceksin" sözü ızgaranın gösterdiği şeyle aynı veriden çıkıyor.

## Karar 3 — Seçili ay ve seçili gün ekranın kısa ömürlü durumu

`monthlyHeatmapProvider` `Provider.family<MonthlyHeatmap, int>` oluyor
(anahtar: offset). Ekran 06'da küçük bir `StatefulWidget` (`_HeatmapSection`)
offset ile seçili günü tutuyor ve `monthlyHeatmapProvider(offset)`ı izliyor.

Kart **saf kalıyor**: `heatmap`, `selectedDay`, `onDayTap`, `onMonthStep`.
Böylece kartın testi Riverpod kurmadan tek widget'la yazılabiliyor — madde
29'un `MonthlyHeatmapCard(heatmap: ...)` kalıbı bozulmuyor.

Durum neden kalıcı değil: ikisi de bir bakışın süresi kadar yaşıyor. Seçili
günü DB'ye ya da `SharedPreferences`a yazmak, kullanıcının iki gün sonra
Ekran 06'yı açtığında hatırlamadığı bir günü seçili bulması demek. Ay
değişince seçim de sıfırlanıyor — başka aydaki bir günün detayını gösteren
satır yalan söylerdi.

## Karar 4 — Ay adı `MaterialLocalizations`tan, büyük harfe çevrilmeden

Madde 29 başlığı `BU AY` yaptı çünkü `DateFormat` ya 12 yeni ARB anahtarı ya
da karta `intl` + `initializeDateFormatting` bağımlılığı demekti. Gezinme
gelince başlık ay adını söylemek zorunda.

Üçüncü bir yol var: `MaterialLocalizations.of(context).formatMonthYear(month)`
→ "Eylül 2026". `GlobalMaterialLocalizations` uygulamada zaten bağlı
(`app_localizations.dart`), yani yeni ARB anahtarı da yeni başlatma da yok.

**Bu ayda başlık yine `BU AY`** — madde 29'un kararı duruyor, ve gezinmeden
sonra "buradayım" demenin en kısa yolu. Geçmiş ayda ay adı yazılıyor.

Ay adı **büyük harfe çevrilmiyor**. Dart'ın `toUpperCase()` Unicode
varsayılanını uyguluyor: `"Ekim".toUpperCase()` → `"EKIM"`, `"Nisan"` →
`"NISAN"`. Türkçe noktalı İ kaybolur. Kicker stilinin büyük harfi ARB
metinlerinden geliyordu, burada metin yerelleştirme kütüphanesinden geliyor —
olduğu gibi yazılıyor.

## Karar 5 — Detay satırı efsanenin solunda, tooltip değil

Seçilen günün karşılığı **efsane satırının soluna** yazılıyor:
`18 Eyl • 45 dk`, odak yoksa `18 Eyl • odak yok`. Tarih
`MaterialLocalizations.formatShortMonthDay`, süre `compactFocusDuration`
(kısa hâl: kartın sağındaki ay toplamı uzun hâlde, günün satırı efsaneyle
aynı satırı paylaştığı için kısa).

Tooltip elendi: dokunmatikte uzun basış istiyor, kenar sütunlarda taşıyor ve
ekran görüntüsüyle doğrulaması zor. Alt sayfa elendi: yeni ekran, yeni ARB,
yeni testler — bu maddenin sorusu "bu kutu kaç dakika", bir günün dökümü
değil.

Seçili hücre `colors.text` çerçeve alıyor. Bugünün ember çerçevesinden ayrı
bir renk, ve ikisi çakıştığında (bugüne dokunulduğunda) **seçim kazanıyor**:
kullanıcının az önceki eylemi, sabit işaretten daha taze. Aynı hücreye ikinci
dokunuş seçimi kaldırıyor.

Gelecek günler ve ayın dışındaki yer tutucular dokunmayı hiç karşılamıyor —
çizilmeyen bir hücre `SizedBox.shrink()`, dokunulacak bir şey yok.

## Karar 6 — Erişilebilirlik: ızgara yine tek durak

Madde 29 ızgarayı tek `Semantics` durağı yaptı (`excludeSemantics: true`);
hücre hücre gezinme 30 durak demekti. Bu madde onu bozmuyor:

- **Oklar iki yeni durak** — `statsHeatmapPreviousMonth` /
  `statsHeatmapNextMonth` etiketleriyle, pasifken dokunmayı karşılamıyor.
- **Seçim özet cümlesine ekleniyor**: bir gün seçiliyken kabın etiketi
  "Bu ay 30 günün 14 gününde odaklandın, toplam … 18 Eyl • 45 dk." oluyor.
  Ekran okuyucu kullanıcısı seçimi dokunarak yapamaz (hücreler durak değil)
  ama ekranı gören biriyle aynı ekranı dinlerken kopmuyor.

## Testler

`monthly_heatmap_test.dart` (hesaplayıcı):
- `monthOffset: -1` geçen ayın penceresini veriyor, `leadingBlanks` o ayın
  1'ine göre.
- Ocakta `-1` geçen yılın aralığını veriyor (yıl sınırı).
- Geçmiş ayda hiçbir gün `isFuture` değil ve `days` ay uzunluğunda.
- `isCurrentMonth` yalnızca offset 0'da.
- `hasEarlier` en eski **tamamlanmış odak** seansına göre; yalnızca mola/iptal
  seansı olan geçmiş ay geri oku açmıyor.
- `hasLater` offset 0'da false.

`monthly_heatmap_card_test.dart` (kart):
- Geri ok `onMonthStep(-1)` çağırıyor; `hasEarlier` false iken çağırmıyor.
- Geçmiş ayın başlığı ay adını yazıyor, bu ayınki `BU AY`.
- Geçmiş ayda hiçbir hücrede ember çerçeve yok.
- Hücreye dokunma `onDayTap`i o günle çağırıyor; gelecek hücre çağırmıyor.
- `selectedDay` verilince detay satırı yazılıyor; odaksız günde "odak yok".
- Seçili hücrenin çerçevesi var ve bugünle çakışınca `text` rengi kazanıyor.

Ekran testi (`stats_screen`): geri ok bir önceki ayı çiziyor, sonra hücreye
dokunmak detay satırını getiriyor, ileri ok seçimi sıfırlayıp bu aya dönüyor.

## Kapsam dışı

Yıllık pencere, hücreye uzun basma, seçili günün ders kırılımı, gelecek aya
gezinme (yaşanmamış gün gösterilmiyor — madde 29'un kararı), bar chart'ın ve
diğer kartların geçmiş aya bakması (ızgara dışındaki her sayı yine bugünün
penceresi), ay geçişinin animasyonu.
