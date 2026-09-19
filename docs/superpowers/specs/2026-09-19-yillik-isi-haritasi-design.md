# Yıllık ısı haritası penceresi — tasarım

ROADMAP madde 37. Madde 29 aylık ısı haritasını getirirken üç şeyi kapsam dışı
bıraktı: **ay gezinme okları, hücreye dokunma, yıllık pencere**. Madde 35 ilk
ikisini yaptı. Bu madde üçüncüsünü yapıyor ve o listeyi kapatıyor.

## Sorun

Aylık ızgara "bu ay hangi günler çalıştım"ı cevaplıyor, gezinmeyle "geçen ay
nasıldı"yı da. Cevaplayamadığı soru **ölçek**: kullanıcının ritmi aylar boyunca
nasıl gidiyor, sınav yaklaşırken yoğunlaştı mı, yazın nerede koptu. Ayı ay ay
gezerek bu görülmüyor — on iki ayrı bakış, tek bir şekil değil.

Veri zaten bellekte: `allSessionsProvider` tüm kayıtları tutuyor. Madde 35'in
`monthOffset` kalıbındaki gibi, bu da **yeni sorgu değil, aynı listeden başka
bir pencere**.

## Karar 1 — Takvim yılı değil, yuvarlanan 52 hafta

Pencere **52 sütun × 7 satır = 364 gün**. Son sütun bugünün içinde bulunduğu
hafta (Pzt–Paz), ilk sütun ondan 51 hafta öncesi.

Takvim yılı (`2026`) elendi: ocak ayında pencere neredeyse boş olurdu ve yılın
ilk haftalarında ritim diye gösterilecek bir şey kalmazdı. Yuvarlanan pencere
her gün aynı miktarda geçmişi gösteriyor.

Hafta pazartesiyle başlıyor — aylık ızgaranın `leadingBlanks` kuralıyla ve
`shortDayNames` sırasıyla aynı. Gün sınırı yine `appDayKey`: 04:00 TSİ
(SPEC §5.3), aylık hesaplayıcıyla **aynı fonksiyon**, ikinci bir gün tanımı
açılmıyor.

Gelecek günler — bu haftanın kalanı — çizilmiyor. Madde 29'un kuralı aynen:
yaşanmamış günü boş kutu olarak göstermek onu kaçırılmış gün gibi okuturdu.

Kullanıcının uygulamayı kurmasından önceki günler seviye 0 olarak çiziliyor,
pencereden kırpılmıyor. Geçmiş bir aya bakmakla aynı davranış: pencere sabit,
veri ne kadarsa o kadar.

## Karar 2 — Eşikler aynı kalıyor, ve bu artık bir seçim değil

ROADMAP "madde 29'un mutlak seviye eşikleri (1/25/50/90 dk) yıllık ölçekte
yeniden düşünülmeli" diyordu. Düşünüldü: **aynı kalıyor**, ve yerleşim kararı
bunu zorunlu hâle getirdi.

Şerit aylık ızgarayla aynı kartta duruyor ve kartın altındaki efsane
(`az ▫▪▪▪ çok`) **ikisine birden** hizmet ediyor. Tek efsane → tek rampa → tek
eşik takımı. İkinci bir eşik takımı, aynı günün iki ızgarada iki farklı tonda
görünmesi demekti; efsane o durumda hangi ızgarayı anlattığını söyleyemezdi.

Madde 29'un "ayın en yoğun gününe ölçekleme" gerekçesi yıllık ölçekte daha da
güçlü: yılın tek 8 saatlik gününe göre ölçeklenen bir harita, 90 dakikalık
normal günlerin hepsini soluk gösterirdi. Eşikler dakikada sabit olduğu için
iki pencere birbiriyle de karşılaştırılabiliyor — üstteki ayın koyu kutusu ile
alttaki şeridin koyu kutusu aynı şeyi söylüyor.

`heatmapLevel` ve `kHeatmapLevelThresholds` paylaşılıyor, kopyalanmıyor.

## Karar 3 — Sığdırılmış şerit: etkileşim yok, bugün işareti yok

360dp ekranda kullanılabilir genişlik **268dp** (360 − 2×26 ekran payı − 2×20
kart payı). 52 sütun ve 51×1dp boşlukla hücre **~4.2dp**.

