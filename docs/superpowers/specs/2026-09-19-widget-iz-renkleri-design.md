# Widget'ın izleri açık temada görünsün — tasarım

ROADMAP madde 44. Madde 41'in emülatör doğrulamasında çıkan, kapsam dışı
bırakılan kusur: `RingRenderer` iz renklerini düz beyaz-alfa hex olarak tutuyor,
açık temada widget zemini de açık olduğu için üç iz de görünmüyor.

## Sorun

`RingRenderer` iki sabit taşıyor:

```kotlin
private const val FILL_SUBTLE = 0x17FFFFFF   // dis tel + emek izi
private const val TRACK_COLOR = 0x12FFFFFF   // zaman izi
```

Bunlar `AppColors.dark()`in `fillSubtle`/`hairline` değerleri. Koyu zeminde
doğru; açık temada yanlış, çünkü `AppColors.light()` aynı iki rolü **siyah**
alfayla kuruyor (`0x14000000` / `0x12000000`). Madde 41'in emülatör ölçümü:
zemin `(212,212,213)`, izin çizdiği renk `(216,216,218)` — dört ton.

Kusur madde 41'den eski; madde 41 yalnızca üçüncü izi ekledi. Sonucu en çok
emek ekseninde acıtıyor: hedef açık ama hafta boşken widget'ta o eksenin yeri
hiç görünmüyor, Ekran 02'de `colors.fillSubtle` ile görünüyor.

**Diğer çiziciler temiz.** `StripRenderer`ın izi `withAlpha(palette.text, 0x12)`
— `text` zaten temadan geliyor, iki temada da dönüyor. `SparkRenderer`ın taban
çizgisi accent renginde; accent doygun bir renk, iz değil işaret.
`FlameRenderer`ın düz hex'leri alev gövdesi, iz değil. Madde yalnızca
`RingRenderer`a dokunuyor.

## Karar 1: izler palete bağlanıyor

`focus_colors.xml` (açık) ve `values-night/focus_colors.xml` (koyu) iki yeni
token alıyor, `FocusPalette` ikisini açıyor:

| token | açık | koyu |
| --- | --- | --- |
| `focus_fill_subtle` | `#14000000` | `#17FFFFFF` |
| `focus_hairline` | `#12000000` | `#12FFFFFF` |

Değerler uydurulmadı: `AppColors.light()`/`AppColors.dark()`ten birebir
kopyalandı, `test/android/focus_palette_sync_test.dart` de bunu zaten sınıyor —
`expectedFor` haritasına iki satır ekleniyor, yeni bir kanal gerekmiyor.

Rol eşlemesi Ekran 02'nin painter'ından aynen geliyor
(`countdown_ring_painter.dart`): dış tel ve emek izi `fillSubtle`, zaman izi
`hairline`. İki yüzey aynı halkayı aynı tokenlarla boyuyor.

`render` içinde `FocusPalette` bir kez kuruluyor ve `drawCenterText`e de o
örnek geçiliyor — bugün ikinci bir `FocusPalette(context)` orada ayrıca
kuruluyordu.

## Karar 2: sözleşme eşiği renkten değil **kontrasttan** okuyor

Madde 39'un `RingRendererContract`ı şunu varsayıyordu:

> Alfa (iz `0x12`, kesikli çember `0x59`, yaylar `0xFF`) ve sıcaklık, ikisi de
> tema niteleyicisinden bağımsız: halkanın izleri `RingRenderer`da düz hex.

İzler temaya bağlanınca bu cümlenin ikinci yarısı düşüyor. İki seçenekten
(sözleşmeyi iki temada da koşturmak / eşiği kontrasttan okumak) **ikisi de**
alınıyor, çünkü tek başlarına eksikler:

- Alfa sondaları iki temada da tutuyor ama bunu **iddia eden** bir şey yok;
  yarın biri `fillSubtle`i `0x88`e çekse `drawnFraction`ın `0x80` eşiği sessizce
  yalan söylerdi.
- Alfa bandını sınamak da yetmez: bugünkü kusur tam da alfası doğru, **rengi**
  yanlış bir izdi.

Yeni 13. iddia: `verifyTrackContrast(context)`. İki temayı da kuruyor
(`createConfigurationContext` ile `uiMode`u çevirerek — hem Robolectric hem
cihaz bunu çözüyor) ve her iz için iki şey sınıyor:

1. **Alfa bandı**: `8 < alfa < 0x80`. Sözleşmenin öteki iddialarının dayandığı
   iki eşik (izler `verifyTrack`ta 8'in üstünde, `drawnFraction`da `DRAWN`in
   altında) artık varsayım değil, iddia.
2. **Kontrast**: iz, widget zemininin üstüne bindirildiğinde en az 10 ton fark
   bırakıyor.

Kontrast ölçüsü zemini tahmin etmiyor, **aralığını** alıyor: widget kartı
(`focus_surface_card`) yarı saydam, altında duvar kâğıdı var. Kart en koyu
(siyah duvar kâğıdı) ve en açık (beyaz) uçlara bindirilip iz her ikisinin de
üstünde ölçülüyor. Bir iz ancak zeminin **karşı** tarafındaysa iki uçta birden
geçer; bugünkü beyaz iz açık temada beyaz uçta 0 ton bırakıyor ve düşüyor.

Ölçülen paylar (en kötü uç): zaman izi açıkta 14.8 / koyuda 13.0, emek izi
açıkta 16.4 / koyuda 16.6 ton. Eşik 10, yani dar değil.

Dış tel sondaya girmiyor: 1 px'lik çizgi üretim ölçeğinde (273/316) bir piksele
tam oturmuyor, kenar yumuşatma alfayı ölçülemez hâle getiriyor. Emek iziyle
**aynı** tokenı (`fillSubtle`) kullandığı için bağlanması zaten sınanıyor.

Sözleşmenin başlık yorumu da düzeltiliyor: "izler düz hex" cümlesi kalkıyor,
yerine izlerin paletten geldiği ve alfa bandının iddia edildiği yazılıyor.

## Koşum

```
flutter analyze && flutter test
./gradlew :app:testDebugUnitTest --tests "*RingRenderer*"
./gradlew :app:connectedDebugAndroidTest
```

## Kanıt

`RingRendererDeviceTest`e `izPngleriniDok`: aynı halka iki temada üretim
ölçüsünde (273 px) çizilip `m44_a_acik` / `m44_b_koyu` olarak cihaza yazılıyor,
`adb pull` ile `.verify/m44/`'e alınıyor. Hedef **açık ve hafta boş** durumu
seçiliyor — maddenin kabul ölçütündeki kare bu.

Üstüne emülatörde açık temada halka widget'ı ana ekrana yerleştirilip ekran
görüntüsünden izin pikselleri ölçülüyor (madde 41'in kalıbı).

## Kapsam dışı

- Yayların renkleri — zaten paletten geliyor.
- Widget zemininin kendisi (madde 38'de karara bağlandı).
- `StripRenderer` / `SparkRenderer` / `FlameRenderer` — yukarıda gerekçesiyle
  temiz bulundu.
- Uygulama içi "Açık/Koyu" seçiminin widget'a ulaşması: widget Flutter tema
  ağacının dışında, **sistem** temasını izliyor (`focus_colors.xml` başlığındaki
  not). Bu madde o sınırı değiştirmiyor.

## Kabul

Emülatörde açık temada halka widget'ı yerleştirilip hedef açık ama hafta boş
bırakılır; emek ekseninin izi görünür. Koyu temada üç izin de bugünkü görüntüsü
değişmez.
