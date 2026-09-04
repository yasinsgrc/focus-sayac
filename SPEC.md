# MASTER PROMPT v3 — FocusSayaç: DİNAMİK KATMAN

> Tasarım **dondurulmuştur**. Bu doküman, `design/FocusSayac Prototip v2.dc.html` içindeki
> statik ekranların arkasına çalışan mantığı takmak içindir.
> Proje köküne `SPEC.md` olarak koyulmuştur. Repo: `yasinsgrc/focus-sayac`.

---

## 0. ROL VE KURALLAR

Sen Senior Flutter Mimarısın. `FocusSayac Prototip v2.dc.html` prototipini Flutter'a
**birebir** taşıyacak ve arkasına çalışan dinamik katmanı yazacaksın.

**Tasarım dondurulmuştur:**
1. Prototipteki hiçbir renk, boşluk, yazı tipi, köşe yarıçapı, ikon veya yerleşimi
   değiştirme. "Daha iyi olur" diye düzeltme yapma.
2. Görsel sonuç prototiple aynı olmak zorunda; **uygulama tekniği** farklı olabilir
   (BÖLÜM 6). Aynı görünen ama daha ucuz çalışan bir çözüm serbesttir, farklı görünen çözüm değildir.
3. Prototipte olmayan ekran, buton veya özellik **ekleme**.
4. Yeni metin yazma. Prototipteki Türkçe metinler birebir ARB'ye taşınır.

**Genel kurallar:**
5. Bana soru sorma. Belirtilmeyen detayda kendi kararını ver, `DECISIONS.md`'ye tek
   cümle gerekçesiyle yaz, devam et.
6. `TODO`, `FIXME`, sözde kod yasak. Her dosya derlenebilir olacak.
7. Kod/değişken İngilizce, kullanıcı metinleri **yalnızca ARB'den**. Kodda hard-coded Türkçe yasak.
8. Faz faz ilerle (BÖLÜM 8). Her faz sonunda `flutter analyze` → 0 hata/0 uyarı → tek commit.
9. Feature modülleri birbirini import edemez; iletişim `core/` ve `domain/` üzerinden.

**Çakışma önceliği:** Prototip v2 → bu doküman → senin kararın.
`FocusSayac Prototip.dc.html` (v1) **eskidir, kullanma.** v2 esastır.

---

## 1. TEKNİK YIĞIN (sabit)

Flutter 3.32+ / Dart 3.8+ · Material 3 · **Android-first** (iOS sonraki faz, macOS gerekir)

