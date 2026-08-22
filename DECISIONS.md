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

## Faz 2 — core/ katmanı

- `AppColors` tek koyu tema olarak modellendi (`AppColors.dark()`) — prototip yalnızca koyu zeminde
  tasarlandı, açık tema hiçbir ekranda yok, bu yüzden `ThemeMode`/açık varyant eklenmedi.
- Tipografi sabitleri (`AppTypography.display/kicker/body/counter`) `letterSpacing`'i `fontSize * em`
  olarak hesaplıyor — CSS'teki `em` birimi font boyutuna göreli, Flutter'ın `letterSpacing`'i mutlak
  piksel; birebir görsel eşleşme için bu dönüşüm gerekli. Ekrana özgü tam piksel boyutları (örn. büyük
  sayaç 58px, istatistik rakamı 30px) ilgili ekranın fazında, prototipin o bölümü okunarak uygulanacak
  — Faz 2 yalnızca aile/letter-spacing/tabular-figures altyapısını kuruyor.
- `router`: Faz 2'de yalnızca tek geçici kök rota (`/`) var; gerçek ekranlar henüz yok. `RoutePaths`
  sabitleri sonraki fazlarda kullanılacak yol adlarını şimdiden belgeliyor. Ekran 09 (mola) ve Ekran 10
  (iptal onayı) ayrı rota değil — SPEC.md'nin "İptal → Ekran 10" ifadesi geri sayım niteliğinde bir
  onay adımını tarif ediyor, prototipte tam ekran çerçevede gösterilse de gerçek uygulamada Ekran 03'ün
  durum makinesi/dialog'u içinde ele alınması UX açısından daha doğru (Faz 5'te uygulanacak).
- Ortak widget seti (`AppCard`, `KickerLabel`, `FadingDivider`, `AppPillButton`) prototipte tekrar eden
  somut CSS kalıplarından (kart yüzeyi `rgba(30,32,48,.82)`, Michroma uppercase etiketler, Nocturne'ün
  sönümlenen `.hr` çizgisi, hap buton `border+gradient-deep+role-color` üçlüsü) türetildi — icat edilmiş
  bileşen değil, birden çok ekranda gözlenen kalıbın tekilleştirilmesi.

## Faz 3 — services/storage (drift)

- Dört tablo (`Exams`, `PomodoroSessions`, `UserBadges`, `AppSettingsTable`) SPEC.md §4 şemasıyla
  birebir; `PomodoroSession.type`, `Exam.accentRole`, `Exam.source` `textEnum<T>()` ile modellendi
  (drift 2.31'in `EnumNameConverter`'ı, enum adını metin olarak saklar) — `intEnum` yerine tercih
  edildi çünkü DB'yi elle inceleyen biri için okunur kalması, sayısal indekse göre daha az kırılgan.
  `Exam.timeOfDay` düz `"HH:mm"` metin — drift'in yerel bir `TimeOfDay` türü yok, ekstra bir tür
  eklemek bu basit alan için gereksiz karmaşıklık olurdu.
- **Sınav tarihleri koda gömülmedi:** `onCreate` migration'ı 4 preset satırı `assets/data/exam_dates.json`
  dosyasını `rootBundle.loadString` ile okuyarak yazıyor (SPEC.md §4 "Tarihleri `.dart` dosyasına gömme"
  kuralı gereği). JSON şeması `{key, name, subtitle, dateUtc, timeOfDay, accentRole, verifiedAt}` —
  `exam_json_models.dart`'taki `ExamJsonEntry`, hem yerel seed hem uzak override tarafından paylaşılan
  tek çözümleyici. Seed içeriği: YKS/LGS/KPSS Lisans/ALES, 2027 tarihli (2026-08-22 "bugün"e göre en
  yakın gerçekçi gelecek sınav tarihleri) — JSON'daki `_note` alanı bunların resmî takvimden
  doğrulanması gerektiğini belirtiyor.
- **Uzak override, gerçek bir backend olmadan mimari olarak tam kodlandı, çalışma zamanında pasif:**
  `ExamSourceService.remoteOverrideUrl`, `String.fromEnvironment('EXAM_DATES_REMOTE_URL')` ile boş
  varsayılana sahip; boşken ağa hiç çıkmıyor ve yerel seed veri geçerliliğini koruyor. Henüz bir uç
  nokta verilmediği için sahte/rastgele bir URL icat etmek yerine bu yol seçildi — gerçek backend
  bağlanınca `--dart-define=EXAM_DATES_REMOTE_URL=...` ile kod değişikliği olmadan açılır. 24 saatlik
  önbellek `shared_preferences`'a yazılan ISO-8601 zaman damgasıyla tutuluyor; ağ/format hatasında
  `catch (_) {}` ile sessizce yerel veriye düşülüyor (SPEC.md §4 "sessizce 3'e düş" — kullanıcıya hata
  gösterilmiyor, bu kasıtlı ve yorumla belirtildi).
