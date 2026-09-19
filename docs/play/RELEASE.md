# Play yayın paketi — FocusSayaç

SPEC.md Faz 15 / ROADMAP madde 9. Mağaza **metinleri** burada tekrarlanmaz:
tek kaynak `design/FocusSayac ASO Paketi.dc.html`. Bu belge, o metinlerin
hangi Console alanına gireceğini, imzalamayı, yayın komutlarını ve yayından
önce elle yapılması gereken işleri tutar.

---

## 1. Sürüm numarası

`pubspec.yaml` → `version: 1.0.0+1`. `versionName` = `1.0.0`,
`versionCode` = `1` (Gradle bunları `flutter.versionName/versionCode`
üzerinden okur, `android/app/build.gradle.kts`). Her Play yüklemesinde
`versionCode` artmalı — aynı numara ikinci kez kabul edilmez.

## 2. İmzalama

Anahtar deposu ve parolalar depoya girmez: `key.properties` ile `*.p12`,
`*.jks`, `*.keystore` hem kökte hem `android/.gitignore`da yoksayılıyor.

```bash
# 1) Anahtar deposu (bir kez üret ve YEDEKLE — kaybolursa uygulama
#    bir daha güncellenemez; Play App Signing kaydı buna bağlanır).
#    PKCS12: JKS için keytool "proprietary format" uyarısı veriyor.
cd android
keytool -genkey -v -keystore focussayac-release.p12 -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias focussayac

# 2) Parolaları gir
cp key.properties.example key.properties   # sonra doldur
```

`android/app/build.gradle.kts` `key.properties` varsa `release` imza
yapılandırmasını ondan kurar, yoksa **debug** anahtarına düşer. Debug imzalı
bir çıktı Play'e yüklenemez — Console reddeder. Yüklemeden önce doğrula:

```bash
# Çıktının debug anahtarıyla imzalanmadığını gör (CN=Android Debug ÇIKMAMALI)
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

## 3. Yayın derlemesi

Gerçek AdMob birimleri koda gömülü değil, `--dart-define` ile geliyor
(`lib/services/ads/ad_unit_ids.dart`). **Bu tanımlar verilmezse Google'ın
resmî test reklamları yayımlanır** — gelir sıfır olur.

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX
```

Bilinen `--dart-define` anahtarları:

| Anahtar | Varsayılan | Kaynak |
| --- | --- | --- |
| `ADMOB_BANNER_ANDROID` / `ADMOB_BANNER_IOS` | Google test birimi | `lib/services/ads/ad_unit_ids.dart` |
| `ADMOB_INTERSTITIAL_ANDROID` / `ADMOB_INTERSTITIAL_IOS` | Google test birimi | aynı dosya |
| `EXAM_DATES_REMOTE_URL` | boş (ağa hiç çıkmaz) | `lib/services/storage/exam_source_service.dart` |

AdMob **App ID**'si `--dart-define` ile verilemez, manifest'te olmak zorunda:
`android/app/src/main/AndroidManifest.xml` içindeki
`com.google.android.gms.ads.APPLICATION_ID` satırı gerçek hesap açılınca elle
değiştirilir (şu an Google'ın test App ID'si).

## 4. Console alanları → ASO paketi eşlemesi

Metinlerin tamamı `design/FocusSayac ASO Paketi.dc.html`de; seçilen
seçenekler:

| Play Console alanı | Kaynak | Seçim |
| --- | --- | --- |
| Uygulama adı (≤30) | ASO §1 | **FocusSayaç: YKS Geri Sayım** (26/30) |
| Kısa açıklama (≤80) | ASO §2 | **birinci seçenek** (62/80) |
| Tam açıklama | ASO §3 | tamamı, sondaki ÖSYM/MEB feragati dâhil |
| Sürüm notu | ASO §7 | "İlk yayın (1.0.0)" metni |
| Gizlilik politikası URL'si | `docs/privacy-policy.md` | `focussayac.app/gizlilik` |

Cihaz launcher'ında görünen ad manifest'teki `android:label` — mağaza adından
ayrı ve **FocusSayaç** olarak sabit (uzun ASO adı simgenin altına sığmaz).

## 5. Görseller

Hepsi depoda; Console'a elle yüklenecek.

| Öğe | Ölçü | Dosya |
| --- | --- | --- |
| Uygulama simgesi | 512×512 PNG, alfasız | `assets/logo/export/play_store_512.png` |
| Feature graphic | 1024×500 PNG | `docs/play/store/feature_graphic_1024x500.png` |
| Telefon ekran görüntüsü ×5 | 1080×1920 (9:16) PNG | `docs/play/store/0{1..5}_*.png` |

