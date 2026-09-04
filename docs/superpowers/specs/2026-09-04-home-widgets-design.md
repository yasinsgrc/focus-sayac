# FocusSayaç — Ana Ekran Widget'ları (Tasarım)

Tarih: 2026-09-04
Durum: Onaylandı

## Amaç

Kullanıcının seçili sınav geri sayımını ana ekranda, uygulamayı açmadan
göstermek. Beş ayrı widget; her biri farklı bir mantık ve farklı bir görsel
hikâye taşır. Hepsi `Exam.isActive = true` olan sınavı gösterir.

## Kapsam dışı

- iOS (projede `ios/` dizini yok, Android-only).
- Widget içinden pomodoro duraklat/bitir (foreground service gerektirir).
- Widget'a özel tema/renk seçimi.

## Mimari

Tek yönlü akış: Dart yazar, Kotlin okur ve çizer.

```
activeExamProvider  ─┐
focusStatsProvider  ─┼─> HomeWidgetSnapshot ─> HomeWidget.saveWidgetData
streakProvider      ─┤     (saf model)              │
todayFocusStats     ─┘                              ▼
                              SharedPreferences (HomeWidgetPlugin)
                                                    │
                                     BaseFocusWidgetProvider (Kotlin)
                                       • gün/saat/oran targetUtcMillis'ten
                                         yeniden hesaplanır
                                       • RemoteViews + Canvas bitmap
```

### Bayatlamama garantisi

Dart **kalan günü yazmaz**, hedef zaman damgasını (`targetUtcMillis`) yazar.
Gün/saat/oran her çizimde Kotlin tarafında yeniden hesaplanır. Uygulama
haftalarca açılmasa bile widget doğru sayıyı gösterir.

`progressRatio` formülü `lib/domain/countdown/countdown_math.dart` ile birebir
aynıdır: `clamp(1 - days/400, 0.06, 1)`.

### Payload şeması

`HomeWidget.saveWidgetData` ile yazılan düz anahtarlar:

| Anahtar | Tür | Örnek |
|---|---|---|
| `hasActiveExam` | bool | `true` |
| `examName` | String | `YKS 2026` |
| `examSubtitle` | String? | `Temel Yeterlilik` |
| `targetUtcMillis` | int (epoch ms, UTC) | `1782000000000` |
| `accentHex` | String (`#AARRGGBB`) | `#FFFFB03A` |
| `streak` | int | `12` |
| `todayMinutes` | int | `75` |
| `weeklyMinutes` | String (7 sayı, virgülle) | `0,25,50,25,75,100,75` |
| `sessionActive` | bool | `false` |
| `updatedAtMillis` | int (epoch ms, UTC) | `1780000000000` |

### Dart dosyaları

| Dosya | Sorumluluk |
|---|---|
| `lib/domain/widgets/home_widget_snapshot.dart` | Saf model + `toPayload()`. IO yok, test edilebilir. |
| `lib/services/widgets/home_widget_service.dart` | Payload'ı yazar, beş provider'ı günceller. |
| `lib/services/widgets/home_widget_sync.dart` | Riverpod dinleyicisi; kaynaklar değişince servisi tetikler. |
| `lib/services/widgets/widget_launch_handler.dart` | Widget tıklaması → `go_router` yönlendirmesi. |

Tetikleyiciler: uygulama açılışı, resume, aktif sınav değişimi, pomodoro
seansı tamamlanışı, ayar değişimi.

### Kotlin dosyaları

`android/app/src/main/kotlin/com/focussayac/focussayac/widget/`

| Dosya | Sorumluluk |
|---|---|
| `FocusWidgetSnapshot.kt` | Prefs okur; `daysLeft`, `hoursLeft`, `progressRatio`, `state` türetir. |
| `FocusPalette.kt` | `AppColors.dark()` tokenlarının aynası. |
| `RingRenderer.kt` | `CountdownRingPainter` portu — hairline dış çember, track, SweepGradient yay, kesikli iç çember, ortada büyük gün rakamı. |
| `SparkRenderer.kt` | 7 günlük mini bar bitmap. |
| `StripRenderer.kt` | Yatay doluluk çubuğu bitmap. |
| `BaseFocusWidgetProvider.kt` | Snapshot yükleme, durum seçimi, PendingIntent kurulumu. |
| `RefreshScheduler.kt` | Saat başına hizalı `AlarmManager`. |
| `FocusWidgetRefreshReceiver.kt` | `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED`, `DATE_CHANGED`, alarm. |
| `*WidgetProvider.kt` (5 adet) | Her widget'ın layout'u ve veri bağlaması. |

