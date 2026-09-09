# FocusSayaç — Kalan İş Sırası

Durum: **Faz 0-13 bitti**, **Faz 14 ve 15'in kod tarafı bitti**, **SPEC §10 DoD
kapanışı bitti** (geri sayım, sınav seçimi, odak/mola durum makinesi,
bildirimler, rozetler, başarı kartı + export, istatistik, onboarding + izinler +
UMP, reklamlar + satın alma, ayarlar, ARB yerelleştirme, performans geçişi,
testler + yayın paketi, demo sayı/palet taramaları).
`flutter analyze` 0/0, 171 test geçiyor. Kaynak plan: `SPEC.md` §8.
Kararlar: `DECISIONS.md`. Yayın adımları: `docs/play/RELEASE.md`.

Madde 11'de emülatör açıldı ve **ilk Android derlemesi yapıldı**: iki blocker
çıktı (desugaring kapalı, geçersiz manifest XML), ikisi de düzeltildi.
`--profile` 60 fps ölçümü emülatörde alındı. Kalan iş dış kaynak bekliyor:
**AdMob hesabı** (gerçek reklam kimlikleri), **imzalama anahtarı**
(`key.properties`), **görseller** (launcher simgesi + store görselleri) ve
gerçek bir ARM cihazda doğrulama.

Aşağıdaki maddeler **teste/yayına çıkma önceliğine** göre sıralı. Her madde tek
oturumda (`/clear` sonrası) yapılabilecek şekilde bağımsız yazıldı: sırayla git,
her maddenin sonunda `flutter analyze` + `flutter test` + tek commit.

