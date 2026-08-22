# DECISIONS.md

Belirtilmemiş her detayda alınan kararlar, tek cümle gerekçesiyle, faz sırasına göre.

## Faz 0 — Repo düzeni

- Üç prototip `.dc.html` dosyası, `_ds/` (Nocturne tasarım sistemi) ve `github.md`
  `design/` altına taşındı — bunlar tasarım referansı, Flutter kaynak ağacının parçası değil.
- `doc-page.js`, `support.js`, `.thumbnail` silindi — tasarım aracının kendi görüntüleyici/destek
  betikleri, prototipin statik görsel referans değeri için gerekli değil (SPEC.md Faz 0 talimatı).
- `docs/superpowers/specs/2026-08-22-focussayac-app-design.md` silinmedi ama artık ikincil:
  `SPEC.md` (bu dokümanın kök kopyası) esas kaynak, çakışan noktalarda (ör. interstitial reklamlar)
  `SPEC.md` geçerli — SPEC.md §0 çakışma önceliği kuralı gereği.
- `SPEC.md` proje köküne, kullanıcının verdiği master prompt v3'ün birebir kopyası olarak eklendi.
- Standart Flutter `.gitignore` şablonu eklendi (build artifact'leri, `.dart_tool/`, üretilen
  `*.g.dart`/`*.freezed.dart`/`*.gr.dart` dosyaları, imzalama anahtarları) — Faz 1'de `flutter create`
  çalıştırıldığında üretilecek dosyaların commit'e sızmaması için önceden hazırlandı.

## Faz 1 — Proje iskeleti

- Uygulama ID'si `com.focussayac.focussayac` (org `com.focussayac`, proje adı `focussayac`) —
  prototipin filigranı `focussayac.app` ile aynı marka kökü, belirtilmemiş bir detay.
- `flutter create --platforms=android` kullanıldı — SPEC.md §1 "Android-first (iOS sonraki faz,
  macOS gerekir)" gereği yalnızca Android platformu üretildi.
- minSdk 23 / targetSdk 35 `android/app/build.gradle.kts` içine sabit yazıldı (SPEC.md §1),
  `flutter.minSdkVersion`/`flutter.targetSdkVersion` yerine — SPEC değeri Flutter SDK varsayılanından
  farklı olabileceği için doğrudan sabitlendi.
- `flutter create`'in ürettiği `// TODO` yorumları (uygulama ID'si, imzalama) SPEC.md §0 kural 6
  gereği ("TODO yasak") kaldırıldı; release imzalama Faz 15'e ertelendiği açıkça yorum olarak belirtildi.
- **Riverpod/Drift sürüm pinleme:** Bu ortamdaki Flutter stable (3.38.5, Dart 3.10.4) `meta` paketini
  1.17.0'a sabitliyor; `riverpod_generator`'ın en güncel sürümleri (≥4.0.4) ve `drift_dev`'in en güncel
  sürümleri (analyzer ≥13) `meta ^1.18.0` gerektiriyor ve pub sürüm çözümü başarısız oluyor. Bu yüzden
  `flutter_riverpod`/`riverpod_annotation` 3.1.0/4.0.0 ve `riverpod_generator` ^4.0.0+1, `drift`/`drift_dev`
  2.31.0'a sabitlendi — hepsi karşılıklı uyumlu ve mevcut SDK ile derleniyor. `flutter pub outdated`
  bunları "yeni sürüm var" olarak işaretleyecek; bu kasıtlı, SDK'nın kendisi güncellenmeden çözülemez.
- **`drift_flutter` paketi kullanılmadı** — bu paket `sqlite3 ^3.0.0` zorunlu kılıyor ve bu da yukarıdaki
  Riverpod/analyzer çakışmasını yeniden tetikliyor. Onun yerine Faz 3'te veritabanı bağlantısı
  `drift`'in `NativeDatabase` + `sqlite3_flutter_libs` + `path_provider` ile elle açılacak; davranış
  aynı, ekstra paket bağımlılığı yok.
- `riverpod_lint`/`custom_lint` eklenmedi — SPEC.md §1'deki paket tablosunda yok, ve `freezed_annotation`
  ^3.1.0 ile sürüm çakışması yaratıyordu; strict lint zaten `analysis_options.yaml`'da elle sağlanıyor.
- `analysis_options.yaml`: `strict-casts`/`strict-inference`/`strict-raw-types` ve ek linter kuralları
  (ör. `unawaited_futures`, `cancel_subscriptions`, `close_sinks`) eklendi — SPEC.md §8 Faz 1 "strict
  analysis_options.yaml" talimatı somut bir kural seti gerektiriyordu, seçim Flutter/Dart ekibinin
  önerdiği "sağlamlaştırılmış" kurallardan oluşuyor. Üretilen kod dosyaları (`*.g.dart` vb.) analizden
  hariç tutuldu çünkü bunlar elle düzenlenmez.
- **AndroidManifest izinleri:** `INTERNET`/`ACCESS_NETWORK_STATE` (reklam + uzak JSON), `WAKE_LOCK`
  (`wakelock_plus`), `POST_NOTIFICATIONS`/`SCHEDULE_EXACT_ALARM` (SPEC.md §0 Ekran 01 izin akışı),
  `RECEIVE_BOOT_COMPLETED` (yeniden başlatma sonrası zamanlanmış bildirimlerin kurtarılması,
  `flutter_local_notifications`'ın kendi belgelediği gereksinim) ve `com.google.android.gms.permission.AD_ID`
  eklendi. `flutter_local_notifications`'ın `ScheduledNotificationReceiver` ve
  `ScheduledNotificationBootReceiver` bileşenleri manifest'e kayıtlı — paketin kendi kurulum
  talimatının zorunlu adımı.
- **AdMob App ID placeholder:** `com.google.android.gms.ads.APPLICATION_ID` meta-data'sına Google'ın
  resmi genel test App ID'si (`ca-app-pub-3940256099942544~3347511713`) girildi — gerçek bir AdMob
  hesabı/App ID'si henüz verilmedi; Faz 11'de gerçek reklamlar bağlanırken değiştirilecek, yorumda
  belirtildi.
- **Fontlar indirildi ve subset edildi:** Space Grotesk ve Inter, Google Fonts deposunda yalnızca
  değişken (variable) font olarak dağıtılıyor; `fonttools`'un `varLib.instancer`'ı ile 400/500/600/700
  (Space Grotesk) ve 400/500/600 (Inter, `opsz=14` sabitlenerek) statik enstansiyasyonlar üretildi.
  Michroma zaten tek ağırlıkta statik. Üçü de `fonttools subset` ile Türkçe alfabe + temel Latin +
  yaygın tipografik noktalama (§ U+0020–007E, Türkçe harfler, tire/tırnak/üç nokta/orta nokta) karakter
  kümesine indirildi; Michroma SPEC.md §2 gereği yalnızca büyük harf + rakam + birkaç etiket noktalama
  işaretiyle sınırlandı. Sonuç: Inter 856KB→68KB/ağırlık, Space Grotesk 133KB→~30KB/ağırlık,
  Michroma 63KB→15KB. OFL lisans metinleri `assets/fonts/licenses/` altında referans için tutuluyor
  (build'e dahil değil, yalnızca dokümantasyon).