Büyük gün rakamı bitmap içinde çizilir: `letterSpacing -0.045em` ve tabular
figures'ı RemoteViews `TextView` üzerinden garanti etmek mümkün değil.
Diğer metinler RemoteViews `TextView` + `res/font/` kaynakları.

`updatePeriodMillis="0"` — sistemin güvenilmez 30 dakikalık döngüsü yerine
kendi saat başı alarmımız kullanılır.

## Beş widget

| # | Ad | Boyut | Gösterdiği | Dokunma |
|---|---|---|---|---|
| 1 | Halka | 2×2 (110×110dp) | Gün rakamı + accent ilerleme halkası + sınav adı | `/countdown` |
| 2 | Şerit | 4×1 (250×40dp) | Sınav adı + gün/saat + doluluk çubuğu | `/countdown` |
| 3 | Seri | 2×2 | Streak + bugünkü odak dakikası + 7 günlük spark | `/stats` |
| 4 | Hızlı Odak | 4×2 (250×110dp) | Sınav özeti + tek eylem butonu | `/focus?autostart=1` |
| 5 | Panorama | 4×2 | Halka + sınav tarihi + streak + spark | `/countdown` |

Hepsi `resizeMode="horizontal|vertical"`; API 31+ için `previewLayout`
(gerçek layout önizlemesi) ve `description`.

## Durum makinesi

Her widget dört durumdan birini çizer:

| Durum | Koşul | Görünüm | Dokunma |
|---|---|---|---|
| `NO_EXAM` | aktif sınav yok | Nötr palet, "Sınav seç" | `/countdown` (seçici açılır) |
| `TODAY` | `daysLeft == 0`, hedef gelecekte | Ember vurgu, "BUGÜN" | `/countdown` |
| `EXPIRED` | hedef geçmişte | Solgun, "Sınav geçti" | `/exam-expired` |
| `COUNTING` | normal | Accent rol rengi | widget'a göre |

Hızlı Odak widget'ı ek olarak: seans zaten aktifse buton "Devam et" olur ve
`/focus` açar (yeni seans başlatmaz).

Sayaç asla negatife düşmez — `remainingDuration` Dart'ta, `coerceAtLeast(0)`
Kotlin'de.

## Metinler

Android widget'ları ARB okuyamaz; widget metinleri
`android/app/src/main/res/values/strings.xml` içinde yaşar. ARB'de karşılığı
olan ifadeler ("GÜN KALDI", "BUGÜN") birebir aynı kelimelerle kopyalanır ve
`strings.xml`'e ARB'ye geri işaret eden bir yorum düşülür.

## Test

| Test | Kapsam |
|---|---|
| `test/domain/widgets/home_widget_snapshot_test.dart` | Gün/saat/oran, null sınav, geçmiş sınav, bugün sınavı, payload anahtarları |
| `test/services/widgets/home_widget_service_test.dart` | Sahte platform kanalı: doğru anahtarlar yazılıyor mu, beş provider da güncelleniyor mu |
| `test/android/focus_palette_sync_test.dart` | `focus_colors.xml` parse edilip her hex `AppColors.dark()` ile karşılaştırılır |

Palet senkron testi, seçilen mimarinin tek zayıf noktasını (palet iki yerde
tutuluyor) otomatik yakalar.

## Riskler

1. **Kotlin tarafında birim testi yok.** Projede JVM test altyapısı kurulu
   değil; kurmak kapsamı ciddi büyütür. Doğrulama emülatörde görsel yapılır.
2. **`progressRatio` iki yerde.** Formül tek satır; sapma görsel olarak hemen
   fark edilir. Ayrı doğrulama mekanizması kurulmuyor (YAGNI).
3. **`home_widget` eklentisi release derlemesini etkileyebilir.** Faz sonunda
   `flutter build apk --release` ile doğrulanır.

## SPEC.md ihlalleri

İki kural bilinçli olarak kırılıyor:

- §0.3 "Prototipte olmayan ekran, buton veya özellik ekleme" — widget'lar
  tanım gereği prototipte olmayan yeni bir yüzey.
- §0.7 "kullanıcı metinleri yalnızca ARB'den" — Android widget'ları ARB
  okuyamaz.

Gerekçe `DECISIONS.md`'ye yazılır, `SPEC.md`'ye widget bölümü eklenir.
