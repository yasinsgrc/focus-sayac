# FocusSayaç — Kalan İş Sırası

Durum: **Faz 0-13 bitti** (geri sayım, sınav seçimi, odak/mola durum
makinesi, bildirimler, rozetler, başarı kartı + export, istatistik,
onboarding + izinler + UMP, reklamlar + satın alma, ayarlar, ARB
yerelleştirme). `flutter analyze` 0/0, 126 test geçiyor.
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

Kalan bağlı iş: bildirim kapısının regresyon testi **madde 5**'te bitti,
gizlilik metninin reklamlara göre güncellenmesi **madde 9**'da.

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

Kalan bağlı iş: `canRequestAds` kapısı **madde 6**'da eklendi; gizlilik
metninin reklamlara/UMP'ye göre güncellenmesi **madde 9**'da.

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

Banner yer tutucusu **madde 6**'da gerçek `BannerAdSlot` ile değişti.

---

## 4. Ekran 05 — Başarı kartı + export (SPEC Faz 8) ✅ bitti

`lib/features/story_card/story_card_screen.dart`, rota `app_router.dart`e
eklendi; rozet dialogundaki "BAŞARI KARTINI OLUŞTUR" artık buraya gidiyor.
Üç şablon (`GECE MEŞALESİ` / `MİNİMAL` / `SERİ`) üçü de ücretsiz; seçim
`selectedTemplateIndex` kolonuna yazılıyor (kolonun ilk kullanıcısı bu madde).
Kart mantıksal boyutu **270×480**, `pixelRatio = 1080/270 = 4` → export tam
**1080×1920** (prototipin 248×441'i 1921 verirdi; gerekçe `DECISIONS.md`
"Faz 8"). PAYLAŞ (`share_plus`) / Kaydet (`gal`) / Kopyala (`pasteboard`)
tek servise toplandı (`services/export/story_card_exporter.dart`), izin reddi
ayrı mesaj alıyor. `focussayac.app` filigranı sabit. Kart metinlerindeki
Türkçe yönelme eki `domain/text/turkish_suffix.dart` ile okunuştan türüyor
(`YKS 2027'ye`, `Yarın 7'ye`).

**DoD karşılandı:** export testi PNG'yi çözüp 1080×1920 ölçüyor; 3 haneli gün
+ uzun sınav adı üç şablonda da taşmıyor
(`test/features/story_card/story_card_screen_test.dart`).

---

## 5. Küçük düzeltmeler + test boşlukları ✅ bitti

- **skipForward butonu kaldırıldı** (yeri aynı genişlikte boş bırakıldı ki
  oynat/duraklat halkanın merkezinde kalsın). Bağlanmadı: "fazı atla" SPEC'te
  tanımsız ve rozet/seri/istatistik semantiği icat etmek gerekirdi; görünür ama
  ölü bir düğme de eksik olandan kötü. Gerekçe `DECISIONS.md` "ROADMAP madde 5".
- **Geri tuşu `PopScope` ile engellendi**: odak fazında "X" ile aynı iptal
  onayını (Ekran 10) açıyor, molada hiçbir şey yapmıyor (Ekran 09'un kendi
  "ODAĞA DÖN" çıkışı var). İptal onayı iki yerden açıldığı için `_confirmCancel`
  dosya düzeyine taşındı.
- **Ekran 09'un başlık satırındaki 22px taşma** düzeltildi (`Flexible` +
  `FittedBox(scaleDown)`) — mola gövdesini ilk kez bu maddenin testi çizdiği
  için görüldü.
- **Üç test boşluğu kapandı** (`test/features/focus_session/`,
  `test/services/notifications/`): bildirim kapısı (kapalıyken hiçbir gönderim,
  iptaller yine çalışıyor + açık hâlde karşı kontrol), `SessionRingPainter`
  gerçek `progress` alıyor (odak ve duraklatılmış hâl), `didChangeAppLifecycleState`
  `inactive`/`hidden`/`paused`te tikleyiciyi durduruyor ve `resumed`de yakalama
  tiki atıyor. Geri tuşu davranışının regresyon testi de aynı dosyada.

---

## 6. Reklamlar + satın alma (SPEC Faz 11) ✅ bitti

Her reklam isteği tek kapıdan geçiyor: `services/ads/ad_service.dart`
(`canRequestAds` = `isPremium` değil **ve** UMP onayı var). `ConsentService`e
`canRequestAds()` eklendi, `adServiceProvider` `main.dart`ta gerçek örnekle
geçersiz kılınıyor (diğer servislerle aynı DI kalıbı; varsayılanı hâlâ
`UnimplementedError`).

