# Ring ile Strip boş durumda aynı dili konuşsun — tasarım

ROADMAP madde 43. Madde 39'un sözleşmeyi yazarken bulduğu, kapsam dışı bıraktığı
ayrışma: sınav seçilmemişken (`muted`) `StripRenderer` boş iz yerine bir kapak
çiziyor, `RingRenderer` ise yayı hiç çizmiyor.

## Sorun

Madde 39 ikisinin **bugünkü** davranışını sabitledi ama hangisinin doğru
olduğuna karar vermedi. İki widget ana ekranda yan yana durduğunda aynı durumu
iki farklı görsel dille anlatıyorlar:

| | sınav seçilmemişken |
| --- | --- |
| Halka (`RingRenderer`) | iz duruyor, yay **yok** |
| Şerit (`StripRenderer`) | iz duruyor, solda bir **kapak** var |

Şeridin kapağı `fillWidth`in tabanından geliyor:

```kotlin
val fillWidth = (widthPx * ratio.coerceIn(0f, 1f)).coerceAtLeast(heightPx.toFloat())
```

## Karar: halkanın dili doğru — boş, çıplak iz

Üç dayanak:

**1. Taban, yazılış gerekçesinin dışındaki tek durumda çalışıyor.** Yorumu
"çok küçük oranlarda çubuk tamamen kayboluyordu" diyor. Ama
`FocusWidgetSnapshot.progressRatio` `clamp(1 - days/400, 0.06, 1)` — sınav
varken oran **asla 0.06'nın altına inmiyor**, ve %6 dolgu 240×6dp'lik çubukta
~14.4dp, yani tabandan (6dp) iki kat uzun. Taban üretimde yalnızca
`StripWidgetProvider`ın `muted` için gönderdiği `0f`'ta ateşleniyor — tam da
halkanın hiçbir şey çizmemeyi seçtiği durumda.

**2. Aynı kusur halkada iki yüzeyde birden bilerek kapatılmış.**
`RingRenderer.drawEffortArc` ve `countdown_ring_painter.dart` aynı cümleyi
taşıyor: *"sıfır uzunluklu yay yuvarlak uçla nokta bırakırdı; haftanın başında
ekranda açıklanamayan bir leke olurdu — iz zaten ekseni gösteriyor."* Şeridin
kapağı, o lekenin düz çizgiye açılmış hali.

**3. Şeridin uygulama içinde karşılığı yok.** `lib`'de doğrusal bir doluluk
çubuğu bulunmuyor; "boş" dilini kuran tek otorite halka. Kapağı doğru kabul
etmek, halkayı **ve** Ekran 02'nin painter'ını birlikte değiştirmeyi
gerektirirdi — madde 41'in yeni kapattığı pariteyi yeniden açardı.

## Kararlar

### 1. `muted` kararı sağlayıcıdan çizicinin içine taşınıyor

`StripRenderer.render` `muted: Boolean` alıyor; `StripWidgetProvider` gerçek
oranı ve `muted`ı olduğu gibi geçiyor:

```
-   ratio = if (render.muted) 0f else render.ratio
+   ratio = render.ratio,
+   muted = render.muted,
```

Halkada karar zaten çizicinin içinde (`if (!muted)`), imzalar da böylece aynı
dili konuşuyor. Örtük "0 = boş" eşlemesi kalkıyor: onunla %0 ile %0.1 arasında
hiçlik→tam kapak uçurumu vardı, oysa aradaki fark artık sayısal değil anlamsal.

`EXPIRED` de `muted` sayılıyor (`WidgetRenderContext.muted`), yani sınav geçince
oran 1.0 gelse bile dolgu çizilmiyor — bugünkü davranış korunuyor.

### 2. Taban, **sıfır olmayan** oran için yerinde kalıyor

`coerceAtLeast(heightPx)` silinmiyor. Sözü değişmiyor, yalnızca kapsamı
netleşiyor: oran sıfır değilse çubuk görünür kalır. Üretimdeki 0.06 kırpması onu
zaten ateşlemiyor ama renderer kendi girdisinin kırpılmış geldiğine güvenmemeli.

## İddialar (`StripRendererContract`)

Madde 39'un kalıbı: gövde `src/sharedTest`te tek yerde, Robolectric NATIVE ve
cihaz koşumu aynı dosyayı derliyor.

**3. iddia düzeltiliyor.** Bugünkü `verifyMinimumFill` listesi `0f` ve `0.001f`
içeriyor, yorumu da maddenin yanlış saydığı cümleyi kuruyor: *"şerit o zaman boş
bir izle değil, bir kapakla duruyor."* Liste `0.001f` ve `0.06f` (üretimin
gerçek tabanı) oluyor, yorum "taban sıfır olmayan oran için" diye yeniden
yazılıyor.

**5. iddia ekleniyor** — `verifyMutedHasNoFill`, halkanın 6. iddiasının
(`verifyMutedHasNoArc`) birebir ikizi:

| # | İddia |
| --- | --- |
| 5 | `muted`'ken iz kesintisiz duruyor ve orta satırda `0x80` üstü tek piksel yok |

İki koşum evi de yeni testi alıyor.

## Kanıt

`StripRendererDeviceTest`e `bosDurumPngleriniDok`: üretim ölçüsünde (630×15)
`m43_a_serit_bos` ve `m43_b_serit_dolu` cihaza yazılıp `adb pull` ile
`.verify/`'a alınıyor. Yanına halkanın mevcut `m41_e_sinav_yok` dökümü konup iki
widget'ın boş hâli yan yana okunuyor.

## Koşum

```
flutter analyze && flutter test
./gradlew :app:testDebugUnitTest --tests "*StripRenderer*"
./gradlew :app:connectedDebugAndroidTest
```

## Kapsam dışı

- `SparkRenderer` ve `FlameRenderer`ın boş durumu — ikisinin girdisi sınava
  bağlı değil (maddenin kendi kapsam dışı notu).
- İzlerin açık temada görünmemesi (madde 44). Bu madde izin **rengine**
  dokunmuyor, yalnızca dolgunun çizilip çizilmediğine.
- Dart tarafı: `countdown_ring_painter.dart` bu kuralı zaten uyguluyor,
  şeridin uygulama içinde ikizi yok.

## Kabul

Emülatörde şerit widget'ı ana ekrana konup sınav seçilmemiş durumda çizdirilir:
çubukta soldaki kapak yok, iz baştan sona kesintisiz. Sınav seçilince dolgu
oranı kadar geri geliyor.
