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
**Madde 18, 19 ve 20 bitti**; hareket katmanı tamam.

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

# Hareket geçişi (madde 18-20) ✅ bitti

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
- **Cihazda doğrulandı** — emülatörde sınav değişimi (282 → 247) kare kare izlendi:
  baştaki `2` hiç kımıldamıyor, yalnızca son iki hane yukarıdan aşağı kayıyor, krom
  gradyan kayan hanelerin üstünde doğru duruyor, halka oranı sıçramadan akıyor.
  Ayrıntı: `DECISIONS.md` "Madde 18-19-20 — emülatör doğrulaması".

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

## 19. Tamamlama anı — seans bitişi, rozet açılışı, seri artışı ✅ bitti

251 test geçiyor (+13). Kararlar: `DECISIONS.md` "Madde 19".

- **Seans bitişi:** `focusRunning → breakRunning` geçişinde mola gövdesi 420ms
  bekliyor; o pencerede odak gövdesi duruyor, sayaç 00:00'da ve dolu halka
  közden naneye dönüyor (`_CompletionRing`, `AppMotion.slow` + `standard`).
  Denetim düğmeleri `IgnorePointer` ile kapalı. **Yalnızca doğal bitişte** —
  iptal (`→ idle`) ve duraklatma (`→ focusPaused`) pencereyi açmıyor, ikisinin
  de karşı kontrol testi var. §6.4 çatışması yok: hareket seans **bittiği anda**
  başlıyor, süren seans boyunca fazladan kare üretmiyor.
- **Rozet dialogu:** kart `AppMotion.pop` ile 0.92 → 1.0; rozet ikonunun
  arkasında tek seferlik halo (0.45 → 0, 600ms), yalnızca **açılmış** rozette.
  Halo nabız atmıyor, bir kez sönüyor — testin `pumpAndSettle`i bunun kilidi.
  Otomatik açılan bir rozet dialogu **eklenmedi**: açılış anının yüzeyi bildirim
  (SPEC Ekran 12), o yüzden "birden fazla rozet: sırayla mı, tek dialogda mı"
  sorusu bu maddede doğmuyor.
- **Seri artışı:** `core/widgets/pop_on_increase.dart` — alev ikonu 1.0 → 1.25 →
  1.0, yalnızca değer **arttığında**. İlk build'de ve değer düşünce çalışmıyor;
  ölçek tam 1'ken ağaca `Transform` bile girmiyor.
- **Haptik zaten vardı** — maddenin 4. şıkkı güncel değildi. `hapticEnabled`
  kolonu Faz 2'den beri şemada, anahtar Ekran 07'de, `mediumImpact` her faz
  geçişinde (seans bitişi dahil) ve `heavyImpact` rozet açılışında, ikisi de
  ayara bağlı. Bu maddede yalnızca görsel katman kodlandı.
- **Cihazda doğrulandı** — doğal bitişte sayaç 00:00'da duruyor, dolu halka közden
  naneye enterpole oluyor, sonra mola gövdesi geliyor. Seri artışının `PopOnIncrease`i
  cihazda **gözlenemedi**: değer Ekran 02 sahne dışındayken değişiyor, dönüşte ilk
  build oluyor ve ilk build'de animasyon tasarım gereği yok — o davranış widget
  testinde duruyor. Ayrıntı: `DECISIONS.md` "Madde 18-19-20 — emülatör doğrulaması".

---

## 20. Rota geçişleri + dokunma geri bildirimi ✅ bitti

258 test geçiyor (+7). Kararlar: `DECISIONS.md` "Madde 20".

- **Rota geçişleri:** dokuz rotanın hepsi `pageBuilder` (`CustomTransitionPage`),
  iki dil. Sekmeler arası fade-through (opaklık + 1.02 → 1.0 ölçek,
  `AppMotion.base` + `enter`); üste `push` edilenler (odak seansı, sınav ekleme)
  aşağıdan yukarı 0.04 kayma + opaklık. Ekran 08 de sekme dilinde: oraya da
  Ekran 02'nin **yerine** gidiliyor. Çıkan ekranın ayrı animasyonu yok — alttaki
  rota olduğu yerde duruyor, ikisini birden soldurmak çubuğun opak zeminini
  yarı saydam gösterirdi. Reduce-motion `NoTransitionPage` yerine **sıfır süre**:
  gözlemlenebilir olarak aynı, kapı tek yerde (`AppMotion.respectingMotion`).
- **Alt çubuk hapı: (a) şıkkı tuttu — `Hero`.** Ortak etiket + `flightShuttleBuilder`
  (hapın içeriği sekmeye göre değiştiği için iki hap çapraz soluyor, dikdörtgeni
  `Hero` taşıyor). Şıkkın tek riski `pushReplacement`ti; bugünkü Flutter'da
  `HeroController`ın kancası `didChangeTop`, üstteki rota nasıl değişirse değişsin
  tetikleniyor. (b)'ye düşmek gerekmedi. Reduce-motion'da `Hero` hiç kurulmuyor.
- **`core/widgets/app_pressable.dart`:** basılıyken 0.97, bırakınca
  `AppMotion.pop.flipped` ile 1'e. CTA, `AppPillButton`, sınav seçim satırları
  (orada 0.99 — satır geniş ve alçak), Ekran 05'in üç butonu. `Listener` ile,
  `GestureDetector` değil: jest arenasına hiç girmiyor, `onTap` yine `InkWell`in.
  Dalgalar kaldırılmadı, ölçek üstlerine biniyor.
- **Yolda çıkan gerçek hata:** `PopOnIncrease`in "ölçek 1'ken `Transform`u ağaca
  sokma" deseni buraya kopyalanınca **birincil CTA tamamen ölü kaldı** —
  `Transform`u basış anında araya sokmak `InkWell`in alt ağacını yeniden kuruyor
  ve tanıyıcıyı jestin ortasında iptal ediyor. `Transform` artık her zaman ağaçta;
  testin `expect(taps, 1)` satırı bunun kilidi.
- **Madde 12 ve 13'ün testleri değişmeden geçiyor** (48px dokunma hedefi, gezinme
  yığını büyümüyor).
- **Cihazda doğrulandı — ve bir hata çıktı.** Sekme geçişi çapraz soluyor, hap yuvadan
  yuvaya uçuyor, CTA basılıyken 0.97'ye iniyor ve `onTap` çalışıyor (ölü CTA regresyonu
  cihazda da yok). Ama **uçan hapın etiketi sarı çift alt çizgiliydi**: mekik `Overlay`de
  çizildiği için çubuğun `Material`ı ağacın o dalında yok ve `Text`, `WidgetsApp`in geri
  düşüş biçimini miras alıyordu. Mekik saydam bir `Material`a sarıldı; uçuşun ortasında
  `decoration`a bakan bir regresyon testi eklendi (259 test, +1). Ayrıntı: `DECISIONS.md`
  "Madde 18-19-20 — emülatör doğrulaması".

---

## 21. Son düzlük — geri sayımın işaretini çevirme ✅ bitti

284 test geçiyor (+6). Kararlar: `DECISIONS.md` "Son düzlük — geri sayımın
işaretini çevirmek".

- **Sorun:** kahraman sayı sınav yaklaştıkça daha korkutucu okunuyordu
  (247 → 12) — tam da bırakma anında ekranın en büyük tipografisi kaygıyı
  büyütüyordu. Biriken emek ise hiçbir yerde kahraman değildi (Ekran 06 haftalık
  bakıyor).
- **Kural:** kalan gün ≤ 30 **ve** o sınav için biriken emek ≥ 1 saat ise halka
  içindeki kahraman sayı "kalan gün" olmaktan çıkıp **biriken odak saati**
  oluyor; altındaki kicker `GÜN KALDI` → `SAAT ODAKLANDIN`. İkinci koşul şart:
  emeksiz kullanıcıda ekran "0 SAAT ODAKLANDIN"a düşer, yani çevirmenin tam
  tersi bir mesaj verirdi.
- **Sayı sınav başına** (`PomodoroSessions.examId`), tüm zamanların toplamı
  değil — cümle sınav adıyla kuruluyor, başka hedefin saatleri o toplama
  giremez. Yeni sütun gerekmedi, `examId` seans açılırken zaten yazılıyordu.
- **Kalan gün kaybolmuyor,** meta satırına iniyor: `12 GÜN • 04:22:31 •
  12 Haziran 2027`. Saniye nabzı duruyor; satır `FittedBox(scaleDown)` ile
  halkanın iç çemberini aşmaya karşı korunuyor. Halkanın oranı değişmedi — o
  zaten dolan, yani ileriye bakan bir gösterge.
- **Yeni ARB anahtarları:** `countdownFocusedHoursUnit`,
  `countdownDaysLeftInline`. İkisinin glifleri de font subset'lerinde (`cmap`
  tarandı), sessiz Roboto düşüşü yok.
- **Emülatör doğrulandı (2026-09-17).** Cihaz saati sınavdan 11 gün öncesine
  alındı: kahraman sayı `100`, kicker `SAAT ODAKLANDIN`, kalan gün meta
  satırına indi. **Ama meta satırı halkanın altına giriyor** — madde 32.

---

## 22. Görünen ilerleme — kilitli rozet ve saat merdiveni ✅ bitti

296 test geçiyor (+12). Kararlar: `DECISIONS.md` "Görünen ilerleme — kilitli
rozet ve saat merdiveni".