Ekran görüntülerinin sırası ASO §5'in beş altyazısıyla birebir: `01` geri
sayım, `02` odak seansı, `03` rozetler, `04` istatistik, `05` başarı kartı.
Altyazılar Console'a ASO §5'ten girilir; görsellerin kendi üstünde metin yok.

Yeniden üretme:

```bash
python tool/generate_app_icon.py          # 512×512 dâhil tüm simge yüzeyleri
python tool/generate_feature_graphic.py   # 02_odak.png'yi girdi alır
```

Ekran görüntüleri emülatörde (`focussayac_verify`, Android 16, release APK)
çekildi; koşullar ve tohumlanan durum ROADMAP madde 38'de. Play'in kabul
ettiği en büyük en-boy oranı 2:1 olduğu için cihazın kendi 1080×2400'ü (9:20)
kullanılamıyor, çekim öncesi `wm size 1080x1920` ile tam 9:16'ya zorlanıyor.
Durum çubuğu SystemUI'nin demo kipinde (`9:41`, dolu pil, bildirimsiz) —
uygulamanın çizdiği bir şey değil.

512'lik simge cihazdaki launcher simgesiyle aynı görsel olmak zorunda. Zemin
bir kez temaya bağlı bir tokene bağlanmıştı ve açık moddaki cihazlarda simge
krem zeminle çiziliyordu (madde 38); artık düz `#0B0C14` ve
`test/android/launcher_icon_background_test.dart` sapmayı yakalıyor. Simge
katmanlarına dokunulursa 512'yi yeniden üretmek gerekiyor.

## 6. Veri güvenliği formu (Data safety)

`docs/privacy-policy.md` ile birebir tutarlı doldurulacak:

- **Toplanan veri:** yalnızca reklam kaynaklı — *Cihaz veya diğer kimlikler*
  (reklam kimliği) ve *Yaklaşık konum* (IP tabanlı), amaç **Reklamcılık**.
  Veri **paylaşılıyor** (Google AdMob ile).
- **Toplanmayan:** ad/e-posta, kişiler, dosyalar, mesajlar, sağlık, tam
  konum. Sınavlar/seanslar/rozetler cihazda kalıyor → "toplanan veri" değil.
- **Aktarımda şifreleme:** evet. **Silme talebi:** uygulama içinden
  (Ayarlar → Verileri sıfırla).
- **Reklam kimliği kullanılıyor** → Console'un ilgili beyanı ve manifest'teki
  `com.google.android.gms.permission.AD_ID` izni tutarlı.
- İçerik derecelendirme anketinde uygulamada **reklam gösterildiği**
  işaretlenmeli.

## 7. Yayın öncesi kontrol listesi

- [ ] `flutter analyze` 0 hata / 0 uyarı
- [ ] `flutter test` tamamı geçiyor
- [ ] `versionCode` bir önceki yüklemeden büyük
- [ ] `key.properties` dolu, çıktı debug anahtarıyla imzalanmamış (§2)
- [ ] Gerçek AdMob birim kimlikleri `--dart-define` ile verildi (§3)
- [ ] Manifest'teki AdMob `APPLICATION_ID` gerçek hesabınki
- [ ] `focussayac.app/gizlilik` yayında ve `docs/privacy-policy.md` ile aynı
- [ ] Veri güvenliği formu §6'ya göre dolduruldu
- [ ] Simge + feature graphic + 5 ekran görüntüsü Console'a yüklendi
      *(dosyalar hazır ve depoda — §5; kalan iş yalnızca yükleme)*
- [ ] Sürüm notu girildi (§4)
- [ ] Odak ekranı `--profile` modda sürekli 60 fps (ROADMAP madde 8, cihaz)
- [ ] İç test kanalında bir cihazda kurulup açıldı

## 8. Sürüm notu — 1.0.0

ASO §7'deki "İlk yayın" metni:

> Merhaba! FocusSayaç yayında: sınav geri sayımı, pomodoro zamanlayıcı,
> Başarı Meşalesi, rozetler ve haftalık istatistik. Eksik gördüğün sınavı
> veya istediğin özelliği yazarsan bir sonraki sürüme ekliyoruz.

Sonraki sürümlerde ASO §7'nin `[Yeni] / [İyileştirme] / [Düzeltme]` şablonu
kullanılır.
