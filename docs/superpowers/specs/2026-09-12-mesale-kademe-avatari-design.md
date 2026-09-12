# FocusSayaç — Meşale Kademe Avatarı (Tasarım)

Tarih: 2026-09-12
Durum: Onaylandı

## Amaç

Meşaleyi seans içinde büyüyüp sıfırlanan bir süsten, kümülatif odak saatine
bağlı **kalıcı bir avatara** dönüştürmek. Tek hamlede üç şey:

1. **Sonsuz ilerleme ekseni** — rozetler bir gün biter, saat birikimi bitmez.
2. **Kimlik** — "ben 6. kademedeyim" diyebilen bir görsel.
3. **Uygulamayı açtıran sebep** — ana ekranda "sonraki kademeye 38 saat"
   yazan bir widget.

Veri zaten var: `PomodoroSession` kayıtlarından türetilen
`FocusStats.cumulativeSeconds`. Yeni tablo, yeni kolon, migration yok.

## Kapsam dışı

- iOS (projede `ios/` dizini yok, Android-only).
- Kademe atlama kutlaması/dialogu. Rozet açılış dialogu zaten dört saat
  eşiğinde tetikleniyor; ikinci bir kutlama aynı ana iki modal koyardı.
- Kademeye bağlı tema/renk değişimi. Avatar kendi paletini taşır, uygulamanın
  accent rol sistemi (`exam_accent.dart`) değişmez.
- Geriye dönük "hangi kademeye ne zaman çıktın" geçmişi.

## Alınan dört karar

| Karar | Seçim | Elenen alternatif ve sebebi |
|---|---|---|
| Seans vs kademe | Kademe taban, seans üstte yoğunluk | "Seans kümülatif ekseni canlı ilerletir": 25 dk = 0.42 sa; sonraki kademeye 5 saat kalmışsa hareket ~2px, ödül görünmez. |
| Rozetle ilişki | Eşikler hizalanır, rozet kademenin belgesi | "Kademe rozetleri yutsun": `UserBadges`'te kayıtlı satırların katalog karşılığı kalmaz, `badgeByKey()` fırlatır — kazanılmış bir şey geri alınmış olur. |
| Yerleşim | Ekran 04 (Rozetler) başında kahraman kart | Ekran 02'nin 316px halka kahramanı zaten dolu; avatar orada ~24px'e düşer ve kimlik hissi kaybolur. |
| Kademe ekseni | Tek gövde, üç eksende evrim | "Her kademe ayrı siluet": 10 çizim × 2 platform = 20 çizim, ve kademe geçişi animasyonla bağlanamaz (siluet zıplar). |

## Merdiven

```
K1  Kıvılcım          0 sa
K2  Köz               1 sa
K3  Kandil            3 sa
K4  Fener            10 sa   ← rozet: tenHours
K5  Meşale           25 sa
K6  Ocak             50 sa   ← rozet: fiftyHours
K7  Şenlik Ateşi    100 sa   ← rozet: hundredHours
K8  Harman Ateşi    175 sa
K9  Volkan          250 sa   ← rozet: twoFiftyHours
K10 Güneş           400 sa
```

Dört saat rozeti (`badge_rules.dart:76-79`) merdivenin K4/K6/K7/K9
basamaklarına **düşer**. O eşiklere varıldığında tek bir olay olur, iki yüzeyde
görünür: kademe atlanır ve rozet açılır. Aradaki altı kademenin rozeti yoktur,
sessizce geçilir. Hiçbir rozet silinmez, DB'ye dokunulmaz.

Eşik aralıkları erken sık, geç seyrek: ilk 10 saatte dört kademe (yeni
kullanıcı hemen ilerleme görür), 100 saatten sonra üç kademe (uzun vadeli
kullanıcı için eksen tükenmez).

### Neden hizalama kendiliğinden tutuyor

`FocusStats.cumulativeSeconds` ile `evaluateBadgeProgress`'in
`totalPlannedSeconds`'ı **aynı hesap**: tamamlanmış odak seanslarının
`plannedDurationSec` toplamı. İkisi ayrı dosyada yaşadığı için bir test
eşitliği çivileyecek (bkz. Test).

