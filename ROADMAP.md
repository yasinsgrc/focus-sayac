# FocusSayaç — Kalan İş Sırası

Durum: **Faz 0-7 + 9 + 10 + 12 bitti** (geri sayım, sınav seçimi, odak/mola
durum makinesi, bildirimler, rozetler, istatistik, onboarding + izinler + UMP,
ayarlar). `flutter analyze` 0/0, 66 test geçiyor.
Kaynak plan: `SPEC.md` §8. Kararlar: `DECISIONS.md`.

Aşağıdaki maddeler **teste/yayına çıkma önceliğine** göre sıralı. Her madde tek
oturumda (`/clear` sonrası) yapılabilecek şekilde bağımsız yazıldı: sırayla git,
her maddenin sonunda `flutter analyze` + `flutter test` + tek commit.

---

## 1. Ekran 07 — Ayarlar (SPEC Faz 12) ✅ bitti

`lib/features/settings/settings_screen.dart`, rota `app_router.dart`e eklendi,
alt çubuğun dişli sekmesi bağlandı. Slider'lar (odak 5-90, mola 1-30) ve
anahtarlar `AppSettingsDao`ya yazıyor; sınav seçimi mevcut sheet'i açıyor;
"Verileri sıfırla" onaylı dialogla odak geçmişi + rozetleri siliyor (sınavlar ve
ayarlar korunuyor); `in_app_review` 3. tamamlanan seanstan sonra bir kez
(`domain/review/app_review_service.dart`, tetik `_completeBreak`); "Reklamları
kaldır · yakında" satırı pasif. Kararlar: `DECISIONS.md` "Faz 12".

Kalan bağlı iş: bildirim kapısının regresyon testi **madde 5**'te, gizlilik
metninin reklamlara göre güncellenmesi **madde 6/9**'da.

---

## 2. Ekran 01 — Onboarding + izinler + UMP (SPEC Faz 10) ✅ bitti

