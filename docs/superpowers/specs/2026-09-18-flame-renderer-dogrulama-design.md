# `FlameRenderer` doğrulaması — tasarım

ROADMAP madde 31. Madde 23'ten devredilen açık iş: Kotlin `FlameRenderer`
(`android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameRenderer.kt`)
üretim kodunda duruyor ama **hiçbir yerde çalıştırılmadı** ve birim testi yok.
Dart tarafı 2026-09-17'de cihazda on kademenin onunda da çizdirildi
(`.verify/tiers_all.png`); Kotlin tarafı kör nokta.

## Sorun

Kotlin `FlameRenderer` yalnızca gerçek bir ana ekran widget'ı yerleştirildiğinde
çalışıyor ve **widget'ı adb ile ana ekrana koymak mümkün değil** — `appwidget`
kabuk komutu yalnızca `grantbind` destekliyor, `cmd appwidget` yok. Yani madde
23'ün bıraktığı boşluk emülatör ekran görüntüsüyle kapanamıyor; çizim yolunu
kodla çağırmak gerekiyor.

`render` gerçek `Bitmap`/`Canvas`/`Paint`/`Shader` istiyor. Stub `android.jar`
bunların hepsinde `RuntimeException("Stub!")` atar, yani düz JVM testi yetmez:
ya Robolectric'in native grafik kipi ya da cihaz gerekiyor.

## Kod okunurken çıkan hata

Dart'ta şekil kutusu 64×98, gövde 44×86 ve **tabana yapışık** — tepede 12px hava
var, kıvılcımlar oraya çiziliyor (`Clip.none` sayesinde taşabiliyorlar da,
`lib/core/widgets/flame_widget.dart:186-266`).

Kotlin'de `bodyHeight = heightPx * tier.scale`, yani `scale == 1.0`da gövde
bitmap'in tamamını yiyor, `top = 0` oluyor ve kıvılcım döngüsündeki
`if (y > 0f)` koruması kıvılcımları **sessizce** atıyor. Üretim ölçüsünde
(`FlameWidgetProvider`: 60×64dp, ~157×168px):

| Kademe | merdivendeki `sparkCount` | gerçekte çizilen |
| ------ | ------------------------- | ---------------- |
| K6     | 2                         | 2                |
| K7     | 3                         | 3                |
| K8     | 3                         | **2**            |
| K9     | 4                         | **1** (tepeden kırpık) |
| K10    | 5                         | **0**            |

Mesale merdiveninin sözü "K6'dan sonra kıvılcımlar"; en tepedeki üç kademede
tutulmuyor. Hiç çalıştırılmamış kod olduğu için kimse görmemiş — maddenin var
olma sebebi bu.

## Kararlar

### 1. İki koşum evi, tek iddia gövdesi

Robolectric testi kalıcı ve cihazsız kapı; instrumented test bu maddenin
emülatör kanıtı. Aynı iddiaları iki dosyada tutmak ileride ayrışma demek,
o yüzden iddialar `src/sharedTest/kotlin` altında tek dosyada duruyor ve
`build.gradle.kts` bu dizini hem `test` hem `androidTest` kaynak kümesine
ekliyor:

```
src/sharedTest/kotlin/.../FlameRendererContract.kt    ← tüm iddialar, düz JUnit
src/test/kotlin/.../FlameRendererRobolectricTest.kt   ← @RunWith(RobolectricTestRunner) + @GraphicsMode(NATIVE)
src/androidTest/kotlin/.../FlameRendererDeviceTest.kt ← @RunWith(AndroidJUnit4)
```

`@GraphicsMode` Robolectric'e özel; sözleşme dosyasında değil koşucuda duruyor,
böylece `androidTest` classpath'ine Robolectric girmiyor.

### 2. Piksel sondası, altın görüntü değil

Bayt-bayt karşılaştırma Robolectric'in native grafiğiyle gerçek cihazın
grafik yığını arasında zaten ayrışır — iki koşum evi altın görüntüyle
uzlaşamaz. Onun yerine iddialar geometriyi **merdivene** bağlıyor; her kademe
için:

- bitmap istenen boyutta ve tamamen saydam değil (çizim gerçekten oldu),
- **ölçek:** merkez sütununda ilk opak piksel ≈ `heightPx * (1 - scale)`,
  kademeler arası monoton yükseliyor,
- **köz:** en alt satırda, gövdenin yuvarlatılmış dibinin dışında opak piksel
  ⇔ `emberBase`,
- **hâle:** gövdenin yanında, merkezden `bodyWidth * 0.7` uzaklıkta opak piksel
  ⇔ `haloOpacity > 0`,
- **kıvılcım:** beklenen `sparkCount` konumun hepsinde opak piksel,
  `sparkCount`'un bir fazlasında saydam.

Son iddia yukarıdaki hatayı yakalayan iddia.

### 3. Kıvılcımlar tepeden yukarı yığılmak yerine tepeden aşağı iniyor

```kotlin
val y = top + sparkRadius + bodyHeight * 0.08f * i
// önce: top - bodyHeight * 0.06f * i - sparkRadius
```

`x` değişmiyor (gövdenin iki yanında, `centerX ± bodyWidth * 0.6`). Yeni konum
her ölçekte kare içinde kalıyor; `y > 0f` koruması artık hiç tetiklenmiyor ama
ucuz olduğu için kalıyor.

**Gövde boyutuna dokunulmuyor.** Dart'ın 12px havasını Kotlin'e taşımak
(`bodyHeight = heightPx * scale * 86f / 98f`) tüm kademelerde alevi %12
küçültürdü ve K10'da yine 5 kıvılcımın 2'sine yer açardı — hem görsel regresyon
hem yarım çözüm. Kotlin zaten dosya başında belgeli bir sadeleştirme
("widget ölçeğine indirilmiş hâli"), Dart'la piksel paritesi hedef değil.

### 4. Emülatör kanıtı testin kendisinden çıkıyor

Cihaz testi on bitmap'i `getExternalFilesDir` altına PNG olarak döküyor;
`adb pull` ile `.verify/m31_k1..k10.png`. Ekran görüntüsü değil, `FlameRenderer`
çıktısının kendisi — kanıt zinciri doğrudan.

## Koşum

```
./gradlew :app:testDebugUnitTest            # cihazsız, kalıcı kapı
./gradlew :app:connectedDebugAndroidTest    # focussayac_verify AVD açık
```

Robolectric ilk koşumda `android-all` jar'ını indiriyor (~100MB); `flutter test`
zincirine girmiyor, Gradle'ın kendi görevi.

## Kapsam dışı

- Widget'ı ana ekrana adb ile yerleştirmek (hâlâ mümkün değil — madde 31 bu
  boşluğu yerleştirmeyle değil *testle* kapatıyor).
- Diğer renderer'lar: `RingRenderer`, `StripRenderer`, `SparkRenderer`.
- Dart ↔ Kotlin piksel paritesi.
- Kıvılcım geometrisini Dart'ın `bottom: 74 + 7i` / `left: 22 ± 13 + 1.5i`
  düzenine birebir çevirmek.

## Kabul

`FlameRenderer`ın on kademesi için çizim yolu iki koşum evinde de çalıştırılmış,
kıvılcım sayısı on kademede merdivenle birebir, emülatörden on PNG çekilmiş.