Madde 11 ve 14-17 bu dosyaya yazılmadan yapıldı (ilk Android derlemesi, ana
ekran widget'ları, emülatör doğrulaması, açık tema + uygulama simgesi);
kayıtları `DECISIONS.md`de. **Madde 18-20** yayın engelleyicisi değil, cila:
uygulamanın eksik kalan hareket katmanı — dosyanın sonundaki ayrı bölümde.
**Madde 18 bitti**, 19 ve 20 kaldı.

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
gizlilik metninin reklamlara göre güncellenmesi **madde 9**'da bitti.

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
metninin reklamlara/UMP'ye göre güncellenmesi **madde 9**'da bitti.

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

Kalan bağlı iş: gizlilik politikası metni **madde 9**'da yazıldı
(`docs/privacy-policy.md`). Gerçek AdMob birim/uygulama kimlikleri hâlâ
girilmedi — bir AdMob hesabı gerekiyor; şu an Google'ın resmî test kimlikleri,
`--dart-define` ile değiştirilebilir (`docs/play/RELEASE.md` §3).

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

## 8. Performans geçişi (SPEC Faz 14) 🟡 kod tarafı bitti, ölçüm cihazda

SPEC §6'nın altı kuralı tek tek geçildi. 1-3 (runtime blur yok, `BackdropFilter`
yok, krom tipografi `ShaderMask` + shimmer yalnızca Ekran 01) Faz 2'de zaten
böyle inşa edilmişti; artık `test/performance/runtime_blur_scan_test.dart`
kaynağın tamamını tarayıp pinliyor (madde 7'nin grep yaklaşımı). Kural 4 ve 5
gerçek iş çıkardı:

- **Kural 4 — Ekran 02'nin saniye tikleyicisi odak seansı boyunca duruyor.**
  Odak ekranı Ekran 02'nin üstüne `push` ediliyor ve Ekran 02 yığında kalıyor.
  Halkanın `AnimationController`ı `Overlay`in `TickerMode`u sayesinde zaten
  susuyordu, ama `Timer.periodic` `TickerMode`a bakmıyor: kapalı rota, odak
  ekranı 60 fps çizerken saniyede bir `setState` ile yeniden build + layout
  oluyordu — 25 dakika boyunca, görünmeyen bir ekran için. Tikleyici artık
  `didChangeDependencies`te aynı `TickerMode` sinyaline bağlı.
- **Kural 5 — meşale iki `RepaintBoundary` ile ayrıldı.** Dıştaki, alevin kare
  başına `markNeedsPaint`ini 72px sayaç metninden ayırıyor (saat saniyede 60 kez
  yeniden çiziliyordu); içteki `Transform`u bileşikleştirip alev gövdesinin
  rasterini saklıyor. Halkanın sınırı zaten vardı.
- **Duraklatılmış seansta alev donuyor.** §6.4'ün "meşale çalışmaya devam eder"
  istisnası **süren** seans için; duraklatılmış ekran wakelock ile süresiz açık
  kalabiliyor ve orada kare üretecek bir sebep yok.

Testler: `test/features/countdown/countdown_ticker_test.dart` (+2, karşı
kontrolüyle), `focus_session_screen_test.dart` (+2), blur taraması (+1) — üçü de
düzeltme geri alındığında düşüyor.

**Kalan:** `flutter run --profile` ile odak ekranının sürekli 60 fps olduğunun
gerçek bir Android cihazında doğrulanması. Bu makinede Android cihaz/emülatör
bağlı değil (`flutter devices` yalnızca Windows/Chrome/Edge veriyor), ölçüm
yapılamadı.

---

## 9. Testler + Play yayın paketi (SPEC Faz 15) 🟡 kod tarafı bitti, mağaza işi cihaz/hesap bekliyor

SPEC §9'un kalan testleri yazıldı, yayın paketinin depodan yapılabilen kısmı
(imzalama, gizlilik politikası, Console eşlemesi) kuruldu. 159 test geçiyor.

- **`badge_rules` testi** (`test/domain/badges/`, +15): yedi rozetin her biri,
  07:59/08:00 ve 22:59/23:00 sınırları — hepsi karşı kontrolüyle (3 seans
  yetmez/4 açar, 6 gün yetmez/7 açar, 99sa59dk kapalı/100sa açık). Seanslar
  TSİ duvar saatiyle kuruluyor, çeviri tek yardımcıda: kurallar duvar saatinde
  tanımlı, depolama UTC. "00:30 gece nöbeti değil" testi iki zaman kavramının
  kesiştiği tek yeri pinliyor (gün anahtarı ≠ duvar saati).
- **`duration_formatter` testi** (`test/domain/time/`, +12): 0 / 1 dk / 99+ sa,
  yuvarlamama (59 sn → 0 dk) ve negatif girişin 0'a kırpılması.
- **Kart export taşma testi zaten vardı** (madde 4, `story_card_screen_test.dart`)
  — SPEC §9'un o satırı Faz 8'de kapanmıştı, yeniden yazılmadı.
- **Play imzalama:** `android/key.properties` (`.gitignore`da, şablonu
  `key.properties.example`) varsa `release` ondan imzalanıyor, yoksa debug'a
  düşüyor — geliştirme koşumları kırılmasın diye; debug imzalı AAB'yi Console
  zaten reddediyor. Her iki dal `:app:signingReport` ile doğrulandı. Belgelenen
  format PKCS12 (JKS için `keytool` uyarı basıyor); `*.p12`/`*.keystore`
  yoksayma kalıpları `git check-ignore` ile teyit edildi.
- **Gizlilik politikası:** `docs/privacy-policy.md` (Console'un URL alanına
  girecek `focussayac.app/gizlilik` sayfasının kaynağı) + uygulama içi özet
  reklam/UMP gerçeğine göre düzeltildi. Eski metin "kişisel veri toplamaz"
  diyordu — Faz 11'den beri yanlıştı; madde 1/2/6'nın bıraktığı iş buydu.
  Regresyon testi (`settings_screen_test.dart`) eski iddianın dönmesini
  engelliyor; uzun metin için dialog gövdesi kaydırılabilir yapıldı.
- **`docs/play/RELEASE.md`:** sürüm numarası, imzalama, `--dart-define`
  tablosu, ASO paketi → Console alanı eşlemesi (seçilen ad/açıklama
  varyantlarıyla), veri güvenliği formu cevapları, sürüm notu 1.0.0 ve yayın
  öncesi kontrol listesi. Mağaza metinleri kopyalanmadı; tek kaynak
  `design/FocusSayac ASO Paketi.dc.html`.
- Launcher etiketi `focussayac` → `FocusSayaç`, `pubspec` açıklaması gerçek
  açıklamayla değişti.

**Kalan (ikisi de dış kaynak bekliyor, `docs/play/RELEASE.md`de açık kutu):**
gerçek AdMob birim/App ID'leri bir AdMob hesabı gerektiriyor (kod tarafı hazır,
`--dart-define`, kod değişikliği yok); simge/feature graphic/ekran görüntüleri
bağlı bir Android cihaz gerektiriyor — madde 8'in `--profile` ölçümüyle aynı
engel.