| Katman | Paket |
|---|---|
| State | `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` |
| Router | `go_router` 14+ |
| Model | `freezed` + `json_serializable` |
| DB | `drift` |
| Bildirim | `flutter_local_notifications` + `timezone` |
| Ekran uyanık | `wakelock_plus` |
| Reklam | `google_mobile_ads` + UMP Consent SDK |
| Satın alma | `in_app_purchase` (v1'de UI pasif — bkz. 7.3) |
| Paylaşım | `share_plus` + `gal` |
| Lokalizasyon | `flutter_localizations` + `intl` + ARB (tr varsayılan) |
| Test | `flutter_test` + `mocktail` |

minSdk 23 / targetSdk 35. **Yasak:** GetX, Provider, singleton servisler, backend, hesap, cloud sync.

---

## 2. TASARIM TOKENLARI (prototipten çıkarılmış — birebir)

`lib/core/theme/app_colors.dart` içinde `ThemeExtension<AppColors>` olarak tanımla.
Widget'larda ham hex veya `Colors.*` **yasak**.

```
bg          #0b0c14      text         #f6f7ff
ember       #ffb03a      ember-dim    #8a4f14      ember-deep  #33200c
mint        #4fe0b4      mint-deep    #0d3a31
rose        #ff6a86      rose-deep    #3d1420
sky         #63b4ff      sky-deep     #10283f

neutral-300 #cfd3e5   neutral-400 #b2b6ca   neutral-500 #9397ab
neutral-600 #75798c   neutral-700 #595d6c   neutral-800 #3f424d   neutral-900 #292b31
accent-200  #e7e5fe   accent-300 #d2cefd   accent-400 #b5abfc   accent-900 #2b2741

surface-card  rgba(30,32,48,.82)
divider       rgba(255,255,255,.08)
shadow-md     0 0 0 1px #595d6c, 0 6px 18px rgba(0,0,0,.55)
chrome-gradient  #f6f7ff → #b5abfc 34% → #63b4ff 52% → #ffb03a 78% → #fff
```

**Renk ROL taşır — bunu bozma:**
`ember` = ateş, seri, aktif odak · `mint` = tamamlanan iş, başarı ·
`rose` = iptal, risk, uyarı · `sky` = veri, istatistik · `accent (mor)` = ikincil vurgu, izin/bilgi

Spacing: 2.8 / 5.6 / 8.4 / 11.2 / 16.8 / 22.4 px (yoğunluk 0.70×, prototipten).
Radius: sm 4 · md 8 · lg 14 · kart 22 · telefon çerçevesi 46 · chip 999.

**Fontlar** — üçü de `assets/fonts` altına, **subset edilerek** paketlenir (hepsi OFL):
- `Space Grotesk` (400/500/600/700) → başlıklar, `letter-spacing: -.045em`
- `Michroma` (400, yalnız büyük harf + rakam subset) → kicker/etiket, `letter-spacing: .26em`, uppercase
- `Inter` (400/500/600) → gövde

Sayaç rakamlarında `FontFeature.tabularFigures()` **zorunlu**.

---

## 3. BINDING HARİTASI — İŞİN ÖZÜ

Prototip dinamik alanları `{{ }}` ile işaretlemiş. Her birinin veri kaynağı aşağıda.
**Prototipteki sabit sayılar (132, 42 SAAT, %86, 6 gün seri, 3/7) demo verisidir — hiçbiri koda girmez.**

### Ekran 01 — Karşılama + izinler
| Prototip | Kaynak / davranış |
|---|---|
| `9:41` durum çubuğu | Gerçek sistem çubuğu; prototipteki sahte çubuğu **çizme** |
| "İZİN VER VE BAŞLA" | `POST_NOTIFICATIONS` → `SCHEDULE_EXACT_ALARM` sırayla iste |
| "Şimdi değil" | İzinsiz devam; uygulama tam çalışır, ilgili ekranda kapatılabilir banner |
| — | UMP Consent akışı burada, ilk reklam isteğinden önce |
| — | Bitişte `onboardingCompleted = true` |

### Ekran 02 — Geri sayım
| Binding | Kaynak |
|---|---|
| `{{ examLabel }}` | `activeExam.name` |
| `{{ days }}` | `daysTo(examDate)` — UTC hesap, `Europe/Istanbul` gösterim |
| `14 : 06 : {{ secs }}` | Kalan saat/dakika/saniye |
| `{{ examDateText }}` | Biçimli tarih + "resmî takvimden doğrula" notu sabit kalır |
| Dairesel ilerleme | `ratio = clamp(1 - days/400, 0.06, 1)` — **prototipin formülü**, `CustomPainter`, `C = 2πr`, r=130 |
| "6 gün seri" | `streakProvider` |
| "1 SA 15 DK" | Bugünün toplam odak süresi |
| "Hedefe 1 pomodoro kaldı — serin 7'ye çıkar." | Hesaplanan; `streak + 1` ve bugünkü seans sayısına göre |
| `{{ e.name/sub/days }}` | `exams` listesi (sheet) |
| "Kendi sınavımı ekle" | → Ekran 11 |
| `banner 320×50` | Gerçek AdMob adaptive banner |
| `sheetOpen` | Sınav seçici modal bottom sheet durumu |

Tarihi geçmiş sınav seçiliyse → **Ekran 08**. Sayaç asla negatife düşmez.

### Ekran 03 — Odak seansı
| Binding | Kaynak |
|---|---|
| `ODAK 3/4` | `completedInCycle`/4 — 4 noktalı ilerleme satırı da buna bağlı |
| `{{ focusClock }}` | `startedAt + planned - now()` (BÖLÜM 5.1) |
| `{{ phaseLabel }}` | Durum makinesi fazı |
| `{{ hintLine }}` | Çalışırken/duraklıyken farklı; prototipteki iki metin |
| `reklam gizli` | Banner bu ekranda **yüklenmez** (gizlenmez — hiç istenmez) |
| Meşale | `progress` 0→1 ile büyür; duraklıyken gri (BÖLÜM 5.4) |
| Dairesel halka | `FC = 2π×135` — prototipin sabiti |
| İptal | → Ekran 10 |

### Ekran 04 — Rozetler
| Binding | Kaynak |
|---|---|
| `3/7` | `unlockedCount`/7 |
| `{{ b.name }}` `{{ b.rule }}` | Statik katalog **kodda**; DB yalnızca `badgeKey, unlockedAt` |
| Kilitli görünüm | `unlockedAt == null` |
| `unlockOpen` + `{{ unlockName/unlockRule }}` | Rozet detay/açılış dialogu |
| "BAŞARI KARTINI OLUŞTUR" | → Ekran 05 |

### Ekran 05 — Başarı kartı
| Binding | Kaynak |
|---|---|
| `{{ cardTag }}` `{{ cardBig }}` `{{ cardLine1 }}` `{{ cardLine2 }}` | Bugünkü odak + kalan gün + seri |
| `{{ t.name }}` | `GECE MEŞALESİ` / `MİNİMAL SAYAÇ` / (3. şablon) — üçü de v1'de ücretsiz |
| Alt imza | `focussayaç · Google Play` — üç şablonun da altında, şablonun vurgu renginde. (Eskiden filigran yoktu; Instagram paylaşım metnini yok saydığı için linkin görselin içinde de durması gerekti) |
| PAYLAŞ / Kaydet | `share_plus` / `gal` |
| Paylaşım metni | Kartın `shareHeadline`'ı + `kPlayStoreUrl`, `ShareParams.text` olarak — hedef uygulama metni düşürebilir, alt imza bunun yedeği |
| `1080 × 1920 png` | `RenderRepaintBoundary`, `pixelRatio = 1080 / kartMantıksalGenişlik` |

### Ekran 06 — İstatistik
| Binding | Kaynak (hepsi `PomodoroSession` üzerinde SQL — agregat tablo yok) |
|---|---|
| `42 SAAT` | Kümülatif odak |
| "günlük ortalama 1 sa 48 dk" | Son 7 gün ortalaması |
| `{{ d.val }}` `{{ d.day }}` | 7 günlük bar chart — `CustomPainter`, `sky` renginde |
| `11 GÜN` | En uzun seri |
| `%86` | Tamamlanma oranı — `mint` |
| "En verimli aralığın 20:00–22:00 — tamamlanma %94" | Saat kovalarına göre hesaplanır |
| `banner 320×50` | AdMob |

### Ekran 07 — Ayarlar
`{{ sliders }}` → Odak / Kısa mola / Uzun mola (varsayılan 25/5/15; odak 5–90, mola 1–30).
`{{ settings }}` → Bildirimler, Ses, Titreşim, Sınav seçimi, "Gün 04:00'te başlar" bilgi satırı,
Hakkında, Gizlilik Politikası, Uygulamayı Değerlendir (`in_app_review`, 3. tamamlanan seanstan sonra bir kez),
Verileri sıfırla (onaylı).
"Reklamları kaldır · **yakında**" → prototipteki gibi **pasif** görünür (bkz. 7.3).

### Ekran 08 — Sınav tarihi geçti
Otomatik yönlenir. "Odak geçmişin ve rozetlerin korunur." metni **doğru olmak zorunda** — hiçbir veri silinmez.
"YENİ SINAV SEÇ" → Ekran 02'nin sheet'i.

### Ekran 09 — Mola
| Binding | Kaynak |
|---|---|
| `KISA MOLA` / uzun mola | Döngü konumu (4. sonrası uzun) |
| `3. pomodoro bitti` | `completedInCycle` |
| `03:18` | Mola geri sayımı, aynı wall-clock mantığı |
| "molada dene" ipuçları | Statik katalog, ARB'de; her molada rastgele 2 tanesi |
| **`5 dk ekle`** | Mola `endAt`'ini +5 dk kaydırır, bildirimi yeniden kurar, bir molada **en fazla 2 kez** |
| `ODAĞA DÖN` | Molayı erken bitirir |
| `interstitial · 3 pomodoroda 1` | Mola **başlangıcında** tetiklenir (bkz. 7.2) |

### Ekran 10 — Seans iptal onayı
| Binding | Kaynak |
|---|---|
| `09:24` | O anki kalan süre |
| "6 günlük serin risk altına girer" | Bugün başka tamamlanmış seans **yoksa** gösterilir; varsa seri risk altında değildir → metni gösterme |
| "15 dakika 36 saniye kaldı" | Molaya kalan gerçek süre |
| DEVAM ET / Seansı iptal et | İptal → seans `completed = false` yazılır, rozet/seri sayılmaz |

### Ekran 11 — Özel sınav ekleme
Alanlar: sınav adı, oturum etiketi (opsiyonel), tarih, saat (varsayılan 10:00), **vurgu rengi**, canlı önizleme.
Vurgu rengi paleti: `ember / mint / rose / sky / accent-400` — serbest renk seçici **yok**.
Kayıt: `isPreset = false`, kullanıcı sınavı her zaman preset'lerden önceliklidir.

### Ekran 12 — Bildirimler (kilit ekranı)
Bu bir ekran değil, **bildirim metin şartnamesidir.** Dört tip, metinler birebir ARB'ye:

| Tip | Başlık | Gövde | Tetik |
|---|---|---|---|
| Seans bitişi | Seans tamamlandı | 25 dakika odak bitti. Meşalen büyüdü — 5 dakika mola vakti. | `zonedSchedule`, seans başında kurulur |
| Seri riski | Serin risk altında | 6 günlük seri için bugün 1 pomodoro yeter. Gün 04:00'te kapanıyor. | Her gün **21:00**, yalnızca bugün seans yoksa ve seri ≥1 ise |
| Rozet | Yeni rozet: {ad} | {kural açıklaması} Başarı kartını paylaş. | Rozet açıldığında |
| Kalıcı | Odak · {n}. pomodoro | — | Seans sürerken `ongoing: true`, `autoCancel: false` |

**Kalıcı bildirim notu:** Foreground service kullanma. `ongoing` bayraklı normal bildirim
yeterlidir; **canlı saniye güncellemesi yapma** (foreground service gerektirir ve pil yakar).
Bildirim seans başında kurulur, bitince iptal edilir. Bu kararı `DECISIONS.md`'ye yaz.

---

## 4. VERİ MODELİ (drift)

```
Exam             id, name, subtitle, dateUtc, timeOfDay, accentRole, isPreset,
                 isActive, source, verifiedAt
PomodoroSession  id, examId, type(focus|shortBreak|longBreak), startedAt,
                 completedAt, plannedDurationSec, completed, breakExtensions
UserBadge        badgeKey, unlockedAt
AppSettings      (tek satır) focusMinutes(25), shortBreakMinutes(5), longBreakMinutes(15),
                 notificationsEnabled, soundEnabled, hapticEnabled, isPremium(false),
                 selectedTemplateIndex, activeExamId, onboardingCompleted, streakReminderEnabled
```

`schemaVersion = 1`, `MigrationStrategy.onCreate` → 4 preset sınav + varsayılan `AppSettings` satırı.

**Sınav tarihi kaynağı — üç katman, bu öncelikle:**
1. Kullanıcı sınavı (`isPreset = false`)
2. Uzaktan JSON override — HTTPS GET, 24 sa cache, salt-okunur, kullanıcı verisi gönderilmez.
   Hata/ağ yoksa **sessizce** 3'e düş, kullanıcıya hata gösterme.
3. `assets/data/exam_dates.json` — ilk açılışta seed

Her kayıtta `source` + `verifiedAt`. JSON başına `_note`: tarihler resmî takvimden doğrulanmalı.
**Tarihleri `.dart` dosyasına gömme.**

---

## 5. DİNAMİK MOTORLAR

### 5.1 Zaman — tek kural
Kalan süre **asla** azalan sayaçtan okunmaz. Her zaman `startedAt + planned - DateTime.now()`.
- UI tazelemesi `Ticker` ile; uygulama arka plandayken durur, öne gelince yeniden hesaplanır.
- Aktif seans `shared_preferences`'a yazılır, cold start'ta kurtarılır.
- Tüm hesap UTC, gösterim `Europe/Istanbul`.
- Cihaz saati geriye alınırsa: negatif kalan süre → seans anında tamamlanmış sayılmaz, `completed = false` ile kapatılır.

### 5.2 Durum makinesi (`freezed` sealed union)
`idle → focusRunning → focusPaused → focusCompleted → breakRunning → breakPaused → breakCompleted → idle`
Döngü: 4 odak → 1 uzun mola. `ODAK 3/4` göstergesi ve 4 nokta buna bağlı.
Faz geçişlerinde `HapticFeedback.mediumImpact()` (ayarlardan kapatılabilir).

### 5.3 Seri (`streak_calculator.dart`, saf fonksiyon)
Gün sınırı **04:00 TSİ** — prototipin bildirim metniyle uyumlu ("Gün 04:00'te kapanıyor").
Seri = ≥1 tamamlanmış odak seansı olan ardışık gün sayısı; bugün veya dün biten seri canlıdır.

### 5.4 Rozetler (`badge_rules.dart`, saf fonksiyonlar, IO yok)
İlk Kıvılcım (ilk pomodoro) · Odak Meşalesi (günde 4) · Sabah Yıldızı (08:00 öncesi başlayan) ·
Gece Nöbeti (23:00 sonrası başlayan) · Haftalık Seri (7 gün) · Maraton (günde 8) ·
100 Saat Kulübü (kümülatif 100 sa).
Yalnızca başarıyla açılır, asla satın almayla. Açılışta `HapticFeedback.heavyImpact()`.

### 5.5 Meşale
`progress` 0→1 ile alev büyür. Duraklıyken `ColorFiltered` ile doygunluk 0.
Prototipteki `flick` keyframe'i (scale/translateY/skewX, 0→33→66→100) `AnimatedBuilder` +
`Transform` ile birebir uygulanır — **Lottie gerekmez**, CSS keyframe'i zaten Flutter transform'una birebir çevrilir.

---

## 6. PERFORMANS — GÖRÜNÜM AYNI, TEKNİK FARKLI

Prototipte 29 `blur()`, 15 `backdrop-filter`, 61 animasyon, 12 sonsuz `aurora` var.
CSS'te bunlar GPU'da ucuz; Flutter'da `BackdropFilter`/`ImageFiltered` her karede yeniden rasterize eder.
Odak ekranı **25 dakika wakelock ile açık kalıyor** — bu ekranda sürekli blur = ısınma + pil + jank.

Zorunlu uygulama:
1. **Aurora zeminleri runtime blur ile çizme.** Önceden blur'lanmış PNG olarak `assets/images`'a koy,
   üstüne yavaş `Transform.translate`/`rotate` animasyonu uygula. Görsel sonuç aynı, maliyet ~sıfır.
2. **`backdrop-filter` kartlarını** `BackdropFilter` ile yapma; prototipteki `rgba(30,32,48,.82)` düz
   dolgu görsel olarak ayırt edilemez sonucu verir.
3. **Krom tipografi** (`background-clip:text`, 4 yerde) → `ShaderMask` + `LinearGradient`.
   `shimmer` animasyonunu yalnızca Ekran 01 başlığında çalıştır; diğerlerinde statik gradient.
4. **Odak seansı aktifken tüm dekoratif animasyonları durdur** (aurora, shimmer, marquee, sheen).
   Meşale ve halka çalışmaya devam eder. Hem pil hem odak vaadi için doğrusu budur.
5. `RepaintBoundary` ile meşale/halkayı ayır — arka plan onlarla birlikte repaint olmasın.
6. Hedef: odak ekranında sürekli **60 fps**, `flutter run --profile` ile doğrula.

---

## 7. REKLAM & SATIN ALMA (prototipin dediği gibi)

### 7.1 Banner
Yalnızca **Ekran 02 (Geri sayım)** ve **Ekran 06 (İstatistik)**, `AnchoredAdaptiveBannerAdSize`.
Ekran 03'te (odak) hiç istenmez. Onboarding/Kart/Rozet ekranlarında yok.
Yüklenemezse aynı yükseklikte `SizedBox` → layout zıplamaz. `isPremium` ise hiç istenmez.

### 7.2 Interstitial
Prototip Ekran 09'da `interstitial · 3 pomodoroda 1` yazıyor → **v1'de açık.**
Kurallar tek yerde (`InterstitialManager`): mola **başlangıcında**, 3 tamamlanan pomodoroda 1,
iki gösterim arası min. **180 sn**. Rozet açılışının veya kart export'unun üstüne **asla** binmez.
`RemoteFlags.interstitialEnabled` ile kapatılabilir olsun (varsayılan `true`).

### 7.3 Satın alma
Prototip "Reklamları kaldır · **yakında**" gösteriyor → v1'de UI **pasif**.
`purchase_service.dart` ve `pro_lifetime` ürün akışı **tam kodlanır**, satır pasif görünür.
Bir sonraki sürümde tek satır değişiklikle açılır. `isPremium == true` iken hiçbir reklam isteği atılmaz.

---

## 8. FAZ PLANI

Her faz sonunda `flutter analyze` (0/0) + tek commit.

| Faz | İçerik |
|---|---|
| 0 | Repo düzeni: prototipler → `design/`, `doc-page.js`/`support.js`/`.thumbnail` sil, Flutter `.gitignore`. `DECISIONS.md` başlat |
| 1 | Proje iskeleti, `pubspec.yaml` (sürüm pinli), strict `analysis_options.yaml`, `AndroidManifest.xml`, font subset'leri |
| 2 | `core/` — `AppColors` ThemeExtension, tipografi (3 font), spacing, router, ortak widget'lar |
| 3 | `services/storage` — drift tabloları, DAO'lar, migration, seed, `exam_dates.json`, uzak override |
| 4 | Ekran 02 + 11 + 08 — geri sayım, sınav seçici sheet, özel sınav, boş durum |
| 5 | Ekran 03 + 09 + 10 — durum makinesi, wall-clock timer, meşale, mola, "5 dk ekle", iptal onayı |
| 6 | Bildirimler (4 tip, Ekran 12 metinleri) + wakelock + izin akışı |
| 7 | Ekran 04 — `badge_rules` + `streak_calculator` + açılış dialogu |
| 8 | Ekran 05 — kart şablonları + 1080×1920 export + 3 aksiyon |
| 9 | Ekran 06 — SQL agregasyonlar + `CustomPainter` bar chart |
| 10 | Ekran 01 — onboarding + izinler + UMP consent |
| 11 | Reklamlar (banner + interstitial) + `purchase_service` (UI pasif) |
| 12 | Ekran 07 — ayarlar |
| 13 | ARB geçişi + kodda kalan hard-coded Türkçe metin taraması (grep ile doğrula) |
| 14 | Performans geçişi (BÖLÜM 6) + `--profile` ile 60 fps doğrulaması |
| 15 | Testler + Play yayın paketi |

---

## 9. TESTLER

**Unit:** `streak_calculator` (04:00 kesimi, seri kırılması, günde çok seans, artık yıl) ·
`badge_rules` (7 rozet + 07:59/08:00 ve 22:59/23:00 sınırları) · drift stats sorguları
(boş veri, tek gün, hafta sınırı) · `duration_formatter` (0, 1 dk, 99+ sa) ·
`daysTo` + `ratio` formülü (prototiple aynı sonucu vermeli).

**Widget:** faz geçişleri (odak → mola → odak → 4. sonrası uzun mola) ·
Ekran 02 → 08 yönlenmesi · kart export'unda 3 haneli gün + uzun rumukla taşma yok ·
iptal onayında seri metninin doğru koşulda görünmesi.

---

## 10. DEFINITION OF DONE

- [ ] `flutter analyze` 0 hata / 0 uyarı
- [ ] Her ekran prototiple yan yana konduğunda ayırt edilemiyor
- [ ] Prototipteki demo sayılarının **hiçbiri** kodda yok (132, 42, %86, 6, 3/7, 11)
- [ ] 10 dk arka plandan dönüşte sayaç doğru
- [ ] Uygulama öldürülüp açıldığında aktif seans kurtarılıyor
- [ ] Cihaz saati geriye alındığında seans yanlış "tamamlandı" sayılmıyor
- [ ] İzinler reddedildiğinde uygulama tam çalışıyor
- [ ] Tarihi geçmiş sınav → Ekran 08, rozet/geçmiş korunuyor
- [ ] Ekran 03'te hiçbir reklam isteği atılmıyor
- [ ] `isPremium` iken hiçbir reklam isteği atılmıyor
- [ ] Kart export'u tam 1080×1920
- [ ] Odak ekranı `--profile` modda sürekli 60 fps
- [ ] Odak seansında dekoratif animasyonlar duruyor
- [ ] Kodda hard-coded Türkçe metin yok
- [ ] Testler geçiyor
- [ ] `DECISIONS.md` her kararı gerekçesiyle içeriyor

---

## 11. ANA EKRAN WIDGET'LARI (Faz 16)

Tasarım dokümanı: `docs/superpowers/specs/2026-09-04-home-widgets-design.md`.

Beş Android ana ekran widget'ı. Hepsi aktif sınavı (`Exam.isActive`) gösterir.

| Widget | Boyut | Gösterdiği | Dokunma |
|---|---|---|---|
| Halka | 2×2 | Gün + ilerleme halkası | `/countdown` |
| Şerit | 4×1 | Gün + saat + doluluk çubuğu | `/countdown` |
| Seri | 2×2 | Seri + bugünkü odak + 7 günlük spark | `/stats` |
| Hızlı Odak | 4×2 | Sınav özeti + tek eylem butonu | `/focus?autostart=1` |
| Panorama | 4×2 | Halka + tarih + seri + spark | `/countdown` |

**Mimari kuralı:** Dart kalan günü YAZMAZ, hedef zaman damgasını yazar.
Gün/saat/oran her çizimde Kotlin tarafında yeniden hesaplanır
(`FocusWidgetSnapshot.kt`). Uygulama haftalarca açılmasa bile widget doğru
sayıyı gösterir. `progressRatio` formülü `countdown_math.dart` ile birebir
aynıdır.

### §0 kurallarından iki bilinçli sapma

1. **§0.3 "prototipte olmayan özellik ekleme"** — widget'lar tanım gereği
   prototipte olmayan yeni bir yüzey. Kullanıcı isteğiyle eklendi.
2. **§0.7 "kullanıcı metinleri yalnızca ARB'den"** — `RemoteViews` launcher
   sürecinde şişirildiği için ARB'ye erişemez; widget metinleri
   `res/values/focus_widget_strings.xml` içinde. Azaltma: metinlerin tamamına
   yakını ARB'de zaten vardı ve birebir kopyalandı, her satırda kaynak ARB
   anahtarı yorumla belirtildi. Yalnızca widget seçicideki ad/açıklamalar yeni
   (bunlar uygulama içinde değil, sistem arayüzünde görünüyor).

### Faz 16 DoD

- [x] `flutter analyze` 0 hata / 0 uyarı
- [x] Beş widget da `flutter build apk --release` ile derleniyor
- [x] Palet Dart ↔ Android senkron (`focus_palette_sync_test.dart`)
- [x] Sınav seçilmemiş / bugün / geçmiş durumları ayrı ayrı çiziliyor
- [x] Sayaç negatife düşmüyor (`coerceAtLeast(0)`)
- [x] Widget'tan gelen odak isteği süren seansı sıfırlamıyor
- [ ] Emülatörde beş widget görsel doğrulaması