- **Sorun:** kilitli rozet yalnızca kuralı yazıyordu, yani 61 saat biriktirmiş
  kullanıcının kartı ilk gündekiyle birebir aynıydı — ulaşılamaz bir duvar.
  Ayrıca yedi rozet bitince hedef tükeniyordu.
- **Halka + sayaç:** her kilitli ve **sayılabilir** rozetin ikonu 2px'lik bir
  ilerleme halkasıyla çevrili, kural metninin altında çıplak sayaç ("61/100").
  Birim yazılmıyor, kural metni zaten söylüyor; ekran okuyucuya sözlü karşılık
  gidiyor. Hedefi 1 olan rozetlerde (Sabah Yıldızı, Gece Nöbeti, İlk Kıvılcım)
  halka da sayaç da yok — "0/1" ilerleme değil, kuralın tekrarı olurdu.
- **Merdiven:** tek "100 Saat Kulübü" yerine 10 → 50 → 100 → 250. Dördü de aynı
  kümülatif saate bakıyor, yalnızca hedefleri farklı; göç gerekmedi.
  `hundred_hours` anahtarı ve adı aynen duruyor (yayınlanmış `badgeKey`
  değiştirilemez). Yeni anahtarlar: `ten_hours`, `fifty_hours`,
  `two_fifty_hours`.
- **İlerleme kuralın kendisinden türüyor:** `evaluateEarnedBadgeKeys` artık
  `evaluateBadgeProgress`in süzülmüş hâli — halkanın dolduğu an ile rozetin
  açıldığı an ayrışamıyor.
- **Kart durumu = DB kaydı ∪ kural.** Güncellemeden önce biriken emek yüzünden
  10/50 saat kartları bir sonraki seansa kadar kilitli kalsaydı "61/10" yazan
  taşmış kartlar çıkardı. Açılış anı (bildirim, halo, haptik) yine DB tarafında.
- **Yan bulgu:** kartın ikon dairesi meğer hiç çizilmiyormuş — çocuksuz
  `DecoratedBox`, `Stack`in gevşek kısıtlarında sıfır boyuta iniyor. Daire
  diyalogdaki gibi `SizedBox` çocukla ölçülendirildi.
- **Yeni ARB anahtarları:** `badgeTenHours*`, `badgeFiftyHours*`,
  `badgeTwoFiftyHours*`, `badgeProgressCounter`, `badgeProgressSemantics`.
- **Emülatör doğrulandı (2026-09-17).** 100 saatlik tohumlanmış geçmişte
  merdivenin dördü de göründü: 10/50/100 açık, kilitli "250 Saat Kulübü"
  halkası kısmen dolu ve çıplak sayaç `100/250` yazıyor. İkon daireleri
  çiziliyor — "yan bulgu"daki `SizedBox` düzeltmesi cihazda da tutuyor.

---

## 23. Meşale kademe avatarı ✅ bitti

359 test geçiyor (+63). Kararlar: `DECISIONS.md` "Meşale kademe avatarı".
Tasarım: `docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md`.

**Sorun.** Meşale yalnızca seans içinde büyüyüp sıfırlanan bir süstü —
kümülatif odak saatine bağlı kalıcı bir kimlik yoktu ve ana ekranda
uygulamayı geri açtıracak "sonraki kademeye kaç saat" diyen bir sebep yoktu.

- **`lib/domain/flame/flame_tier.dart`** — 10 basamaklı `kFlameTierLadder`
  (K1 Kıvılcım 0 sa → K10 Güneş 400 sa), saat rozetleriyle (10/50/100/250)
  K4/K6/K7/K9'da hizalı; `flameTierFor()` saf fonksiyon, `flameTierProvider`
  ile okunuyor.
- **`FlameWidget`** `lib/features/focus_session/`den `lib/core/widgets/`e
  taşındı, iki eksenli API'ye kavuştu: kademe (boyut, palet, süsleme —
  kalıcı) ile seans (çekirdek parlaklığı, titreşim, kıvılcım — geçici)
  ayrıştı; odak ekranı yeni API'ye bağlandı.
- **Ekran 04'e kahraman kart** (`FlameAvatarCard`): kademe adı, `62/100 sa`
  sayacı, "Sonraki kademeye 38 saat"; mevcut rozet grid'i değişmedi.
- **Altıncı ana ekran widget'ı ("Meşale")** — `FlameTierLadder.kt` +
  `FlameRenderer.kt` + `FlameWidgetProvider.kt`; dokunuş `/badges`'e gidiyor.
- **`cumulativeFocusSeconds`** tek yeni payload anahtarı; kademe/kalan
  saat/oran Kotlin'de hesaplanıyor (türetilmiş değer Dart'tan okunmaz kuralı).

**Doğrulama.** `flutter analyze` temiz, 359 test geçiyor, `flutter build apk
--release` derleniyor. Emülatörde (API 36) görsel doğrulama yapıldı: alev
seans ilerlerken boyutunu koruyor, açık/koyu tema kontrastı çalışıyor,
duraklamada tam gri, widget seçicide doğru ad/boyut/önizlemeyle listeleniyor
ve dokunuş Rozetler'e gidiyor. **Açık iş:** emülatör geçmiş verisiyle
seed'lenemediği için yalnızca K1 hiç gözlemlenebildi —
`FlameRenderer`'ın közlü taban (K4+), kıvılcım (K6+) ve hâle (K8+) dalları
hiçbir yerde çalıştırılmadı. Öneri: seed'li geçmişle bir debug koşumu ya da
`FlameRenderer` için Kotlin/Robolectric birim testleri. Ayrıntı:
`DECISIONS.md` "Meşale kademe avatarı".

---

## 24. Haftalık hedef ✅ bitti