- **`Exam.isActive` + `AppSettings.activeExamId` birlikte tutuluyor:** SPEC.md §4 her iki alanı da
  ayrı ayrı listelediği için ikisi de şemada var; `ExamDao.setActiveExam`/`AppSettingsDao.setActiveExam`
  ayrı DAO'larda ayrı metotlar olarak kaldı (drift `DatabaseAccessor` sınırları tablo bazlı) ama Faz 4+
  UI katmanı ikisini birlikte çağırmalı — bu tek işlemli bir "değiştir" API'si Faz 4'te bir Riverpod
  notifier'ında birleştirilecek.
- **`store_date_time_values_as_text: true`** (`build.yaml`, drift_dev seçeneği) eklendi. Varsayılan
  epoch-int depolama, okurken `DateTime`'ı **yerel saate** çeviriyor (test sırasında somut olarak
  gözlendi: UTC `00:00Z` yazılan bir zaman `03:00` yerel olarak geri geldi) — SPEC.md §5.1 "Tüm hesap
  UTC" kuralını cihaz saat dilimine bağlı olarak sessizce bozardı. ISO-8601 metin depolama UTC'yi
  birebir korur; bu, prod DB dosyası + bellek-içi test DB'si için ortak, tek bir codegen ayarı.
- **`sqlite3_flutter_libs` sürümü `^0.6.0+eol`'den `^0.5.41`'e düşürüldü.** `0.6.0+eol`, yalnızca
  `sqlite3` paketinin 3.x sürümüyle (yerel asset hook'ları native kütüphaneyi kendisi indirir)
  kullanılmak üzere **hiçbir şey yapmayan boş bir stub**; ama Faz 1'in `meta`/`analyzer` sürüm
  pinlemesi `sqlite3`'ü 2.9.4'te tutuyor (native asset hook'u yok). `0.6.0+eol` ile 2.x arasında hiçbir
  şey Android/iOS için `libsqlite3.so`/`.a`'yı gerçekten paketlemiyordu — bu, cihazda sessizce
  `NativeDatabase` açma hatasına yol açacak gizli bir Faz 1 hatasıydı, Faz 3'te veritabanı gerçekten
  açılırken ortaya çıktı. `0.5.41` (son işlevsel, EOL öncesi sürüm) native kütüphaneyi eskisi gibi
  gradle/CocoaPods ile paketliyor ve `sqlite3` 2.x ile uyumlu.
- **`build_runner` dev_dependency olarak eksikti** (Faz 1'de hiç eklenmemiş) — `^2.4.13` eklendi
  (`drift_dev`'in kendi `pubspec.yaml`'ındaki `build_runner: ^2.4.0` alt sınırıyla uyumlu).
- **`dart run build_runner build` bu ortamda yalnızca `--force-jit` ile çalışıyor.** Varsayılan AOT
  derlemesi `'dart compile' does not support build hooks, use 'dart build' instead` hatasıyla
  başarısız oluyor — paket grafiğindeki bir native-asset-hook paketi (muhtemelen bir Flutter eklentisi)
  Dart 3.10 SDK'sının `dart compile`'ının artık desteklemediği bir "hook" tanımlıyor. `--force-jit`
  AOT'yi atlayıp derleme betiğini JIT modda çalıştırıyor — biraz daha yavaş ama tam olarak çalışıyor;
  bu proje için `dart run build_runner build --force-jit` standart komut olarak benimsendi.
- **Enum sütun karşılaştırması:** DAO `where()` kapatmalarında closure parametresi DSL soyut tablo
  tipiyle (`PomodoroSessions s`) açıkça tipleniyor; bu tip `textEnum` sütunlarını düz `TextColumn`
  olarak görüyor (tip-dönüştürücülü sürüm yalnızca *üretilen* `$PomodoroSessionsTable`'da var), bu
  yüzden `equalsValue(SessionType.focus)` derlenmiyor. Bunun yerine `s.type.equals(SessionType.focus.name)`
  kullanıldı — enum'un adı zaten disk üzerindeki temsil, bu yüzden doğru ve DSL/üretilmiş sınıf
  tipi farkından bağımsız.
- Test: `test/services/storage/app_database_test.dart`, `AppDatabase.forTesting(NativeDatabase.memory())`
  ile 4 DAO'yu ve `onCreate` seed'ini kapsıyor (11 test, hepsi geçiyor). Gerçek dosya tabanlı DB yerine
  bellek-içi DB kullanıldı — testler hızlı ve izole, disk temizliği gerekmiyor.