---

## 10. SPEC §10 DoD kapanışı 🟡 kod tarafı bitti, iki kutu cihaz bekliyor

Aşağıdaki kontrol listesinin depodan kapatılabilecek kutuları kapatıldı, kalan
ikisi tek bir dış kaynağa — bağlı bir Android cihaza — bağlandı. 167 test
geçiyor (+8). Kararlar: `DECISIONS.md` "SPEC §10 DoD kapanışı".

- **Demo sayıları artık taramayla pinli** (`test/prototype/demo_numbers_scan_test.dart`).
  SPEC "demo sayılarının hiçbiri **kodda** yok" dediği için kontrol ekran değil
  kaynak düzeyinde: bir widget testi yalnız o an çizdiği ağacı görür, sızıntının
  hangi ekrandan geleceğiyse önceden bilinmiyor (madde 7 ve 8'in tarama kalıbı).
  Altı demo değer de (`132`, `42`, `%86`, `6`, `3/7`, `11`) iki yüzeyde aranıyor:
  ARB değerleri ve `lib/` Dart dize sabitleri. Sayılar **rakam koşusu** olarak
  karşılaştırılıyor, alt dize olarak değil — yoksa `1080 × 1920 PNG` ve AdMob
  test kimliği yanlış alarm verir, tek haneli `6` ise taramayı kullanılamaz
  kılardı. Sonuç: hiçbir yüzeyde tek bir demo değer yok; ekrana çıkan her sayı
  kullanıcının kendi verisinden türüyor.
- **Palet/tipografi prototipten ayrıştırılıp doğrulanıyor**
  (`test/prototype/prototype_palette_test.dart`). `app_colors.dart`ın "prototipin
  `:root`undan birebir" iddiası bugüne kadar yalnızca bir yorum satırıydı. Test
  tasarım dosyasını kaynak kabul edip dokuz rol rengini, `body` zeminini,
  `--chrome` gradyanının renk ve duraklarını, `--disp`/`--mono` ailelerini ve
  `letter-spacing` oranlarını koda karşı sınıyor — hepsi eşleşiyor.
- **12 ekranın metin denetimi:** prototipteki her kullanıcı metninin ARB'de
  birebir karşılığı var; prototipte sabit görünen sayıların tamamı (`{days} gün
  seri`, `ODAK {position}/4`, `{position}. pomodoro bitti`, `$unlockedCount/7`)
  placeholder'a bağlı.
- **İki tarama da mutasyonla doğrulandı:** ARB'ye `11 GÜN` sokulunca ve `ember`
  bir bit kaydırılınca ikisi de düşüyor.

**Kalan (ikisi de aynı engelde):** `--profile` 60 fps ölçümü (madde 8) ve
"her ekran prototiple yan yana ayırt edilemiyor" görsel karşılaştırması. İkincinin
mekanik kısmı yukarıda doğrulandı, ama maddenin sözü *yan yana konduğunda* — bu
bir render kararı ve bağlı bir cihaz istiyor (madde 9'un store ekran
görüntüleriyle aynı engel). Bu makinede Android cihaz/emülatör yok.

---

## 12. Alt gezinme çubuğu — çift hedef + dokunma/erişilebilirlik ✅ bitti

169 test geçiyor (+2). Kararlar: `DECISIONS.md` "ROADMAP madde 12".

- **Çift hedef giderildi:** `flame` ve `medal` yuvalarının ikisi de rozetler
  ekranını açıyordu. `flame` artık Ekran 05'e (başarı kartı) gidiyor — alev =
  seri, başarı kartı serinin paylaşılabilir yüzü ve o ekranın tek girişi rozet
  dialogundaki düğmeydi. Prototipin beş ikonu ve dizilimi olduğu gibi duruyor.
- **`onSelect` `switch`e çevrildi** (Ekran 02 ve 06). Yeni bir `AppNavTab`
  eklendiğinde derleyici her çağıranda dalı zorluyor; çift hedefin fark
  edilmeden yaşamasının sebebi sessizce düşen `if` zinciriydi.
- **Dokunma hedefi 21px → 48px.** `InkWell`, `Row`un gevşek dikey sınırı altında
  ikonun boyuna küçülüyordu. İkon boyutu (21px) değişmedi, yalnızca görünmeyen
  vuruş alanı büyüdü.
- **Dalga görünür oldu:** çubuğun `Row`u saydam bir `Material`e sarıldı; dalga
  daha önce Scaffold'un materyaline düşüp çubuğun opak zemininin altında
  kalıyordu.
- **Ekran okuyucu adları eklendi:** beş yuva + `AppBackButton` + Ekran 05'in
  satır içi geri oku. Etiketler gidilen ekranın mevcut ARB başlığından geliyor;
  tek yeni dize `commonBack` ("Geri").
- **Regresyon testleri:** "alev" yuvası Ekran 05'i açıyor ve rozetler ekranı
  açılmıyor; üç ikon yuvasının dokunma hedefi 48px (ikisi de semantics açık,
  yani etiketleri de doğruluyor).

**Kapsam dışı:** ayarlardaki "Gün 04:00'te başlar" satırının boş değer alanı hata
değil (değer etiketin kendi metninde); "Reklamları kaldır / YAKINDA" satırı SPEC
§7.3 gereği bilinçli pasif.

---

## 13. Alt gezinme çubuğu beş ekranda ✅ bitti

171 test geçiyor (+2). Kararlar: `DECISIONS.md` "ROADMAP madde 13".

- **Çubuk artık beş sekmenin hepsinde.** Ekran 04/05/07 çubuğu göstermediği için
  gezinme tek yönlüydü: oraya gidiliyor ama oradan başka bir sekmeye
  geçilemiyordu.
- **Her yuvanın aktif "hap"ı var.** Ekran 05 kısa `navStoryCard` ("BAŞARI"),
  Ekran 04 ve 07 kendi başlıklarını kullanıyor; `_NavSlot.pill` opsiyonel değil.
- **Yönlendirme tek yerde:** `navigateToNavTab`. Ekran 02 kök, diğer sekmeler
  onun üstünde tek kat (`pushReplacement`) — beş kopya `switch` de gitti.
- **Regresyon testleri:** çubuk beş sekmede de görünüyor; dört sekme arasında
  dolaşmak gezinme yığınını büyütmüyor.
- **Emülatörde doğrulandı** (`Medium_Phone_API_36.1`, yazılım render): beş
  sekmenin ekran görüntüsü alındı, rozet kataloğu 0/7 ve yedi kart tekil.

---

---

# Hareket geçişi (madde 18-20) — yapılacak

Uygulamanın tipografisi, paleti ve düzeni prototiple birebir; eksik olan tek
katman **hareket**. Şu an var olanlar: `RiseIn` (600ms giriş, 60ms basamak),
geri sayım halkasının 40sn dönen kesikleri, alevin 1.7sn titreşimi, onboarding
shimmer/spin, `AppToast`, odak ipucu satırının fade'i. Eksik olanlar üç kümede
toplanıyor ve üç madde tam olarak o kümeler.

**Yön kararı — sürekli değil olay bazlı.** SPEC §6 sürekli blur'u, sürekli
dekoratif animasyonu ve odak seansında her tür süslemeyi yasaklıyor; hedef
sürekli 60 fps. Bu bir kısıt gibi görünüyor ama aslında doğru yönü işaret
ediyor: pahalı görünen hareket *sürekli parlayan* değil, *olaya tepki veren*
harekettir. Aşağıdaki üç maddenin hiçbiri boşta kare üretmiyor — hepsi bir
değer değişince, bir dokunuşta ya da bir rota geçişinde bir kez çalışıp duruyor.
Bu yüzden §6.4 ile çatışmıyorlar ve odak ekranının fps bütçesine dokunmuyorlar.

**Üçünde de ortak kural:** `MediaQuery.disableAnimationsOf(context)` açıkken
hiçbir hareket çalışmaz, içerik doğrudan son hâlinde çizilir — `RiseIn`in
zaten uyguladığı desen (`lib/core/widgets/rise_in.dart:68`). Madde 18 bu
kontrolü tek bir yardımcıya topluyor, 19 ve 20 onu kullanıyor.

---

## 18. Hareket token'ları + sayı ve oran geçişleri ✅ bitti

238 test geçiyor (+9). Kararlar: `DECISIONS.md` "Madde 18".

- **`AppMotion`** kuruldu (altı süre, dört eğri, `respectingMotion`); `RiseIn`in
  600ms/60ms'i oraya taşındı, eğrisi (CSS `ease-out`) bilinçli olarak yerinde kaldı.
- **`RollingNumber`** karakter bazlı odometre: yalnızca değişen hane kayıyor, yuva
  anahtarları sağdan sayılıyor, hane sayısı değişince `AnimatedSize`, taşmaya karşı
  `FittedBox(scaleDown)`, ekran okuyucuya tek `Semantics` etiketi.
  Uygulandığı yerler: Ekran 02 gün sayısı + bugünkü saat/dakika + seri rozeti,
  Ekran 06 kümülatif odak / en uzun seri / tamamlanma oranı, Ekran 04 rozet sayacı.
- **Dışarıda bırakılanlar:** `hh:mm:ss` saniye sayacı (boşta 60 fps) ve Ekran 06'nın
  günlük ortalama **cümlesi** (bir cümleyi karaktere bölmek satır kırmayı kaybettirir,
  sayı da yalnız ekran kapalıyken değişiyor).
- **Oran geçişleri:** Ekran 02'nin halkası `TweenAnimationBuilder`; odak/mola halkası
  `SettlingProgress` ile **yalnızca ilk yerleşmede** akıyor — her saniye tikini
  tween'lemek §6.4'ün yasakladığı sürekli kare üretimi olurdu.
- **Testler:** `test/core/rolling_number_test.dart` + `test/core/settling_progress_test.dart`;
  `stats_screen_test` sayıları artık `findRollingNumber` ile arıyor,
  `focus_session_screen_test`in iki halka ölçümü yerleşmeyi bekliyor.
- **Cihazda bakılmadı** — hareketin son hâli emülatörde görülmedi (madde 16 gibi bir tur).

**Neden ilk buydu:** uygulamanın en görünür açığı. Bir geri sayım uygulamasında
ekranın ortasındaki 100px'lik gün sayısı (`countdown_screen.dart:385`) gece
yarısı bir kareden diğerine zıplıyor; bugünkü odak saati bir seans bitince
zıplıyor; halkanın oranı sınav değişince tween'siz sıçrıyor. Yüzey küçük,
etki büyük, SPEC §6 ile hiç sürtünmesi yok.

**Yapılacaklar:**

1. **`lib/core/theme/app_motion.dart`** — `app_spacing.dart` / `app_shadows.dart`
   ile aynı desen (`abstract final class`, `const` alanlar). İçinde:
   - Süreler: `instant` 120ms, `fast` 180ms, `base` 260ms, `slow` 420ms,
     `entrance` 600ms, `step` 60ms. Son ikisi `RiseIn`in bugün kendi içinde
     tuttuğu değerler — `RiseIn` de bu token'lara taşınsın, iki kaynak kalmasın.
   - Eğriler: `enter` = `Curves.easeOutCubic`, `exit` = `Curves.easeInCubic`,
     `standard` = `Curves.easeInOutCubic`, `pop` = `Curves.easeOutBack`.
   - `static Duration respectingMotion(BuildContext, Duration)` → "hareketi
     azalt" açıkken `Duration.zero`. Erişilebilirlik kontrolü bundan sonra
     tek yerde; her çağıran `if (disableAnimationsOf)` yazmasın.

2. **`lib/core/widgets/rolling_number.dart`** — basamak bazlı sayaç. Değer
   değişince yalnızca **değişen** basamaklar dikey olarak kayar (odometre),
   sabit kalanlar yerinde durur; 132 → 131'de yalnızca son hane hareket eder.
   - Basamak genişliği zıplamasın diye
     `FontFeature.tabularFigures()` — saat metninde zaten kullanılan çözüm
     (`countdown_screen.dart:397`).
   - Yön: azalan sayıda basamak yukarıdan aşağı, artan sayıda aşağıdan yukarı.
     Geri sayım azalır, odak süresi artar; ikisi de doğru yöne aksın.
   - Hane sayısı değişince (100 → 99) düzenin genişliği değişir; `AnimatedSize`
     ya da sabit genişlik — hangisi seçilirse gerekçesi `DECISIONS.md`ye.
   - `TextStyle` dışarıdan verilir: `AppTypography.counter` ve `display`in
     ikisiyle de çalışmalı, `ShaderMask` içinde de doğru çizilmeli (gün sayısı
     krom gradyanın altında).

3. **Uygulama yerleri:**
   - Ekran 02 gün sayısı (`countdown_screen.dart:385`, `ShaderMask` içinde).
   - Ekran 02 "bugün" kartının saat/dakikası (`todayParts.hours/minutes`,
     satır 454-462) ve seri rozetinin sayısı (satır 440).
   - Ekran 06 istatistik sayıları (`stats_screen.dart` — kümülatif odak, günlük
     ortalama, en uzun seri, tamamlanma oranı).
   - Ekran 04 rozet sayacı (`$unlockedCount/7`).
   - `hh:mm:ss` saniye sayacına **uygulanmayacak**: saniyede bir kayan üç hane
     odak vaadine aykırı ve boşta 60 fps demek. Bu bilinçli bir dışarıda
     bırakma, `DECISIONS.md`ye gerekçesiyle yazılsın.

4. **Oran geçişleri:** `CountdownRingPainter.progressRatio` ve
   `SessionRingPainter.progress` `TweenAnimationBuilder<double>` ile
   (`AppMotion.slow`, `AppMotion.standard`). Odak halkası saniyede bir zaten
   ilerliyor — orada tween **yok**, yalnızca seans başında 0'a/ilk değere
   yerleşirken. Geri sayım halkası sınav değişiminde ve gün dönümünde akar.

**DoD / testler** (`test/core/rolling_number_test.dart`,
`test/features/countdown/`):
- Değer değişince ara karede eski ve yeni basamak **birlikte** ağaçta; animasyon
  bitince yalnızca yeni değer.
- Değişmeyen basamaklar hiç hareket etmiyor (132 → 131'de ilk iki hane sabit).
- `disableAnimations: true` (`MediaQueryData(disableAnimations: true)`) altında
  ara kare yok, ilk karede son değer.
- `AppMotion.respectingMotion` reduce-motion'da `Duration.zero` döndürüyor.
- `RiseIn`in mevcut testi (`test/core/rise_in_test.dart`) token taşımasından
  sonra da geçiyor.

Kapanış: `flutter analyze` + `flutter test`, `DECISIONS.md`ye "Madde 18" başlığı,
tek commit.

---

## 19. Tamamlama anı — seans bitişi, rozet açılışı, seri artışı

**Neden:** uygulamanın en duygusal üç anı şu an tamamen sessiz. 25 dakika odak
bitiyor ve ekran öylece mola ekranına geçiyor; yedi rozetten biri açılıyor ve
dialog hiçbir şey söylemeden beliriyor; seri 6'dan 7'ye çıkıyor ve rozet aynı
karede yeni sayıyı gösteriyor. Kullanıcının uygulamaya dönme sebebi tam olarak
bu üç an; hiçbirinin karşılığı yok.

**Madde 18'e bağımlı** (`AppMotion` token'ları ve `respectingMotion`).

**Yapılacaklar:**

1. **Seans bitişi** (`focus_session_screen.dart`, `PomodoroController`'ın odak →
   mola geçişi): halka son %5'i doldurup tamamlandığında bir kez
   `HapticFeedback.mediumImpact()` (`package:flutter/services.dart`, yeni
   bağımlılık yok) + halkanın renk geçişi (`ember` → `mint`, `AppMotion.slow`).
   Mola ekranına geçiş bu animasyon bittikten sonra.
   - **§6.4 çatışması yok:** bu hareket seans **bittiği anda** çalışıyor, yani
     odak süresi dolmuşken. Süren seans boyunca hiçbir yeni kare üretilmiyor.
     Bu gerekçe `DECISIONS.md`ye yazılsın; §6.4 taraması (`test/performance/`)
     yanlış alarm veriyorsa taramanın kapsamı netleştirilsin.
   - Duraklatılmış seansta ya da iptalde **çalışmaz** — yalnızca doğal bitişte.

2. **Rozet açılışı** (`badges_screen.dart`'ın dialogu +
   `BadgeUnlockService.evaluateAfterFocusCompletion()`'ın döndürdüğü anahtarlar):
   dialog kartı `AppMotion.pop` eğrisiyle 0.92 → 1.0 ölçekte gelsin, rozet
   ikonunun arkasında **tek seferlik** bir halo (opaklık 0.45 → 0, 600ms).
   `HapticFeedback.heavyImpact()` bir kez.
   - Halo sürekli nabız **atmayacak** — bir kez sönüp bitecek. Sürekli olan her
     şey SPEC §6.4'ün yasakladığı sınıfa girer.
   - Aynı çağrıda birden fazla rozet açılabiliyor (interstitial bastırma mantığı
     bunu varsayıyor, madde 6); dialoglar sırayla mı, tek dialogda mı — karar
     `DECISIONS.md`ye.

3. **Seri artışı** (Ekran 02'nin `streak > 0` rozeti, `countdown_screen.dart:430`):
   sayı büyüdüğünde alev ikonu `AppMotion.pop` ile 1.0 → 1.25 → 1.0. Madde 18'in
   `RollingNumber`ı sayıyı zaten çeviriyor; bu yalnızca ikonun eşlik etmesi.
   Yalnızca **artışta**; ekran her açıldığında değil (`didUpdateWidget` ile
   önceki değere bak, ilk build'de çalışma).

4. **Haptic ayarı:** ayarlar ekranında haptic anahtarı yok. Üç seçenek —
   (a) `AppSettings`e yeni bir `hapticsEnabled` kolonu + göç, (b) sistemin kendi
   dokunsal geri bildirim ayarına güven (`HapticFeedback` zaten ona saygı
   duyuyor), (c) hiç haptic ekleme. **(b) öneriliyor**: yeni kolon + göç +
   ARB dizesi, kullanıcının işletim sisteminde zaten verdiği bir karar için
   fazla maliyet. Seçim gerekçesiyle `DECISIONS.md`ye.

**DoD / testler** (`test/features/focus_session/`, `test/features/badges/`,
`test/features/countdown/`):
- Odak doğal bitişinde tamamlama animasyonu bir kez çalışıyor; **iptalde ve
  duraklatmada çalışmıyor** (karşı kontrol).
- Seans **sürerken** hiçbir yeni animasyon denetleyicisi tik atmıyor — §6.4
  regresyonu.
- Rozet halosu bitiyor: animasyon süresinden sonra `pumpAndSettle` takılmıyor
  (sonsuz animasyon testi kilitler, bu testin asıl değeri bu).
- Seri rozeti ilk build'de pop yapmıyor, yalnızca değer arttığında yapıyor.
- Reduce-motion altında üçü de anında son hâlinde.

Kapanış: `flutter analyze` + `flutter test`, `DECISIONS.md`ye "Madde 19",
tek commit.

---

## 20. Rota geçişleri + dokunma geri bildirimi

**Neden:** beş sekme arasında geçiş Material'ın varsayılan sayfa animasyonuyla
oluyor — uygulamanın kendi kimliği yok. Alt çubuğun aktif hapı sekme değişince
bir yerden diğerine ışınlanıyor. Birincil CTA'da (`countdown_screen.dart:533`)
yalnızca jenerik `InkWell` dalgası var; basıldığını hissettiren bir şey yok.

**Madde 18'e bağımlı** (`AppMotion`).

**Yapılacaklar:**

1. **Rota geçişleri** (`lib/core/router/app_router.dart` — şu an hiç
   `pageBuilder` yok, hepsi varsayılan): `CustomTransitionPage` ile
   - Sekmeler arası (yatay kardeşler): fade-through — çıkan opaklıkla gider,
     giren opaklık + 1.02 → 1.0 ölçekle gelir. `AppMotion.base`.
   - Üste `push` edilenler (odak seansı, sınav ekleme, başarı kartı): aşağıdan
     yukarı kayma + fade. `AppMotion.base`, `AppMotion.enter`.
   - Reduce-motion'da ikisi de `NoTransitionPage`.

2. **Alt çubuk hapının kayması** (`bottom_nav_bar.dart`) — **dikkat, burada bir
   yapısal engel var:** beş sekmenin her biri ayrı bir rota ve çubuk her rotada
   sıfırdan kuruluyor. Hap bu yüzden basit bir `AnimatedPositioned` ile
   kayamaz; iki yol var:
   - **(a) `Hero`** — hapa ortak bir tag ver, sekmeden sekmeye uçsun.
     Hapın içeriği sekmeye göre değiştiği için (`_PillStyle`: etiket, ikon,
     gradyan) `flightShuttleBuilder` gerekiyor; genişlik de değişiyor
     (`flex: 16` ↔ `flex: 10`), `Hero` onu kendi enterpole eder. **Önerilen.**
   - **(b) Yapmamak** — fade-through geçişte çubuğun tamamı zaten çapraz
     soluyor, hap onunla birlikte yerini alıyor. Sıfır risk, daha az etki.
   - Hangisi seçilirse `DECISIONS.md`ye gerekçesiyle; (a) denenip çalışmazsa
     (b)'ye düşmek meşru bir sonuç, yarım bırakılmış bir `Hero` değil.

3. **`lib/core/widgets/app_pressable.dart`** — basılı tutulduğunda çocuğu
   0.97'ye küçültüp bırakınca `AppMotion.pop` ile geri getiren sarmalayıcı
   (`AppMotion.instant`). Uygulanacağı yerler: Ekran 02'nin "… DAKİKA ODAKLAN"
   butonu, `AppPillButton`, sınav seçim sheet'inin satırları, Ekran 05'in
   PAYLAŞ/Kaydet/Kopyala üçlüsü.
   - Mevcut `InkWell` dalgaları **kaldırılmıyor**; ölçek onların üstüne biniyor.
     Dalga "nereye bastım"ı, ölçek "bastım"ı söyler.
   - Dokunma hedefi küçülmemeli: ölçek `Transform`la, düzenle değil.

**DoD / testler** (`test/core/`, `test/features/`):
- Sekme geçişinde ara karede iki ekran birlikte ağaçta; `pumpAndSettle`
  sonrası yalnızca hedef ekran.
- Reduce-motion'da geçiş yok — ilk karede hedef ekran.
- Madde 13'ün gezinme yığını testi ("dört sekme arasında dolaşmak yığını
  büyütmüyor") `CustomTransitionPage`e geçtikten sonra da geçiyor.
- `AppPressable` basılıyken ölçek < 1, bırakınca 1'e dönüyor; sardığı butonun
  `onTap`i hâlâ tetikleniyor (ölçek jesti yutmamalı).
- Madde 12'nin 48px dokunma hedefi testleri hâlâ geçiyor.

Kapanış: `flutter analyze` + `flutter test`, `DECISIONS.md`ye "Madde 20",
tek commit.

---

## Yayın öncesi son kontrol (SPEC §10 DoD)

- [x] `flutter analyze` 0 hata / 0 uyarı
- [ ] Her ekran prototiple ayırt edilemiyor *(madde 10 — metin/palet/tipografi
      doğrulandı; madde 11'de emülatörde 7 ekran çizdirildi, gerçek cihazda
      yan yana karşılaştırma kaldı)*
- [x] Demo sayılarının hiçbiri kodda yok (132, 42, %86, 6, 3/7, 11)
- [x] 10 dk arka plandan dönüşte sayaç doğru
- [x] Uygulama öldürülüp açıldığında aktif seans kurtarılıyor
- [x] Cihaz saati geriye alındığında seans yanlış "tamamlandı" sayılmıyor
- [x] İzinler reddedildiğinde uygulama tam çalışıyor
- [x] Tarihi geçmiş sınav → Ekran 08, rozet/geçmiş korunuyor
- [x] Ekran 03'te hiçbir reklam isteği atılmıyor
- [x] `isPremium` iken hiçbir reklam isteği atılmıyor
- [x] Kart export'u tam 1080×1920
- [x] Odak ekranı `--profile` modda sürekli 60 fps *(madde 11 — emülatörde
      375 kare, ort. 60.0 fps, 33 ms üstü kare yok; gerçek ARM cihaz teyidi
      hâlâ önerilir)*
- [x] Android `--profile` / `--release` derlemesi geçiyor *(madde 11 — iki
      blocker düzeltildi)*
- [ ] Launcher simgesi üretildi *(madde 11 — hâlâ Flutter varsayılanı)*
- [ ] Yayın çıktısı gerçek anahtarla imzalı *(`key.properties` yok, AAB şu an
      `CN=Android Debug`)*
- [x] Odak seansında dekoratif animasyonlar duruyor
- [x] Kodda hard-coded Türkçe metin yok
- [x] Testler geçiyor *(238 test, `flutter test`)*
- [x] `DECISIONS.md` her kararı gerekçesiyle içeriyor

Play Console tarafının kendi kontrol listesi ayrı: `docs/play/RELEASE.md` §7.
