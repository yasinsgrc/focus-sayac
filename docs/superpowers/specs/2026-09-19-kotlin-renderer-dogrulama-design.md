# Ring / Strip / Spark doğrulaması — tasarım

ROADMAP madde 39. Madde 31'in kapsam dışı bıraktığı iş: `FlameRenderer` için
kurulan **iki koşum evli sözleşme testi** kalıbı (`src/sharedTest` +
Robolectric NATIVE + instrumented) diğer üç Kotlin renderer'a uygulanmadı.

## Sorun

`RingRenderer`, `StripRenderer` ve `SparkRenderer` yalnızca gerçek bir ana ekran
widget'ı yerleştirildiğinde çalışıyor ve widget'ı adb ile ana ekrana koymak
mümkün değil (`appwidget` kabuk komutu yalnızca `grantbind` destekliyor). Yani
bu üç çizim yolu, ekran görüntüsüyle de kapanamayan bir kör nokta.

Kapsam bir "test borcu" gibi görünüyor ama madde 31 aynı boşluğa bakarken **hiç
çalıştırılmamış kodda gerçek bir hata** bulmuştu (üst kademelerde kıvılcımlar
sessizce atlanıyordu). Boşluk teorik değil.

Tek istisna `RingRenderer`: madde 33 ona bir Robolectric testi yazmıştı, ama
tek iddialık ve sözleşmesiz — cihazda hiç koşmuyor.

## Kararlar

### 1. Kalıp aynen madde 31'den

```
src/sharedTest/kotlin/.../{Ring,Strip,Spark}RendererContract.kt   ← iddialar, düz JUnit
src/test/kotlin/.../{Ring,Strip,Spark}RendererRobolectricTest.kt  ← @GraphicsMode(NATIVE)
src/androidTest/kotlin/.../{Ring,Strip,Spark}RendererDeviceTest.kt ← @RunWith(AndroidJUnit4)
```

`build.gradle.kts` `src/sharedTest/kotlin`i zaten iki kaynak kümesine de
ekliyor; yeni Gradle ayarı gerekmedi. Madde 33'ün iki iddiası
(`yayin baslangicinda koz lekesi yok`, `iki uc da yuvarlak kaliyor`)
`RingRendererContract`a taşındı — koşucu inceldi, iddia gövdesi tek yerde
kaldı ve artık cihaz da aynı sondaya bakıyor.

### 2. Altın görüntü değil; ölçüler üretimin ölçüsü

Robolectric'in native grafiği ile gerçek cihazın yığını bayt bayt uzlaşmaz.
Sondalar iki eksene bağlı, ikisi de tema niteleyicisinden bağımsız:

- **alfa** — iz `0x12`, kesikli çember `0x59`, çizilen yaylar/dolgular opak;
  `0x80` eşiği ikisini ayırıyor,
- **sıcaklık** (kırmızı − mavi) — halkanın gradyanı `RingRenderer`da düz hex,
  köz ise iki temada da sıcak (`#FFA35D00` / `#FFFFB03A`).

Bitmap ölçüleri sağlayıcıların `dp` sabitlerinden, `px()`in kestiği
~2.6× yoğunlukla: halka 273², şerit 630×15, sütun grafiği **iki** yerleşimde
(seri 220×68, panorama 367×57). İkisi de koşuyor, çünkü sütun genişliği karenin
oranından geliyor — aynı kod iki yerleşimde farklı geometri üretiyor ve
aşağıdaki hata tam oradan çıktı.

### 3. İddialar formülü değil **sözü** sınıyor

Renderer'ın hesabını teste kopyalamak testi düzeltmenin aynasına çevirirdi.
Onun yerine her iddia çizimin vaadine bağlı:

| Renderer | İddia |
| --- | --- |
| Ring | iz kesintisiz; yayın **kapladığı açı** = oran (merdiven, monoton); gradyan gökyüzünden köze; başlangıçta köz lekesi yok; iki uç yuvarlak; `muted` yay çizmiyor; günlük yay kesikli çemberde, oranı kadar ve yeşil; ortadaki yazı izin içinde |
| Strip | iz iki uç arasında kesintisiz; dolgunun ucu = `genişlik × oran` (merdiven, monoton); çok küçük oranda bir kapak kalıyor; gradyan accent'ten köze |
| Spark | yedi sütun, merkezleri yerinde; sütun yüksekliği / grafik = değer / en büyük değer; sıfır gün **ince** bir taban; bugün opak, geçmiş solgun |

### 4. Bulunan iki hata

**a) Sütun grafiğinin tabanı sütun genişliğine bağlıydı.**
`minHeight = radius * 2f`, `radius = barWidth * 0.26f` — yani boş günün tabanı
**yatay** eksenden geliyordu. Panorama yerleşiminde (140×22dp) sütunlar geniş,
kare alçak: taban grafiğin **%32'si** çıkıyor. Sonuç: 120 dakikalık bir haftada
20 dakikalık gün ile hiç odaklanılmamış gün **aynı** çiziliyordu — grafik
sessizce yanıltıyordu. Seri yerleşiminde de %16.

Düzeltme payı dikey eksene taşıyor: `minHeight = heightPx * 0.06f`. Taban hâlâ
var (boş hafta "veri yok" değil "sıfır"), ama bir günün odağı gibi görünmüyor.

**b) Halkanın kicker'ı uzun durum adlarında izin üstünden geçiyordu.**
Punto sabitti (`sizePx * 0.058f`). "GÜN KALDI" ve "BUGÜN" sığdığı için kimse
görmemiş; "HEDEF SEÇİLMEDİ" 238 px çiziliyor, o satırda izin iç kenarına kadar
kalan kiriş 183 px. Yazı halkanın stroke'unun üzerine biniyordu — üstelik
**yeni kullanıcının ilk gördüğü durum** bu.

Düzeltme `counterSizeFor`un rakama yaptığını kicker'a yapıyor: punto ölçülüp
kirişe sığacak kadar küçülüyor (`labelFitFor`). Ölçü karakter sayısından değil
metnin kendisinden geliyor — çeviri uzarsa da tutsun diye. Sığan etiketler hiç
küçülmüyor, yani yaygın durumda görünür değişiklik yok.

## Koşum

```
./gradlew :app:testDebugUnitTest            # cihazsız, kalıcı kapı
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true
```

İkinci bayrak şart: AGP koşum sonunda iki APK'yı da kaldırıyor ve uygulamaya
özel dış dizin onunla siliniyor, yani test yeşil ama PNG yok.

## Kapsam dışı

- Widget'ı ana ekrana adb ile yerleştirmek (hâlâ mümkün değil).
- Dart ↔ Kotlin piksel paritesi.
- `StripRenderer`ın `muted` davranışı: sınav seçilmemişken oran 0 gidiyor ve
  şerit boş iz yerine bir kapakla duruyor. Halka o durumda yayı hiç çizmiyor,
  yani ikisi tam aynı dili konuşmuyor; ama kapak grafiğin %2.4'ü ve "yüzde
  sıfır" okuması da doğru bir okuma. Sözleşme davranışı **sabitliyor**, karar
  ayrı bir maddeye bırakıldı.
- Sağlayıcıların `RemoteViews` tarafı (metin, tıklama hedefi, yenileme) —
  bu madde yalnızca çizim yollarını kapsıyor.

## Kabul

Üç renderer'ın çizim yolu iki koşum evinde de çalıştırılmış, bulunan iki hata
düzeltilmiş, emülatörden çıktı PNG'leri çekilmiş.