Bu boyut dokunma hedefi olarak imkânsız, o yüzden şerit `DecoratedBox`'tan
ibaret — jest ağacı hiç kurulmuyor. Bedel kayıp değil: "bu kutu kaç dakika"
sorusunu madde 35 zaten üstteki aylık ızgarada cevapladı. Şeridin işi tek bir
şey, **yılın şekli**.

Yatay kaydırmalı GitHub düzeni elendi: hücreyi 10dp'de tutardı ve gün seçimini
yıllık görünüme taşırdı, ama Ekran 06'nın gövdesi zaten dikey kaydırılıyor ve
içine yatay kaydırılan bir şerit koymak iki jesti birbirine düşürürdü. 12 ayrı
mini ay ızgarası da elendi: kartı ~500dp uzatıyor ve on iki takvim düzeni tek
bir şekil olarak okunmuyor.

**Bugünün ember çerçevesi yok.** Gelecek günler çizilmediği için son çizilen
hücre zaten bugün — işaret gereksiz. Ayrıca 4.2dp hücrede 1.5px çerçeve
hücrenin üçte biri olurdu.

## Karar 4 — Kartın içinde, ızgarayla hizalı

Sıra: mevcut başlık (oklar + `BU AY` + ay toplamı) → gün adları → aylık ızgara
→ **`colors.hairline` ayırıcı** → **`SON 52 HAFTA` kicker + yıl toplamı** →
**şerit** → mevcut alt satır (seçili gün detayı + efsane).

Ayrı ikinci kart elendi: efsaneyi ve rampayı iki kez yazardı, oysa karar 2'nin
tamamı tek efsane üzerine kurulu. Başlıkta `AY / YIL` segmenti de elendi: yeni
bir ekran durumu, yeni bir kontrol ve "yıl görünümündeyken oklar ne yapar"
sorusu getirirdi. Sabit şerit hiç hareketli parça eklemiyor.

Şerit **kart payının içinde**, aylık ızgarayla hizalı. Tam genişliğe taşırmak
hücreyi 4.9dp'ye çıkarırdı (+%18) ama iki ızgaranın aynı kenardan başladığı
görsel bağı koparırdı — o bağ karar 2'nin görünür hâli.

**Ay adı etiketi yok.** `MaterialLocalizations` kısa ay adı vermiyor
(`formatMonthYear` var, `formatShortMonth` yok); `DateFormat` ise madde 29 ve
35'in bilerek reddettiği şey — 12 yeni ARB anahtarı ya da karta `intl` +
`initializeDateFormatting` bağımlılığı. Zaman çapası şeridin kendi geometrisi:
sağ ucu her zaman "şimdi", eni her zaman 52 hafta.

Yıl toplamı **boş pencerede hiç yazılmıyor** — ay toplamının ve haftalık
kapanış kartının gerekçesinin aynısı: "0 dakika" eşlik eden bir tondan ölçen
bir tona geçiş. Şeridin kendisi boş pencerede de çiziliyor.

## Karar 5 — Paylaşılan ölçek kendi dosyasına çıkıyor

`HeatmapDay`, `heatmapLevel`, `kHeatmapLevels` ve `kHeatmapLevelThresholds`
bugün `monthly_heatmap.dart`ta. İkinci bir hesaplayıcı bunları kullanacağı için
"yıllık, aylıktan import ediyor" gibi yanlış bir bağımlılık yönü doğardı.

Dördü **`lib/domain/stats/heatmap_scale.dart`**a taşınıyor; her iki hesaplayıcı
oradan alıyor. `monthly_heatmap.dart` bir `export 'heatmap_scale.dart';` satırı
ekliyor, böylece mevcut hiçbir import (kart, `stats_providers`, testler)
kırılmıyor — taşıma tek dosyaya dokunuyor.