`lib/features/onboarding/onboarding_screen.dart`, rota `app_router.dart`e
eklendi. İzin isteği `NotificationService.initialize()`ten ayrılıp
`requestPermissions()`a taşındı (`POST_NOTIFICATIONS` →
`SCHEDULE_EXACT_ALARM`, sırayla) ve artık açılışta değil "İZİN VER VE BAŞLA"
dokunuşunda çalışıyor; "Şimdi değil" izinsiz devam ediyor. UMP consent akışı
`lib/services/consent/consent_service.dart` (`ConsentService.gatherConsent`,
`google_mobile_ads`in UMP API'si) ve **iki** çıkışta da toplanıyor. Bitişte
`onboardingCompleted = true`; başlangıç rotası
`onboardingCompletedAtLaunchProvider` (açılış anlık görüntüsü, `main.dart`
override eder) üzerinden Ekran 01 ya da Ekran 02. Sahte `9:41` durum çubuğu
çizilmiyor. Kararlar: `DECISIONS.md` "Faz 10".

Kalan bağlı iş: gerçek reklam isteğinin `canRequestAds` kapısı **madde 6**'da;
gizlilik metninin reklamlara/UMP'ye göre güncellenmesi **madde 6/9**'da.

---

## 3. Ekran 06 — İstatistik (SPEC Faz 9) ✅ bitti

`lib/features/stats/stats_screen.dart`, rota `app_router.dart`e eklendi, alt
çubuğun grafik sekmesi bağlandı (hap artık aktif sekmenin yuvasında —
Ekran 06'da `VERİLER`). Agregat tablo yok: kümülatif odak, son 7 gün günlük
ortalama, en uzun seri, tamamlanma oranı ve "en verimli aralık" saf
`domain/stats/focus_stats.dart` içinde ham `PomodoroSession` kayıtlarından
türüyor (SQL yerine Dart — 04:00 gün sınırını ikinci kez yazmamak için;
gerekçe `DECISIONS.md` "Faz 9"). 7 günlük bar chart `CustomPainter`
(`weekly_focus_bar_painter.dart`), `sky` gradyanı, bugün `ember`. Boş veri /
tek gün / hafta sınırı / 04:00 kesimi testleri `test/domain/stats/`de.
Prototipin demo sayıları (42 SAAT, %86, 11 GÜN) kodda yok — regresyon testi
`test/features/stats/stats_screen_test.dart`.

Kalan bağlı iş: banner hâlâ `BANNER 320×50` yer tutucusu — gerçek reklam
**madde 6**'da.

---

## 4. Ekran 05 — Başarı kartı + export (SPEC Faz 8) 🟠

`badges_screen.dart:264` bu ekranı bekliyor. `selectedTemplateIndex` kolonu
(`tables.dart:59`) şu an **hiç okunmuyor** — kullanıcısı bu madde.

- 3 şablon: `GECE MEŞALESİ` / `MİNİMAL SAYAÇ` / 3. şablon — üçü de v1'de ücretsiz.
- `RenderRepaintBoundary`, `pixelRatio = 1080 / kartMantıksalGenişlik`.
- PAYLAŞ (`share_plus`) / Kaydet (`gal`) / Kopyala (`pasteboard`).
- `focussayac.app` sabit filigran — kaldırma özelliği **yok**.

**DoD:** Export tam **1080×1920**. 3 haneli gün + uzun rumuzda taşma yok (SPEC §9).

---

## 5. Küçük düzeltmeler + test boşlukları 🟡

Tek oturumda toplu yapılabilir, hepsi küçük:

- `focus_session_screen.dart:251` — **skipForward butonu `onTap: null`**, görünür
  ama ölü. Ya işlevini bağla (fazı atla) ya da prototipten çıkar. Karar
  `DECISIONS.md`'ye yazılsın.
- Odak seansı sürerken Android geri tuşuyla countdown'a dönülürse odak ekranına
  dönüş yolu yok — `PopScope` ile engelle ya da countdown'a "seansa dön" çıkışı ekle.
- **Test boşlukları** (11 hata düzeltmesinden 3'ünün regresyon testi yok):
  - Bildirim ayarı kapalıyken `NotificationService` hiçbir şey göndermiyor,
    iptaller yine çalışıyor (`notification_service.dart` kapısı).
  - `SessionRingPainter` gerçek `progress` alıyor (halkanın dolması).
  - `didChangeAppLifecycleState` — `inactive`/`hidden`de ticker duruyor,
    `resumed`de yakalama tiki atılıyor.

---

## 6. Reklamlar + satın alma (SPEC Faz 11) 🟠 yayın zorunlu

**Bağımlılık:** madde 3 (Ekran 06 banner hedefi) bitti — banner yeri hazır,
`BANNER 320×50` yer tutucusu gerçeğiyle değiştirilecek. UMP consent (madde 2) bitti —
`ConsentService` var; bu maddede `canRequestAds()` eklenip her reklam isteğinin
önüne konulmalı.

- Banner **yalnızca** Ekran 02 ve Ekran 06, `AnchoredAdaptiveBannerAdSize`.
  Yüklenemezse aynı yükseklikte `SizedBox` → layout zıplamaz.
- Interstitial: kuralları tek yerde (`InterstitialManager`) — mola
  **başlangıcında**, 3 tamamlanan pomodoroda 1, iki gösterim arası min. 180 sn.
  Rozet açılışının/kart export'unun üstüne **asla** binmez.
  `RemoteFlags.interstitialEnabled` ile kapatılabilir (varsayılan `true`).
- `purchase_service.dart` + `pro_lifetime` akışı **tam kodlanır**, UI pasif kalır.
- Ekranlardaki `BANNER 320×50` / `interstitial · 3 pomodoroda 1` placeholder
  metinlerini gerçekleriyle değiştir.

**DoD:** Ekran 03'te **hiçbir** reklam isteği atılmıyor. `isPremium == true` iken
hiçbir reklam isteği atılmıyor.

---

## 7. ARB yerelleştirme (SPEC Faz 13) 🟡 yayın zorunlu

Tüm metinler şu an kodda gömülü. Son ekran bittikten **sonra** yapılmalı,
yoksa iki kez çevrilir.

- Ekran 12'nin 4 bildirim metni **birebir** ARB'ye.
- Ekran 09'un "molada dene" ipuçları statik katalog → ARB, her molada rastgele 2.
- Bitişte grep ile doğrula: kodda hard-coded Türkçe metin kalmamalı (SPEC DoD).

---

## 8. Performans geçişi (SPEC Faz 14) 🟡

- `--profile` modda odak ekranı **sürekli 60 fps**.
- Odak seansında dekoratif animasyonlar duruyor (SPEC DoD).
- SPEC §6'daki tüm maddeleri tek tek doğrula.

---

## 9. Testler + Play yayın paketi (SPEC Faz 15) 🟡

- SPEC §9'un kalan unit testleri: `badge_rules` (7 rozet + 07:59/08:00 ve
  22:59/23:00 sınırları), `duration_formatter` (0, 1 dk, 99+ sa).
- Widget: kart export taşma testi.
- Play imzalama, sürüm notu, gizlilik politikası bağlantısı, store görselleri.

---

## Yayın öncesi son kontrol (SPEC §10 DoD)

- [ ] `flutter analyze` 0 hata / 0 uyarı
- [ ] Her ekran prototiple ayırt edilemiyor
- [ ] Demo sayılarının hiçbiri kodda yok (132, 42, %86, 6, 3/7, 11)
- [x] 10 dk arka plandan dönüşte sayaç doğru
- [x] Uygulama öldürülüp açıldığında aktif seans kurtarılıyor
- [x] Cihaz saati geriye alındığında seans yanlış "tamamlandı" sayılmıyor
- [x] İzinler reddedildiğinde uygulama tam çalışıyor
- [x] Tarihi geçmiş sınav → Ekran 08, rozet/geçmiş korunuyor
- [ ] Ekran 03'te hiçbir reklam isteği atılmıyor *(madde 6)*
- [ ] `isPremium` iken hiçbir reklam isteği atılmıyor *(madde 6)*
- [ ] Kart export'u tam 1080×1920 *(madde 4)*
- [ ] Odak ekranı `--profile` modda sürekli 60 fps *(madde 8)*
- [ ] Odak seansında dekoratif animasyonlar duruyor *(madde 8)*
- [ ] Kodda hard-coded Türkçe metin yok *(madde 7)*
- [ ] Testler geçiyor
- [ ] `DECISIONS.md` her kararı gerekçesiyle içeriyor
