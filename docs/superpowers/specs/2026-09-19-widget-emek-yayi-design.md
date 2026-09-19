# Widget'ın halkasında emek yayı — tasarım

ROADMAP madde 41. Madde 27'nin kapsam dışı bıraktığı iş: geri sayım halkasının
**ikinci ekseni** (haftalık hedefin emek yayı) yalnızca Ekran 02'ye eklendi,
ana ekran widget'ının Kotlin ikizine eklenmedi.

## Sorun

Madde 27'nin şikâyeti şuydu: sınava 300 gün kalan kullanıcıda halka aylarca
~%25'te duruyor — geçen zamanı gösteriyor, harcanan emeği değil. Çözüm zaman
yayının yanına ikinci bir yay koymaktı.

`RingRenderer.kt` o çözümü hiç almadı. Bugün widget'ta iki yay var ama ikincisi
başka bir eksen: günün döngüsü (bugün kaç pomodoro / 4, madde 28). Yani:

| | zaman yayı | emek yayı | gün yayı |
| --- | --- | --- | --- |
| Ekran 02 (`CountdownRingPainter`) | r=130 | r=119 | — |
| Widget (`RingRenderer`) | r=130 | **yok** | r=112 |

Aynı halka iki yüzeyde iki farklı şey anlatıyor. Üstelik widget'ın çizdiği tek
"sınav" yayı tam da madde 27'nin ölü aralık dediği yay: ana ekranda duran,
aylarca kıpırdamayan bir gösterge.

## Kararlar

### 1. Payload'a iki ham sayı; oran Kotlin'de

Yeni anahtarlar `weeklyGoalSeconds` ve `weeklyFocusedSeconds` —
`WeeklyGoalProgress`in iki alanının birebir karşılığı. Oran, "hedef kapalı" ve
"hedef doldu" kararları Kotlin tarafında aynı formüllerle türetiliyor.

Neden oran değil de iki operand: `WeeklyGoalProgress` bu üç şeyi de tek yerden
türetiyor (`ratio`, `isOff`, `isReached`) ve üçü tek bir kırpma kuralına bağlı.
Oranı hazır göndermek Kotlin'in `isReached`i ayrıca bilmesini gerektirirdi
(oran 1.0 kırpılmış, hedefi aşmakla tam tutturmak aynı sayı) — yani ikinci bir
anahtar yine gerekirdi, ama bu kez türetilmiş olanı.

Neden `weeklyMinutes`i (zaten payloadda olan 7 günlük liste) Kotlin'de toplamak
değil: pencere aynı pencere, ama liste gün başına `saniye ~/ 60` taşıyor.
Bugün seanslar tam dakika olduğu için toplam tutuyor; olmadığı gün widget ile
Ekran 02 sessizce farklı bir yay çizerdi. Madde 27'nin "ikisi aynı örnekten
besleniyor, ayrışamazlar" güvencesi ancak sayı aynı sayı olursa taşınır.

Bu, `FocusWidgetSnapshot.kt`in "türetilmiş değer Dart'tan okunmaz" kuralıyla
çelişmiyor. O kuralın gerekçesi **bayatlama**: kalan gün ve meşale kademesi
zaman geçtikçe yanlışlaşır, o yüzden her çizimde yeniden hesaplanır.
`weeklyFocusedSeconds` zamanla değişmiyor — yalnızca bir seans tamamlanınca
değişiyor, o da zaten yeni bir push tetikliyor.

### 2. Yayın geometrisi Ekran 02'den birebir

r=119, kalınlık 4, başlangıç 12 yönü, yuvarlak uç. Prototipin boş bandına
oturuyor (zaman izinin iç kenarı 125.5, kesikli çember 112) — madde 27'nin
ölçüsü, yeniden ölçülmedi. Zaman yayının yarıçapı, kalınlığı ve gradyanı
değişmiyor.

Altındaki soluk iz `fillSubtle` (dış telin rengi, `0x17FFFFFF`). Halkanın
izleri `RingRenderer`da düz hex, palet değil — madde 39'un sözleşmesi bunu
temadan bağımsız sayıyor ve sondalar buna göre kurulu.

### 3. Halka üç yaylı oluyor — gün yayı kalıyor