Saat yuvarlaması rozetlerle aynı kural: aşağı yuvarlanır, `floor(sn/3600)`.
99sa 59dk hâlâ K6'dır.

### K1 = 0 saat

Uygulamayı ilk açan herkesin bir avatarı var. Alternatif ("ilk seansa kadar
avatar yok") boş bir kutu gösterirdi; kimlik, kazanılmadan önce de bir yerden
başlamalı. Kıvılcım zaten "henüz hiçbir şey yapmadın"ın görsel karşılığı.

## Veri katmanı

`lib/domain/flame/` — yeni dizin, `badge_rules.dart` ile aynı sözleşme (saf
fonksiyon, IO yok, SPEC.md §5.4).

| Dosya | Sorumluluk |
|---|---|
| `flame_tier.dart` | `FlameTier` (indeks, eşik saati, görsel parametreler), `kFlameTierLadder`, `flameTierFor()`. |
| `flame_providers.dart` | `flameTierProvider` — `focusStatsProvider`'ı okur. |

```dart
class FlameTierStatus {
  final FlameTier tier;
  final FlameTier? nextTier;      // K10'da null
  final int? hoursRemaining;      // K10'da null
  final double ratioInTier;       // 0–1, K10'da 1
}

FlameTierStatus flameTierFor(int cumulativeSeconds);
```

K10'da kart "en üst kademe" der; `hoursRemaining` null olduğu için "sonraki
kademeye 0 saat" gibi bir yalan kurulamaz.

## Çizim

`lib/features/focus_session/widgets/flame_widget.dart` →
**`lib/core/widgets/flame_widget.dart`**. Artık iki özellik kullanıyor, paylaşılan
widget'ların evi `core/widgets/`.

```dart
FlameWidget({
  required FlameTier tier,      // dinlenme biçimi
  double intensity = 0,         // seans 0→1
  bool flickering = false,
  bool desaturated = false,     // duraklatılmış seans
  required double boxHeight,    // yüzeyin verdiği taban ölçü
})
```

### İki eksen, ayrı kanallar

| Eksen | Kanallar |
|---|---|
| **Kademe** (kalıcı) | Boyut oranı, palet durakları, süsleme (taban közü, kıvılcım parçacıkları, hale) |
| **Seans** (geçici) | Çekirdek parlaklığı, titreşim genliği, kıvılcım yoğunluğu |

Seans `intensity`si **boyutu değiştirmiyor**. Sebep: K9→K10 arası oran farkı
%9; seans şişmesi eklenseydi iki eksen birbirine karışır, "kademe atladım mı?"
sorusu belirsizleşirdi. Seans bitince alev kademenin dinlenme hâline döner,
**asla altına inmez** — kalıcılık vaadinin tamamı bu cümlede.

### Boyut

Kademe oranı `0.35 (K1) → 1.0 (K10)`; mutlak piksel yok, her yüzey kendi
kutusunu verir:

| Yüzey | `boxHeight` | K1 görünen | K10 görünen |
|---|---|---|---|
| Odak ekranı (03) | 98px (mevcut) | 34px | 98px |
| Rozet kahraman kartı (04) | 120px | 42px | 120px |
| Meşale widget'ı | ~64dp | 22dp | 64dp |

Böylece yeni kullanıcı odak ekranında 34px alev görür — "K1 sekiz piksellik
nokta" sorunu ölçek ayrımıyla çözülüyor.

### Korunan kararlar

- İki `RepaintBoundary` aynen kalıyor (SPEC.md §6 kural 5, `DECISIONS.md:811`):
  dıştaki 72px sayaç metnini alevin kare başına `markNeedsPaint`inden ayırıyor,
  içteki `Transform`u bileşikleştiriyor.
- Duraklatılmış seansta titreşim duruyor (`DECISIONS.md:816`) — artık
  `flickering: false` ile açıkça.
- Açık/koyu tema palet ayrımı (`_lightBody` uç düzeltmesi) kademe paletlerinin
  her birine taşınır: krem uç açık zeminde 1.02:1 kontrasta düşüyordu.

Rozet kartındaki avatar da hafif titrer (`flickering: true`, düşük genlik) —
odak seansı içinde olmadığı için SPEC.md §6 kural 4'ün dekoratif animasyon
yasağı burayı kapsamıyor. `TickerMode`'a bağlı, sekme arkada kalınca duruyor.

## Ekran 04 — kahraman kart

`lib/features/badges/widgets/flame_avatar_card.dart`, rozet grid'inin üstünde:

```
        ▲
       ███       ← kademe alevi, 120px kutu
      █████
     OCAK
     ███████░░░  62 / 100 sa
     Sonraki kademeye 38 saat
```

İlerleme şeridi `ratioInTier`, sayaç `62 / 100 sa`. Mevcut rozet grid'ine,
`_BadgeCard`'a, `_BadgeUnlockDialog`'a dokunulmuyor.

Ekran okuyucu: kart tek bir semantik düğüm — "Ocak, 6. kademe, 62 saatte 100,
sonraki kademeye 38 saat".

## Widget — altıncı sağlayıcı

### Payload

Tek yeni anahtar: **`cumulativeFocusSeconds`** (int).

Kademe, kalan saat ve oran Kotlin'de hesaplanır, Dart'tan okunmaz —
`FocusWidgetSnapshot.kt:11`'deki "türetilmiş değer Dart'tan okunmaz" kuralının
aynısı. Ayrıca merdiven zaten **çizim için** Kotlin'de bulunmak zorunda; oranı
da Dart'tan göndermek ikinci bir gerçek kaynağı olurdu.

`HomeWidgetSnapshot.payloadKeys` listesine eklenir (mevcut test eksik anahtarı
yakalıyor).

### Kotlin dosyaları

`android/app/src/main/kotlin/com/focussayac/focussayac/widget/`

| Dosya | Durum | Sorumluluk |
|---|---|---|
| `FlameTierLadder.kt` | yeni | Merdiven sabitleri + `tierFor()`. Dart tablosunun aynası. |
| `FlameRenderer.kt` | yeni | Kademe alevinin Canvas bitmap'i. `RingRenderer`/`SparkRenderer` kalıbı. |
| `FlameWidgetProvider.kt` | yeni | `BaseFocusWidgetProvider` alt sınıfı; rota `/badges`. |
| `FocusWidgetSnapshot.kt` | değişir | `cumulativeFocusSeconds` okunur. |
| `BaseFocusWidgetProvider.kt` | değişir | `PROVIDERS` listesine eklenir (`onDisabled` alarm iptali doğru çalışsın diye). |
| `WidgetRoutes.kt` | değişir | `BADGES = "/badges"`. |

Kaynaklar: `res/layout/widget_flame.xml`, `res/xml/widget_flame_info.xml`,
`res/drawable/widget_preview_flame.xml`, `strings.xml` (10 kademe adı + widget
etiketi/açıklaması), `AndroidManifest.xml` receiver girdisi.

### Widget içeriği (2×2)

```
┌─ Meşale 2x2 ─────┐
│ MEŞALE           │  kicker, michroma 8sp
│       ▲          │
│      ███         │  FlameRenderer bitmap
│     █████        │
│ OCAK             │  space_grotesk_700
│ ██████░░░░       │  ilerleme şeridi
│ Sonraki: 38 sa   │  inter_500
└──────────────────┘
```

K10'da alt satır "En üst kademe" olur.

`updatePeriodMillis="0"` — diğer beş widget gibi saat başı alarma bağlı. Sayı
zamanla değişmediği için (kalan gün değil, biriken saat) bayatlama riski zaten
yok; yazma anı seans tamamlandığında gelir.

### Dokunuş

`WidgetRoutes.BADGES` → `WidgetLaunchScope._handle`'a `RoutePaths.badges`
case'i eklenir. Şu an tanınmayan yol geri sayıma düşüyor (`widget_launch_handler.dart:67`),
yani bu case olmadan widget yanlış ekrana götürür.

## Metinler

Kademe adları ARB'de (`lib/l10n/app_tr.arb`) — `flameTierK1Name` … `flameTierK10Name`,
artı `flameNextTierHours` ("Sonraki kademeye {hours} saat") ve
`flameTopTier` ("En üst kademe").

Widget tarafı ARB okuyamaz; aynı metinler `strings.xml`'e kopyalanır ve ARB'ye
geri işaret eden yorum düşülür (widget tasarımının kurduğu emsal).

## Test

| Test | Kapsam |
|---|---|
| `test/domain/flame/flame_tier_test.dart` | Sınırlar: 0 sn, tam eşik, eşiğin 1 sn altı, K10 üstü (`nextTier == null`), `ratioInTier` uçları |
| aynı dosya | **Hizalama:** her saat rozeti eşiğinde `flameTierFor` bir kademe sınırı veriyor |
| aynı dosya | **Tek kaynak:** `flameTierFor(FocusStats.cumulativeSeconds)` ile `evaluateBadgeProgress`'in saat sayacı aynı seans listesinde aynı saati veriyor |
| `test/android/flame_tier_sync_test.dart` | `FlameTierLadder.kt` sabitleri ayrıştırılıp Dart tablosuyla karşılaştırılır — palet senkron testinin emsali |
| `test/features/badges/badges_screen_test.dart` | Kahraman kart kademe adını, sayacı ve kalan saati gösteriyor; K10'da "En üst kademe" |
| `test/features/focus_session/focus_session_screen_test.dart` | Mevcut `_flameFlickTransform` testi bozulmadan geçer; **yeni:** seans bitince alev kademe tabanına döner, altına inmez |
| `test/domain/widgets/home_widget_snapshot_test.dart` | `cumulativeFocusSeconds` payload'da |

Merdiven senkron testi, seçilen mimarinin tek zayıf noktasını (merdiven iki
yerde tutuluyor) otomatik yakalar.

## Riskler

1. **Merdiven iki dilde.** Palet ile aynı durum, aynı çözüm: senkron testi.
   Görsel parametreler (oran, palet, süsleme) de aynı testin kapsamında.
2. **Kotlin tarafında birim testi yok** — projede JVM altyapısı kurulu değil.
   `FlameRenderer` doğrulaması emülatörde görsel yapılır.
3. **Eşik değerleri yayınlandıktan sonra değiştirilemez.** Kademe düşüren bir
   değişiklik, kazanılmış kimliği geri almak olur. Eşikler rozet anahtarlarıyla
   aynı kısıt altında (`badge_definition.dart:9`).
4. **Altıncı widget listeyi kalabalıklaştırıyor.** Launcher seçicisinde artık
   altı girdi var. Kabul ediliyor: her biri farklı bir soruya cevap veriyor ve
   hiçbiri diğerinin işlevini tekrarlamıyor.

## Açık varsayımlar

Kullanıcı "devam" dedi, bu iki nokta açıkça onaylanmadı — ilk uygulamada
böyle kurulacak, itiraz gelirse tek dosyada döner:

1. **Kademe adları.** `Kıvılcım` (K1) ve `Meşale` (K5), mevcut rozet adlarıyla
   (`İlk Kıvılcım`, `Odak Meşalesi`) kelime paylaşıyor. Çakışma kabul edildi:
   ikisi de ateş metaforunun doğal kelimeleri ve bağlamları ayrı (rozet adı
   grid'de, kademe adı kahraman kartta).
2. **K1 = 0 saat** — avatar ilk açılıştan itibaren var.

## SPEC.md ihlalleri

- §0.3 "Prototipte olmayan ekran, buton veya özellik ekleme" — kademe avatarı
  ve altıncı widget prototipte yok. Widget tasarımının kurduğu emsalle aynı
  gerekçe.
- §5.5 "Meşale: `progress` 0→1 ile alev büyür" — boyut artık kademeden
  geliyor, `progress` yoğunluğa bağlandı. Bu maddenin yerine kademe ekseni
  geçiyor.

Gerekçeler `DECISIONS.md`'ye yazılır, `SPEC.md` §5.5 güncellenir.