- **Banner** yalnızca Ekran 02 ve Ekran 06 (`services/ads/banner_ad_slot.dart`,
  `AdSize.getLargeAnchoredAdaptiveBannerAdSize` — 9.x'te `Anchored…` sürümü
  `@Deprecated`). Yükseklik istekten önce ayrılıyor, yüklenemese de korunuyor;
  reklam **hiç istenmiyorsa** (premium/onay yok) yuva 88px payıyla kapanıyor.
  Boyut sorgusu cevapsız kalırsa prototipin 320×50'siyle isteniyor.
- **Interstitial** `services/ads/interstitial_manager.dart`: mola
  başlangıcında, 3 tamamlanan pomodoroda 1, iki gösterim arası min. 180 sn
  (son gösterim anı `SharedPreferences`ta kalıcı). Rozet açıldığı tamamlanışta
  bastırılıyor — `BadgeUnlockService.evaluateAfterFocusCompletion()` artık o
  çağrıda açılan anahtarları döndürüyor. `RemoteFlags.interstitialEnabled`
  (`services/remote/remote_flags.dart`, varsayılan `true`) ile kapatılabiliyor.
- `services/purchase/purchase_service.dart` + `pro_lifetime` akışı tam kodlandı
  (ürün sorgusu, satın alma, restore, `completePurchase`); v1'de **hiçbir
  çağıranı yok**, ayarlardaki satır pasif kalıyor (SPEC §7.3).
- Placeholder'ların ikisi de kalktı: `BANNER 320×50` → gerçek yuva,
  `interstitial · 3 pomodoroda 1` → gerçek tam ekran reklam.

**DoD karşılandı:** Ekran 03'te hiçbir reklam isteği atılmıyor ve `isPremium`
iken hiçbir istek atılmıyor — istekleri sayan `RecordingAdService`
(`test/support/`) ile `test/features/ads/banner_placement_test.dart`,
`test/features/focus_session/focus_session_screen_test.dart`,
`test/services/ads/` altında doğrulandı (+26 test).

Kalan bağlı iş: gerçek AdMob birim/uygulama kimlikleri ve gizlilik politikası
metni **madde 9**'da (şu an Google'ın resmî test kimlikleri, `--dart-define`
ile değiştirilebilir).

---

## 7. ARB yerelleştirme (SPEC Faz 13) ✅ bitti

Tüm kullanıcı metinleri `lib/l10n/app_tr.arb`de (tek dil `tr`); üretim
`l10n.yaml` → `lib/l10n/gen/` (`.gitignore`'da, `*.g.dart` ile aynı kural).
`pubspec.yaml`a `flutter_localizations` + `flutter: generate: true` eklendi,
`intl` kısıtı SDK pini yüzünden `^0.20.2`ye indi.

Erişim iki yollu ama tek kaynak: widget'lar `AppLocalizations.of(context)`,
bağlamsız katmanlar (`NotificationService`, `BadgeUnlockService`)
`appLocalizationsProvider` (`core/l10n/l10n_providers.dart`).
`MaterialApp.locale = kAppLocale` ile dil sabit; delegeler Ekran 11'in
tarih/saat seçicilerini de Türkçeleştiriyor (önce İngilizcelerdi).

- Ekran 12'nin 4 bildirim metni **birebir** ARB'de; kanal ad/açıklamaları da
  (kimlikler değişmedi — Android kanalı ilk kimlikle tanıyor).
- Ekran 09'un ipuçları statik katalog → ARB (`domain/pomodoro/break_tips.dart`,
  6 ipucu), her molada rastgele 2. Tohum molanın `startedAtUtc`'si: ekran
  saniyede bir çizildiği için `Random()` ipuçlarını titretirdi
  (`test/domain/pomodoro/break_tips_test.dart`, +5 test).
- Rozet ad/kuralı ve kart şablonu etiketi alan değil metot
  (`definition.name(l10n)`, `template.label(l10n)`) — katalog `const` kalıyor,
  DB'de yine yalnızca `badgeKey`, veri göçü gerekmedi.
- Testler `localizedTestApp` (`test/support/`) üzerinden çiziyor; delegeler
  `FocusSayacApp` ile birebir aynı.

**DoD karşılandı:** grep taraması kodda kullanıcıya görünen hiçbir Türkçe metin
bulmuyor. Kalan 13 literal geliştirici hatası (`UnimplementedError` /
`ArgumentError`), `Space Grotesk` font adı ve `turkish_suffix.dart`ın ünlü
uyumu verisi — hiçbiri ekrana çıkmıyor. Kararlar: `DECISIONS.md` "Faz 13".

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
- [x] Ekran 03'te hiçbir reklam isteği atılmıyor
- [x] `isPremium` iken hiçbir reklam isteği atılmıyor
- [x] Kart export'u tam 1080×1920
- [ ] Odak ekranı `--profile` modda sürekli 60 fps *(madde 8)*
- [ ] Odak seansında dekoratif animasyonlar duruyor *(madde 8)*
- [x] Kodda hard-coded Türkçe metin yok
- [ ] Testler geçiyor
- [ ] `DECISIONS.md` her kararı gerekçesiyle içeriyor