Madde 28 günün döngüsü yayını "widget'ı bir geri sayımdan bir alışkanlık
hatırlatıcısına çevirmek" için koymuştu; emek yayı onun yerine geçmiyor, çünkü
ikisi farklı soruların cevabı (bugün ne yaptım / bu hafta hedefin neresindeyim).
Yarıçap paritesi Ekran 02 ile korunuyor, yani üçüncü yay yeni bir bant açmıyor.

Bedeli gün yayı (109.5–114.5) ile emek yayı (117–121) arasındaki 2.5 birimlik
boşluk: 104dp'de ~2 px. Emülatörde bakılacak; sıkışıksa çözüm gün yayını
inceltmek, emek yayını yerinden oynatmak değil (o yarıçap Ekran 02'nin).

### 4. `muted` emek yayını almıyor

Sınav seçilmemişken ve sınav geçtiğinde zaman yayı çizilmiyor, emek yayı
çiziliyor. Gün yayının gerekçesiyle aynı: geri sayım durmuş olabilir ama odak
birikmeye devam ediyor ve bu yayın anlattığı şey sınav değil, hafta.

### 5. Hedef kapalıyken yay **da izi de** yok

`effortRatio` `0.0` değil `null`. Boş bir yay "hedefinin %0'ındasın" derdi, oysa
kullanıcının koyduğu bir hedef yok — `CountdownRingPainter`ın ve
`_WeeklyGoalRow`un kararı aynen taşınıyor.

### 6. Kicker'ın sığma kirişi iç sınıra iniyor

Madde 39 uzun durum adlarının izin üstüne binmesini `labelFitFor` ile çözmüştü;
kiriş **zaman izinin** iç kenarından (125.5) ölçülüyordu. Halkanın en içteki
dolu yayı artık emek yayı, yani yeni sınır 117 — Dart tarafında
`CountdownRingPainter.innerContentRadius` zaten bu sayıyı veriyor ve madde 32'nin
meta satırı oradan okuyor.

Sınır koşulsuz iniyor, hedefin açık olmasına bağlanmıyor: punto hedefe göre
değişseydi kullanıcı ayarı açıp kapattığında widget'ın yazısı boy değiştirirdi.

## İddialar (`RingRendererContract`)

Madde 39'un kalıbı: gövde `src/sharedTest`te tek yerde, Robolectric NATIVE ve
cihaz koşumu aynı dosyayı derliyor. Yeni iddialar:

| # | İddia |
| --- | --- |
| 9 | Emek yayı kendi yarıçapında, **kapladığı açı** = oran (merdiven, monoton) |
| 10 | Hedef kapalıyken o yarıçapta hiçbir şey yok — iz bile |
| 11 | Hedef dolunca ton közden naneye dönüyor (yeşil, sıcaklık negatif) |
| 12 | Zaman yayı emek yayından etkilenmiyor: üç emek durumunda da aynı oran |

8. iddia (`ortadaki yazi ize girmiyor`) yeni sınıra bağlanıyor.

## Koşum

```
flutter analyze && flutter test
./gradlew :app:testDebugUnitTest --tests "*RingRenderer*"
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true
```

## Kapsam dışı

- `StripRenderer`ın haftalık hedefi — şeridin kendi dili var, ikinci bir eksen
  orada aynı boş bandı bulmuyor.

`PanoramaWidgetProvider` **kapsam içinde**, çünkü halkayı aynı `RingRenderer`
ile çiziyor (84dp): orada `effortRatio = null` geçmek maddenin kapattığı
ayrışmayı bu kez iki widget arasında kurardı.
- Widget'ta hedefe kalan sürenin **metni** (Ekran 02'de `_WeeklyGoalRow` var);
  halka widget'ının alt satırı zaten dolu (`12 gün · 3 pomodoro`).
- Dart ↔ Kotlin piksel paritesi (madde 39'dan beri kapsam dışı).

## Kabul

Emülatörde halka widget'ı yerleştirilip hedef kapalı / hedefe giderken / hedef
dolmuş üç durum çizdirilir; emek yayı Ekran 02'dekiyle aynı oranda ve aynı
tonda, zaman yayı üç karede de kıpırdamadan.