**Sorun.** Uygulamada tek zaman ufku "bugün" (Ekran 02'nin `BUGÜN` kartı) ve
"sınava kalan gün". İkisinin arası boş: bir günü kaçıran kullanıcı için o gün
zaten kapanmış, sınav ise kapatılamayacak kadar uzak. Haftalık hedef
kaçırılan günü telafi edilebilir kılar ve hafta içinde birden çok seans
başlatmaya sebep verir.

**Kanıt.** `weeklyGoal` / `weeklyTarget` kodda hiç geçmiyor; `AppSettings`
tablosunda (`lib/services/storage/tables.dart:51-60`) yalnızca `focusMinutes`,
`shortBreakMinutes`, `longBreakMinutes`, `selectedTemplateIndex`,
`activeExamId` var.

371 test geçiyor (+12). Kararlar: `DECISIONS.md` "Haftalık hedef".
Tasarım: `docs/superpowers/specs/2026-09-13-haftalik-hedef-design.md`.

- **Hafta tanımı yazılmadı — asıl karar bu.** Hedef `weeklySummaryProvider`ı
  tüketiyor, kendi pencere hesabını kurmuyor; "iki farklı hafta kavramı
  çıkmasın" şartı testle değil **kurguyla** sağlanıyor — sapabilecek ikinci
  bir hesap yok. `WeeklyGoalProgress` (`lib/domain/stats/weekly_goal.dart`)
  yalnızca iki `int` alıyor, içinde hiç tarih geçmiyor.
- **`AppSettings.weeklyGoalMinutes`** (drift v4 → v5), varsayılan 300 dk =
  5 sa/hafta. Kolon dakika (tablodaki diğer üç süreyle aynı), slider saat
  (haftalık hedefi dakikayla konuşmak okunmaz).
- **Ekran 07'de 0–30 saat slider'ı**; **0 = kapalı**, değer alanı "Kapalı"
  yazıyor ve Ekran 02'deki satır hiç çizilmiyor. `_DurationSlider`ın değer
  etiketi dışarı alındı (birimi dakikaya çivili değil artık).
- **Ekran 02'de `BUGÜN` kartının ikinci satırı:** `BU HAFTA · 4sa 30dk / 5sa`
  + çubuk; hedef karşılanınca çubuk közden naneye dönüp "Hedef tamam" oluyor.
  Boş haftada gizlenmiyor — günlük noktaların aksine, %0 eksiklik değil
  haftanın başıdır.
- **Yolda çıkan gerçek sorun: Ekran 02'nin dikey bütçesi yokmuş.** 390×844
  ekranda 90dp'lik adaptive banner'la toplam boşluk 26px, satır ise en sıkı
  hâliyle 43px istiyordu. Gövde artık **yalnızca sığmadığında** kayıyor
  (`LayoutBuilder` + `SingleChildScrollView` + `minHeight`), banner kaydırma
  alanının dışına alındı (`Spacer` kalktı, reklam da kaydırılıp kaybolmuyor).
  Prototipin hiçbir ölçüsü değişmedi. Ekran bu madde olmadan da büyük sistem
  yazı tipinde taşıyordu.
- **Kapsam dışı:** pazar bildiriminin hedefe göre konuşması ("hedefinin
  %80'i") — dört bildirim varyantını sekize çıkarır ve `weekly_summary.dart`
  yüzde yerine farkı seçme kararıyla çelişir. Ayrı madde olmalı.
- **Kabul karşılandı:** hedef değiştirilebiliyor, Ekran 02'de görünüyor,
  hafta sınırı `weekly_summary.dart` ile aynı ve testle çivilenmiş.
- **Emülatör doğrulandı (2026-09-17).** `BU HAFTA 55dk / 5sa` satırı Ekran
  02'de `BUGÜN`ün altında göründü ve bir seans sonrası `1sa 20dk`ya yürüdü;
  varsayılan hedef göçten gelen 300 dk.

---

## 25. Interstitial'ı mola başlangıcından çıkar ✅ bitti

**Sorun.** Reklam, ürünün korumayı vaat ettiği tek anı — odak ritüelinin
molasını — kesiyor. Gelir aynı kalacak şekilde taşınabilir.

377 test geçiyor (+6). Kararlar: `DECISIONS.md` "Madde 25 — Interstitial'ın
yeri". SPEC.md §7.2 ve Ekran 09 binding tablosu güncellendi.

- **Yeni an `_completeBreak`:** mola dolup uygulama `idle`'a döndüğü, geri
  sayıma dönülen an. `maybeShowOnBreakStart` → `maybeShowOnCycleComplete`.
  Sıklık kuralı (3 pomodoroda 1), 180 sn penceresi, uzak bayrak ve
  premium/onay kapısı aynen korundu — sayaç gösterimleri değil tamamlanan
  odak seanslarını saydığı için gösterim sayısı da değişmedi.
- **Yolda çıkan gerçek sorun: değerlendirme istemiyle çakışma.** İkisi de tam
  3. tamamlanan odak seansında düşüyor ve artık aynı satırda. Eski
  yerleşimde farklı anlarda oldukları için kimse fark etmemişti.
  `requestIfEligible()` artık `Future<bool>` ve çıktısı interstitial'ın
  `otherPromptShown` kapısını besliyor; değerlendirme istemi öncelikli (bir
  kez sorulabiliyor, reklamın üç seans sonra yeni şansı var).
- **Kutlama bastırması gereksizleşti.** `badgeUnlocked` parametresi
  hastalığı değil belirtiyi tedavi ediyordu: kutlama molanın **başında**,
  reklam artık **sonunda**. `_offerCelebration` `Future<void>` oldu.
- **`ODAĞA DÖN` reklam çıkarmıyor.** Teknik olarak o da `idle`'a dönüş ama
  niyeti odağa dönmek; değerlendirme istemi de orada tetiklenmiyor. Molasını
  hep erken bitiren kullanıcı hiç interstitial görmeyecek — bilinçli kabul
  edilen maliyet.
- **Kapsam dışı:** kart export'u sonrası ikinci bir tetik noktası. Tek
  noktada toplanan kuralın ikinci bir çağıranı, `InterstitialManager`ın
  sınıf yorumunun tam da uyardığı şey.
- **Kabul karşılandı:** mola başlangıcında interstitial çıkmıyor (testle
  çivili), sıklık kuralı korunuyor, `interstitial_manager` testleri yeni ana
  göre güncel.
- **Emülatör doğrulandı (2026-09-17).** Üç molanın üçünde de başlangıçta
  interstitial çıkmadı (logcat'te tek `interstitial` izi bile yok); 1. molanın
  başında yerine kutlama sayfası açıldı. 3. pomodoronun mola **sonunda** önce
  `requestInAppReview` çağrıldı — Play Store'suz `google_apis` imajında servis
  bulunamadığı için istem düştü ve sıra interstitial'a geldi. Yani
  `otherPromptShown` kapısı tasarlandığı gibi: değerlendirme gösterilebilseydi
  reklam bastırılacaktı.

---

## 26. Dönüş yolu — 3 gün yokluk sonrası ✅ bitti

**Sorun.** Seri koparsa kullanıcıyı geri çağıran ya da karşılayan hiçbir an
yok. Seri koruma mekaniği (SPEC §5.3) zaten var ama kullanıcıya bunu söyleyen
bir yüzey yok — döndüğünde onu suçlayan bir sıfır tablosu karşılıyor.

394 test geçiyor (+16). Tasarım:
`docs/superpowers/specs/2026-09-17-donus-yolu-design.md`, plan:
`docs/superpowers/plans/2026-09-17-donus-yolu.md`. Kararlar: `DECISIONS.md`
"Madde 26 — Dönüş yolu".

- **Saf katman `comeback_status.dart`:** `streak_calculator.dart` ile aynı imza
  ve aynı felsefe — saklanan bayrak yok, yokluk tamamlanmış odak seanslarının
  geçmişinden türetiliyor. Üç çıktı: `absentDays`, `welcomeDue`,
  `reminderAtUtc`.
- **Bildirim ileriye kuruluyor.** Mevcut iki zamanlı bildirimden tek farkı bu:
  yokluk çağrısı tanımı gereği kullanıcı uygulamayı **açmazken** düşmeli, o
  yüzden son değerlendirme noktasında (açılış + her odak tamamlanışı) üç gün
  sonrasının 21:00 TSİ anına kurulup dönüşte yeniden hesaplanıyor. Arka plan
  işi yok, "iptal et → kapılar → kur" kalıbı aynen korundu.
- **Pencere tek gün.** Hedef an kaçarsa ileriye taşınmıyor: on gün yok olan
  kullanıcı bildirim yığınıyla karşılaşmıyor. Winback dizisi (3./7./14. gün)
  bilinçli olarak kapsam dışı.
- **Eşik üç tamamlanmış seans** — `AppReviewService.minCompletedFocusSessions`
  ile aynı sayı ve aynı gerekçe: uygulamayı bir kez deneyip bırakana geri çağrı
  göndermek ürünün kaçındığı tona kayardı.
- **Yeni ayar anahtarı yok.** `streakReminderEnabled` ve `streakRisk` kanalı
  paylaşılıyor; ikisi de aynı sözü veriyor ve ayrı kanal kullanıcının kapattığı
  kategoriyi ikiye bölerdi. Drift göçü gerekmedi.
- **Karşılama şeridi bayraksız.** `BUGÜN` kartında, haftalık hedef satırının
  üstünde; korunanı söylüyor ("Kandil kademen ve 3 saat yerinde duruyor") ve
  ilk odak tamamlandığı anda `absentDays` sıfırlandığı için kendiliğinden
  kapanıyor — "gösterildi mi" bayrağı ya da kapatma butonu yok.
- **Kabul karşılandı:** eşik aşılınca bildirim planlanıyor, odak tamamlanınca
  iptal edilip ileriye yeniden kuruluyor, şerit ve eşik altı kapsam dışılığı
  testle çivili.
- **Emülatör doğrulandı (2026-09-17).** Üç odak seansı tamamlandıktan sonra
  `dumpsys alarm` bildirimi tam üç gün sonrasının 21:00 TSİ anına kurulu
  gösterdi (`ScheduledNotificationReceiver`, `exactAllowReason=permission`).
  Cihaz saati o ana alınınca bildirim `streak_risk` kanalında id `1006` ile
  düştü — "Ateşin sönmedi · Kıvılcım kademen ve 55 dakika…". Uygulama
  açılınca karşılama şeridi çıktı ("Kıvılcım kademen ve 55 dakika yerinde
  duruyor") ve ilk odak tamamlanınca bayraksız biçimde kendiliğinden kapandı.

---

## 27. Geri sayım halkasının ölü aralığı ✅ bitti

**Sorun.** Halka formülü `clamp(1 - days/400, 0.06, 1)`: sınava 300 gün kalan
kullanıcıda halka aylarca ~%25'te duruyor. Kullanıcı 40 saat çalışsa da halka
kıpırdamıyor — geçen zamanı gösteriyor, harcanan emeği değil. Madde 21 (son
düzlük) doğru içgüdüydü ama yalnızca sonda devreye giriyor.

395 test geçiyor (+1). Kararlar: `DECISIONS.md` "Madde 27 — Geri sayım
halkasının emek ekseni". Ayrı tasarım belgesi yok: üç seçenek ROADMAP'te zaten
yazılıydı, karar doğrudan alındı.

- **Seçilen yol: ikinci eksen.** Halkayı tamamen emeğe bağlamak "hedef saat"
  diye yeni bir kural icat etmeyi gerektiriyordu ve ekran sınava kalan zamanı
  görsel olarak anlatmayı bırakırdı; ölçeği yeniden eşlemek ise şikâyetin
  özünü çözmezdi (halka yine yalnızca zamanı gösterirdi). Zaman yayı aynen
  duruyor, emeğin kendi yayı oldu.
- **Emek ekseni = bu haftanın odağı / haftalık hedef.** Madde 24'ün
  `weeklyGoalProgressProvider`ı okunuyor — yeni ayar, yeni kolon, drift göçü ve
  ikinci bir hesap yok. Halkanın yayı ile `BUGÜN` kartının çubuğu aynı
  `WeeklyGoalProgress` örneğinden besleniyor, ayrışamazlar.
- **Hedef kapalıyken yay hiç çizilmiyor** (`effortRatio` `0.0` değil `null`):
  boş bir yay "hedefinin %0'ındasın" derdi, oysa kullanıcının hedefi yok.
- **Prototipin hiçbir ölçüsü değişmedi.** Yay var olan boş banda yerleşti
  (r=119, kalınlık 4; zaman izinin iç kenarı 125.5, kesikli çember 112).
  Zaman yayının yarıçapı, kalınlığı ve gradyanı aynen korundu.
- **Ton `_WeeklyGoalRow` ile aynı:** hedefe giderken `ember`, dolunca `mint`.
  Gradyan yok — iki eksen aynı boyayı paylaşsaydı tek gösterge sanılırdı.
- **Yeni ekran okuyucu etiketi yok:** yay, kartın zaten seslendirdiği
  sayıların görsel yankısı; ikinci kez duyurmak aynı bilgiyi iki kez okuturdu.
- **Kabul karşılandı** ve fazlası: halka artık hafta hafta değil **her
  tamamlanan seansta** kıpırdıyor. Karşılığı, paydanın kayan yedi gün olması —
  yay ileri gittiği gibi geri de gidebiliyor; kartın çubuğu da aynısını yapıyor
  ve iki yüzeyin farklı davranması daha kötü olurdu.
- **Kapsam dışı:** ana ekran widget'ının Kotlin ikizi `RingRenderer.kt` yalnızca
  zaman yayını çiziyor; emek yayını oraya taşımak payload'a haftalık hedef
  verisi eklemeyi gerektirir, ayrı madde olmalı.
- **Emülatör doğrulandı (2026-09-17).** Kabul ölçütü birebir kuruldu: aktif
  sınav +300 güne alındı (zaman yayı `1-300/400` = %25'e çivilendi), haftalık
  hedef 10 saate çekildi ve haftalık pencere tohumlandı. Dört durum gözlendi —
  **hafta boş:** yalnızca soluk iz, yay ve leke yok; **4sa 10dk / 10sa:** köz
  yayı 12 yönünden ~150°'ye (%42) gitti, kartın çubuğuyla aynı sayı;
  **10sa / 10sa:** yay nane rengine döndü ve kart "Hedef tamam" dedi;
  **hedef kapalı:** yay da izi de yok, halka madde 27 öncesiyle birebir aynı.
  Zaman yayı dördünde de %25'te kaldı — iki eksen gerçekten bağımsız.
  Ekran görüntüleri `.verify/m27_*.png`, tohumlama `.verify/seed_week.py`.
- **Yan bulgu (madde 27'den değil):** zaman yayının 12 yönündeki başlangıç
  ucunda küçük bir köz lekesi var. `SweepGradient` + `StrokeCap.round`
  birleşiminden geliyor: yuvarlak uç başlangıç açısının biraz gerisine taşıyor
  ve gradyanı ~360°'de, yani `ember` durağında örnekliyor. Hedef kapalı
  karesinde emek yayı hiç çizilmediği hâlde leke durduğu için kaynağı kesin.
  Ayrı madde olmalı.

---

## 28. Alt gezinme çubuğunun bilgi mimarisi ✅ bitti

397 test geçiyor (+2). Kararlar: `DECISIONS.md` "Madde 28".

- **Boşalan yuva odak eylemine geçti.** `storyCard` sekmesi kalktı, yerine
  ikinci yuvada "ODAKLAN" düğmesi duruyor: `AppNavTab` artık dört üyeli ve
  `startFocusFromNav` çubuktan seans başlatıyor. Uygulamanın birincil eylemi
  bugüne kadar yalnızca Ekran 02'deydi — rozetler/veriler/ayarlar ekranındaki
  kullanıcı seans başlatmak için önce sayaca dönmek zorundaydı.
- **Yuva bir sekme değil.** Aktif hâli, hapı, `Hero` uçuşu yok; boyası Ekran
  02'nin birincil düğmesinin küçültülmüş hâli (köz kenarlık, sönen `emberDeep`
  gradyanı, dolu `play`). Beş yuva ve flex oranları (16/10) prototipten
  değişmedi, dokunma hedefi sekmelerle aynı 48px.
- **Seans sürerken yeniden başlatmıyor:** `startFocus` yalnızca faz `idle` iken
  çağrılıyor, aksi hâlde yuva "devam et" gibi davranıp odak ekranını açıyor.
- **Ekran 05 üste binen bir kat oldu.** Rotası `_tabPage` değil `_pushedPage`,
  çubuğu yok, sol üstte Ekran 11'in kapatma düğmesinin aynısı var. Girişleri
  madde 19'dan devralındı: rozet dialogu, rozet açılışı kutlaması, seri eşiği
  kutlaması. Kapatma kullanıcıyı **geldiği** ekrana bırakıyor; sekmeyken yığında
  o ekranın yerini alıyordu.
- **Kademe atlama kutlaması bu maddeye girmedi** — `SessionCelebration`a yeni
  bir tür, kalıcı "son kutlanan kademe" anahtarı ve yeni bir dialog demek.
  Madde 34 olarak ayrıldı.
- **Test altyapısı düzeltmesi (yan kazanım):** `countdown_navigation_test`
  veritabanını artık `tester.runAsync` içinde kuruyor. Sahte zaman kuşağında
  kurulan `NativeDatabase` dosyanın **ilk** testinden sonra hiç açılmıyordu ve
  tek-seferlik her `Future` (ör. `startFocus()`ün ayar okuması) sonsuza kadar
  bekliyordu; yeni testler bu yüzden tek başına geçip takımda düşüyordu.
- **Emülatör doğrulandı (2026-09-17).** Yeni çubuk açık ve koyu temada
  (`.verify/m28_a_sayac.png`, `m28_f_koyu.png`); rozetler ekranından ODAKLAN
  25:00'lık seansı açtı (`m28_c_odak.png`), iptal kullanıcıyı sayaca değil
  **rozetlere** geri bıraktı (`m28_d_donus.png`); rozet dialogundan açılan
  başarı kartı çubuksuz ve kapatma düğmeli (`m28_e_kart.png`), kapatınca yine
  rozetlere döndü.

---

## 29. Aylık ısı haritası (katkı ızgarası) ✅ bitti

416 test geçiyor (+19). Tasarım belgesi:
`docs/superpowers/specs/2026-09-17-aylik-isi-haritasi-design.md`.
Kararlar: `DECISIONS.md` "Madde 29".

- **Ekran 06'ya takvim ızgarası.** Sütunlar Pzt–Paz, satırlar haftalar; pencere
  içinde bulunulan ay. Veri yeni bir alandan değil, mevcut `PomodoroSession`
  kayıtlarından türüyor (`calculateMonthlyHeatmap`), göç yok.
- **Seviye eşikleri mutlak** (1 / 25 / 50 / 90 dk), ayın en yoğun gününe göre
  ölçeklenmiyor. Bar chart kendi haftasına göre ölçekleniyor ama ızgarada aynı
  şey, ayda tek bir 5 dakikalık günü olan kullanıcıya o günü **en koyu** tonda
  gösterirdi.
- **Gelecek günler hiç çizilmiyor** ve ızgara bugünün satırında bitiyor. Önce
  soluk bir dolgu denendi; emülatörde boş geçmiş günden ayırt edilemedi
  (%9 ↔ %5 beyaz) ve kalan satırlar ölü alan bıraktı.
- **Ekran 06 kaydırmaya geçti** (madde 24'te Ekran 02'ye uygulanan kalıp).
  Gövde `_StatsBody`ye çıktı, banner kaydırma alanının dışında kaldı.
- **Alt çubuğun payı yuvadan yerleşime taşındı (yan kazanım).**
  `BannerAdSlot` reklam istenmediğinde (onay yok ya da premium) tamamen
  kapanıyor ve `bottomMargin: 88`i de götürüyor; sabit yerleşimde farkı
  `Spacer` yutuyordu, kaydırmalı gövdede ızgaranın alt iki satırı çubuğun
  arkasında kalıyordu. Ekran 02'de aynı gizli kusur duruyor — orada içerik
  henüz o kadar uzamıyor.
- **Başlık ayın adı değil `BU AY`:** `DateFormat` ya 12 yeni ARB anahtarı ya da
  karta `intl` bağımlılığı demek, oysa kart `initializeDateFormatting`
  çağrılmadan da çizilmek zorunda.
- **Kapsam dışı:** ay gezinme okları, hücreye dokunma/tooltip, yıllık pencere.
- **Emülatör doğrulandı (2026-09-17).** Boş ay ızgarayı yine çiziyor ama toplam
  metnini yazmıyor (`.verify/m29_g_bos_ay_koyu.png`); tohumlanmış 14 günlük
  eylülde dört ton da ayırt ediliyor, bugünün ember çerçevesi yerinde, toplam
  `14 saat 40 dakika` (`m29_e_dolu_ay_koyu.png`), açık temada rampa tersine
  dönüyor (`m29_f_dolu_ay_acik.png`). `m29_c_dolu_ay.png` düzeltme **öncesi**
  hâli: kartın alt satırları çubuğun arkasında.

---

## 30. Ders bazlı seans ✅ bitti

440 test geçiyor (+24). Tasarım belgesi:
`docs/superpowers/specs/2026-09-17-ders-bazli-seans-design.md`.
Kararlar: `DECISIONS.md` "Madde 30".

- **Şema v6, iki nullable sütun:** `PomodoroSessions.subjectKey` ve
  `AppSettingsTable.activeSubjectKey`. İkisi de **varsayılansız** — göç alan
  kullanıcının seansları gerçekten dersiz, onlara kolon varsayılanıyla bir ders
  atamak veri uydurmak olurdu. `null` = "belirtilmemiş" ve ekranlarda kendi
  dilimi var.
- **Katalog sınava göre, kodda** (`domain/subjects/subject_catalog.dart`),
  rozet kataloğunun kalıbı. Anahtarlar sınavlar arasında paylaşılıyor (YKS'nin
  ve LGS'nin "Matematik"i aynı `math`); preset'i olmayan sınav genel katalogu
  alıyor. 18 anahtar, yeni tablo yok.
- **Yapışkan hap** ODAKLAN'ın üstünde; dokununca hap ızgaralı alt sayfa. ODAKLAN
  tek dokunuşla başlatmaya devam ediyor — her seansa bir dokunuş eklemek Hızlı
  Odak widget'ını ve onboarding'in ilk seansını akışın dışında bırakırdı.
- **Ekran 06'da üç yüzey:** ders dağılımı kartı (çubuk + yüzde), haftalık denge
  (en çok artan/azalan), "en çok ihmal ettiğin ders". Üçü de `BU HAFTA` kartıyla
  **aynı** yedi günlük pencereyi kullanıyor.
- **İhmal yalnızca geçmişi olan ders için:** hiç çalışılmamış ders aday değil,
  yoksa satır her hafta aynı yedi dersi sayan bir suçlamaya dönerdi.
- **`startFocus` sınavı DAO'dan okuyor (test sırasında çıktı):** katalog
  `activeExamProvider`ın akışından gelseydi, soğuk başlangıçta widget'tan açılan
  seansta geçerli bir ders sessizce kaybolurdu.
- **Göç testlerinin kurgusu eksikmiş (yan kazanım):** üç eski göç testi yalnızca
  `app_settings_table` yaratıyordu; v6 seans tablosuna da dokunduğu için üçüne de
  pre-v6 `pomodoro_sessions` eklendi (tarih sütunları `TEXT`).
- **Kapsam dışı:** ders başına hedef, ders bazlı rozet, geçmiş seansın dersini
  düzenleme, kullanıcının kendi dersini yazması, ders bazlı bildirim.
- **Emülatör doğrulandı (2026-09-18).** Gerçek yükseltme yolu koştu: madde
  29'dan kalan v5 veritabanı `user_version = 6` olarak açıldı, eski seanslar
  dersiz, hap boş (`.verify/m30_a_hap_davet.png`); Kimya seçimi ayara ve seansa
  yazıldı (`m30_c_hap_secili.png`, DB `adb pull` ile doğrulandı); tohumlanmış
  haftada dağılım, denge ve ihmal satırları doğru (`m30_g_ekran06_dagilim.png`),
  açık temada rampa tersine dönüyor (`m30_h_ekran06_acik.png`).

---

## 31. `FlameRenderer` doğrulama boşluğu ✅ bitti

Madde 23'ten devredilen açık iş kapandı. Tasarım belgesi:
`docs/superpowers/specs/2026-09-18-flame-renderer-dogrulama-design.md`.
Kararlar: `DECISIONS.md` "Madde 31".

- **Ekran görüntüsüyle kapanamıyordu:** widget'ı ana ekrana koymak adb ile
  sürülemiyor (`appwidget` yalnızca `grantbind` destekliyor, `cmd appwidget`
  yok), `render` de gerçek `Bitmap`/`Canvas`/`Shader` istediği için düz JVM
  testi "Stub!" atıyor. Çizim yolunu kodla çağırmak tek yoldu.
- **İki koşum evi, tek iddia gövdesi:** Robolectric (`src/test`, NATIVE grafik
  kipi) cihazsız kalıcı kapı, instrumented test (`src/androidTest`) emülatör
  kanıtı. İddiaların tamamı `src/sharedTest/.../FlameRendererContract.kt`te;
  `build.gradle.kts` bu dizini iki kaynak kümesine de ekliyor, böylece iki
  koşum evi zamanla ayrışamıyor.
- **Altın görüntü yok:** iki grafik yığını bayt bayt uzlaşmaz. İddialar
  geometriyi merdivene bağlıyor; kıvılcım sayımı konumdan bağımsız, gövdenin
  dışındaki şeritte taşma doldurmayla leke sayıyor.
- **Hiç çalıştırılmamış kodda hata çıktı:** `bodyHeight = heightPx * scale`
  yüzünden üst kademelerde gövdenin tepesinde hava kalmıyor ve `if (y > 0f)`
  kıvılcımları sessizce atıyordu — K8'de 3'ün 2'si, K9'da 4'ün 1'i, K10'da
  5'in hiçbiri çizilmiyordu. Kıvılcımlar tepeden yukarı yerine tepeden aşağı
  inecek şekilde düzeltildi; gövde boyutuna dokunulmadı.
- **Türkçe yerel ayarı tuzağı:** Robolectric açılışta conscrypt yüklüyor,
  conscrypt kütüphane adını varsayılan yerel ayarla küçültüyor ve tr-TR'de
  `wındows` (noktasız ı) arıyor. Test JVM'i `-Duser.language=en` ile koşuyor.
- **Kapsam dışı:** widget'ı adb ile yerleştirmek, diğer renderer'lar
  (`RingRenderer`, `StripRenderer`, `SparkRenderer`), Dart ↔ Kotlin piksel
  paritesi.
- **Emülatör doğrulandı (2026-09-18).** `focussayac_verify` (Android 16)
  üzerinde cihaz testinin üçü de geçti; on bitmap `.verify/m31_k1..k10.png`
  olarak çekildi, kontak sayfası `.verify/m31_tum_kademeler.png`. K1–K3 sade,
  K4'ten köz, K6/K7'de 2 ve 3 kıvılcım, K8'den hâle, K8/K9/K10'da 3/4/5
  kıvılcım. PNG dökümünü çekmek için
  `-Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true` şart
  (AGP koşum sonunda APK'ları kaldırıp dış dizini siliyor) ve dosyalar
  `/data/media/0/...` altından, `MSYS_NO_PATHCONV=1` ile çekiliyor.
- **Kalan bağlı iş yok.** Dart tarafının cihaz kanıtı 2026-09-17'de alınmıştı
  (`.verify/tiers_all.png`).

---

## 32. Son düzlükte meta satırı halkanın altına giriyor ✅ bitti

441 test geçiyor (+1). Kararlar: `DECISIONS.md` "Madde 32". Seçilen yol
(a)+(c): kapak kirişe göre hesaplanıyor **ve** son düzlükte tarih kısalıyor.

- **Kapak çaptan geliyordu:** `SizedBox(width: 284)` halkanın yatay çapındaki
  genişlikti; satır merkezin ~75px altında duruyor ve kiriş orada çok daha
  dar. Kontrol de `FittedBox` de vardı, ikisi de yanlış sayıya bakıyordu.
- **Ölçü en içteki *dolu* yaya bağlı:** ilk düzeltme zaman izinin iç kenarını
  (125.5) aldı, ama madde 27'nin emek yayı 117'den başlıyor ve daha içeride —
  186'lık kapağın köşesi tam o şeride düşüyordu. Sabit tek:
  `CountdownRingPainter.innerContentRadius` = 117, kapak 176. İkinci bir
  sabit bırakılmadı, yoksa çağıran yanlışını seçer.
- **Kesik çizgili 112'lik çember kapsam dışı:** 1px, %35 saydam, dönen dekor;
  satırın uçları onu bu maddeden önce de teğet geçiyordu.
- **Son düzlükte tarih kısalıyor** (`d MMM` → "29 Eyl"), normalde tam
  (`d MMMM y`). Son düzlük en çok otuz gün, o pencerede yıl okunmuyor; tam
  tarih sınav ekranında ve paylaşım kartında duruyor. Kısaltmalar tam ay
  adının ön eki olduğu için font altkümesine yeni glif girmiyor.
- **Kalan %3 küçülme bilinçli:** satır 181px, kapak 176 (12px → 11.6px).
  186'ya açmak küçülmeyi kaldırırdı ama kapağı yine sığdırmayacağı hâlde
  "sığar" diyen bir sayıya çevirirdi.
- **Test genişliği değil geometriyi ölçüyor:** `flutter test` gerçek fontları
  yüklemiyor (satır orada 373px, cihazda 181px). `countdown_meta_row_test.dart`
  kapağın dört köşesinin merkeze uzaklığını ölçüyor; dikey ofset gerçek
  yerleşimden geldiği için kahraman sayı büyürse iddia düşüyor. Eski 284 ile
  kırmızı, 176 ile yeşil.
- **Emülatör doğrulandı (2026-09-18).** `focussayac_verify` (Android 16),
  `.verify/seed_final_stretch.py` ile tohumlandı. Son düzlükte alt köşe
  merkezden 110.5px, metinle emek yayı arası en kısa mesafe 5.9px, kesişme yok
  (`m32_b_son_duzluk.png`, `m32_c_metarow_zoom.png`); normal durum tam tarihle
  ve küçülmeden duruyor (`m32_a_normal.png`, `m32_d_normal_zoom.png`); açık
  temada aynı geometri (`m32_e_acik_tema.png`, `m32_f_acik_zoom.png`).

---

## 33. Zaman yayının başlangıcında köz lekesi ✅ bitti

446 test geçiyor (+5), Kotlin birim koşumu +2. Kararlar:
`DECISIONS.md` "Madde 33". Seçilen yol (c): gradyan, yuvarlak ucun geride
bıraktığı şeridi de kapsayacak kadar geri çevrildi — tek sabit, iki dosyada.

- **Sorun ve nedeni yerinde duruyordu:** yay `SweepGradient` +
  `StrokeCap.round` ile çiziliyor, yuvarlak uç başlangıç açısının
  `strokeWidth / 2` kadar gerisine taşıyor ve gradyan orada turu tamamlayıp son
  durakta (`ember`) örnekleniyordu. Leke yayın oranıyla kımıldamıyordu.
- **Gradyan 2.9° geri çevrildi** (`_gradientBackshift` = `(9/2 + 2) / 130`
  radyan): 0. durak (`sky`) kapağın altındaki açıyı da kapsıyor, sarma noktası
  ise **hiç çizilmeyen** bir açıya düşüyor. 2px'lik fazla kenar yumuşatma payı —
  sarma noktası kapağın ucundan 2px geride, oraya taşan yumuşatma pikseli yok.
- **(a) ve (b) elendi:** (a) gradyanı süpürülen açıya sığdırırdı, yani %25'te
  bile yayın ucu köz olurdu — 300 gün kalan kullanıcıya aciliyet rengi.
  (b) başlangıç ucunu düzleştirirdi ama `butt` kenarının yumuşatma pikselleri
  de aynı sarma bölgesinden örnekleniyor; leke hairline'a iner, gitmez.
- **Widget'ın Kotlin portu da düzeltildi:** `RingRenderer.kt` aynı gradyanı
  aynı `-90°` ile kuruyordu, dosyanın kendi başlığı "gradyanı uygulamayla AYNI"
  diyor. Birini düzeltip diğerini bırakmak o sözü bozardı.
- **Depodaki ilk piksel testi:** `countdown_ring_start_test.dart` painter'ı
  `PictureRecorder`a çizip 12'nin 20° gerisinden 2° ilerisine tarıyor ve hiçbir
  pikselin kırmızısının mavisini 12'den fazla aşmadığını söylüyor. Painter'ın
  alanlarını okuyan kalıp (`effort_arc_test.dart`) bu hatayı göremezdi — hata
  boyanın kendisinde. Kotlin karşılığı `RingRendererRobolectricTest`.
- **Emülatör doğrulandı (2026-09-18).** `focussayac_verify` (Android 16), sınav
  300 gün ileri (%25 yay, bitiş ucu 3 yönünde — böylece başlangıç yalnız
  kalıyor). Düzeltmeden önce 12'deki yuvarlak ucun **tamamı** köz
  (`m33_a_once.png`, 6× yakın çekim `m33_c_once_zoom.png`; tepedeki piksel
  `(163,93,0)`). Sonra aynı konumdaki piksel `(31,110,192)` = `sky` ve 12'nin
  solundaki 130px'de en sıcak piksel −160, yani saf gökyüzü
  (`m33_b_sonra.png`, `m33_d_sonra_zoom.png`, halka `m33_e_halka.png`). Koyu
  temada aynı sonuç, `(100,180,255)` (`m33_f_koyu.png`, `m33_g_koyu_zoom.png`).
  Uç yuvarlaklığı ve yayın yeri değişmedi — kapak aynı pikselde başlıyor.
- **Kalan bağlı iş:** widget halkası launcher'da yeniden çekilmedi (ekranda
  bağlı örnek yoktu). Kotlin tarafının kanıtı Robolectric'in NATIVE Skia'sı;
  widget zaten RemoteViews bitmap'i, yani cihazda da aynı yığın.

---

## 34. Kademe atlama kutlaması ✅ bitti

451 test geçiyor (+5). Kararlar: `DECISIONS.md` "Madde 34". Çakışma kuralı
kullanıcıya soruldu, seçilen sıra **rozet → kademe → seri**.

- **Üçüncü kutlama türü:** `FlameTierCelebration` eşiğin saatini değil
  `FlameTier` nesnesini taşıyor — dialog alevi tam o kademede çiziyor, yani
  kutlamanın görseli ödülün kendisi. Bir Phosphor ikonu koymak, kademenin tek
  görünür karşılığını (alevin büyümesi) kutlamanın dışında bırakırdı.
- **Çakışma kural, istisna değil:** K4/K6/K7/K9 eşikleri 10/50/100/250 saatlik
  rozetlerle birebir aynı — dokuz atlamanın dördü bir rozetle birlikte düşüyor.
  Rozet öne geçiyor: saat rozeti **yalnızca** o anda kutlanabilir, kademenin
  ödülü ise kalıcı (alev her ekranda büyümüş duruyor, Ekran 04 onu adıyla
  söylüyor) ve rozet zaten aynı kümülatif saati kutluyor.
- **Yutulan kademe yine de işaretleniyor:** aksi hâlde bir sonraki seansta,
  artık atlanmamış bir kademe için bayat bir dialog açılırdı. Seri eşiğindeki
  "gösterilmeden önce işaretle" kuralının aynısı.
- **İşaretin varsayılanı 1:** K1 başlangıç hâli, atlanan kademe değil — 0
  olsaydı ilk pomodoro "Kıvılcım'a yükseldin" derdi. Güncelleyerek gelen
  kullanıcıda güncel kademe bir kez kutlanıp geçiliyor. "Verileri sıfırla"
  anahtarı siliyor (`AppDataResetService`).
- **Kart şablonu zorlanmıyor:** üç şablonun hiçbiri kademeyi göstermiyor;
  rozet kutlamasının kuralıyla kullanıcının seçtiği kart açılıyor. Seri
  kutlaması SERİ şablonunu öneriyordu çünkü o şablon vardı.
- **Testteki tuzak:** geçmiş yazan yardımcı önce **saat** aralıklıydı; gece
  yarısını kesen koşumda satırların bir kısmı düne düşüyor ve Maraton (8/gün)
  rastgele bir seansta açılıp kutlamayı çalıyordu. Gün başına bir satır +
  ardışık olmayan günler, gün bazlı rozetleri de seri eşiklerini de erişilemez
  kılıyor.
- **Emülatör doğrulandı (2026-09-18).** `focussayac_verify` (Android 16),
  release derlemesi, `focus_minutes = 1`, `.verify/m34_seed.py` ile toplam
  eşiğin bir dakika altına çekilerek. K2 kutlaması açıldı ve anahtar 2 oldu
  (`m34_a_kademe_k2.png`); kart kullanıcının kendi şablonuyla açıldı
  (`m34_b_kart.png`); 10 saatte iki rozet dialogu açıldı, kademe dialogu
  açılmadı ama anahtar 4'e ilerledi (`m34_c_rozet_onde.png`,
  `m34_d_rozet2.png`); aynı kademedeki sonraki seans hiçbir şey açmadı
  (`m34_e_ikinci_kez_yok.png`); koyu temada K4→K8 atlaması tek kutlama açtı ve
  "Harman Ateşi" tek satıra sığdı (`m34_f_koyu_k8.png`), Ekran 04 aynı adı ve
  "175 / 250 sa"yı gösterdi (`m34_g_ekran04.png`).

---

## 35. Isı haritasında ay gezinme + gün seçimi ✅ bitti

470 test geçiyor (+19). Tasarım belgesi:
`docs/superpowers/specs/2026-09-18-isi-haritasi-etkilesim-design.md`.
Kararlar: `DECISIONS.md` "Madde 35". Madde 29'un kapsam dışı bıraktığı üç
şeyden ikisi; yıllık pencere hâlâ dışarıda.

- **Pencere hesaplayıcının parametresi oldu:** `calculateMonthlyHeatmap`
  `monthOffset` alıyor (0 bu ay, −1 geçen ay) ve ayı yine uygulama gününden
  türetiyor — 04:00 TSİ sınırı tek yerde kalıyor. `monthlyHeatmapProvider`
  aileye döndü ama geçmiş ay ek sorgu değil: `allSessionsProvider`ın aynı
  listesinden başka bir pencere.
- **`isCurrentMonth` sessiz bir hatayı kapattı:** `_todayIndex` "gelecek
  olmayan son gün" diyor, geçmiş ayda bu ayın son günü olurdu — ızgara
  31 Ağustos'a bugünün ember çerçevesini çizerdi. Aynı bayrak "bugünün
  satırında bitir" kuralını da bu aya hapsediyor.
- **Geri okun kapısı takvim değil veri:** `hasEarlier` "bu aydan önce
  tamamlanmış odak var mı" diye soruyor (ızgaranın ölçütünün aynısı), yoksa
  uygulamayı bu ay kuran kullanıcı boş aylarda kaybolurdu. İleri ok bu ayda
  kapalı — yaşanmamış gün gösterilmiyor.
- **Ay adı `MaterialLocalizations.formatMonthYear`den** ("Ağustos 2026"): 12
  ARB anahtarı da `intl` başlatması da gerekmedi. **Büyük harfe çevrilmiyor** —
  `"Ekim".toUpperCase()` Dart'ta "EKIM" verir, Türkçe noktalı İ kaybolur.
- **Seçim ekranın kısa ömürlü durumu** (`_HeatmapSection`), kart saf kaldı.
  Ay değişince seçim sıfırlanıyor, aynı hücreye ikinci dokunuş kaldırıyor.
  Detay efsanenin solunda: `18 Eyl • 7dk`, odak yoksa `10 Ağu • odak yok`.
  Seçim çerçevesi (`text`) bugünün ember çerçevesini yeniyor.
- **Erişilebilirlik kapsamı daraldı:** madde 29'un `excludeSemantics`i kabın
  tamamındaydı, oklar altında kalınca ekran okuyucuya hiç görünmüyordu (testte
  çıktı). Artık ızgara + efsane dışlanıyor, oklar kendi durakları, seçim özet
  cümlesine ekleniyor.
- **Emülatör doğrulandı (2026-09-18).** `focussayac_verify` (Android 16),
  release, `.verify/m35_seed.py` ile üç aya yayılmış 15 seans. Geçen ay
  "Ağustos 2026" başlığıyla ve ay sonuna kadar dolu ızgarayla açılıyor, hiçbir
  hücrede ember çerçeve yok (`m35_b_gecen_ay.png`, `m35_c_gecen_ay_tam.png`);
  seçim "11 Ağu • 2sa 30dk" (`m35_d_secim.png`), boş gün "10 Ağu • odak yok"
  (`m35_e_odak_yok.png`), ikinci dokunuş kaldırıyor (`m35_f_secim_kalkti.png`).
  En eski ayda geri ok susuyor (`m35_h_sinir.png`), ay değişince seçim
  düşüyor (`m35_j_ay_degisti.png`), bugüne dokununca çerçeve beyaza dönüp
  "18 Eyl • 7dk" yazıyor (`m35_n_bugun_secili.png`). Açık temada aynısı
  (`m35_q_acik_tema.png`, `m35_r_acik_secim.png`, `m35_s_acik_gecen_ay.png`).
  **Tuzak:** `adb push` edilen DB uid 10000'de kalıyor, `chown 10220` +
  `restorecon` yapılmazsa uygulama açılış ekranında donuyor.
- **Kapsam dışı:** yıllık pencere, uzun basma, seçili günün ders kırılımı,
  gelecek aya gezinme, ay geçişinin animasyonu, diğer kartların geçmiş aya
  bakması.

---

## 36. Ekran 02'de alt çubuğun payı reklam yuvasına bağlıydı ✅ bitti

471 test geçiyor (+1). Kararlar: `DECISIONS.md` "Madde 36". Madde 29'un
Ekran 06'da düzeltip Ekran 02'de bilerek açık bıraktığı kusur ("Ekran 02'de
aynı gizli kusur duruyor — orada içerik henüz o kadar uzamıyor").

- **Kusur:** alt gezinme çubuğunun payı `BannerAdSlot`ın `bottomMargin`indeydi
  (`BannerAdSlot(bottomMargin: 88)`). Yuva reklam **hiç istenmediğinde** —
  premium ya da UMP onayı yok — `SizedBox.shrink()`e iniyor ve payı da
  götürüyor; kaydırılan gövdenin sonu, yani **ODAKLAN'ın kendisi**, opak
  çubuğun arkasında kalıyor ve kaydırarak kurtarılamıyor. Ölçülen fark
  **−82px**: butonun tamamı çubuğun altında.
- **Neden ancak şimdi görünür oldu:** madde 24'te Ekran 02 kaydırmaya geçti.
  Sabit yerleşimde farkı alttaki boşluk yutuyordu — madde 29'un notu bu yüzden
  "içerik henüz o kadar uzamıyor" diyordu. Kusurun koşulu artık kuruluyor.
- **Düzeltme Ekran 06'nınkiyle aynı:** pay yuvadan çıkıp kardeş bir `SizedBox`a
  taşındı. Ölçü ekranın kendi 88'i değil Ekran 04 ve 07'nin de kullandığı ortak
  `kBottomNavReservedSpace` (96px); Ekran 06'nın özel `_navBarFootprint`i de
  aynı sabite bağlandı. Aynı kavramın üç kaynağı (88 literal, private 88,
  paylaşılan 96) tek kaynağa indi.
- **Regresyon testi** (`test/features/countdown/nav_bar_footprint_test.dart`):
  390x640'ta, reklam istenmeyen hâlde, kaydırma sonuna götürülüp ODAKLAN'ın altı
  ile çubuğun üstü ölçülüyor. İki koruma var: kaydırmanın gerçekten devreye
  girdiği (`maxScrollExtent > 0` — yoksa uzun ekranda test boşa koşar) ve payın
  yuvaya geri bağlanmadığı (`bottomMargin == 0`).
- **`banner_placement_test` beklentisi düzeltildi:** Ekran 02'nin yuvası artık
  `90 + 88` değil `90`. Test eski mekanizmayı pinliyordu; payın gerçekten
  ayrıldığını yeni test ölçüyor.
- **Tek `pumpWidget` zorunlu (yolda çıkan tuzak):** aynı dosyada ikinci bir
  `testWidgets` — hatta aynı testte ikinci bir `pumpWidget` — drift göçünü
  yarıda bırakıyor, ekran `CircularProgressIndicator`da donuyor ve koşum 10
  dakikada zaman aşımına düşüyor. Dosyanın ilk iki hâli sırayla tam olarak buna
  düştü. Reklamın istendiği hâlin karşı kontrolü bu yüzden geometriyle değil
  **mekanizmayla** pinlendi: orada yuva kendi yüksekliğini de eklediği için
  ayrılan alan yalnızca artıyor, yani asıl iddiayı geçen yerleşim orada da
  geçiyor.
- **Emülatör doğrulandı (2026-09-19).** `focussayac_verify` (Android 16),
  release. Kusur koşulu `.verify/m36_seed.py` ile kuruldu (`is_premium = 1` →
  `canRequestAds()` false → yuva kapalı); taşma gerçek bir küçük telefon
  sınıfıyla zorlandı (`wm size 720x1440`, `wm density 320` → 360x720dp,
  `font_scale 1.3` — uygulama yazı ölçeğini kırpmıyor, `textScaler` araması
  boş). Madde 35'ten kurulu kalan APK düzeltme **öncesi** hâl olduğu için "önce"
  görüntüsü yeniden derlemeden alındı: kaydırmanın sonunda "1 DAKİKA ODAKLAN"
  çubuğun arkasında, yalnızca kenarlığı üstten sızıyor
  (`.verify/m36/m36_b_kusur.png`). Düzeltilmiş APK birebir aynı koşullarda
  CTA'yı çubuğun üstünde ve tam görünür bırakıyor (`m36_c_duzeltme.png`), koyu
  temada da aynı (`m36_f_koyu.png`).
- **Cihazda doğrulanamayan tek hâl — reklam açık.** `is_premium = 0` ile
  koşulduğunda UMP onay formunun WebView'ü açılıyor ve emülatörde **ağ yok**
  (`ping 8.8.8.8` %100 kayıp, `res_stats_usable_server: too many resolution
  errors`); uygulama açılış ekranında %82 CPU ile asılı kalıyor ve systemui
  ANR'ye düşüyor. Ortam kısıtı, kodla ilgisi yok. O dal
  `banner_placement_test`in adaptive yükseklik iddiasıyla ve yukarıdaki
  mekanizma iddiasıyla kapalı.
- **Kapsam dışı:** `kBottomNavReservedSpace`in 96 değerinin kendisi (çubuğun
  64+18'ine göre yeniden ölçülmedi), Ekran 02'nin uzun ekranlardaki `Spacer`sız
  üst hizalı yerleşimi, banner'ın kaydırma alanının dışında durması kuralı.

---

## 37. Yıllık ısı haritası penceresi ✅ bitti

489 test geçiyor (+18). Kararlar: `DECISIONS.md` "Madde 37", tasarım
`docs/superpowers/specs/2026-09-19-yillik-isi-haritasi-design.md`. Madde 29 ve
35'in kapsam dışı bıraktığı üç şeyden geriye kalan sonuncusu; o liste kapandı.

- **Pencere takvim yılı değil, yuvarlanan 52 hafta.** 52 sütun × 7 satır = 364
  gün; son sütun bugünün içinde bulunduğu hafta (Pzt–Paz). Takvim yılı elendi —
  ocakta pencere neredeyse boş olur ve ritim diye gösterilecek bir şey kalmazdı.
  Yeni sorgu yok: `allSessionsProvider`ın aynı listesinden başka bir kesit
  (madde 35'in kalıbı). Gün sınırı yine `appDayKey`, aylık hesaplayıcıyla aynı
  fonksiyon.
- **Eşikler aynı kaldı, ve bu bir tercih değil sonuç.** Şerit aylık ızgarayla
  aynı kartta durduğu için karttaki **tek efsane** ikisine birden hizmet ediyor:
  tek efsane → tek rampa → tek eşik takımı. İkinci bir takım aynı günü iki
  ızgarada iki farklı tonda gösterirdi. `heatmapLevel` ve eşikler paylaşıldı,
  kopyalanmadı.
- **Sığdırılmış şerit, salt bakış.** 360dp ekranda hücre 4.17dp hesaplanıp 8px'e
  yuvarlanıyor (emülatörde ölçülen 4.0dp). Dokunma hedefi olamayacağı için jest
  ağacı hiç kurulmuyor — "bu kutu kaç dakika" sorusunu madde 35 zaten üstteki
  ızgarada cevapladı. Bugünün ember çerçevesi de yok: gelecek günler
  çizilmediği için son çizilen hücre zaten bugün.
- **Elenen düzenler:** yatay kaydırmalı GitHub şeridi (Ekran 06 zaten dikey
  kaydırılıyor, iki jest birbirine düşerdi), 12 mini ay ızgarası (kartı ~500dp
  uzatıyor), başlıkta `AY / YIL` segmenti (yeni durum + "oklar ne yapar"
  sorusu). Ay adı etiketi yok — `MaterialLocalizations` kısa ay adı vermiyor.
- **Paylaşılan ölçek `heatmap_scale.dart`a çıktı**, `monthly_heatmap.dart` onu
  re-export ediyor: mevcut beş import edenin hiçbiri değişmedi. Yeni hesaplayıcı
  `RollingYearHeatmap`; sağlayıcı aile değil (pencere sabit).
- **Emülatör doğrulandı (2026-09-19).** `focussayac_verify` (Android 16),
  release. `.verify/m37_seed.py` 52 haftayı tohumluyor. Doğrulananlar: pencere
  sınırları birim testiyle birebir aynı (22 Eyl 2025 Pzt – 20 Eyl 2026 Paz);
  satır sırası Pzt..Paz (6. satır tekdüze seviye 1 = her cumartesi 20 dk, 7.
  satır tekdüze boş = her pazar); son sütunda pazar çizilmiyor (bugün
  cumartesiydi); pencerenin ilk günü çiziliyor, bir gün öncesi hiç görünmüyor;
  ızgara Haziran 2026'ya götürülünce ay toplamı 37 sa 15 dk oldu ama şerit
  334 sa 9 dk'da kaldı; 360×720dp küçük telefon sınıfı ve koyu tema.
- **Yolda çıkan tuzak:** `adb push` tohumlanan DB'nin SELinux **MLS
  kategorisini** bozuyor (dizin `c220`, dosya `c216`) ve uygulama
  `SqliteException(14)` ile splash'ta asılı kalıyor. `restorecon` düzeltmiyor;
  dizinin bağlamını `chcon` ile birebir uygulamak gerekiyor.
- **Kapsam dışı:** yıl gezinme, şeritte gün seçimi, ay sınırı etiketleri, tam
  genişliğe taşan şerit, şeridin açık olan ayı vurgulaması, giriş animasyonu.

---

## 38. Yayın engelleyicileri — imzalama anahtarı, AdMob kimlikleri, mağaza görselleri 🟡 görseller bitti, ikisi dış kaynak bekliyor

492 test geçiyor (+3). Kararlar: `DECISIONS.md` "Madde 38". Maddenin üç
ayağından **görseller kapandı**; diğer ikisi bilinçli olarak açık bırakıldı.

- **Mağaza görselleri hazır ve depoda.** Beş telefon ekran görüntüsü
  (`docs/play/store/0{1..5}_*.png`, 1080×1920), feature graphic (1024×500),
  simge (`assets/logo/export/play_store_512.png`, 512×512). Sıra ASO §5'in beş
  altyazısıyla birebir; görsellerin üstünde metin yok. Kalan iş yalnızca
  Console'a **elle yükleme**.
- **Play'in oran sınırı yerleşimi belirledi.** En büyük kabul edilen en-boy
  oranı 2:1, emülatörün kendi ekranı 9:20 — çekim öncesi `wm size 1080x1920`
  ile tam 9:16'ya zorlanıyor. Kırpmak elendi: kırpma uygulamanın yerleşim
  kararını değil bizim kestiğimizi gösterirdi.
- **Banner'ın içindeki telefon taklit değil**, `02_odak.png`'nin kendisi —
  banner ile mağaza görüntüsü tek kaynağa bağlı. Üreteç
  `tool/generate_feature_graphic.py`; `132` ASO §6'nın örnek rakamı, uygulamanın
  geri sayımına bilerek bağlanmadı.
- **Emülatörde gerçek bir hata çıktı: launcher simgesi sistem temasıyla renk
  değiştiriyordu.** `ic_launcher_background.xml` zemini `@color/focus_bg`e
  bağlamıştı; o token niteleyiciye göre çözülüyor ve launcher onu **sistem**
  temasıyla çözüyor, yani açık moddaki bir cihazda simge krem zeminli, Play'e
  gidecek 512 ise koyu zeminliydi. Zemin düz hex (`#FF0B0C14`) yapıldı.
  Sessiz hataydı: derleniyor, açılıyor, hiçbir test düşmüyordu — proje boyunca
  hep koyu temada bakılmıştı.
  `test/android/launcher_icon_background_test.dart` artık adaptive zemini,
  `generate_app_icon.py`nin `BG` sabitini ve `AppColors.dark().bg`i birbirine
  kilitliyor.
- **Emülatör doğrulandı (2026-09-19).** `focussayac_verify` (Android 16),
  release APK. Simge zemininin ortalama RGB'si düzeltme öncesi `(225,226,231)`,
  sonrası `(57,58,65)`; açık ve koyu sistem temasında alınan iki kare aynı
  değeri verdi.
- **Açık kalan — imzalama anahtarı:** `android/key.properties` hâlâ yok, AAB
  `CN=Android Debug` ile imzalı. Şablon `key.properties.example`, format PKCS12
  (JKS'te `keytool` uyarı basıyor). Anahtar kaybolursa uygulama güncellenemiyor;
  parola ve saklama kullanıcının kararı.
- **Açık kalan — AdMob kimlikleri:** gerçek birim/App ID'leri bir AdMob hesabı
  gerektiriyor. Kod değişikliği gerekmiyor, `--dart-define` tablosu
  `docs/play/RELEASE.md` §3'te; şu an Google'ın resmî test kimlikleri kullanılıyor.
- **Kapsam dışı:** tablet ve 7"/10" görüntüleri (Play zorunlu tutmuyor), tanıtım
  videosu, görsellerin İngilizce sürümü, gerçek ARM cihazda yeniden çekim.

---

## 39. Kotlin renderer'ların doğrulama boşluğu (Ring / Strip / Spark) ✅ bitti

492 Dart testi geçiyor (değişmedi) + Gradle tarafında 18 Robolectric / 20 cihaz
testi. Kararlar: `DECISIONS.md` "Madde 39". Tasarım:
`docs/superpowers/specs/2026-09-19-kotlin-renderer-dogrulama-design.md`.

Madde 31'in kalıbı üç renderer'a taşındı: iddialar `src/sharedTest` altında üç
sözleşme dosyasında, koşucular ince, iki koşum evi de aynı gövdeyi derliyor.
`build.gradle.kts` bu dizini zaten iki kaynak kümesine ekliyordu — yeni ayar
gerekmedi. Madde 33'ün iki halka iddiası da sözleşmeye taşındı; orada
cihazsızdı, artık emülatörde de koşuyor.

**Beklentinin aksine iki gerçek hata çıktı** — madde 31'deki gibi, hiç
koşulmamış kodda:

- **Sütun grafiğinin tabanı sütun genişliğine bağlıydı** (`radius * 2f`).
  Panorama yerleşiminde (140×22dp) taban grafiğin **%32'si** oluyordu: 120
  dakikalık bir haftada 20 dakika odaklanılmış gün ile hiç odaklanılmamış gün
  aynı çiziliyordu. Pay dikey eksene taşındı (`heightPx * 0.06f`); taban duruyor
  ama artık bir günün odağı gibi görünmüyor.
- **Halkanın kicker'ı uzun durum adlarında izin üstünden geçiyordu.**
  "HEDEF SEÇİLMEDİ" 238 px, o satırdaki kiriş 183 px — üstelik bu, sınav
  seçmemiş kullanıcının gördüğü tek hâl. Punto artık `measureText` ile ölçülüp
  kirişe sığdırılıyor (`labelFitFor`); sığan etiketler hiç küçülmüyor.

**Emülatör doğrulandı (2026-09-19).** `focussayac_verify` (Android 16), 20 test
sıfır hata. Çıktı PNG'leri `.verify/m39_*.png`, kontak sayfaları
`m39_{halka,serit,sutun}_tablosu.png` — ekran görüntüsü değil, çizim
yollarının çıktısının kendisi.

Türkçe yerel ayarı tuzağı (conscrypt tr-TR'de `wındows` arıyor) burada da
geçerliydi; `tasks.withType<Test>` zaten `-Duser.language=en` veriyor.

**Kapsam dışı:** `StripRenderer`ın `muted` davranışı — sınav seçilmemişken
şerit boş iz yerine bir kapakla duruyor, halka ise yayı hiç çizmiyor. Sözleşme
davranışı sabitliyor, ikisini aynı dile getirmek ayrı bir maddenin işi.

---

## 40. Izgaranın özet cümlesi geçmiş ayda da "Bu ay" diyor

Madde 37'de yolda çıkan, kapsam dışı bırakılan bir ifade kusuru. Madde 35 ay
gezinmeyi getirdi ve kartın **başlığını** geçmiş ayda ay adına çevirdi
(`Ağustos 2026`), ama ekran okuyucunun duyduğu cümle
(`statsHeatmapSemantics`) sabit kaldı: "**Bu ay** 31 günün 1 gününde
odaklandın…". Gören kullanıcı ağustosa baktığını biliyor, ekran okuyucu
kullanıcısı bilmiyor — üstelik gezinme okları onun da kullanabildiği iki durak
(madde 35 bunları bilerek durak yaptı), yani kendi gittiği aya yanlış isim
duyuyor.

Düzeltme yeni bir ARB anahtarı gerektiriyor (geçmiş ay için ay adını alan bir
cümle); kart zaten `MaterialLocalizations.formatMonthYear`i elinde tutuyor,
yani yeni bağımlılık yok. Boş ay dalı (`statsHeatmapEmptySemantics`) aynı
sorunu taşıyor.

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
- [x] Launcher simgesi üretildi *(kutu bayattı: `mipmap-anydpi-v26/ic_launcher.xml`
      beş yoğunlukta foreground + monochrome katmanlarıyla duruyor, keyline
      kararı dosyanın yorumunda; emülatörde Ayarlar'ın uygulama sayfasında
      Flutter varsayılanı değil özel simge göründü. Madde 38: zemin sistem
      temasıyla renk değiştiriyordu, artık temadan bağımsız ve Play'e gidecek
      512 ile aynı)*
- [ ] Yayın çıktısı gerçek anahtarla imzalı *(`key.properties` yok, AAB şu an
      `CN=Android Debug`)*
- [x] Odak seansında dekoratif animasyonlar duruyor
- [x] Kodda hard-coded Türkçe metin yok
- [x] Testler geçiyor *(492 test, `flutter test`)*
- [x] `DECISIONS.md` her kararı gerekçesiyle içeriyor

Play Console tarafının kendi kontrol listesi ayrı: `docs/play/RELEASE.md` §7.