| dosya | ne |
| --- | --- |
| `domain/stats/heatmap_scale.dart` *(yeni)* | paylaşılan ölçek + `HeatmapDay` |
| `domain/stats/monthly_heatmap.dart` | taşınanlar çıkıyor, `export` giriyor |
| `domain/stats/rolling_year_heatmap.dart` *(yeni)* | `RollingYearHeatmap` + `calculateRollingYearHeatmap` |
| `domain/stats/stats_providers.dart` | `rollingYearHeatmapProvider` |
| `features/stats/widgets/monthly_heatmap_card.dart` | ayırıcı + yıl başlığı + şerit |
| `features/stats/stats_screen.dart` | `_HeatmapSection` ikinci sağlayıcıyı da izliyor |
| `l10n/app_tr.arb` | üç yeni anahtar |

Ad **`RollingYearHeatmap`**: takvim yılı olmadığını adın kendisi söylüyor.
`YearlyHeatmap` okuyana "2026" dedirtirdi.

Sağlayıcı `Provider`, `Provider.family` değil: pencere sabit, anahtarlanacak
bir şey yok. Madde 35 aylık olanı aileye çevirmişti çünkü orada gezinme var.

Kart parametresi (`required this.year`) **zorunlu**, opsiyonel değil: üretimde
her zaman verilecek bir alanın null hâli, yalnızca testlerin yaşadığı bir kod
yolu olurdu. Kart yine **saf** — `year` da dışarıdan veriliyor, madde 29'un
"Riverpod kurmadan çizilebilen kart" kalıbı bozulmuyor.

`CustomPainter` değil widget ağacı (364 `DecoratedBox`, kartın mevcut
`RepaintBoundary`si içinde): madde 29'un gerekçesi ve madde 31'in
doğrulanamayan painter dersi.

## Karar 6 — Erişilebilirlik: yine yeni durak yok

Şerit kartın mevcut `ExcludeSemantics` bölgesinin içinde kalıyor. Madde 29
ızgarayı tek durak yapmıştı (hücre hücre gezinme 30 durak demekti); 364 hücre
bunu 394'e çıkarırdı.

Kabın özet cümlesine bir cümle ekleniyor:
*"Son 52 haftanın 128 gününde odaklandın, toplam 182 saat 40 dakika."*
Boş pencerede `statsHeatmapYearEmptySemantics`. Süre uzun hâlde
(`spellFocusDuration`) — "182sa" harf harf okunurdu.

Yeni ARB anahtarları: `statsHeatmapYearLabel`, `statsHeatmapYearSemantics`,
`statsHeatmapYearEmptySemantics`.

## Testler

`test/domain/stats/rolling_year_heatmap_test.dart`:
- 364 gün; ilk gün pazartesi, son gün içinde bulunulan haftanın pazarı.
- Bu haftanın yarını `isFuture`, dünü değil.
- Pencerenin sol kenarı: 52 hafta + 1 gün önceki seans toplama girmiyor,
  tam 52 hafta öncesi giriyor.
- 03:30 TSİ'de başlayan seans bir önceki güne düşüyor (04:00 sınırı).
- Yalnızca `completed && type == focus` sayılıyor.
- Aynı dakika aylık ızgarayla aynı seviyeyi veriyor (paylaşılan `heatmapLevel`).
- Boş pencerede `isEmpty`, `totalMinutes == 0`, `days` yine 364.

`test/features/stats/monthly_heatmap_card_test.dart` ekleri:
- Çizilen yıl hücresi sayısı = gelecek olmayan gün sayısı.
- Yıl toplamı boş pencerede yazılmıyor, dolu pencerede yazılıyor.
- Yıl hücresi dokunmayı karşılamıyor: `onDayTap` verilmişken şeride dokunmak
  geri çağrıyı tetiklemiyor (aylık hücre tetikliyor).
- Semantics cümlesi yıl özetini içeriyor.

`test/features/stats/stats_screen_test.dart` eki:
- Ay okuyla geçmiş aya gidildiğinde şerit **değişmiyor** — pencere sabit.

Madde 36'nın tuzağı burada da geçerli: ağır ekran testlerinde dosya başına tek
`pumpWidget`, yoksa drift göçü yarıda kalıyor.

## Kapsam dışı

Yıl gezinme (geriye bir 52 hafta daha), şeritte gün seçimi, ay sınırı
etiketleri ya da çentikleri, tam genişliğe taşan şerit, şeridin aylık ızgarada
açık olan ayı vurgulaması, şeridin giriş animasyonu, diğer kartların yıllık
pencereye bakması.
