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
  **(Faz 17'de geri alındı: `AppColors.light()` + `ThemeMode` eklendi — bkz. "Faz 17".)**
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

## Faz 4 — Ekran 02 + 11 + 08

- **`phosphor_flutter: ^2.1.0` eklendi.** Prototip tüm ekranlarda `@phosphor-icons/web` (`ph`/`ph-fill`/
  `ph-duotone` sınıfları) kullanıyor ama Faz 0-3 hiç ikon çizmediği için paket eksikti. `flutter pub add`
  ile eklendi, mevcut `meta`/`analyzer`/`sqlite3` pinleriyle çakışmadan çözüldü.
- **Telefon çerçevesi (46px radius, `shadow-md`) ve sahte `9:41` durum çubuğu çizilmedi** — SPEC.md
  Ekran 01'in "gerçek sistem çubuğu; sahte çubuğu çizme" kuralı, tasarım aracının kendi mockup çerçevesi
  olduğu için tüm ekranlara genellendi; gerçek cihazda zaten `SafeArea`/sistem çubuğu var.
- **Aurora zeminler ve kartlar BÖLÜM 6'nın performans kurallarına göre baştan inşa edildi** (Faz 14'ü
  beklemeden): `BackdropFilter`/runtime blur hiç kullanılmadı, aurora parıltıları `RadialGradient`
  (kenarda zaten saydama düşen) ile çizildi — SPEC.md §6 "Zorunlu uygulama" ifadesiyle "aynı görünen
  ama daha ucuz" serbestliği (§0 kural 2) örtüşüyor; Faz 14 yalnızca `--profile` doğrulaması için var,
  ekranları yanlış teknikle yazıp sonra değiştirmek gereksiz iş olurdu.
- **Krom (chrome) tipografi Ekran 02'nin gün rakamında statik `ShaderMask` gradyanı** — `shimmer`
  animasyonu SPEC.md §6.3 gereği yalnızca Ekran 01 başlığında çalışıyor.
- **"Bugün" kartı `rgba(30,32,48,.72)` literal alfasıyla** çizildi, `AppCard`'ın varsayılan `.82`'si
  yerine — prototip bu kartta farklı bir alfa kullanmış, "birebir taşı" kuralı `AppCard`'ı zorlamaktan
  önceliklidir; bu yüzden burada `AppCard` yerine doğrudan `Container` kullanıldı.
- **Alt gezinme çubuğu (`BottomNavBar`) rozetler/istatistik/ayarlar sekmelerinde no-op** — o ekranlar
  Faz 7/9/12'de geliyor; var olmayan bir rotaya `go_router` ile gitmeye çalışmak çökerdi. Görsel olarak
  prototipteki gibi duruyor, `onSelect` ileride bağlanacak.
- **`streak_calculator.dart` (saf fonksiyon) ve `duration_formatter.dart` Faz 7/9'dan Faz 4'e çekildi.**
  Ekran 02 gerçek "N gün seri" ve "H SA M DK" değerleri göstermek zorunda (DoD: "demo sayıların hiçbiri
  kodda yok" — 6 gün seri prototipin demo verisi). Rozet açma/kilit mantığı hâlâ Faz 7'de; yalnızca IO'suz
  saf hesaplama fonksiyonları öne çekildi.
- **`lib/core/time/app_day.dart` sabit UTC+3 ofset kullanıyor**, `timezone` paketinin tam `TZDateTime`
  altyapısı yerine — Türkiye 2016'dan beri DST uygulamıyor, bu yüzden 04:00 TSİ gün sınırı ve tarih
  gösterimi için sabit ofset tam doğru ve çok daha ucuz. `timezone` paketi Faz 6'da bildirim
  zamanlamasında kullanılacak (`zonedSchedule` gerçek `TZDateTime` ister).
- **"25 DAKİKA ODAKLAN" butonu şimdilik no-op** — Ekran 03 (odak seansı) Faz 5'te geliyor; buton
  prototipteki gibi etkin görünüyor ama henüz gidecek bir rota yok.
- **Sınav seçici sheet'teki satır ikonu tek tip (`graduation-cap`), rol rengiyle boyanıyor.** Prototip
  bu alanı `{{ e.icon }}` olarak veriye bağlamış ama somut bir değer vermemiş (yalnızca
  `hint-placeholder-count`); icat edilmiş bir ikon-başına-sınav eşlemesi yerine tek, tutarlı bir seçim
  yapıldı.
- **`GoRouter.initialLocation` doğrudan `RoutePaths.countdown`'a alındı.** Ekran 01 (onboarding) Faz
  10'da geliyor; o zamana kadar uygulama doğrudan geri sayımla açılıyor, eski `_BootstrapPlaceholder`
  kaldırıldı.
- **`main()` artık async**: `AppDatabase` + `SharedPreferences.getInstance()` açılışta kuruluyor,
  `ProviderScope.overrides` ile `appDatabaseProvider`/`sharedPreferencesProvider`'a enjekte ediliyor
  (Faz 3 `DECISIONS.md`'nin bıraktığı yer). `ExamSourceService.syncIfNeeded()` `unawaited` çağrılıyor —
  SPEC.md §4 zaten sessiz/bloklamayan bir sözleşme tanımlıyor.
- **`ProviderScope(overrides: [...])` listesi tip parametresiz bırakıldı** (`Override` sınıfı
  `flutter_riverpod` paket barrel'ından dışa aktarılmıyor — riverpod 3.1.0'da iç bir tür); Dart'ın
  yukarıdan-aşağı tip çıkarımı `ProviderScope.overrides`'ın beklediği türü zaten çözüyor.
  Aynı sürümde `AsyncValue.valueOrNull` da yok — `.value` zaten `ValueT?` döndürüyor, doğrudan o kullanıldı.
- **Ekran 11'de tarih/saat girişi TSİ duvar saati olarak alınıp UTC'ye çevriliyor** (`-3 saat`);
  `Exam.timeOfDay` metni kullanıcının girdiği saat değerini birebir taşıyor.
- **Yeni özel sınav kaydedilince otomatik aktif ediliyor.** SPEC.md Ekran 11 bunu açıkça yazmıyor ama
  kullanıcı az önce hedef olarak eklediği bir sınavı takip etmek istiyor olmalı — makul bir UX çıkarımı,
  `ActiveExamSwitcher` zaten Faz 4'ün kendi birleşik API'si.
- **`test/widget_test.dart`, eski "FocusSayaç" placeholder smoke testinden Ekran 02'yi render eden
  gerçek bir smoke testine dönüştürüldü.** `SharedPreferences` override'ı teste eklenmedi — Ekran 02'nin
  render yolu `sharedPreferencesProvider`'ı hiç okumuyor (yalnızca `ExamSourceService`/`main.dart`
  kullanıyor), gereksiz platform kanalı riski almaya değmedi. Test yüzeyi `tester.view.physicalSize`
  ile 390×844'e sabitlendi — varsayılan ~800×600 test penceresi, telefon boyu için tasarlanmış Ekran
  02'de dikey taşmaya yol açıyordu. **`database.close()` teste eklenmedi ve teardown'da
  `pumpAndSettle()` kullanıldı** — ikisi birbirine bağlı, ayrıntılı gerekçe: `ProviderScope` kaldırılınca
  Riverpod'un `StreamProvider`ları drift'in `.watch()` aboneliklerini iptal ediyor, drift de her
  abonelik kapanışında `FakeAsync` bölgesinde sıfır-süreli bir temizlik `Timer`'ı zamanlıyor;
  `database.close()`'u doğrudan `await` etmek (kare pompalamadan) bu sahte saat hiç ilerlemediği için
  asla tamamlanmayan bir `Future`'a kilitleniyordu (gözlemlenen: çoklu dakikalık gerçek hang).
  Kapatmayı hiç çağırmamak (bellek-içi test DB'si zaten process'le birlikte yok oluyor) ve teardown'un
  ardından `pumpAndSettle()` ile bu zamanlayıcıları güvenle boşaltmak çözüm oldu — o noktada ekranın
  kendi sonsuz-tekrarlı halka animasyonu zaten ağaçtan kalkmış olduğu için `pumpAndSettle` orada takılmıyor.

## Faz 5 — Ekran 03 + 09 + 10: durum makinesi, wall-clock timer, meşale, mola, iptal

- **`freezed` dev_dependency olarak eklendi** (`^3.2.3`) — SPEC.md §5.2 "durum makinesi (freezed sealed
  union)" talimatı gereği. Faz 1'in `meta`/`analyzer` sürüm pinlemesiyle çakışmadan temiz çözüldü
  (`flutter pub add -d freezed` dry-run ile önce doğrulandı), Faz 1/3'teki riverpod/drift codegen
  çakışmalarının aksine burada ekstra bir pinleme gerekmedi.
- **`PomodoroPhase` union'ı SPEC'in andığı 8 addan yalnızca 4'ünü modelliyor**: `idle`, `focusRunning`,
  `focusPaused`, `breakRunning`. `focusCompleted`/`breakCompleted` kendi başına render edilen bir ekrana
  sahip değil — tamamlanma (DB yazımı + bir sonraki faza geçiş) `PomodoroController` içinde tek senkron
  adımda oluyor, bu yüzden ayrı bir union üyesi olarak modellenmedi. `breakPaused` da yok: Ekran 09
  prototipinde molayı duraklatan bir kontrol yok (yalnızca "5 dk ekle"/"ODAĞA DÖN") — hiç üretilmeyecek
  bir durumu union'a eklemek SPEC.md §0 "basitlik" ilkesine ve CLAUDE.md "do not over-engineer"
  kuralına aykırı düşerdi.
- **`NotifierProvider` (elle yazılmış, `riverpod_generator` kullanılmadan) tercih edildi** — mevcut
  kod tabanında (Faz 2-4) `@riverpod` annotation'lı codegen'e hiç geçilmemiş, tüm provider'lar elle
  yazılmış; `PomodoroController` de bu kurulu kalıba uyuyor. `flutter_riverpod` 3.1.0'da hem modern
  `Notifier`/`NotifierProvider` hem eski `StateNotifierProvider` mevcut — legacy olmayanı seçildi.
- **Döngü konumu (`cyclePosition`) ayrı bir kalıcı sayaç yerine `todayFocusStatsProvider.completedCount % 4`
  üzerinden türetiliyor** — Ekran 02'nin Faz 4'te kurduğu "bugünkü tamamlanan sayısı" akışıyla aynı
  kaynağı paylaşıyor (SPEC §2 "Basitlik"); gün sınırı zaten 04:00 TSİ'de sıfırlandığı için ekstra bir
  DB alanı/durum gerekmiyor.
- **Durum diyagramı `breakCompleted → idle` yazıyor, `breakCompleted → focusRunning` değil** — bu yüzden
  hem molanın doğal bitişi hem de "ODAĞA DÖN" (erken bitirme) `idle`'a dönüyor; sonraki pomodoro'yu
  başlatmak kullanıcının Ekran 02'den "25 DAKİKA ODAKLAN"a tekrar dokunmasını gerektiriyor. Prototipin
  "ODAĞA DÖN" ("molayı erken bitirir") ifadesi de bunu destekliyor — otomatik yeni seans başlatma SPEC
  metninde yok, eklemek "prototipte olmayan özellik ekleme" riski taşırdı.
- **Duraklat/devam ettir, azalan bir sayaç tutmadan `resumeVirtualStart` ile çözüldü**: devam ederken
  `startedAtUtc`, "eğer kesintisiz çalışsaydı duraklama anındaki kalan süreyi verecek" bir sanal değere
  kaydırılıyor; DB'deki gerçek `startedAt` hiç değişmiyor. SPEC §5.1'in "her zaman `startedAt+planned-now()`"
  formülü böylece duraklatma sonrasında da birebir korunuyor.
- **Cihaz saati geri alma koruması, `startedAt`'e değil ardışık `now()` okumalarına kıyaslıyor**:
  `tick()` her çağrıldığında son ölçülen `now()` ile yeni `now()` karşılaştırılıyor; yeni değer eskisinden
  küçükse (saat geri alındı) aktif seans `completed:false` ile kapatılıp `idle`'a dönülüyor. Bu, SPEC'in
  "negatif kalan süre → tamamlanmış sayılmaz" kuralını hiçbir zaman `completed:true` üretmeyerek
  kesin biçimde garanti ediyor; sahte bir `Clock` enjeksiyonu eklenmediği için otomatik testle değil
  kod incelemesiyle doğrulandı (DoD'nin bu maddesi).
- **Aktif faz `SharedPreferences`'a elle yazılmış küçük bir JSON blob'u olarak yazılıyor** (`json_serializable`
  kullanılmadan) — yalnızca 3-4 alanlı, tek yerde encode/decode edilen basit bir yapı için ekstra bir
  codegen bağımlılığı gereksiz karmaşıklık olurdu.
- **Ekran 10'un (iptal onayı) hiçbir metni prototipte `{{ }}` ile işaretli değil** — v2 prototipinin bu
  ekranı tamamen statik demo sayılarla (09:24, 9 dakika 24 saniye, 15 dakika 36 saniye, 6 gün) yazılmış.
  Gerçek bağlamalar SPEC.md'nin binding tablosundaki düz metin açıklamalarından çıkarıldı: demo
  sayılarının kendisi bile tutarlı (elapsed 9:24 + remaining 15:36 = planned 25:00) — bu da "elapsed =
  planned - remaining" ilişkisini doğruluyor. "6 günlük serin risk altına girer" cümlesi yalnızca bugün
  tamamlanmış seans yoksa **ve** güncel seri ≥1 ise gösteriliyor (seri 0 iken "risk altına giren" bir
  şey yok); yalnızca "bugün seans yoksa" koşulu olsaydı seri 0 için de anlamsız bir cümle üretirdi.
- **"UZUN MOLA" etiketi SPEC.md'nin kendi metninden alındı** ("KISA MOLA / uzun mola" — SPEC.md Ekran 09
  binding tablosu), prototipte yalnızca kısa mola demo edilmiş; bu, "yeni metin yazma" kuralını ihlal
  etmiyor çünkü kaynağı SPEC.md'nin kendisi, benim icadım değil.
- **"molada dene" katalogu yalnızca prototipteki 2 ipucuyla sınırlı** (ekrana bakmama, su içme) — SPEC
  "her molada rastgele 2 tanesi" diyor ama prototip yalnızca 2 tane somut metin veriyor; ekstra ipucu
  icat etmek "yeni metin yazma yasak" kuralını ihlal ederdi. Katalog büyüdükçe (gelecek faz/ürün kararı)
  rastgele seçim otomatik anlamlı hale gelecek.
- **Ekran 03'ün "skip-forward" ikonu görsel olarak duruyor ama dokunmaya bağlı değil** *(ROADMAP madde
  5'te geri alındı — düğme tamamen kaldırıldı, gerekçesi en alttaki bölümde)* — SPEC.md'nin
  Ekran 03 binding tablosunda bu buton için hiçbir davranış tanımlı değil (yalnızca X/oynat-duraklat
  bağlanmış); var olan bir prototip elemanını görsel olarak silmek "birebir taşı" kuralını, ona
  tanımsız bir davranış icat etmek de "özellik ekleme yasağı"nı ihlal ederdi — Faz 4'ün alt gezinme
  sekmeleri için kurduğu "görsel var, `onTap` yok" emsaliyle aynı çözüm.
- **Meşalenin `flick` animasyonunun sayısal keyframe değerleri prototip HTML'inde yok** — yalnızca
  `_ds_bundle.js` içinde derlenmiş halde duruyor, kaynak yüzdeleri dışa açık değil. Sinüs tabanlı bir
  salınım (yatay kayma + dikey gerilme + hafif eğim) kendi kararımızla uygulandı — SPEC §0 kural 5
  "belirtilmemiş detayda kendi kararını ver" kapsamında.
- **Alev şekli tam CSS `border-radius` yüzde/eliptik zincirinin birebir eşdeğeri yerine
  `BorderRadius.elliptical` ile yaklaşık bir gözyaşı damlası olarak çizildi** — CSS'in çok parçalı
  `50% 50% 46% 46% / 68% 68% 32% 32%` söz dizimi Flutter'da doğrudan karşılığı olmayan bir birleşik
  eğri; SPEC §6'nın "aynı görünen ama daha ucuz" serbestliği burada da uygulandı.
- **İptal onayı dialog'unun arka planı `BackdropFilter` ile bulanıklaştırılmadı**, düz yarı saydam bir
  `barrierColor` kullanıldı — bu dialog, wakelock'un açık olacağı odak seansı sırasında görünebiliyor;
  SPEC §6'nın "odak ekranında runtime blur'dan kaçın" ruhu kısa süreli bir modal için de uygulandı.
- **`PhosphorIconsDuotone.flameSlash` yok** (`phosphor_flutter ^2.1.0`'da yalnızca `flame` var) —
  prototipin `ph-duotone ph-flame-slash` ikonuna en yakın karşılık olarak `flame` (rose renkte)
  kullanıldı.
- **Wakelock ve bildirimler Faz 5'te bağlanmadı** — SPEC.md §8 faz planı bunları açıkça Faz 6'ya
  koyuyor ("Bildirimler ... + wakelock + izin akışı"); Faz 5 yalnızca durum makinesi/wall-clock/UI
  kapsıyor.
- **Testler için odak/mola süresi 0 saniyeye ayarlandı** (`AppSettingsDao.updateSettings`), gerçek
  `DateTime.now()` kullanan `tick()`'in anında tamamlanma üretmesi için — controller'a sahte bir
  `Clock` enjekte edilmedi (SPEC §5.1 "gerçek duvar saati" ilkesiyle en sade uyum).
- **`ProviderContainer` tabanlı testlerde `container.read(streamProvider)` tek başına aboneliği
  güvenilir şekilde tetiklemedi** (gözlemlendi: `AsyncLoading` içinde süresiz asılı kaldı) —
  `container.listen(provider, ..., fireImmediately: true)` eklemek akışın ilk yayınını gerçekten
  başlattı. Bu, `pomodoro_controller_test.dart`'ın kurulumunda belgelenmiş bir gözlem/atlatma.
- **`test/widget_test.dart`'a `sharedPreferencesProvider` override'ı eklendi** — Faz 4'ün "bu ekranların
  render yolunda hiç okunmuyor" notu artık geçersiz: `CountdownScreen` artık aktif seans kurtarma
  yönlendirmesi için `pomodoroControllerProvider`ı okuyor, o da `SharedPreferences`'a bağlı.

## Faz 6 — Bildirimler (4 tip) + wakelock + izin akışı

- **`NotificationService`, `AppDatabase`/`appDatabaseProvider` ile birebir aynı DI kalıbında** — elle
  yazılmış statik bir singleton yerine `notificationServiceProvider` (varsayılanı
  `UnimplementedError` fırlatan bir `Provider`) `main.dart`'ta gerçek örnekle override edilir
  (SPEC §1 "singleton servisler yasak"). Testler için `NotificationService.disabled()` — gerçek
  `FlutterLocalNotificationsPlugin`'i hiç oluşturmayan, tüm çağrıları no-op yapan ikinci bir
  constructor — `AppDatabase.forTesting`'le aynı kalıp; `pomodoro_controller_test.dart`'ın
  `_buildContainer()`'ı bunu override ediyor.
- **Bildirim izin akışı (`POST_NOTIFICATIONS` → `SCHEDULE_EXACT_ALARM`, SPEC.md Ekran 01) Ekran 01'in
  kendisi olmadan `main.dart`'ta açılışta tetikleniyor** — onboarding UI'ı (İZİN VER VE BAŞLA / Şimdi
  değil) Faz 10'a ait; ama bildirimler Faz 6'nın kapsamı ve Android 13+'ta `POST_NOTIFICATIONS`
  reddedilirse hiç gösterilmiyor, bu yüzden izin isteği bugünden itibaren çalışmalı. İzin reddedilirse
  `NotificationService`'in her metodu sessizce no-op'a düşer (SPEC DoD "izinler reddedildiğinde
  uygulama tam çalışıyor") — Faz 10 aynı `NotificationService.initialize()`'ı kendi buton akışından
  tekrar çağırabilir, bu idempotent.
- **"Kalıcı" bildirim (`Odak · n. pomodoro`) yalnızca odak fazında gösteriliyor, molada değil** —
  SPEC.md Ekran 12 tablosunun başlığı özellikle "Odak" diyor (genel "Seans" değil); duraklatmada da
  iptal edilip devam ederken yeniden gösteriliyor (SPEC'in "Ekran açık kalır" ipucu yalnızca çalışırken
  anlamlı).
- **Seans bitişi bildirimi yalnızca odak → mola geçişi için var, mola bitişi için ayrı bir bildirim
  yok** — SPEC.md Ekran 12 tablosu tam olarak dört tip sayıyor ve "Seans bitişi" metni yalnızca
  "...mola vakti" diyor; beşinci bir tip icat etmek CLAUDE.md "istenmeyen özellik ekleme" kuralını
  ihlal ederdi.
- **Seans bitişi metnindeki dakika sayıları (`{{ }}` değil ama SPEC'in "25 dakika...5 dakika" örneği)
  gerçek `AppSettingsTableData.focusMinutes` ve `isLongBreakFor(cyclePosition)`'a göre seçilen
  kısa/uzun mola dakikasından geliyor** — SPEC DoD "demo sayılarının hiçbiri kodda yok" kuralı
  bildirim metinlerine de uygulanıyor.
- **Seri riski bildirimi, arka planı olmayan bir "yeniden değerlendir ve tek seferlik kur" kalıbıyla
  uygulandı** — SPEC.md §1 backend/cloud sync'i yasaklıyor, bu yüzden "her gün 21:00, yalnızca bugün
  seans yoksa ve seri ≥1 ise" koşulunu gerçek zamanlı değerlendirecek bir arka plan işi kurulamıyor.
  Bunun yerine `NotificationService.rescheduleStreakRiskReminder` her yeniden değerlendirme
  noktasında (uygulama açılışı `main.dart`, ve her `_completeFocus` sonrası) önce mevcut zamanlanmış
  bildirimi iptal edip koşul hâlâ geçerliyse o günün 21:00 TSİ'si için tek seferlik yeniden kuruyor;
  bugünün 21:00'i zaten geçtiyse hiç kurulmuyor. Bilinen sınır: kullanıcı o gün hiç uygulamayı açmazsa
  bildirim hiç kurulmuyor — yerel/backend'siz bir zamanlayıcının doğal sonucu, "basitlik" ilkesiyle
  kabul edildi.
- **`timezone` paketi `Europe/Istanbul` IANA veritabanı girdisiyle kullanıldı**, `app_day.dart`'ın
  sabit UTC+3 kısayolu yerine — Faz 3'ün `app_day.dart` yorumu zaten bunu Faz 6'ya erteliyordu;
  bildirim zamanlaması gibi platform API'lerine geçen değerler için paketin resmî `Location`'ı
  (2016 öncesi DST geçişlerini de doğru modelleyen) daha sağlam, `zonedSchedule`'ın zaten
  `TZDateTime` beklemesiyle de doğal olarak örtüşüyor.
- **Rozet bildirimi (`showBadgeUnlocked`) Faz 6'da yazıldı ama hiçbir yerden çağrılmıyor** —
  `badge_rules.dart` ve rozet açılış akışı Faz 7'nin kapsamı (SPEC §8); SPEC.md Ekran 12'nin dört
  bildirim metnini "birebir" barındırma gereği bu metodu şimdiden tam ve doğru yazmayı gerektiriyordu,
  Faz 7 yalnızca çağıracak.
- **Wakelock, `FocusSessionScreen`in `initState`/`dispose`'unda açılıp kapatılıyor** — ekran hem odak
  (Ekran 03) hem molayı (Ekran 09) aynı rota içinde gösterdiği için (Faz 5 kararı) tek bir aç/kapat
  yeterli; ayrıca duraklat/devam state'ine göre koşullu açıp kapatmak SPEC'in "Ekran açık kalır"
  ipucunun duraklatmada da göründüğü gerçeğiyle çelişirdi (basitlik).
- **`NotificationService` alanı `_istanbul` `final` değil** — `_location` getter'ı onu tembel
  başlatıp önbelleğe alıyor; bu yüzden `NotificationService.disabled()` `const` constructor
  *olamıyor* (Dart kısıtı: non-final alanlı sınıf const constructor'a sahip olamaz) — testte
  `const NotificationService.disabled()` değil `NotificationService.disabled()` kullanılıyor.

## Faz 7 — Ekran 04 (rozetler) + `badge_rules` + `streak_calculator` + açılış dialogu

- **`calculateLongestStreak` `streak_calculator.dart`'a eklendi**, ayrı bir dosyaya değil — SPEC.md
  §5.4 "Haftalık Seri" rozeti "7 gün üst üste ≥1 seans" der ve rozetler asla geri alınmaz; mevcut
  `calculateStreak` yalnızca bugün/dün canlıysa sayar (Ekran 02'nin "6 gün seri" göstergesi için doğru
  semantik), bu yüzden rozet kuralı ayrı, "tüm zamanların en uzun serisi" anlamına gelen saf bir
  fonksiyon gerektiriyordu. Bu fonksiyon Ekran 06'nın "en uzun seri" istatistiğiyle (Faz 9) de birebir
  aynı hesap olduğu için `domain/streak/` içinde kalması, `domain/badges/` altına kopyalanmasından
  daha doğru (SPEC §0 kural 9 "iletişim core/ ve domain/ üzerinden").
- **Rozet kataloğu (`badge_definition.dart`) İngilizce `key` alanları kullanıyor** (`first_spark`,
  `focus_torch`, vb.) — SPEC §0 kural 7 "kod/değişken İngilizce, kullanıcı metinleri yalnızca ARB'den";
  `name`/`rule` alanları hâlâ Türkçe çünkü ARB geçişi Faz 13'e kadar tüm ekranlarda hard-coded
  (Faz 4-6 emsali), rozet kataloğu da bu kuraldan muaf değil.
- **`evaluateEarnedBadgeKeys` idempotent ve geriye dönük yeniden hesaplanabilir** — DB'de "hangi
  rozetler açık" diye ayrı bir önbellek tutmuyor, her çağrıda tüm tamamlanmış odak geçmişinden yeniden
  türetiyor. Bu, SPEC §5.4 "yalnızca başarıyla açılır, asla satın almayla" ve "asla geri alınmaz"
  kurallarını IO'suz saf bir fonksiyonla garanti ediyor; IO'lu kısım (`BadgeUnlockService`,
  `domain/badges/badge_providers.dart`) yalnızca zaten `UserBadge` tablosunda olmayan anahtarları
  fark edip yazıyor.
- **"Sabah Yıldızı"/"Gece Nöbeti" sınırları dakika hassasiyetiyle karşılaştırılıyor** (`hour*60+minute`
  < 480 / ≥ 1380), yalnızca `hour` ile değil — SPEC §9 test listesi "07:59/08:00 ve 22:59/23:00
  sınırları" diye açıkça dakika bazlı bir sınır istiyor; saat bazlı bir kıyas 08:00 tam ile 08:59'u
  ayırt edemezdi.
- **`BadgeUnlockService.evaluateAfterFocusCompletion` `PomodoroController._completeFocus`'un içine
  eklendi** (Faz 6'nın `NotificationService.showBadgeUnlocked` yorumunun işaret ettiği tam nokta) —
  yalnızca odak seansı tamamlandığında rozet kazanılabilir (SPEC §5.4 kuralları hep "tamamlanan
  pomodoro" üzerine), mola tamamlanışında değil.
- **Rozet açılışındaki `HapticFeedback.heavyImpact()` `AppSettings.hapticEnabled`'a bağlı** — SPEC
  §5.4 bunu açıkça söylemiyor ama `PomodoroController._haptic()`'in her çağrısı bu ayarı kontrol
  ediyor (Faz 5 kararı); titreşimi kapatan bir kullanıcı rozet açılışında da titreşim almamalı,
  tutarlılık "basitlik" ilkesinden daha ağır bastı.
- **Ekran 04'te alt gezinme çubuğu yok** — prototip v2'nin Ekran 04 markup'ı (satır 182-212) diğer
  ekranların (02/06) aksine floating nav bar içermiyor; bu yüzden `BadgesScreen` `BottomNavBar`
  render etmiyor, geri dönüş sistem geri tuşu/kaydırmasıyla (`context.push` kullanıldığı için doğal
  olarak çalışıyor). "Prototipte olmayan öğe ekleme" kuralı burada da geçerli.
- **`BottomNavBar`'ın hem `flame` hem `medal` ikonu rozetler ekranına gidiyor** *(ROADMAP madde 12'de
  geri alındı — `flame` artık Ekran 05'e gidiyor, gerekçesi en alttaki bölümde)* — prototipin alt
  çubuğunda 5 ikon var (timer/flame/medal/chart/gear) ama uygulamada "seri" için ayrı bir ekran yok;
  Faz 4'ün bıraktığı `onSelect` parametresi şimdi yalnızca `AppNavTab.badges` için `context.push`
  çağırıyor, istatistik/ayarlar Faz 9/12'ye kadar no-op kalıyor (aynı dosyanın önceki kararı).
  `_ActiveTabPill` hâlâ her zaman "SAYAÇ" gösteriyor (yalnızca Ekran 02/06 bu çubuğu kullandığı ve
  Ekran 06 zaten kendi özel alt çubuğunu prototipte farklı çizdiği için — Faz 9'un kapsamı).
- **Rozet ızgarası `GridView` yerine `LayoutBuilder` + `Wrap` ile çizildi** — `GridView`'in sabit
  `childAspectRatio`'su, 7 rozetin değişken uzunluktaki Türkçe ad/kural metinleriyle (`100 Saat
  Kulübü` gibi 2 satıra sarabilen başlıklar) taşma riski taşıyordu; `Wrap` her kartın kendi içeriğine
  göre yükseklik almasını sağlıyor, 2 sütun düzeni sabit `cardWidth = (genişlik-12)/2` ile garanti
  ediliyor (SPEC §6 "aynı görünen ama daha ucuz/sağlam" serbestliği).
- **Rozet açılış dialogundaki dönen halka (CSS `spin 6s` + üstte farklı renkli kenar) statik, tek
  renkli bir `Border.all` çemberine indirgendi**, `CustomPainter` ile parça parça çizilmiş bir yay
  yerine — Flutter'ın `BoxShape.circle` dekorasyonu tek renkli olmayan (yalnızca üst kenarı farklı
  renkte) bir çember kenarlığını desteklemiyor; simetrik tek renkli bir halkayı döndürmenin görsel
  hiçbir farkı olmayacağı için animasyon da eklenmedi (SPEC §6 "aynı görünen ama ucuz"). Aynı şekilde
  `glow 2.8s` nabız animasyonu da statik bir radyal gradyan olarak sadeleştirildi.
- **Dialog arka planı `BackdropFilter` yerine düz `barrierColor`** — Ekran 10'un iptal onayı
  (`FocusSessionScreen._CancelConfirmDialog`, Faz 5 kararı) ile aynı teknik/gerekçe; burada wakelock
  aktif değil ama tutarlılık ve maliyet nedeniyle aynı çözüm tekrar kullanıldı.
- **"BAŞARI KARTINI OLUŞTUR" butonu `onPressed: null` ile inert** — Ekran 05 (başarı kartı) Faz 8'in
  kapsamı; Faz 5'in mola ekranındaki "5 dk ekle" (`canExtend=false` iken `onPressed: null`) ve Faz
  4'ün `BottomNavBar` no-op sekmeleriyle aynı emsel: görsel birebir, var olmayan bir rotaya gitmeye
  çalışıp çökmek yerine dokunma hedefsiz bırakılıyor.
- **Mola bitişi bildirimi, SPEC Ekran 12'nin "Seans bitişi" tipiyle aynı kanaldan gönderiliyor
  (beşinci bir tip açılmadı)** — mola da bir `PomodoroSession` olduğu için ayrı bir kanal/tip yerine
  yalnızca ayrı bir bildirim `id`'si (1004) kullanıldı; iki bildirim birbirini ezmesin diye id ayrı,
  kullanıcının bildirim ayarlarında dört tip görünmeye devam etsin diye kanal ortak. Bildirim mola
  başlarken kurulur, "5 dk ekle"de yeni bitiş anına taşınır, mola herhangi bir yolla kapandığında
  (erken bitirme, tikle tamamlanma, cihaz saati geri alma) iptal edilir. Fazın **kapanışı** yine
  bildirime değil, öne dönüşteki yakalama tikine bağlı (planlanan bitiş anıyla kapanıyor — Faz 5
  kararı): yerel bildirimler kod çalıştırmadığı ve SPEC §1 arka plan servisini yasakladığı için
  bildirim yalnızca "haber verme" görevini üstleniyor.
- **`notificationsEnabled` / `soundEnabled` / `streakReminderEnabled` tek noktada,
  `NotificationService`in içinde uygulanıyor** — çağıranların (`PomodoroController`,
  `BadgeUnlockService`, `main.dart`) her birinde ayrı ayrı değil. Üç çağıran ve dokuz çağrı noktası
  var; kontrolü onlara dağıtmak birinin unutulmasına açık kapı bırakırdı (kolonlar Faz 3'te
  açılmıştı ama Faz 6'da hiçbir yerde okunmuyordu — tam olarak bu sınıf hata). Servis
  `services/storage`'a bağlanmasın diye ayarlar `AppSettingsTableData` yerine depolamadan bağımsız
  bir `NotificationPreferences` olarak geçiyor; eşleme yalnızca `main.dart`'ta. Ayar anlık görüntüsü
  serviste önbelleğe alınmıyor, her gönderimde okunuyor (tek satırlık tablo, ucuz) — böylece ayar
  değişince servisi haberdar edecek ayrı bir senkronizasyon yolu gerekmiyor.
- **`cancel*` çağrıları bilinçli olarak bu kapının dışında** — kullanıcı seans sürerken bildirimleri
  kapatırsa, o seansın bekleyen/kalıcı kaydını temizleyecek olan yine iptal çağrılarıdır; onları da
  kapatmak, kapatma anında ekranda duran kalıcı bildirimi ("Odak · n. pomodoro") kaldırılamaz hâlde
  bırakırdı. Aynı gerekçeyle `rescheduleStreakRiskReminder` önce iptal edip sonra ayara bakıyor:
  hatırlatma kapatıldıktan sonraki ilk çağrı, önceden kurulmuş olanı da temizlemiş oluyor.
- **`soundEnabled` için kanal başına sessiz ikiz kanal açıldı** (`session_end_silent`,
  `streak_risk_silent`, `badge_unlocked_silent`), tek kanalda `playSound` bayrağı çevrilmedi —
  Android 8+'ta bir kanalın ses ayarı oluşturulduktan sonra uygulama tarafından değiştirilemez
  (kanal ayarları kullanıcıya aittir), bayrağı çevirmek ilk kurulumdan sonra hiçbir etki
  yaratmazdı. "Kalıcı" bildirimin zaten `playSound: false` olduğu için (SPEC Ekran 12) sessiz ikizi
  yok; `soundEnabled` onu etkilemiyor.
- **`selectedTemplateIndex` hâlâ okunmuyor ve bu doğru** — o kolon bir bildirim ayarı değil, SPEC
  Ekran 05'in başarı kartı şablon seçimi (`GECE MEŞALESİ` / `MİNİMAL SAYAÇ` / 3. şablon). Ekran 05
  Faz 8'in kapsamı; onu tüketecek ekran yazılana kadar bağlanacağı bir yer yok.

## Faz 12 — Ekran 07 (ayarlar) + `in_app_review` + veri sıfırlama

- **Ekran 07 `ConsumerStatefulWidget`, süre slider'ları sürükleme boyunca yerel durumda tutuluyor** —
  `appSettingsProvider` (drift `watchSingle`) her yazımda yeniden yayınladığı için `onChanged`'de
  DB'ye yazmak saniyede onlarca yazım demekti; parmak kalkınca (`onChangeEnd`) bir kez yazılıyor,
  o ana kadar gösterilen değer yerel. Yerel değer bilinçli olarak **temizlenmiyor**: ekran açıkken
  o kolonun tek yazarı bu ekran, ekran kapanınca durum da gidiyor ve değer yine ayardan okunuyor.
- **Anahtar satırlarında (`Bildirimler`, `Sesli uyarı`, `Titreşim`, `Seri hatırlatması`) prototipin
  sağ ok işareti yok** — prototip her satırın sonuna `ph-caret-right` koyuyor ama bu dört satır
  başka bir ekrana götürmüyor, yerinde değişiyor; ok olmayan bir hedef vaat ederdi. Satırın
  "Açık/Kapalı" değeri (mint/nötr) hem durumu hem dokunmanın sonucunu gösteriyor. Gezinen satırlarda
  (sınav seçimi, değerlendir, hakkında, gizlilik, sıfırla) ok korundu.
- **Prototipin "Dil · Türkçe" satırı yerine "Sınav seçimi" satırı var** — SPEC Ekran 07 listesi dili
  saymıyor, sınav seçimini sayıyor; uygulama tek dilli (ARB geçişi Faz 13 ama dil seçici yok), var
  olmayan bir ayarı göstermek "prototipte olmayan özellik" kadar yanlış olurdu. Satır Ekran 02'nin
  mevcut `showExamPickerSheet`ini açıyor, ikinci bir seçici yazılmadı.
- **"Seri hatırlatması" satırı prototipte yok ama eklendi** — `streakReminderEnabled` kolonu Faz 3'te
  açılmış, Faz 6'da `NotificationService` içinde uygulanmış ama kullanıcının erişebileceği hiçbir yer
  yoktu; SPEC Ekran 12 bu bildirimi ayrı bir tip olarak sayıyor ve ana "Bildirimler" anahtarı onu
  kapatmanın tek yolu olsaydı, diğer üç tip de kapanmak zorunda kalırdı.
- **"Reklamları kaldır · yakında" satırının kesikli (dashed) kenarlığı düz kenarlığa indirgendi** —
  Flutter'ın `BoxDecoration`'ında kesikli kenarlık yok, bunun için bir `CustomPainter` gerekiyordu;
  Faz 7'nin dönen halka kararıyla aynı gerekçe (SPEC §6 "aynı görünen ama daha ucuz"). Satır SPEC
  §7.3 gereği **pasif**: `onTap` yok, satın alma akışı Faz 11'in kapsamı.
- **"Verileri sıfırla" yalnızca ilerlemeyi siler (odak geçmişi + rozetler + kurtarma kaydı),
  sınavları ve ayarları değil** — sınav tablosunda 4 preset de duruyor, silinseydi Ekran 02 sınavsız
  kalırdı (kullanıcının verisi değil uygulamanın kataloğu); süreler/anahtarlar ise tercih, "veri"
  değil. Onay dialogunun metni kapsamı birebir söylüyor. `SharedPreferences`taki aktif faz kaydı da
  siliniyor ve `pomodoroControllerProvider` invalidate ediliyor: kalsaydı bir sonraki açılışta artık
  var olmayan bir `sessionId` ile odak fazı geri yüklenir, faz kapanışındaki `finishSession` sessizce
  hiçbir satırı güncellemezdi.
- **Değerlendirme isteminin iki ayrı girişi var** — ayarlardaki satır `openStoreListing()` çağırıyor
  (kullanıcının açık isteği; `requestReview` Play'in kotasına tabi olduğu için dokunmanın çoğu zaman
  hiçbir şey yapmaması demekti), kendiliğinden gösterilen istem ise `requestReview()`. Tetikleme
  noktası `PomodoroController._completeBreak`: döngü kapanıp `idle`'a dönüldüğü an — odak/mola
  sürerken göstermek SPEC §7.2'nin interstitial kuralıyla aynı gerekçeyle (ekrandaki işin üstüne
  binmemek) elenmişti. "Bir kez" bayrağı istemden **önce** yazılıyor: Play istemi gösterip
  göstermediğini bildirmiyor, tekrar denemek yalnızca aynı sessiz sonucu üretirdi. Bayrak
  "Verileri sıfırla" ile silinmiyor — sıfırlama ilerlemeyi siler, kullanıcıyı ikinci kez davet etme
  hakkını değil.
- **`in_app_review` çağrıları `PlatformException`/`MissingPluginException` için sarmalanıyor** —
  eklenti kanalı olmayan koşumlarda (widget testleri) `isAvailable()` fırlatıyor; değerlendirme
  istemi uygulamanın işleyişi için kritik olmadığı için sessizce atlanıyor. Ayarlardaki **açık**
  dokunuş bunun istisnası: `openStoreListing()` `false` dönerse ekran SnackBar gösteriyor, dokunuş
  sessizce yutulmuyor.
- **"Hakkında" ve "Gizlilik politikası" uygulama içi dialog, dış bağlantı değil** — `url_launcher`
  doğrudan bağımlılık değil (yalnızca geçişli) ve yayımlanmış bir politika URL'si henüz yok (madde 9);
  metin cihazda saklanan veriyi olduğu gibi anlatıyor. **Faz 11 (reklamlar) bu metni geçersiz
  kılacak**: AdMob/UMP geldiğinde gizlilik metni ve Play listesindeki politika bağlantısı birlikte
  güncellenmeli.

## Faz 10 — Ekran 01 (onboarding) + izin akışı + UMP consent

- **İzin isteği `NotificationService.initialize()`ten `requestPermissions()`e ayrıldı** — Faz 6'da
  ikisi tek metotta duruyordu ve `main.dart` onu açılışta çağırdığı için uygulama, kullanıcı henüz
  hiçbir şey görmeden `POST_NOTIFICATIONS` diyaloğunu açıyordu. SPEC Ekran 01'in tüm işi bu isteğin
  **gerekçesini** göstermek; gerekçe ekranı yazılınca isteğin de oraya taşınması gerekiyordu. Kanal
  başlatma (`plugin.initialize` + `timezone`) açılışta kaldı: kurulmuş bildirimlerin iptali izinden
  bağımsız çalışmalı ve onboarding'i çoktan geçmiş kullanıcı için her açılışta hazır olmalı.
- **Başlangıç rotası bayrağın canlı akışını değil açılış anlık görüntüsünü okuyor**
  (`onboardingCompletedAtLaunchProvider`, `main.dart` override eder) — `appSettingsProvider`
  akışından izlenseydi, onboarding'in sonunda bayrak yazılır yazılmaz `appRouterProvider` yeniden
  kurulur, o anki gezinme yığını sıfırlanırdı. Bayrağın tek tüketicisi zaten `initialLocation`.
  Sağlayıcı `notificationServiceProvider` gibi override edilmeden fırlatıyor: sessiz bir varsayılan,
  testlerde yanlış ekranın doğrulandığını fark ettirmezdi.
- **UMP onayı "Şimdi değil" dalında da toplanıyor** — iki buton yalnızca bildirim izni konusunda
  ayrışıyor. Onay, reklam göstermenin yasal ön koşulu (SPEC §7.1), bildirim izninin bir alt seçeneği
  değil; "Şimdi değil"de atlanırsa Faz 11'de ilk banner isteğinde onaysız kalınırdı.
- **`ConsentService` sahte `ConsentInformation` yerine `disabled()` ikizi kullanıyor** — eklenti
  `requestConsentInfoUpdate` içindeki kanal çağrısını kendi `async` gövdesinde yapıp yalnızca
  `PlatformException`ı yakalıyor; kanalın hiç olmadığı koşumlarda (widget testleri) atılan
  `MissingPluginException` dışarıdan yakalanamıyor, yakalanmamış asenkron hataya dönüşürdü.
  `NotificationService.disabled` / `AppDatabase.forTesting` ile aynı kalıp.
- **Onay akışının her hatası sessizce geçiliyor** — `requestConsentInfoUpdate`in hata dinleyicisi de
  `Completer`ı tamamlıyor. Onay alınamadığında doğru davranış kullanıcıyı onboarding'de kilitlemek
  değil, reklamsız devam etmek; reklam isteğinin asıl kapısı Faz 11'de `canRequestAds()` olacak.
  Bu yüzden `canRequestAds()` şimdiden eklenmedi — tüketicisi olmayan bir API olurdu.
- **`onboardingCompleted` bayrağı akışın en sonunda yazılıyor** (izin → onay → bayrak). Ortada
  uygulama öldürülürse onboarding bir sonraki açılışta tekrar gösterilir; yarım kalmış bir izin/onay
  dizisiyle geri sayıma düşmek, kullanıcının onay formunu bir daha hiç görmemesi demekti.
- **Prototipin "25 dakikalık seanslar tut" cümlesi ayardan okunmuyor, sabit** — SPEC DoD'nin
  yasakladığı demo sayıları (132, 42, %86, 6, 3/7, 11) arasında 25 yok; 25 pomodoro varsayılanının
  kendisi ve bu ekran tanım gereği hiçbir ayar değiştirilmeden önce, yalnızca ilk açılışta
  görünüyor. Ayar akışına bağlamak, karşılama metnini ilk karede sayısız gösterip sonra
  sıçratmaktan başka bir şey kazandırmazdı (Ekran 02'nin buton etiketi bunun tersi: orada ayar
  gerçekten değişmiş olabilir).
- **Prototipin dört dekoratif animasyonundan ikisi uygulandı** — shimmer (SPEC §6.3 bunu
  **yalnızca** bu ekranda açıkça istiyor) ve meşale halkasının dönüşü. `glow` nabzı orta değerinde,
  `sheen` parlaması üstten sönen durağan gradient, `aurora` kayması sabit (Ekran 02'nin aurora
  kararıyla aynı); üçü de ekranın durağan karesinde zaten böyle görünüyor ve ömründe bir kez açılan
  bir ekran için ek `repeat()` denetleyicileri SPEC §6'nın "aynı görünen ama daha ucuz" kuralına
  aykırıydı.
- **Halkanın parlak tepe yayı `CustomPainter` ile çiziliyor** — prototip `border-top-color` ile tek
  kenarı boyuyor, Flutter'da `BoxShape.circle` kenarlığı kenar başına renk almıyor. Dairede
  karşılığı tepedeki çeyrek yay; `drawOval` + `drawArc` bunu tek boyamada veriyor (Faz 4/7'deki
  halka painter'larıyla aynı yaklaşım).

## Faz 8 — Ekran 05 (başarı kartı) + 1080×1920 export

- **Kartın mantıksal boyutu 270×480, prototipin 248×441'i değil** — DoD "tam 1080×1920" istiyor.
  248 genişlikle `pixelRatio = 1080/248 = 4.3548` olur, yükseklik `441 × 4.3548 = 1920.47`e düşer ve
  `OffsetLayer.toImage` bunu **1921**'e yukarı yuvarlar. 270×480 aynı 9:16 oranını verir ama çarpanı
  tam sayı yapar (`1080/270 = 4`, `480 × 4 = 1920`). Prototipin tüm kart ölçüleri `270/248` katsayısı
  (`_s`) ile ölçeklendi, oranlar birebir korundu. Ekranda kart yine prototipin 248px'inde görünüyor:
  önizleme bir `FittedBox` — `RepaintBoundary` kendi katmanını 270×480'de tuttuğu için bu küçültme
  dışa aktarımı etkilemiyor (regresyon testi PNG'yi çözüp gerçek pikselleri ölçüyor).
- **Önizleme ve export aynı widget** (`StoryCardView`) — ayrı bir "export layout"u yazmak, paylaşılan
  görselin kullanıcının gördüğünden sapabileceği tek yer olurdu.
- **Kart renkleri `AppColors`tan değil, sabit** — kart bir **görsel** olarak cihazdan çıkıyor; tema
  uzantısına bağlanırsa aynı şablon ileride tema değiştiğinde farklı renkte paylaşılırdı.
  **(Faz 17'de kısmen geri alındı: renkler hâlâ `AppColors`a bağlı değil ama her şablonun bir açık
  bir koyu varyantı var; hangisinin çizileceğine uygulamanın teması karar veriyor.)**
- **Taşma kırpmayla değil küçültmeyle çözülüyor** — büyük sayı `Flexible` + `FittedBox(scaleDown)`
  içinde, hem genişliğe hem kalan yüksekliğe uyuyor; etiket/satırlar `maxLines` + ellipsis. SPEC §9'un
  "3 haneli gün + uzun rumuz" testi üç şablonu da tek tek pompalayıp `takeException`ı denetliyor.
  Aynı taşma `AppPillButton`da da vardı ("BAŞARI KARTINI OLUŞTUR" rozet dialogunda 7.6px taşıyordu) —
  o da `scaleDown`a alındı; buton başka ekranlarda kısa etiketlerle kullanıldığı için görünürde
  hiçbir şey değişmiyor.
- **Türkçe yönelme eki koddan türetiliyor (`domain/text/turkish_suffix.dart`)** — prototip eki sabit
  yazıyor (`ex.name + "'e "`, `"Yarın 7'ye"`), bu da `YKS 2027'e` üretirdi. Sözcük rakamla bitiyorsa
  ek sayının **okunuşundan** seçiliyor (`…yedi` → `'ye`, `…altı` → `'ya`, `2000` → bin → `'e`),
  aksi hâlde son ünlünün kalınlık/incelik uyumundan. Kısaltmalarda (`KPSS`) ünlü yok, harf okunuşu
  ince bittiği için ince ek veriliyor. Paylaşılan bir görselde yanlış ek kalıcı olduğu için bu
  ~40 satır ve testleri, prototipe birebir sadakatten daha değerli görüldü.
- **Şablon adları prototip v2'den: `GECE MEŞALESİ` / `MİNİMAL` / `SERİ`** — SPEC Ekran 05 satırı
  `MİNİMAL SAYAÇ` diyor ama prototipin düğmesi üçe bölünmüş bir şeritte ve v2 `MİNİMAL` yazıyor;
  düğme genişliği uzun adı zaten küçültürdü.
- **Aktif sınav yokken sayı uydurulmuyor** — Ekran 08'den çıkışta seçim tamamen kalkabiliyor.
  `GECE MEŞALESİ`nin ikinci satırı boş kalıyor (kart o satırı hiç çizmiyor), `MİNİMAL` `—` +
  "hedef seçilmedi." gösteriyor. Seri sıfırken "Yarın 1'e çıkıyor" yerine "Bugün bir pomodoro seriyi
  başlatır." — birincisi olmamış bir seriyi varmış gibi anlatırdı.
- **`selectedTemplateIndex` kolonu artık okunuyor ve yazılıyor** — Faz 3'te açılıp Faz 12'de
  "tüketicisi yok" diye bırakılmıştı; seçim dokunuşta doğrudan DB'ye yazılıyor (sürükleme yok, ayar
  ekranının yerel-durum kalıbına gerek kalmıyor) ve ekran değeri `appSettingsProvider` akışından
  okuyor, böylece seçim ekran kapanıp açıldığında korunuyor.
- **Üç aksiyon tek servise (`StoryCardExporter`) toplandı ve sonucu bir enum** — `success` /
  `permissionDenied` / `failed`. Galeri izninin reddi "kaydedilemedi" ile aynı mesajı almıyor:
  kullanıcının yapabileceği bir şey var. Paylaşımın **başarısı** mesaj göstermiyor (sistem sayfası
  zaten geri bildirim), yalnız hatası gösteriyor. Servis `Provider` üzerinden geldiği ve metotları
  sanal olduğu için testler alt sınıfla değiştirebiliyor — eklenti kanalı olmayan koşumda gerçek
  paylaşım/galeri çağrısı denenmiyor.
- **`gal` için `WRITE_EXTERNAL_STORAGE` (maxSdkVersion 29) manifeste eklendi** — `minSdk = 23`
  olduğu için Android 10 öncesi cihazlarda MediaStore yazımı hâlâ izin istiyor.
- **Rozet dialogu Ekran 05'e geçmeden önce kapanıyor** — açık bırakılsaydı kullanıcı karttan geri
  döndüğünde kendini yine dialogun üstünde bulurdu.

## Faz 9 — Ekran 06 (istatistik) + `CustomPainter` bar chart

- **Agregasyonlar SQL'de değil, saf Dart'ta (`domain/stats/focus_stats.dart`)** — SPEC Faz 9 "SQL
  agregasyonlar" diyor; sapmanın gerekçesi gün sınırı: uygulama günü 04:00 TSİ'de kapanıyor ve bu
  kayma `core/time/app_day.dart`ta test edilmiş halde duruyor. Aynı kaymayı SQL'de
  `date(..., '-1 hour')` ile ikinci kez yazmak, Ekran 02'nin "bugün" kartıyla Ekran 06'nın aynı günü
  farklı sayması riskini açardı. Fonksiyon `nowUtc`'yi parametre aldığı için SPEC §9'un istediği
  "boş veri / tek gün / hafta sınırı" testleri sahte saate ya da veritabanına ihtiyaç duymadan
  yazılabildi. SPEC'in **asıl** kuralı olan "agregat tablo yok" korunuyor: her sayı ham
  `PomodoroSession` satırlarından türüyor.
- **Ekran 02 ile aynı `allSessionsProvider` akışı tüketiliyor** — Faz 4'te kurulan "tüm seansları tek
  akıştan oku, istemcide türet" kalıbı (kişisel cihaz verisi küçük). İkinci bir sorgu akışı açmak,
  iki ekranın kümülatif/seri sayılarının birbirinden sapabileceği bir kapı olurdu.
- **`42 SAAT` başlığı bir saatin altında dakikaya düşüyor (`35 DAKİKA`)** — prototipin biçimi yalnız
  saati tanıyor; ilk gününü yaşayan kullanıcı `0 SAAT` görürdü. Büyük sayı + birim kalıbı aynı
  kalıyor, yalnız birim değişiyor.
- **Tamamlanma oranı hiç odak seansı yokken `—`, `%0` değil** — `%0` "denedin, bitiremedin" demek;
  hiç başlamamış kullanıcı için yanlış. Payda başlatılan (tamamlanan + iptal edilen) odak seansları;
  mola seansları hiçbir hesaba girmiyor.
- **"En verimli aralık" iki saatlik kovalar, en az 3 seans eşiğiyle** — prototipin metni `20:00–22:00`
  olduğu için kova genişliği 2 saat; kovalar `startedAt`in İstanbul duvar saatine göre ayrılıyor.
  Eşiksiz bırakılsaydı tek bir tamamlanmış seans `%100` ile "en verimli aralığın" ilan edilirdi;
  eşiği geçen kova yoksa satır **hiç çizilmiyor** (uydurma bir aralık göstermek yerine). Eşitlikte
  daha çok tamamlanmış seansı olan, o da eşitse günün erken kovası kazanıyor — sonuç kayıt
  sırasından bağımsız olsun diye. Günün son kovası `22:00–00:00` yazıyor (`24:00` değil).
- **Sütun yükseklikleri haftanın kendi en yüksek gününe göre ölçekleniyor** — prototip sabit bir
  tavana (165 dk) bölüyor; az çalışılan bir haftada bu, tüm sütunları okunmaz biçimde kısaltırdı.
  Veri olmayan gün prototipteki gibi 5px'lik soluk kütük + `—` etiketi olarak kalıyor.
- **Chart tek bir `CustomPainter`; sütun/gün/değer etiketleri de canvas'ta** — etiketleri widget'a
  çıkarmak 21 widget'lık bir ağaç demekti, painter `TextPainter` ile aynı görüntüyü tek boyamada
  veriyor (Faz 4/5/7 halka painter'larıyla aynı gerekçe). Gün adları `intl` yerine sabit liste:
  chart'ın `initializeDateFormatting` çağrılmadan da doğru çizilmesi gerekiyor (Faz 13'te ARB'ye).
- **Alt gezinme çubuğu 5 yuvalık listeye dönüştü, aktif "hap" aktif sekmenin yuvasında çiziliyor** —
  Faz 4'te hap sabit biçimde ilk yuvaydı (`SAYAÇ`); prototip v2'nin Ekran 06'sında hap 4. yuvada ve
  `VERİLER` yazıyor. Aynı düzenlemede yuva oranları prototipin `flex:1.6 / 1` değerine çekildi
  (önceki `16 : 1` hapa çubuğun %80'ini veriyordu). Hap içeriği `FittedBox(scaleDown)` ile sarıldı:
  `VERİLER` etiketi dar ekranlarda payına sığmayıp taşıyordu, kırpmak yerine küçültmek prototipe
  daha yakın.
- **Banner yeri prototipteki `BANNER 320×50` yer tutucusu olarak duruyor** — SPEC §7.1 banner'ın iki
  hedefinden biri bu ekran; gerçek `AnchoredAdaptiveBannerAdSize` ve `canRequestAds` kapısı Faz 11'in
  kapsamı (ROADMAP madde 6).

## ROADMAP madde 5 — küçük düzeltmeler + test boşlukları

- **Ekran 03'ün "skip-forward" düğmesi kaldırıldı** (Faz 5'in "görsel var, `onTap` yok" kararı geri
  alındı). ROADMAP madde 5 iki seçenek bırakıyordu: işlevi bağla ya da prototipten çıkar. Bağlamak
  SPEC'te hiç tanımlanmamış bir semantik icat etmek olurdu — "fazı atla" atlanan pomodoroyu
  `completed` sayar mı, rozet/seri/istatistik ona göre değişir mi soruları SPEC'te cevapsız; hepsi
  yeni ürün kararı demek. Görünen ama hiçbir şey yapmayan bir düğme ise eksik olandan daha kötü:
  kullanıcı dokunuyor, uygulama sessiz kalıyor. Düğmenin **yeri** aynı genişlikte boş bir
  `SizedBox` olarak duruyor ki oynat/duraklat düğmesi prototipteki gibi halkanın merkezinde kalsın
  (yalnızca silinseydi büyük düğme sağa kayardı).
- **Odak/mola sürerken sistem geri tuşu ekranı kapatmıyor** (`PopScope`). Ekran 02'nin aktif seans
  kurtarma yönlendirmesi bilinçli olarak yalnızca `initState`te çalışıyor (Faz 5 kararı: `build()`
  içinde izlemek yığına iki `FocusSessionScreen` ekliyordu), bu yüzden geri tuşuyla çıkan kullanıcı
  süren seansa dönemiyordu. Odak fazında geri, "X" ile **aynı** iptal onayını (Ekran 10) açıyor —
  seansı sessizce iptal etmek ya da hiçbir şey yapmamak yerine, kullanıcının zaten bildiği çıkış
  yolunu gösteriyor. Molada geri hiçbir şey yapmıyor: Ekran 09'un kendi "ODAĞA DÖN" çıkışı var ve
  mola için "seriyi kırıyorsun" onayı anlamsız olurdu. Onay dialog'u artık iki yerden açıldığı için
  `_confirmCancel` gövdeden çıkıp dosya düzeyine taşındı.
- **Ekran 09'un başlık satırı 390pt genişlikte taşıyordu** ("KISA MOLA" hapı + "n. pomodoro bitti");
  ilk kez bu maddenin widget testi mola gövdesini çizdiği için görüldü. Sağdaki grup `Flexible` +
  `FittedBox(scaleDown)` ile küçültülüyor — Faz 9'un alt gezinme çubuğundaki `VERİLER` hapıyla aynı
  çözüm (kırpmak yerine küçültmek prototipe daha yakın).
- **Odak ekranı testleri sahte bir `PomodoroController` alt sınıfıyla koşuyor** (`build()` sabit faz
  döndürüyor, `tick()` yalnızca sayıyor). İki nedeni var: gerçek controller'da tik yan etkisiz
  kaldığı için "tikleyici durdu mu" dışarıdan gözlemlenemiyor; ve gerçek `tick()` testin ortasında
  fazı `idle`'a düşürüp ekranı kapatabiliyor. Ekranlar yine gerçek router'la, Ekran 02'nin kurtarma
  yönlendirmesi üzerinden açılıyor — kurulum gerçek yolun aynısı.
- **Sistem geri tuşu testte `flutter/navigation` kanalının `popRoute` bildirimiyle simüle ediliyor**,
  `tester.binding.handlePopRoute()` ile değil: ikincisi `@protected` ve `go_router`ın
  `BackButtonDispatcher`ını atlayan bir kısayol olurdu; kanal bildirimi cihazdaki yolun birebir aynısı
  (`WidgetsBinding.handlePopRoute` → `GoRouterDelegate.popRoute` → `NavigatorState.maybePop`, ki
  `PopScope`u o zincir uyguluyor).
- **Bildirim kapısı testi gerçek eklenti nesnesiyle, sahte `MethodChannel` işleyicisiyle koşuyor** —
  `NotificationService.disabled()` bu iş için uygun değil: kapıya hiç gelmeden her şeyi no-op yapıyor,
  yani "gönderilmedi" sonucu kapıyı değil `_plugin == null` kısa devresini doğrulardı. Kanal
  (`dexterous.com/flutter/local_notifications`) dinlenip hangi metodun çağrıldığı kaydediliyor;
  eklenti platform uygulamasını `defaultTargetPlatform`a göre seçtiği için test hedefi Android'e
  sabitliyor ve `AndroidFlutterLocalNotificationsPlugin.registerWith()`i kendisi çağırıyor (normalde
  üretilen kayıt defterinin işi). Anahtar açık hâldeki karşı kontrolde **seri riski (1003)
  beklenmiyor**: o bildirim yalnızca günün 21:00'i henüz gelmediyse kuruluyor, testi çalıştırma
  saatine bağlamamak için kapsam dışı bırakıldı.

## Faz 11 — Reklamlar (banner + interstitial) + `purchase_service` (UI pasif)

- **Her reklam isteğinin tek kapısı `AdService.canRequestAds()`** (`services/ads/ad_service.dart`).
  Kapıyı çağıranlara (banner yuvası, `InterstitialManager`) dağıtmak yerine tek noktada tutmak,
  `NotificationService`in bildirim anahtarını tek noktada uygulamasıyla aynı gerekçe: SPEC §10'un
  iki DoD maddesi ("Ekran 03'te hiçbir reklam isteği atılmıyor", "`isPremium` iken hiçbir reklam
  isteği atılmıyor") kontrolün unutulabildiği her yerde sessizce ihlal edilir. Sıra bilinçli:
  önce `isPremium`, sonra UMP — premium kullanıcı için onay durumunu hiç sormaya gerek yok
  (`ad_service_test.dart` bunu ayrıca doğruluyor).
- **`isPremium` servise depolama katmanından değil bir okuyucu fonksiyonla geliyor**
  (`PremiumStatusReader`), `NotificationPreferencesReader` ile birebir aynı kalıp: `services/ads`
  `services/storage`a bağlanmıyor, eşleme `main.dart`ta. Her istek anında yeniden okunuyor —
  satın alma sonrası servisi haberdar edecek ayrı bir senkronizasyon yolu gerekmesin diye.
- **SDK'ya dokunan üç metot kapının arkasında ayrı duruyor** (`requestBanner`, `requestBannerSize`,
  `requestInterstitial`). Testler yalnızca bu seam'leri override edip **istek sayısını** ölçüyor
  (`test/support/recording_ad_service.dart`), böylece kapının kendisi gerçek koduyla koşuyor.
  `AdService.disabled()` ile ölçülen "istek yok" sonucu kapıyı değil kapalı servisi doğrulardı.
- **`adServiceProvider` varsayılanı `UnimplementedError` fırlatıyor**, `AdService.disabled()`
  değil — `notificationServiceProvider`/`consentServiceProvider` ile aynı karar. Sessiz bir no-op
  varsayılan, `main.dart`ta unutulan bir override'ı "reklamlar hiç görünmüyor" olarak gizlerdi.
  Bedeli, reklam yuvası ya da odak tamamlanışı içeren her testin override yazması (11 dosya).
- **Banner yüksekliği reklam gelmeden ayrılıyor ve yüklenemese de korunuyor** (SPEC §7.1 "layout
  zıplamaz"). Tek istisna reklamın **hiç istenmediği** hâl (premium ya da onay yok): orada yuva
  `SizedBox.shrink()`e kapanıyor, alt gezinme çubuğunun 88px payı da onunla birlikte kalkıyor —
  asla dolmayacak bir boşluğu ayırmak, reklamsız sürümün kazandırdığı alanı geri vermemek olurdu.
- **`AdSize.getLargeAnchoredAdaptiveBannerAdSize` kullanılıyor**, `getAnchoredAdaptiveBannerAdSize`
  değil: ikincisi `google_mobile_ads` 9.x'te `@Deprecated` ve `analysis_options.yaml` 0 uyarı
  istiyor. Adaptive yükseklik çoğu telefonda prototipin 50'si değil 90 dönüyor; yerleşimin bunu
  taşırmadığı 390×844 yüzeyde `banner_placement_test.dart` ile doğrulandı. Boyut sorgusu cevapsız
  kalırsa (kanalsız koşum) banner'dan vazgeçilmiyor, prototipin 320×50'siyle isteniyor.
- **Interstitial kuralları tek yerde** (`InterstitialManager`): mola başlangıcı *(madde 25'te
  döngü kapanışına taşındı)*, 3 tamamlanan
  pomodoroda 1, iki gösterim arası min. 180 sn. "3'te 1" ile "180 sn" bağımsız iki sayaç; ikisini
  çağırana dağıtmak, ileride ikinci bir tetik noktası eklendiğinde sessizce iki kat reklam demekti.
  Son gösterim anı `SharedPreferences`ta kalıcı — uygulama öldürülüp hemen açılırsa kural yine
  geçerli. Damga yalnızca reklam **gerçekten gösterildiyse** atılıyor: yüklenemeyen bir reklam
  180 sn'lik pencereyi harcamamalı.
- **"3 tamamlanan pomodoro" sayısı `PomodoroSessionDao.getAllCompletedFocusSessions()`ten geliyor**,
  ayrı bir sayaç tutulmuyor — `AppReviewService` ve `BadgeUnlockService` de aynı kaynağı okuyor.
  İptal edilen seanslar (`completed = false`) doğal olarak sayıya girmiyor.
- **Rozet açılışı interstitial'ı bastırıyor** (SPEC §7.2 "asla binmez") *(madde 25'te geçersiz
  kaldı: reklam artık kutlamayla aynı anda tetiklenmiyor, bastırma kapısı değerlendirme istemine
  bağlandı)*. Bunun için
  `BadgeUnlockService.evaluateAfterFocusCompletion()` artık **o çağrıda** açılan anahtarları
  döndürüyor (`Future<void>` → `Future<Set<String>>`); `PomodoroController._completeFocus` bu
  bilgiyi `maybeShowOnBreakStart`a geçiriyor. Bastırma 180 sn penceresini harcamıyor, sonraki mola
  gösterebiliyor. Kart export'u (Ekran 05) için ayrı bir koşul yok: o ekran yalnızca Ekran 04'ün
  rozet dialogundan açılıyor ve mola sürerken erişilemiyor.
- **Ekran 09'un `interstitial · 3 pomodoroda 1` yer tutucusu kaldırıldı** — gerçek reklam tam o
  anda tam ekran açılıyor, molanın gövdesinde yer kaplamasının anlamı yok.
- **`RemoteFlags` `SharedPreferences` üstünde duruyor** (`services/remote/remote_flags.dart`).
  Gerçek bir backend hâlâ verilmedi (`ExamSourceService` ile aynı durum, Faz 3): uzak yapılandırma
  bağlandığında yazacağı yer burası, okuyan taraf değişmiyor. Anahtar hiç yazılmamışken derleme
  zamanı varsayılanı (`--dart-define INTERSTITIAL_ENABLED`) geçerli — acil kapatma için kod
  değişikliği gerekmiyor.
- **Reklam birimi kimlikleri Google'ın resmî test birimleri**, `--dart-define` ile geçersiz
  kılınabiliyor (`AdUnitIds`). Gerçek AdMob hesabı açılmadan gerçek birimlerle koşmak politika
  ihlali sayılan trafik üretirdi; `AndroidManifest.xml`deki `APPLICATION_ID` de aynı sebeple test
  değeri (Play yayınından önce ikisi birlikte değişecek — ROADMAP madde 9).
- **`purchase_service.dart` tam kodlandı, hiçbir çağıranı yok** (SPEC §7.3: UI pasif). Ürün
  sorgusu, satın alma, mağaza tarafından başlatılan/geri yüklenen işlemler ve `completePurchase`
  eksiksiz ve testli; açılacağı sürümde `main.dart` `start()`i, ayarlardaki satır
  `buyProLifetime()`i çağıracak. Hata/iptal durumunda da `completePurchase` çağrılıyor: açık
  bırakılan işlem her açılışta yeniden yayınlanır ve aynı ürünün ikinci denemesini bloklar.
- **`PurchaseService` testi eklenti kanalını taklit etmiyor, `InAppPurchase`i `implements` ediyor**
  — doğrulanması gereken şey kanal değil, satın alma **akışının** `isPremium`e nasıl çevrildiği.
  İmzası `in_app_purchase`ten dışa aktarılmayan bir türe bağlı olan `getPlatformAddition` yalnızca
  o tür için paket bağımlılığı eklemek yerine `noSuchMethod` iletimine bırakıldı.

## Faz 13 — ARB yerelleştirme (ROADMAP madde 7)

- **Erişim iki yollu, ikisi de aynı kaynağa bakıyor.** Widget'lar
  `AppLocalizations.of(context)` kullanıyor (Flutter'ın kendi yolu; `Localizations`
  zaten ağaçta ve `MaterialApp.locale` neyse o geçerli). Bağlamı olmayan katmanlar
  (`NotificationService`, `BadgeUnlockService`) `appLocalizationsProvider`dan
  (`core/l10n/l10n_providers.dart`) alıyor — bir bildirim gövdesi `BuildContext`
  olmadan, hatta hiçbir ekran açık değilken kuruluyor. Elle yazılmış statik bir
  singleton yerine sağlayıcı: SPEC §1 "singleton servisler yasak" ve diğer
  servislerle aynı DI kalıbı.
- **Tek dil `MaterialApp.locale = kAppLocale` ile sabitlendi.** ARB'de yalnızca `tr`
  var; cihaz dili İngilizce olan bir kullanıcıda `supportedLocales` eşleşmesi yine
  Türkçeye düşerdi ama bunu şansa bırakmak yerine açıkça yazılıyor. Delegeler
  Material'ın kendi metinlerini de (`showDatePicker`/`showTimePicker`, Ekran 11)
  Türkçeleştiriyor — daha önce o diyaloglar İngilizceydi.
- **Üretilen Dart `.gitignore`'da** (`lib/l10n/gen/`), kaynak `lib/l10n/app_tr.arb`
  depoda. Depodaki diğer üretilmiş kodla (`*.g.dart`, `*.freezed.dart`) aynı kural;
  `analysis_options.yaml` da aynı gerekçeyle hariç tutuyor.
- **`intl` kısıtı `^0.20.3` → `^0.20.2`'ye indirildi.** `flutter_localizations` SDK'dan
  `intl`i tam 0.20.2'ye sabitliyor; daha yüksek bir alt sınır çözülemiyordu.
  `pubspec.yaml`da `flutter: generate: true` de zorunlu, yoksa `gen-l10n` çıktıyı
  içe aktarılamaz sayıyor.
- **Rozet ad/kuralları ile şablon etiketleri alan değil metot oldu**
  (`BadgeDefinition.name(l10n)`, `StoryCardTemplate.label(l10n)`). Böylece
  `kBadgeCatalog` `const` kalıyor ve DB'de saklanan tek şey yine `badgeKey` —
  Faz 7'nin "ad/kural Türkçe çünkü ARB geçişi Faz 13'te" notu kapandı, veri
  göçü gerekmedi.
- **Kanal ad/açıklamaları `static const` olmaktan çıkıp getter oldu.** Kanal
  *kimlikleri* (`session_end`, `ongoing_focus`, …) değişmedi ve değişmemeli —
  Android kanalı ilk kimlikle tanıyor; kullanıcıya görünen ad/açıklama ise ARB'den.
- **Ekran 09'un ipuçları katalog oldu** (`domain/pomodoro/break_tips.dart`, 6 ipucu,
  SPEC "her molada rastgele 2"). Tohum `Random()` **değil molanın `startedAtUtc`'si**:
  `_BreakBody.build` saniyede bir koşuyor, her karede zar atmak ipuçlarını gözün
  önünde titretirdi. Aynı mola boyunca sabit, her yeni molada farklı — regresyonu
  `test/domain/pomodoro/break_tips_test.dart`te.
- **Testler `localizedTestApp` üzerinden çiziyor** (`test/support/`). Tek bir ekranı
  çıplak `MaterialApp` ile çizen testlerde `Localizations` ağaçta olmadığı için
  `AppLocalizations.of` patlıyordu; delegeler `FocusSayacApp` ile birebir aynı
  yerde tutuluyor ki test ile uygulama aynı ağacı kursun.
- **`countdownStreakHintValue` ARB'de `{streak}'e` olarak duruyor** — mevcut davranış
  birebir korundu. Sayının okunuşuna göre doğrusu bazen `'ye` (2, 6, 7, 9, 10…);
  `domain/text/turkish_suffix.dart`in `dativeSuffix`i bunu zaten biliyor ama
  bağlamak görünen metni değiştireceği için bu maddenin dışında bırakıldı.

## Faz 14 — Performans geçişi (ROADMAP madde 8)

- **SPEC §6'nın 1-3. kuralları için yazılacak kod kalmamıştı** — Faz 2 kararı (yukarıda
  "Aurora zeminler ve kartlar BÖLÜM 6'nın performans kurallarına göre baştan inşa edildi")
  bunları en baştan uygulamıştı. Bu maddede yapılan, kuralı **pinlemek**: üçü de "şu kod hiç
  yazılmasın" biçiminde olduğu için widget testiyle doğrulanamıyor (bir test yalnızca o an
  çizilen ağacı görür), kaynak taramasıyla doğrulanıyor —
  `test/performance/runtime_blur_scan_test.dart`, ROADMAP madde 7'nin "kodda hard-coded Türkçe
  metin yok" grep taramasıyla aynı yaklaşım. Tarama satır içi yorumları atıyor: SPEC
  kararlarının gerekçeleri `BackdropFilter`/`ImageFilter.blur` adlarını zaten anıyor ve bir
  yasağı anlatan yorum yasağın ihlali değil. `BoxShadow.blurRadius` yasak listesinde yok — tek
  geçişte çizilen bir gölge, her karede yeniden rasterize edilen bir filtre katmanı değil.
- **Ekran 02'nin saniye tikleyicisi `TickerMode`a bağlandı** (`didChangeDependencies`).
  `Overlay`, üstteki opak rotanın altında kalan girdileri `tickerEnabled: false` ile kuruyor;
  geri sayım halkasının `AnimationController`ı bu yüzden odak ekranı açıkken kendiliğinden
  susuyordu — ama `Timer.periodic` `TickerMode`a bakmaz. Kapalı rota, odak ekranı 60 fps
  çizerken saniyede bir `setState` ile yeniden build + layout oluyordu; 25 dakika süren,
  ekranda hiç görünmeyen bir iş. `maintainState: true` (ModalRoute varsayılanı) rotayı ağaçta
  tuttuğu için Flutter bunu kendiliğinden durdurmuyor. Aynı sinyale bağlanınca ikisi birlikte
  duruyor, odak ekranı poplandığında ikisi birlikte geri geliyor; tikleyici yeniden kurulurken
  `_nowUtc` ilk periyodik tik beklenmeden yakalanıyor (yoksa dönüşte bir saniyelik eski değer
  görünürdü). `TickerMode.getNotifier` yerine `TickerMode.of`: tek fazladan rebuild'e karşılık
  ağaç taşındığında elle yeniden abone olma yükü yok.
- **Meşale iki `RepaintBoundary` ile ayrıldı** (SPEC §6 kural 5). Dıştaki olmadan alevin kare
  başına `markNeedsPaint`i en yakın üst sınıra çıkıyordu — o sınır Ekran 03'te alevle aynı
  katmanda duran **72px sayaç metnini** de kapsıyor, yani saat saniyede 60 kez yeniden
  çiziliyordu. İçteki (`_FlameShape` çevresinde) `Transform`u bileşikleştiriyor: alevin şekli
  hiç değişmediği için kare başına iş, hazır katmanın matrisini güncellemeye iniyor.
- **Duraklatılmış seansta alev donuyor.** SPEC §5.5 duraklamada yalnızca doygunluğu 0'a
  indiriyor, titreşim hakkında bir şey demiyordu; §6.4'ün "meşale ve halka çalışmaya devam
  eder" istisnası ise **süren** seans için. Duraklatılmış ekran wakelock ile süresiz açık
  kalabildiğinden orada 60 fps üretmenin sebebi yok, ve donmuş alev "duraklatıldı"yı zaten en
  doğru anlatan hâl. `_flick` artık `initState`/`didUpdateWidget`te `running`e göre
  `repeat()`/`stop()` ediyor.
- **Odak ekranında bilerek değiştirilmeyenler:** saniyelik `setState` (kalan süre wall-clock'tan
  okunuyor; 1 Hz'de tüm gövdeyi yeniden kurmanın maliyeti ölçülebilir değil ve fazı parçalamak
  Faz 5'in tek durum makinesi kararını bozardı) ve `SessionRingPainter` (`shouldRepaint`
  yalnızca `progress`/renk değişince `true`, yani zaten 1 Hz).
- **`--profile` 60 fps ölçümü yapılmadı.** Uygulama Android hedefli, bu makinede bağlı Android
  cihaz/emülatör yok (`flutter devices`: Windows/Chrome/Edge). Ölçümün doğrulayacağı kod tarafı
  bitti — odak ekranında kare başına rasterize edilen bir şey kalmadı — ama SPEC §10'un ilgili
  kutusu cihazda koşulana kadar işaretlenmedi.
- **Yeni testlerin üçü de düzeltme geri alındığında düşüyor** (elle doğrulandı). Ölçüt metin
  değil **widget nesne kimliği**: `_nowUtc` gerçek duvar saatinden okunuyor, testin sahte saati
  ilerlese de `hh:mm:ss` metni değişmeyebilir; kimlik ise doğrudan aranan şeyi söylüyor — tik
  gövdeyi yeniden kurdu mu? `Finder`lar da her ölçümde yeniden kuruluyor: `FinderBase` sonucunu
  önbelleklediği için dosya düzeyinde paylaşılan tek bir örnek, ikinci testte ilk testin çöpe
  gitmiş ağacını döndürüyordu.
- **`countdown_ticker_test.dart` veritabanını `runAsync` içinde tohumluyor** (Faz 9/11
  testlerindeki `_newDatabase` kalıbı): drift gerçek zamanda, widget ağacı sahte saatte
  ilerliyor. Kalıba uymayan ilk sürüm, bir isolate'in **ikinci** testinde göç tamamlanmadığı
  için Ekran 02'yi aktif sınavsız çiziyordu.

---

## Faz 15 — Testler + Play yayın paketi (ROADMAP madde 9)

- **`badge_rules` testi seansları TSİ duvar saatiyle kuruyor**, UTC'yle değil. Kuralların
  üçü de duvar saatinde tanımlı (08:00 öncesi, 23:00 sonrası, 04:00 gün kesimi) ama
  `PomodoroSession.startedAt` UTC; testi UTC yazmak her sınır iddiasının yanına elde üç saat
  çıkarma koymak olurdu ve "07:59 açar" ile "04:59Z açar" arasındaki mesafe tam da hatanın
  saklanacağı yer. Çeviri tek yardımcıda (`_at`), iddialar SPEC'in dilinde kalıyor.
- **Sınırların hepsi karşı kontrolüyle yazıldı** (07:59 açar / 08:00 açmaz, 22:59 açmaz /
  23:00 açar, 3 seans yetmez / 4 açar, 6 gün yetmez / 7 açar, 99sa59dk kapalı / 100sa açık).
  Tek yönlü bir iddia, eşiği yanlış tarafa kaydıran bir değişikliği yakalamaz.
- **"00:30 gece nöbeti değil" testi iki kuralın kesiştiği yeri pinliyor:** o seans *önceki*
  uygulama gününe ait (gün 04:00'te kapanıyor) ama Gece Nöbeti gün anahtarına değil duvar
  saatine bakıyor, dolayısıyla açmıyor — üstelik Sabah Yıldızı'nı açıyor. İki farklı zaman
  kavramının aynı satırda kullanıldığı tek yer burası.
- **`duration_formatter` testi yuvarlamama davranışını da pinliyor** (59 sn → 0 dk,
  3599 sn → 0 sa 59 dk). Yukarı yuvarlayan bir "iyileştirme" hiç odaklanmamış kullanıcıya
  "1 DK" gösterirdi. Negatif giriş de test ediliyor: cihaz saati geriye alındığında negatif
  fark hesaplanabiliyor (§5.1) ve ekranda "-1 SA" çıkmamalı.
- **Kart export taşma testi zaten Faz 8'de yazılmıştı** (`story_card_screen_test.dart`,
  "üç haneli gün ve uzun sınav adı taşmıyor"), bu maddede yeniden yazılmadı — SPEC §9'un
  widget listesindeki o satır o zaman kapanmıştı.
- **Yayın imzası `android/key.properties`ten okunuyor, dosya yoksa debug'a düşüyor.**
  Anahtar deposu ve parolalar depoya giremez, ama yapılandırmanın yokluğunda `release`
  hedefini tamamen kırmak geliştirme koşumlarını da kırardı. Debug imzalı bir AAB'yi Play
  zaten reddediyor, yani sessiz bir yanlış yayın riski yok — riskli olan tersi olurdu.
  Her iki dal da `:app:signingReport` ile doğrulandı (dosya yokken `Config: debug`,
  geçici bir anahtar deposuyla `Config: release`).
- **PKCS12, JKS değil.** `keytool` JKS için "proprietary format" uyarısı basıyor. Format
  değişince `.gitignore`daki `*.jks` kalıbı yetmez oldu; `*.p12` (ve kökte `*.keystore`)
  eklendi, `git check-ignore` ile doğrulandı — `key.properties.example`ın **izlenmeye devam
  ettiği** de aynı kontrolde teyit edildi.
- **Gizlilik metni reklamlara göre düzeltildi** (ROADMAP madde 1/2/6'nın bıraktığı iş).
  Eski metin "kişisel veri toplamaz … hiçbiri sunucuya gönderilmez" diyordu; Faz 11'den beri
  AdMob cihazın reklam kimliğini işliyor, yani metin yanlıştı ve Play'in veri güvenliği
  beyanıyla çelişecekti. Yeni metin ikisini ayırıyor: uygulamanın kendi verisi (sınav, seans,
  rozet) cihazda kalıyor, reklam ağına giden şey ayrıca ve açıkça anlatılıyor. Regresyon
  testi eski iddianın geri gelmemesini de kontrol ediyor.
- **Uzun metin `_InfoDialog`u taşırmasın diye gövde `Flexible` + `SingleChildScrollView`.**
  Dialog `mainAxisSize.min` bir `Column`du; üç paragraflık politika küçük ekranda ya da büyük
  yazı tipi ölçeğinde `RenderFlex` taşması verirdi. Kısa metinlerde ("Hakkında") görünüm
  değişmiyor.
- **Mağaza metinleri `docs/`e kopyalanmadı.** Tek kaynak `design/FocusSayac ASO Paketi.dc.html`;
  `docs/play/RELEASE.md` yalnızca hangi metnin hangi Console alanına gireceğini ve seçilen
  varyantı kaydediyor. Kopyalasaydık iki metin ilk düzenlemede ayrışırdı.
- **Launcher etiketi `focussayac` → `FocusSayaç`.** Paket adından türeyen varsayılan, simgenin
  altında görünüyordu. Mağaza adı (ASO §1, 26 karakter) ayrı ve daha uzun — simge altına
  sığmayacağı için ikisi bilerek farklı.
- **Gerçek AdMob kimlikleri ve store görselleri bu maddede üretilemedi.** Birim kimlikleri bir
  AdMob hesabı gerektiriyor (kod tarafı hazır: `--dart-define`, kod değişikliği yok); ekran
  görüntüleri bağlı bir Android cihaz gerektiriyor — madde 8'in `--profile` ölçümüyle aynı
  engel. İkisi de `docs/play/RELEASE.md`in kontrol listesinde açık kutu olarak duruyor.

## SPEC §10 DoD kapanışı (ROADMAP madde 10)

- **Demo sayıları için ekran testi değil kaynak taraması.** SPEC §10 "demo sayılarının
  hiçbiri **kodda** yok" diyor; bir widget testi yalnız o an çizdiği ağacı görür, oysa
  sızıntının hangi ekrandan geleceği önceden bilinmiyor. Tarama madde 7'nin ("hard-coded
  Türkçe metin yok") ve madde 8'in (`runtime_blur_scan_test.dart`) yaklaşımını sürdürüyor:
  `test/prototype/demo_numbers_scan_test.dart`.
- **Sayılar alt dize olarak değil rakam koşusu olarak aranıyor.** `132|42|86|6|11` düz
  `contains` ile arandığında `1080 × 1920 PNG` ve AdMob test kimliği (`3940256099942544`)
  yanlış alarm verirdi; tek haneli `6` ise taramayı tamamen kullanılamaz kılardı. Maksimal
  basamak dizileri çıkarılıp **tam eşitlik** aranınca altı demo değerin hepsi, `6` dâhil,
  yanlış alarmsız kontrol edilebiliyor. Rozet sayacı `3/7` rakam koşusu olarak masum ('3'
  ve '7') olduğu için ayrıca birebir dizeyle aranıyor.
- **Taranan iki yüzey: ARB ve Dart dize sabitleri.** Faz 13'ten beri kullanıcıya görünen
  metnin tek kaynağı ARB, dolayısıyla ekrana çıkan bir sayının saklanabileceği yer orası;
  Dart tarafı ikinci ağ olarak taranıyor. Üretilen kod (`l10n/gen/`, `*.g.dart`,
  `*.freezed.dart`) dışarıda — elle yazılmıyor ve kaynağı zaten taranıyor.
- **Palet prototipten ayrıştırılarak doğrulanıyor.** `app_colors.dart` başından beri
  "prototipteki `:root` değişkenlerinden birebir" diyordu ama bu yalnızca bir yorumdu.
  `test/prototype/prototype_palette_test.dart` tasarım dosyasını **kaynak** kabul edip
  `--ember … --sky-deep`, `body` zemini, `--chrome` gradyanının renk/durakları ve
  `--disp`/`--mono` ailelerini ayrıştırıp koda karşı sınıyor. Nötrler (#9397ab, #75798c …)
  prototipte satır içi yazıldığı için `:root`ta yok, kapsam dışı.
- **İki tarama da mutasyonla doğrulandı.** ARB'ye `11 GÜN` sokulunca ve `ember`
  `0xFFFFB03A → 0xFFFFB03B` yapılınca ikisi de düşüyor; yani boş bir listeyle sessizce
  "geçen" testler değiller. Karşı kontrol ayrıca test içinde de duruyor.
- **"Her ekran prototiple ayırt edilemiyor" kutusu işaretlenmedi.** Mekanik olarak
  doğrulanabilecek her şey doğrulandı: 12 ekranın tüm prototip metni ARB'de birebir
  karşılığını buluyor (demo sayılar placeholder'a bağlı), palet/tipografi prototiple
  eşleşiyor. Ama maddenin sözü "**yan yana konduğunda**" — bu bir render kararı ve bağlı
  bir Android cihaz istiyor; madde 8'in `--profile` ölçümü ve madde 9'un store ekran
  görüntüleriyle aynı engel. Mekanik kısmı "doğrulandı" diye işaretleyip görsel kısmı
  sessizce atlamak, kutuyu yanlış kapatmak olurdu.


---

## ROADMAP madde 11 — İlk Android derlemesi: iki blocker + emülatörde ölçüm

ROADMAP madde 8/9/10'un "cihaz yok" notu yanlıştı: makinede iki AVD kurulu
(`Medium_Phone_API_36.1`, `Resizable_Experimental`). Emülatör açılınca Faz 0-15
boyunca hiç çalıştırılmamış olan **Android derlemesinin kırık olduğu** ortaya
çıktı. `flutter analyze` ve 167 test bunu göremezdi: üçü de host tarafında,
Gradle'a hiç uğramadan koşuyor.

**Blocker 1 — core library desugaring kapalıydı.**
`:app:checkProfileAarMetadata`, `flutter_local_notifications`ın AAR meta
verisindeki desugaring şartı yüzünden düşüyordu. `android/app/build.gradle.kts`e
`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` eklendi.
Faz 5'te bildirim eklendiğinde gerekiyordu, ama o fazda hiç `flutter build`
çalıştırılmadığı için sessiz kaldı.

**Blocker 2 — `AndroidManifest.xml` geçersiz XML'di.**
`:app:processProfileMainManifest` "Error parsing" ile düşüyordu. Sebep Faz 11'de
yazılan yorum satırındaki `--dart-define`: XML yorumlarının içinde `--` dizisi
yasak (XML 1.0 §2.5). Yorum `dart-define bayrağıyla` diye yeniden yazıldı;
`APPLICATION_ID` ve izinler dâhil hiçbir bildirim değeri değişmedi.

Bu ikisinden sonra `flutter build apk --profile` (87.1 MB) ve Play'e yüklenecek
`flutter build appbundle --release` (51.4 MB) geçiyor. AAB `keytool -printcert`
ile denetlendi: `CN=Android Debug` — Faz 15'te belgelenen geri düşüş doğru
çalışıyor, `key.properties` girilene kadar çıktı Play'e yüklenemez.

**60 fps ölçümü emülatörde yapıldı (madde 8'in kalan kutusu, kısmen).**
`dumpsys gfxinfo` Flutter için 0 kare veriyor — Flutter kendi `SurfaceView`ine
çiziyor, HWUI sayaçlarına uğramıyor. Ölçüm bu yüzden
`dumpsys SurfaceFlinger --latency <BLAST layer>` ile alındı, 12 sn boyunca 6
örnek, 375 kare: **ortalama 60.0 fps**, medyan 16.70 ms, p99 18.48 ms, en kötü
kare 18.95 ms, 33 ms üstü kare **yok**. Odak ekranı (meşale + halka + 72px
sayaç) bu pencerede kare düşürmüyor.

Kutu yine de **tam kapatılmadı**: x86_64 emülatör host GPU'suyla çiziyor, gerçek
bir ARM cihazın termal ve GPU davranışını temsil etmiyor. Emülatör sonucu
"regresyon yok" için güçlü bir sinyal, "gerçek cihazda 60 fps" için kanıt değil.

**Cihaz üstü akış doğrulaması:** Ekran 01 → izinler (POST_NOTIFICATIONS,
SCHEDULE_EXACT_ALARM) → Ekran 02 (289 gün geri sayım, banner yükleniyor) →
Ekran 03 (banner yerine "reklam gizli", wakelock satırı) → Ekran 10 (iptal
onayı, geçen süre doğru) → Ekran 04 / 06 / 07. `logcat`te tek bir
`E/flutter` ya da `FATAL` yok. Ekran 03'te hiçbir reklam isteği atılmadığı
böylece testin yanında canlı olarak da görüldü.

**Yeni bulunan eksik:** launcher simgesi hâlâ Flutter'ın varsayılan logosu
(`mipmap-*/ic_launcher.png`). Faz 15 yalnızca 512×512 *mağaza* simgesini eksik
sayıyordu; cihazdaki simge de üretilmemiş — sistem ayar sayfasında Flutter
logosu görünüyor.

## ROADMAP madde 12 — Alt gezinme çubuğu: çift hedef + dokunma/erişilebilirlik

**`flame` yuvası artık Ekran 05'e (başarı kartı) gidiyor.** Faz 4'ten beri hem
`flame` hem `medal` `AppNavTab.badges`e bağlıydı: beş ikonun ikisi aynı ekranı
açıyordu ve kullanıcı çubukta dört değil üç ayrı hedef buluyordu. Prototipin
ikon dizilimi (timer/flame/medal/chart/gear) korunuyor — "birebir taşı" kuralı
**görsele** ait, hedefe değil; yuvanın kendisi silinmedi, boş da bırakılmadı.
Ekran 05 seçildi çünkü alev = seri ve başarı kartı serinin paylaşılabilir yüzü;
üstelik o ekranın tek girişi rozet dialogundaki düğmeydi, yani mevcut bir ekran
gömülü kalıyordu. Yeni ekran, yeni metin ve yeni rota üretilmedi.

**`onSelect` `if` zinciri yerine `switch`.** Çift hedefin sessizce yaşamasının
sebebi, eşleşmeyen sekmenin hiçbir dala düşmeden kaybolmasıydı. `AppNavTab`'e
`storyCard` eklenince derleyici iki çağıranda da (Ekran 02/06) dalın yazılmasını
zorladı; sonraki bir sekme de aynı şekilde derlemeyi durdurur.

**`_NavIcon`in dokunma hedefi 21px'ten 48px'e çıktı.** `Row` çapraz eksende
gevşek sınır verdiği için `InkWell` ikonun boyuna küçülüyordu: 64px yüksekliğinde
bir çubuğun ortasında yalnızca 21px'lik bir şerit dokunuyordu. Yalnızca yükseklik
açıkça veriliyor (genişlik `Expanded`ten sıkı geliyor); **ikon boyutu 21px olarak
kaldı**, büyüyen tek şey görünmeyen vuruş alanı — prototip görüntüsü değişmiyor.

**Dalga çubuğun kendi zemininde çiziliyor.** `InkWell` en yakın `Material`i
Scaffold'unkinde buluyordu; dalga çubuğun opak arka planının (`0xC7181A28`)
altında kalıp hiç görünmüyordu. Çubuğun `Row`u saydam bir `Material`e sarıldı —
`_SettingsRow` ve Ekran 05'in düğmeleriyle aynı kalıp.

**Erişilebilirlik adları mevcut ARB anahtarlarından geliyor.** Yuvalar prototipte
etiketsiz (yalnızca ikon) olduğu için ekran okuyucu hiçbir şey okumuyordu.
Etiketler gidilen ekranın kendi başlığından alındı (`navCountdown`, `navStats`,
`storyCardTitle`, `badgesTitle`, `settingsTitle`) — "yeni metin yazma yasak"
kuralı gereği tek yeni dize `commonBack` ("Geri"), çünkü geri okunun karşılığı
katalogda yoktu. Aynı etiket `AppBackButton`a ve Ekran 05'in satır içi geri
okuna da verildi; `Icon.semanticLabel` `InkWell`in düğme rolüyle birleşmediği
için sarmalayıcı `Semantics` kullanıldı.

**Test:** `countdown_navigation_test.dart`e iki test eklendi — "alev" yuvası
Ekran 05'i açıyor ve rozetler ekranı **açılmıyor** (çift hedefin regresyonu),
üç ikon yuvasının dokunma hedefi 48px. İkisi de `tester.ensureSemantics()`
kullanıyor, yani etiketlerin varlığını da doğruluyor. Tutamak `addTearDown`
yerine gövde sonunda elle bırakılıyor: bırakılıp bırakılmadığı teardown'lardan
önce denetleniyor.

**Kapsam dışı bırakılanlar:** ayarlardaki "Gün 04:00'te başlar" satırının boş
değer alanı **hata değil** — değer etiketin kendi metninde (`settingsDayStartsAt`),
satır bilgi amaçlı. "Reklamları kaldır / YAKINDA" satırı da SPEC §7.3 gereği
bilinçli olarak pasif; `PurchaseService` tam kodlu ama çağıranı yok.

---

## ROADMAP madde 13 — Alt gezinme çubuğu beş ekranda

**Çubuk artık Ekran 04/05/07'de de var.** Prototipte yalnızca Ekran 02 ve 06'da
vardı ve madde 12'ye kadar bu kopyalanmıştı; sonuç tek yönlü bir gezinmeydi:
çubuk kullanıcıyı rozetlere/başarı kartına/ayarlara götürüyor, ama o ekranlardan
başka bir sekmeye geçmenin yolu yoktu — tek çıkış sistem geri hareketiydi.
"Prototipi birebir taşı" kuralı **görsele** ait, gezinme grafiğine değil (madde
12'de `flame` yuvasının hedefi için verilen kararın aynısı). Yeni ekran, yeni
rota, yeni bileşen üretilmedi: aynı `BottomNavBar` üç ekrana daha kondu.

**`_NavSlot.pill` opsiyonel olmaktan çıktı.** Alan `null` olabiliyordu çünkü
"o sekmenin ekranında çubuk zaten görünmüyor" varsayımı vardı; beş ekran da
çubuğu gösterdiğine göre varsayım düştü ve `if (slot.pill != null && ...)`
dalı ölü koda dönüştü. Renkler mevcut rol paletinden: Ekran 05 `ember`
(alev = seri), Ekran 04 `mint` (tamamlanan iş), Ekran 07 nötr `neutral800/900`
— ayarların bir rol rengi yok, hapı vurgu değil yalnızca "buradasın" işareti.

**Ekran 05'in hapı `navStoryCard` ("BAŞARI"), başlığı değil.** Hap çubuğun
beşte birinden pay alıyor; `FittedBox` "BAŞARI KARTI"yı ~9px'e indiriyordu.
Tek yeni ARB dizesi bu — Ekran 04 ve 07 kendi başlıklarını (`badgesTitle`,
`settingsTitle`) kullanıyor, onlar `navStats` ("VERİLER") uzunluğunda.

**Yönlendirme `navigateToNavTab`de toplandı.** Madde 12'nin `switch`i doğruydu
ama beş ekrana kopyalanacaktı; kural tek yerde: Ekran 02 yığının kökü (`go`),
diğer sekmeler onun üstünde **tek** kat (`pushReplacement`). `push` seçilseydi
sekmeler arasında birkaç tur dolaşan kullanıcı köke dönmek için sistem geri
tuşuna onlarca kez basardı. Kök dışındaki ekranlarda geri ok (`AppBackButton`)
duruyor: çubuk tek çıkış yolu değil.

**İçerik çubuğun altında kalmasın diye `kBottomNavReservedSpace` (96px).**
64px yükseklik + 18px alt konum + nefes payı. Ekran 04'te son kartın altındaki
`SizedBox`, Ekran 05'te `Padding`in alt değeri, Ekran 07'de sorumluluk metninin
alt boşluğu bu sabite bağlandı. Ayarların kaydırma listesi böylece sonuna kadar
çubuğun üstüne çıkabiliyor.

**Test:** `countdown_navigation_test.dart`e iki test — çubuk beş sekmede de
görünüyor, ve dört sekme arasında dolaşmak yığını büyütmüyor. İkisi de dokunuşu
ve doğrulamayı **o anki üst ekranın içinde** yapıyor: yığında kalan Ekran 02
kendi çubuğunu çizmeye devam ettiği için `find.bySemanticsLabel` ağaçta iki
"ROZETLER" buluyor. Yığın sayımı, yerini bırakan rotaların çıkış animasyonu
bitene kadar beklemek zorunda; `skipOffstage: false` onları o ana kadar hâlâ
görüyor.

**İki mevcut test güncellendi.** Ekran 04 ve 07'nin başlıkları artık aktif hapta
da yazdığı için `find.text('ROZETLER'/'AYARLAR')` iki sonuç veriyor; iddialar
`find.byType(BadgesScreen/SettingsScreen)`e çevrildi — aranan olgu zaten "ekran
açıldı mı". Gizlilik testine `ensureVisible` eklendi: satır listenin dibinde ve
yüzen çubuk üstünü örtebiliyor.

**Emülatörde doğrulandı.** `adb screencap` donanım hızlandırmalı AVD'de bozuk
kare veriyordu (`MESA: Failed to open rendernode`); emülatör
`-gpu swiftshader_indirect` ile yeniden açılıp beş sekmenin görüntüsü alındı.
Kullanıcının gördüğü "iki aynı rozet sayfası" madde 12 öncesi derlemeydi:
`flame` → Ekran 05, `medal` → Ekran 04, rozet kataloğu 0/7 ve yedi kart tekil.

---

## Madde 15: Ana ekran widget'ları (Faz 16)

**Beş widget, tek veri sözleşmesi.** Halka (2×2), Şerit (4×1), Seri (2×2),
Hızlı Odak (4×2), Panorama (4×2). Hepsi `HomeWidgetSnapshot`un yazdığı aynı
anahtarları okur; ayrı veri yolları açmak aynı sayının iki widget'ta farklı
çıkmasına kapı aralardı.

**Dart kalan günü yazmıyor, hedef zaman damgasını yazıyor.** İlk tasarımda
`daysLeft` de payload'a konacaktı. Vazgeçildi: uygulama birkaç gün açılmazsa
widget bayat bir sayı gösterirdi ve bu, ürünün tek işini yanlış yapması
demekti. Gün/saat/oran artık `FocusWidgetSnapshot.kt` içinde her çizimde
`targetUtcMillis`ten yeniden hesaplanıyor. Bedeli: `progressRatio` formülü iki
dilde duruyor. Formül tek satır ve sapması görsel olarak anında fark edilir,
bu yüzden ayrı bir doğrulama mekanizması kurulmadı.

**Native Kotlin + Canvas, Flutter bitmap render değil.** `home_widget`
`renderFlutterWidget` ile uygulamayla piksel-piksel aynı görüntü üretilebilirdi
ama her tazelemede headless bir Flutter engine açılırdı. Saat başı yenilenen
bir sayaç için bu pil maliyeti kabul edilemezdi. Halka, spark ve şerit Kotlin
`Canvas` ile çiziliyor; `RingRenderer` prototipin `viewBox 316` geometrisini
(r=142/130/112, stroke 9) birebir taşıyor.

**Halkanın gradyanı sınav rengi değil, uygulamanın kendi sweep gradyanı.**
Kullanıcıya "accent renkli halka" denmişti; uygulamada Ekran 02 sabit bir
sky→accent→ember süpürmesi kullanıyor. Widget'ın Ekran 02 ile aynı şey olarak
tanınması daha değerli bulundu. Sınavın `accentRole` rengi kayboluyor değil:
kesikli iç çemberi, kicker etiketini, şeridin dolgusunu ve Şerit widget'ının
sayısını o renk boyuyor.

**Palet `focus_colors.xml`de tek kaynak, `FocusPalette.kt` onu okuyor.**
Değerleri Kotlin sabiti olarak da tutmak üçüncü bir kopya olurdu.
`focus_palette_sync_test.dart` XML'i parse edip `AppColors.dark()` ile
karşılaştırıyor ve iki yönlü kontrol yapıyor (eksik token da fazlalık token da
düşürüyor). Test mutasyonla doğrulandı: `focus_ember` bozulduğunda kırmızı
veriyor.

**`updatePeriodMillis="0"` + kendi saat başı alarmımız.** Sistemin widget
güncelleme döngüsü en iyi ihtimalle 30 dakikada bir ve garantisiz. Alarm kesin
değil (`AlarmManager.set`, `setExact` değil): birkaç dakikalık sapma bir gün
sayacı için önemsiz, kesin alarm ise Android 12+ üzerinde
`SCHEDULE_EXACT_ALARM` gerektirip pil kısıtlarına takılırdı. Alarmın yanı sıra
`TIME_SET`/`TIMEZONE_CHANGED`/`DATE_CHANGED` de dinleniyor — kullanıcı saati
elle değiştirdiğinde kalan gün anında değişir, bir sonraki saati beklemek
görünür bir yanlışlık olurdu.

**Hızlı Odak süren seansı sıfırlamıyor.** Buton, `sessionActive` iken
"ODAĞA BAŞLA" yerine "ODAĞA DÖN" oluyor ve `/focus`u açıyor, `startFocus()`
çağırmıyor. Aksi hâlde widget kullanıcının biriken odağını sessizce silerdi.
Hap da o durumda ember dolgudan accent hairline'a düşüyor: dolu hap bir eylem
çağrısı, devam eden seans için yanlış vurgu.

**Widget seçici önizlemesi için taslak drawable'lar.** `previewLayout` gerçek
yerleşimi çiziyor ama `ImageView`lar bind edilmeden boş kalıyordu; seçicide üç
widget boş kutu görünüyordu. `widget_preview_ring/bar/spark` vektörleri
`android:src` olarak duruyor, çalışma anında bitmap üzerine yazılıyor.

**Derlemede iki tökezleme.** (1) XML yorumları `--` dizisi içeremiyor;
prototipin CSS değişken adlarını (`--surface-card`) yoruma yazmak
`parseReleaseLocalResources`ı düşürdü. (2) Kotlin `internal` taban sınıfı
`public` alt sınıflarca genişletilemiyor; manifest'in örnekleyebilmesi için
widget sınıflarının hepsi public yapıldı — uygulama modülünde görünürlük zaten
gerçek bir iş yapmıyordu.

**Kotlin tarafında birim testi yok.** Projede JVM test altyapısı kurulu değil
ve bu iş için kurmak kapsamı ciddi büyütürdü. Dart tarafı (sözleşme, servis,
palet) test edilmiş durumda; Kotlin çizim katmanının doğrulaması emülatörde
görsel olarak yapılacak — Faz 16 DoD'sinde açık madde olarak duruyor.

---

## Madde 16: Widget'ların emülatör doğrulaması ve çıkan üç hata

Faz 16'nın DoD'sinde açık duran görsel doğrulama yapıldı (API 36 emülatörü).
Üç gerçek hata çıktı, üçü de düzeltildi.

**1. Halka widget'ının görseli hiç çizilmiyordu.** `widget_ring.xml` içindeki
`ImageView`a dikey bir `LinearLayout` altında `layout_width="0dp"` verilmişti.
Ağırlık dikey yerleşimde yüksekliğe uygulanır, genişliğe değil; görünüm sıfır
genişlikte kalıyordu. Panorama'da aynı halka görünüyordu çünkü oradaki kapsayıcı
yatay. `match_parent` ile düzeltildi.

**2. Haftalık sütunlar oval çiziliyordu.** `SparkRenderer` köşe yarıçapını
`barWidth / 2` alıyordu; bütün günler sıfırken sütun yüksekliği taban değerine
düşüyor, yuvarlatılmış dikdörtgen tam daireye dönüşüyor ve `ImageView`ın
`fitXY` germesi onu ovalleştiriyordu. Yarıçap `barWidth * 0.26`ya indirildi.

**3. `?pick=1` sınav seçiciyi açmıyordu.** Ekran 02 seçiciyi yalnızca
`initState` içinde, `autoOpenSheet` parametresinden açıyor. Widget isteği
uygulama zaten geri sayım ekranındayken geliyor ve `go_router` aynı konuma
gidince State yeniden kurulmuyor — parametre bir daha hiç okunmuyordu.
`examPickerRequestProvider` eklendi: değer değil **değişim** anlamlı, böylece
arka arkaya iki istek seçiciyi iki kez açıyor. Ekran 02 `ref.listen` ile
dinliyor.

**Doğrulananlar.** Halka/Şerit/Seri gerçek veriyle doğru (288 gün, `288g 08s`,
`0 gün seri`, ember dolgu %28 = 1−288/400). Beş widget da seçicide doğru
Türkçe ad, boyut ve önizlemeyle listeleniyor. Halka cihaz yeniden başladıktan
sonra uygulama hiç açılmadan doğru sayıyla yeniden çiziliyor. Seri → `/stats`,
Hızlı Odak → `/focus?autostart=1` (seans gerçekten başlıyor). Süren seansta
autostart niyeti tekrar gönderildiğinde sayaç 24:50'den 24:19'a **devam etti**,
25:00'a dönmedi — iptal diyaloğu "1 dakika 12 saniye odaklandın" diyerek tek
seans olduğunu doğruladı.

**Doğrulanamayan.** Hızlı Odak ve Panorama kartlarının ana ekrandaki yerleşik
görünümü. `adb input draganddrop` ile widget yerleştirme güvenilir çalışmadı
(4×2 için ekranda yer kalmıyordu ve seçici koordinatları kayıyordu). İkisinin
de niyet/rota tarafı doğrulandı, çizim tarafı ise zaten doğrulanmış
`RingRenderer` ve `SparkRenderer`ı kullanıyor; kalan risk yalnızca yerleşim.

**Emülatör bir kez çöktü, sebebi bizim kodumuz değildi.** Gece yarısı cihaz
saati geriye sıçrayınca AOSP'nin `Notifier.notifyWakelockRelease` yolu negatif
süre üretip `AppOpsService` içinde `Invalid @IntRange(from = -1): -38649` ile
system_server'ı düşürdü. Stack'te uygulamaya ait tek satır yok; soğuk
başlatmayla geçildi.

## Faz 17 — Açık tema

- **Faz 2'nin "tek koyu tema" kararı geri alındı.** `AppColors` artık iki fabrika taşıyor
  (`dark()`/`light()`) ve `MaterialApp` `theme`/`darkTheme`/`themeMode` üçlüsüyle kuruluyor.
  Koyu setin tek değeri değişmedi — `test/prototype/prototype_palette_test.dart` hâlâ prototiple
  birebir karşılaştırıyor, yani DoD'un "prototiple ayırt edilemiyor" maddesi bozulmadı.
- **Açık palet "aynı rengin açığı" değil, aynı *rolün* açık zemindeki karşılığı.** Nötr rampa ters
  çevrildi: `neutral300` koyuda en açık ikincil metin, açıkta en koyu. Bunun bedeli sıfır çağrı yeri
  değişikliği — 90 küsur kullanımın hiçbiri "hangi temadayım" diye sormuyor.
- **Vurgu renkleri açık temada koyulaştırıldı.** Ham `#FFB03A` beyaz üzerinde 1.8:1; ilk denemede
  seçilen `#B96A00` bile 3.71:1'de kalıyordu. `light_palette_contrast_test.dart` WCAG AA'yı (4.5:1)
  zorunlu kılıyor ve ember/mint/rose'u bu test yüzünden bir tur daha koyulaştırdık.
  Dekoratif ember (alev, halka gradyanları) parlak kaldı — onlar kendi zeminlerini taşıyor.
- **~90 gömülü `Color(0x...)` literali token'a çevrildi.** Yüzey basamakları
  (`surfaceCardSoft/Card/Strong/Sheet/Dialog/Sunken/Nav`) ve çizgi/dolgu merdiveni
  (`hairline`, `divider`, `borderSubtle/Strong`, `fillFaint/Subtle/Medium/Strong`) bu iş için eklendi.
  Merdiven kapalı bir küme: eski 0x0A/0x0F/0x29/0x2E alfaları en yakın basamağa yuvarlandı
  (255'te 10'un altı, gözle ayırt edilmiyor) — karşılığında iki temada da tek kaynak var.
- **Painter'lar paleti parametre olarak alıyor.** `CustomPainter`ın `BuildContext`i yok;
  `AppColors.dark()/light()` `const` olduğu için `shouldRepaint`teki kimlik karşılaştırması
  yalnızca tema gerçekten değiştiğinde yeniden çizdiriyor.
- **Splash ve ana ekran widget'ları sistem temasını izler, uygulama içi seçimi değil.**
  İkisi de Flutter ağacının dışında, Android kaynak sisteminde çözülüyor: `values/focus_colors.xml`
  açık, `values-night/` koyu. Sistemi koyu olan cihazda uygulamada "Açık" seçilirse splash koyu
  açılıp uygulama açık geliyor — platformun sınırı, kaynaklar süreç başlamadan çözülüyor.
  `focus_palette_sync_test.dart` artık iki XML'i birden denetliyor.
- **Aktif sekme hapı temaya duyarlı.** Koyu temada rol renginin dolu gradyanı + açık yazı; açık
  temada aynı gradyan neredeyse beyaza bittiği için yazı kayboluyordu — gradyan seyreltiliyor (0.22)
  ve yazı rolün koyu tonuna düşüyor. Ayarlar hapı istisna: nötr rampa zaten ters çevrildiğinden
  kendiliğinden çalışıyor.
- **Ayarlar satırı üç durumlu ama yerinde dönüyor** (Sistem → Açık → Koyu → Sistem). Üstteki
  açık/kapalı anahtarlarıyla aynı kalıp, bu yüzden ok işareti yok. Etiketler ayrı ARB anahtarları:
  "Açık" Türkçede hem *on* hem *light* demek, tek anahtara bağlanırsa biri diğerini bozardı.
- **Şema v2 → v3**, `theme_mode TEXT NOT NULL DEFAULT 'system'`. Cihazdaki temiz kurulum
  `onCreate`ten geçtiği için yükseltme yolu orada hiç çalışmıyor; `theme_mode_migration_test.dart`
  v2 şemasını elle kurup `onUpgrade`i ve eldeki verinin korunduğunu doğruluyor.
- **Bilinen açık uç:** başarı kartının "Gece Meşalesi" şablonu açık temada açık bir kart çiziyor;
  adı artık içeriğini anlatmıyor. Ya şablon yeniden adlandırılmalı ya da açık varyantı ayrı bir
  şablon olarak sunulmalı — ürün kararı.

### Faz 17 sonrası — temanın gözden kaçan dört ucu

Faz 17 uygulamanın **kendi** widget'larını iki temaya taşıdı. Kalan açıklar paletin
ulaşmadığı yerlerdeydi: Material'ın kendi çizdiği yüzeyler ve "ışık yönü" taşıyan iki
dekoratif efekt. Sonuncu ikisi aynı sınıftan hata: anlamsal aynalama kuralı (`AppColors`
başlığı) nötr bir bindirme için doğru, bir ışık kaynağı için değil.

- **`ColorScheme` dokuz rolle kuruluyordu, gerisi sessizce `onSurface`e düşüyordu.**
  Verilmeyen roller `ColorScheme` içinde en yakın zorunlu role zincirleniyor ve zincir
  çoğunlukla `onSurface`te bitiyor: `outline`/`outlineVariant` tam kontrastlı yazı rengine,
  `surfaceContainerHigh` sayfa zeminine eşitlenmişti. Ekran 11'in `showDatePicker`/
  `showTimePicker` çağrıları uygulamanın tek "yabancı" ekranı — seçici bu yüzden sert
  kenarlıklarla ve perdenin üstünde kendi düzlemi olmadan açılıyordu. Roller tokenlara
  bağlandı (`primaryContainer` = `emberDeep`, kutular = `surfaceSunken`, gövde =
  `surfaceDialog`), `surfaceTint` kapatıldı — yükselti bu tasarımda tintle değil yüzey
  opaklığıyla anlatılıyor. `material_role_mapping_test.dart` boş bırakılan her rolde düşer.
- **Perde rengi çağrı yerlerine bırakılmıştı ve biri atlanmıştı.** Üç diyalog `barrierColor`ı
  elle veriyordu, Ekran 02'nin sınav seçici alt sayfası vermiyordu: Material'ın varsayılan
  `black54`'ü uygulamanın kendi perdesinden (açıkta %40, koyuda %68) hem daha koyu hem başka
  tondaydı. Karar `dialogTheme`/`bottomSheetTheme`e taşındı, üç kopya silindi.
- **Meşalenin ucu açık zeminde kayboluyordu.** Gövde gradyanının en üst durağı prototipin
  krem `#FFF3D8`i; açık zeminle kontrastı 1.02:1, yani alev tepesinden kesilmiş gibi
  duruyordu. Halkanın gradyanı Faz 17'de aynı sebeple zaten düzeltilmişti
  (`_focusRingGradient`), alev atlanmıştı — uç artık ember'ın kendisine iniyor. İçteki beyaz
  çekirdek gövdenin içinde kaldığı için iki temada da aynı.
- **Onboarding'in `sheen` parlaması açık temada lekeye dönüyordu.** Efekt `fillStrong` ile
  çiziliyor, o da nötr bir bindirme: açık temada siyaha dönüyor ve "üstten gelen ışık"
  birincil düğmenin tepesinde gri bir banda dönüşüyordu. Işığın yönü çevrilemeyeceği için
  açık temada efekt hiç çizilmiyor.
- **Cihazda bakılmadı.** Dördü de kod ve token seviyesinde doğrulandı (`flutter analyze`
  temiz, 229 test geçiyor). Seçicinin ve alevin açık temadaki son hâli emülatörde
  görülmedi — madde 16'daki gibi bir tur gerekiyor.

## Madde 18 — Hareket token'ları + sayı ve oran geçişleri

Hareket geçişinin ilk maddesi (ROADMAP madde 18-20). Uygulamanın tipografisi, paleti ve
düzeni prototiple birebirdi; eksik olan katman hareketti. Bu madde token'ları kuruyor ve
en görünür açığı kapatıyor: ekranın ortasındaki sayılar bir kareden diğerine zıplıyordu.
238 test geçiyor (+9), `flutter analyze` temiz.

- **`AppMotion` (`core/theme/app_motion.dart`)** `app_spacing`/`app_shadows` deseninde:
  altı süre, dört eğri ve `respectingMotion(context, duration)`. Erişilebilirlik kontrolü
  artık tek yerde — her çağıran `if (disableAnimationsOf)` yazmıyor. `RiseIn`in kendi
  içinde tuttuğu 600ms/60ms bu token'lara taşındı, iki kaynak kalmadı.
  `RiseIn`in `Curves.easeOut`u **taşınmadı**: o CSS'in `ease-out`u, `AppMotion.enter`
  (`easeOutCubic`) başka bir eğri; prototiple birebirliği bozmamak için yerinde kaldı.
- **`RollingNumber` (`core/widgets/rolling_number.dart`)** — karakter bazlı odometre.
  Yalnızca **değişen** karakter kayıyor, sabit kalanlar yerinde duruyor (132 → 131'de
  yalnızca son hane). Kural bir eşik kontrolünden değil yapının kendisinden geliyor:
  her karakter kendi yuvasında ayrı bir widget ve karakteri değişmeyen yuva animasyon
  denetleyicisi bile kurmuyor. Yuva anahtarları **sağdan** sayılıyor, böylece hane
  eklendiğinde birler basamağı yerinde kalıyor.
  - **Yön:** artan sayı aşağıdan yukarı, azalan sayı yukarıdan aşağı. Geri sayım azalır,
    odak süresi artar.
  - **Hane sayısı değişince `AnimatedSize`** (sabit genişlik değil): sabit genişlik en
    fazla haneye göre yer ayırmak demekti ve gün sayacı ömrü boyunca dört hanelik bir
    kutunun içinde merkezden kaçardı. "Hareketi azalt" açıkken `AnimatedSize` ağaca hiç
    girmiyor — sıfır süreli denetleyici `performLayout` içinde kendini bitirip aynı düzen
    geçişinde yeniden kirletiyor ve çerçeve bunu hata sayıyor.
  - **`FittedBox(scaleDown)`** taşma emniyeti. Tek bir `Text` sığmadığında satır kırıyordu;
    karakter yuvalarından kurulu bir `Row` ise taşma hatası veriyor (`stats_screen_test`
    bunu ilk koşuda yakaladı — test fontunun glifleri Space Grotesk'ten geniş). Beklenen
    genişliklerde ölçek hiç devreye girmiyor.
  - **`Semantics(label:)` + `excludeSemantics`**: ekran okuyucu karakterleri tek tek
    okumasın. Testlerin `find.text('3 SAAT')`i bu yüzden artık tutmuyor; aranan şey
    widget'ın etiketi (`test/support/rolling_number_finder.dart`).
  - `tabularFigures` widget'ın garantisi, çağıranın değil.
- **Uygulandığı yerler:** Ekran 02 gün sayısı (`ShaderMask` içinde), "bugün" kartının
  saat/dakikası ve seri rozeti; Ekran 06 kümülatif odak, en uzun seri, tamamlanma oranı;
  Ekran 04 rozet sayacı. `RichText`/`Text.rich` iki yerde tabana hizalı `Row`a açıldı —
  span'ların verdiği hizalamanın aynısı.
- **Uygulanmayan iki yer, gerekçesiyle:**
  - `hh:mm:ss` saniye sayacı. Saniyede bir kayan üç hane odak vaadine aykırı ve boşta
    60 fps demek (SPEC §6.4).
  - Ekran 06'nın "Son 7 gün · günlük ortalama 25 dk" **cümlesi**. `RollingNumber` kısa bir
    değer etiketi için; bir cümleyi karakterlere bölmek satır kırmayı ve kerning'i
    kaybettirir. Sayı yalnızca ekran kapalıyken değiştiği için kazanç da yok.
- **Oran geçişleri iki farklı desende:**
  - Ekran 02'nin halkası düz `TweenAnimationBuilder` (`slow` + `standard`). Oran yalnızca
    sınav değişince ve gün dönümünde değişiyor, saniye tikleri `days`i kımıldatmıyor.
  - Odak/mola halkası `SettlingProgress` (`core/widgets/settling_progress.dart`): geçiş
    **yalnızca ilk yerleşmede** var. Saniyede bir gelen her adımı tween'lemek 420ms'lik
    bir animasyonu saniyede bir yeniden başlatmak, yani süren seans boyunca kesintisiz
    kare üretmek olurdu — §6.4'ün tam olarak yasakladığı şey. Kazanç kurtarılan seansta:
    ekran %40 dolu bir halkayla açılmak yerine oraya akıyor.
  - `SettlingProgress` bayrağını `setState`siz kuruyor: "hareketi azalt" açıkken
    `TweenAnimationBuilder` sıfır süreli animasyonu daha `initState`indeyken bitiriyor ve
    geri arama bu widget'ın `build`ı sürerken geliyor.
- **Testler (+9):** `test/core/rolling_number_test.dart` (ara karede iki basamak birlikte,
  değişmeyen basamak kımıldamıyor, iki yönde akış, reduce-motion'da ara kare yok, sabit
  ekli metin, `respectingMotion` iki yönde) ve `test/core/settling_progress_test.dart`
  (bir kez akıyor, sonrası aynı karede — §6.4 regresyonu).
  `focus_session_screen_test`in iki halka ölçümü artık yerleşmeyi bekliyor.
- **Cihazda bakılmadı.** Hareketin son hâli emülatörde görülmedi; madde 16'daki gibi bir
  tur gerekiyor.

---

## Madde 19: Tamamlama anı — seans bitişi, rozet açılışı, seri artışı

Uygulamanın en duygusal üç anı sessizdi: 25 dakika bitiyor ve ekran öylece mola gövdesine
geçiyor, rozet dialogu hiçbir şey söylemeden beliriyor, seri 6'dan 7'ye çıkarken alev
kımıldamıyor. 251 test geçiyor (+13).

- **Haptik için yeni bir şey yapılmadı — madde 19'un 4. şıkkı güncel değildi.** ROADMAP
  "ayarlar ekranında haptic anahtarı yok" diyor ve (a) yeni kolon + göç, (b) sisteme
  güven, (c) hiç eklememe arasında seçim istiyordu. Gerçekte (a) çoktan yapılmış: kolon
  Faz 2'den beri şemada (`tables.dart` `hapticEnabled`), anahtar Ekran 07'de
  (`settings_screen.dart:194`), `PomodoroController._haptic()` her faz geçişinde
  `mediumImpact` (seans bitişi dahil, `_completeFocus`) ve `BadgeUnlockService`
  açılışta `heavyImpact` üretiyor — ikisi de ayara bağlı. Bu maddede kodlanan tek şey
  **görsel** katman; titreşim zaten doğru anlarda ve doğru kapının arkasındaydı.
- **Seans bitişi: mola gövdesi 420ms bekletiliyor.** `focusRunning → breakRunning`
  geçişinde `FocusSessionScreen` biten odak fazını `_completingFocus`ta tutuyor ve o
  pencere boyunca **odak gövdesini** çiziyor: sayaç 00:00, halka tam dolu ve közden
  naneye dönüyor (`_CompletionRing`, `AppMotion.slow` + `standard`). Pencere kapanınca
  mola gövdesi geliyor.
  - **§6.4 ile çatışmıyor:** hareket seansın **bittiği** anda başlıyor, yani odak süresi
    dolmuşken; süren seans boyunca tek bir fazladan kare yok. `session_completion_test`in
    "seans sürerken halkanın rengi kıpırdamıyor" testi bunun regresyonu. Blur taraması
    (`test/performance/runtime_blur_scan_test.dart`) yanlış alarm vermedi — taradığı şey
    `BackdropFilter`/blur, animasyon süresi değil.
  - **Yalnızca doğal bitişte:** iptal (`→ idle`) ve duraklatma (`→ focusPaused`) pencereyi
    açmıyor; ikisinin de karşı kontrol testi var.
  - **Gradyanın orta durağı sabit (0.66).** Odak halkası 0.62, mola 0.7 kullanıyor;
    durakları da tween'lemek 420ms boyunca her karede yeni bir `LinearGradient` kurmak
    olurdu, gözle görülür karşılığı yok. Renkler `Color.lerp` ile geçiyor.
  - **Düğmeler `IgnorePointer` ile kapalı** (kaldırılmıyor, yerlerinde duruyorlar): seans
    kapandığı için "X" ve oynat/duraklat artık mola fazına uygulanırdı ve ikisi de
    sessizce düşerdi.
  - **Bilinen sıra:** 3 pomodoroda bir açılan interstitial `_completeFocus` içinde, mola
    başlangıcında isteniyor (SPEC §7.2) ve tam ekran reklam bu 420ms'nin üstünü örtebilir.
    Reklamın anını kaydırmak §7.2'yi değiştirmek olurdu; rozet açılan tamamlanışlarda
    zaten bastırılıyor (Faz 11).
- **Rozet dialogu: `_ScaleIn` + tek seferlik halo.** Kart 0.92 → 1.0, `AppMotion.pop`
  (hedefi hafifçe aşıyor); rozet ikonunun arkasında opaklık 0.45 → 0, 600ms.
  - **Halo yalnızca açılmış rozette.** Kilitli karta dokunmak da aynı dialogu açıyor
    ("Nasıl açılır: …") — orada kutlanacak bir şey yok.
  - **Nabız atmıyor, bir kez sönüyor.** Sürekli bir dekoratif animasyon §6.4'ün yasakladığı
    sınıfa girerdi ve dialog süresiz açık kalabiliyor. Testin `pumpAndSettle`i bunun
    kilidi: sonsuz bir animasyon o satırda takılırdı.
  - **Dialog kuyruğu eklenmedi.** ROADMAP "aynı çağrıda birden fazla rozet açılabiliyor;
    sırayla mı, tek dialogda mı" diye soruyor. Soru bu maddede doğmuyor: açılış anının
    yüzeyi **bildirim** (SPEC Ekran 12 tablosu), dialog ise Ekran 04'te rozete dokununca
    açılan detay ekranı — otomatik açılan bir dialog hiç yok. Eklemek hareket katmanı
    değil yeni bir akış olurdu ve tam da mola başındaki interstitial'ın üstüne binerdi.
- **Seri artışı: `core/widgets/pop_on_increase.dart`.** Alev ikonu 1.0 → 1.25 → 1.0
  (`pop` çıkışta, `standard` dönüşte). `RollingNumber` sayıyı zaten çeviriyordu, ikonun
  eşlik edecek karşılığı yoktu.
  - **Yalnızca artışta:** ilk build'de ve değer düşünce çalışmıyor — seri kırıldığında
    zıplayan bir alev yanlış şeyi kutlar. Ölçek tam 1'ken ağaca `Transform` bile girmiyor,
    denetleyici boşta tik atmıyor.
  - **0 → 1 geçişi vurgusuz:** seri rozeti `if (streak > 0)` ile çiziliyor, 1'e çıkarken
    widget ağaca yeni giriyor ve ilk build vurgu yapmıyor. Rozetin kendisinin belirmesi
    zaten bir değişim; bunu ayrıca kutlamak için rozeti koşulsuz ağaçta tutmak gerekirdi.
  - Vurgu ekran arkadayken tetiklenirse `TickerMode` denetleyiciyi susturuyor ve kullanıcı
    Ekran 02'ye döndüğünde çalışıyor — istenen davranış bu (seri, odak ekranı üstteyken
    artıyor).
- **Testler (+13):** `test/core/pop_on_increase_test.dart` (4),
  `test/features/badges/badge_unlock_dialog_test.dart` (4),
  `test/features/focus_session/session_completion_test.dart` (5 — doğal bitiş, iptal ve
  duraklatma karşı kontrolleri, §6.4 regresyonu, reduce-motion). Üç dosyada da
  "hareketi azalt" dalı var; ekranın tamamını çizen testlerde
  `platformDispatcher.accessibilityFeaturesTestValue` üzerinden.
- **Cihazda bakılmadı** — madde 18 gibi; hareketin son hâli emülatörde görülmedi.

---

## Madde 20: Rota geçişleri + dokunma geri bildirimi

Hareket katmanının son üçte biri: beş sekme arasındaki geçiş Material'ın varsayılan sayfa
animasyonuydu (uygulamanın kendi kimliği yoktu), alt çubuğun aktif hapı sekme değişince bir
yerden diğerine ışınlanıyordu, birincil CTA'da yalnızca jenerik `InkWell` dalgası vardı.
258 test geçiyor (+7).

- **Rota geçişleri `CustomTransitionPage` ile, iki dil.** `app_router.dart`ta artık hiç
  `builder` yok, dokuz rotanın hepsi `pageBuilder`.
  - **Sekmeler (fade-through):** giren ekran opaklıkla ve 1.02 → 1.0 ölçekle gelir,
    `AppMotion.base` + `enter`. Ekran 08 (süresi geçmiş sınav) da bu dile dahil: bir sekme
    değil ama oraya da Ekran 02'nin **yerine** gidiliyor (`context.go`), yani aynı kat.
  - **Üste `push` edilenler (odak seansı, sınav ekleme):** aşağıdan yukarı 0.04 kayma +
    opaklık. Yığında bir kat yukarı çıkan bir ekranın kardeş geçişiyle aynı dili
    konuşması yönü kaybettirirdi.
  - **Çıkan ekran için ayrı bir animasyon yok.** `push`/`pushReplacement`te alttaki rota
    olduğu yerde duruyor ve giren opak ekran üstünü kapatıyor; ikisini birden soldurmak
    alt çubuğun opak zeminini geçiş boyunca yarı saydam gösterirdi (iki %50 katman üst
    üste tam opaklık vermiyor).
  - **`NoTransitionPage` yerine sıfır süre.** ROADMAP reduce-motion için ayrı bir sayfa
    tipi öneriyordu; `transitionDuration: Duration.zero` gözlemlenebilir olarak aynı şeyi
    yapıyor (animasyon ilk karede 1.0'da) ve erişilebilirlik kapısını tek yerde,
    `AppMotion.respectingMotion`da tutuyor — iki kod yolu yerine bir tane.
  - **Eğriler `CurveTween` zinciriyle**, `CurvedAnimation` ile değil: `CurvedAnimation`
    rota animasyonuna bir durum dinleyicisi ekliyor ve her karede yeniden çağrılan bir
    geçiş oluşturucusunda onu bırakacak yer yok.
- **Alt çubuk hapı: ROADMAP'in (a) şıkkı — `Hero`.** Beş sekmenin her biri ayrı bir rota ve
  çubuk her rotada sıfırdan kurulduğu için hap `AnimatedPositioned` ile kayamıyor; `Hero`
  iki rotadaki hapı ortak etiketle eşleştirip aradaki dikdörtgeni (genişlik `flex: 16` ↔
  `flex: 10` değişiyor) kendisi enterpole ediyor. (b)'ye düşmek gerekmedi.
  - **`pushReplacement`te de uçuyor.** Şıkkın tek gerçek riski buydu: sekmeden sekmeye
    geçiş `pushReplacement` ve `HeroController`ın bir zamanlar `didPush`/`didPop` dışında
    bir kancası yoktu. Bugünkü Flutter'da kanca `didChangeTop` — üstteki rota **nasıl**
    değişirse değişsin tetikleniyor (`packages/flutter/lib/src/widgets/heroes.dart:828`).
  - **`flightShuttleBuilder` şart:** hapın içeriği sekmeye göre değişiyor (etiket, ikon,
    gradyan), varsayılan mekik yalnızca hedefi çizerdi. İki hap çapraz soluyor,
    dikdörtgeni `Hero` taşıyor.
  - **İlerleme `pop` uçuşlarında ters çevriliyor:** o yönde `animation` 1'den 0'a gidiyor
    ve ham hâliyle kullanılsaydı geri dönüşte solma yönü şaşardı.
  - **Reduce-motion'da `Hero` hiç kurulmuyor** (`_heroPill`), yer tutucu takasının bile
    olmaması için.
- **`core/widgets/app_pressable.dart` — dalganın üstüne binen ölçek.** Basılıyken 0.97,
  bırakınca `AppMotion.pop.flipped` ile 1'e. Uygulandığı yerler: Ekran 02'nin CTA'sı,
  `AppPillButton`, sınav seçim sheet'inin satırları (orada 0.99 — satır geniş ve alçak,
  0.97 ekranın yarısı kadar bir yüzeyi gözle görülür kaydırırdı), Ekran 05'in
  PAYLAŞ/Kaydet/Kopyala üçlüsü.
  - **`Listener`, `GestureDetector` değil.** `GestureDetector` kendi `TapGestureRecognizer`ını
    jest arenasına sokar ve sardığı `InkWell`inkiyle yarışırdı; arenayı içteki kazandığında
    dıştakinin `onTapCancel`i basılı hâlden erken çıkardı. `Listener` ham işaretçi olaylarını
    arenayı hiç ilgilendirmeden alıyor, `onTap` yine `InkWell`in.
  - **`Transform` ölçek tam 1'ken de ağaçta — `PopOnIncrease`in aksine.** İlk kodlamada
    `PopOnIncrease`in deseni kopyalandı (ölçek 1'ken `Transform`u ağaca hiç sokmama) ve
    **birincil CTA tamamen ölü kaldı**: `Transform`u basış anında araya sokmak `InkWell`in
    alt ağacını yeni bir ebeveynin altına taşıyor, eski öğeler sökülüyor ve tanıyıcı jesti
    ortasında iptal ediliyor — buton basılı görünüyor ama `onTap` hiç çalışmıyor. İki widget
    arasındaki fark animasyonu **neyin** başlattığı: `PopOnIncrease`te bir değer değişimi
    (ağacın o an yeniden kurulmasının kimseye zararı yok), burada parmağın kendisi.
    Testin `expect(taps, 1)` satırı bu regresyonun kilidi.
  - **Ölçek `Transform`la, düzenle değil:** dokunma hedefi küçülmüyor, madde 12'nin 48px
    kuralı basılı hâlde de geçerli.
  - **Mevcut `InkWell` dalgaları kaldırılmadı.** Dalga "nereye bastım"ı, ölçek "bastım"ı
    söyler; ikisi farklı sorunun cevabı.
- **Testler (+7):** `test/core/app_pressable_test.dart` (4 — basılı ölçek, kapalı buton,
  reduce-motion, düzen boyutunun değişmemesi), `test/features/countdown/countdown_navigation_test.dart`
  (3 — fade-through'un ara karesi ve `pushReplacement` sonrası tek ekran, reduce-motion'da
  ilk karede hedef, hapın uçuşu). Hap testinin ölçümü "SAYAÇ" dizesi: aktif hap onu **metin**
  olarak çiziyor, pasif dört yuva yalnızca ikon + ekran okuyucu adı. Uçuş sırasında o metin
  iki rotanın da içinde değil (`Hero` ikisini de yer tutucuya çeviriyor), `Overlay`de.
- **Madde 12 ve 13'ün testleri değişmeden geçiyor:** 48px dokunma hedefi ve "sekmeler
  arasında dolaşmak yığını büyütmüyor" — geçişlerin yığın semantiğine dokunmadığının kanıtı.

## Madde 18-19-20 — emülatör doğrulaması

Üç maddenin de kapanışında "cihazda bakılmadı" notu duruyordu. Android 16 (API 36)
emülatöründe, Impeller (OpenGLES) arka ucuyla, koyu ve açık temada bakıldı. Hareket
`screenrecord` kaydından kare kare çıkarılarak incelendi; `logcat`te tek bir Flutter
istisnası, `RenderFlex` taşması ya da çerçeve hatası yok. 259 test geçiyor (+1),
`flutter analyze` 0/0.

- **Bulunan tek hata — uçan hapın etiketi sarı çift alt çizgiliydi.** `flightShuttleBuilder`
  uçuş boyunca `Navigator`ın `Overlay`inde çiziliyor; çubuğun kendi `Material`ı (bkz.
  `BottomNavBar.build`, dalga gerekçesi) ağacın o dalında yok. `AppTypography.display`
  `decoration` vermediği için hapın `Text`i `DefaultTextStyle`den miras alıyor ve orada
  `WidgetsApp`in "bu metni bir Material'a koyun" geri düşüş biçimi duruyor
  (`Color(0xD0FF0000)` + çift sarı `TextDecoration.underline`). Rengi `style.foreground`
  ezdiği için hata kırmızısı görünmüyordu; alt çizgi ise **her sekme geçişinde** uçuş
  boyunca görünüyordu. Mekik saydam bir `Material`a sarıldı — çubuktakiyle aynı çözüm.
  - **Neden testler görmedi:** madde 20'nin uçuş testi hapın **yerini** ölçüyordu
    ("SAYAÇ" kaynağın çubuğunda değil, `Overlay`de). Biçim ölçülmüyordu. Eklenen test
    (`uçan hapın etiketi alt çizgisiz`) uçuşun ortasında `RenderParagraph`ın birleşmiş
    `TextSpan.style.decoration`ına bakıyor; düzeltme geri alındığında kırmızıya düşüyor.
  - **Genel ders:** `Overlay`de çizilen her şey tema ağacının altında değil. Metin taşıyan
    bir mekik yazılıyorsa `Material` şart.
- **Doğrulanan davranışlar.** Madde 18: sınav değişiminde (282 → 247) yalnızca son iki
  hane kayıyor, baştaki `2` hiç kımıldamıyor; azalan değerde haneler yukarıdan aşağı
  giriyor; `ShaderMask`in krom gradyanı kayan hanelerin üstünde doğru duruyor; halka
  oranı `TweenAnimationBuilder` ile akıyor, sıçramıyor. Madde 19: doğal bitişte sayaç
  00:00'da duruyor, dolu halka közden naneye enterpole oluyor, sonra mola gövdesi
  geliyor. Madde 20: sekme geçişi çapraz solma (iki ekran ara karede birlikte), hap
  yuvadan yuvaya uçuyor, CTA basılıyken 0.97'ye iniyor ve `onTap` **çalışıyor** —
  ölü CTA regresyonu cihazda da yok.
- **Cihazda gözlenemeyenler:** `PopOnIncrease` (seri artışı) ve "bugün" sayaçlarının
  odometresi, değer ekran **sahne dışındayken** değiştiği için kare olarak yakalanamadı —
  seans bitince Ekran 02 odak ekranının altında duruyor ve dönüşte ilk build oluyor
  (tasarım gereği ilk build'de animasyon yok). Bu ikisi widget testlerinde ara kare
  iddialarıyla duruyor.

## Tipografi — 16px eşiği ve Michroma'nın küçük harf boşluğu

"Yazı tipleri tutarsız" geri bildiriminden çıkan tarama. Kodda başıboş `fontFamily`
yoktu: her stil `AppTypography`den akıyordu. Tutarsızlık iki ayrı yerden geliyordu.

- **Michroma'ya küçük harf giriyordu — asıl kaynak buydu.** Subset bilinçli olarak
  yalnız büyük harf + rakam (49 glif); Türkçe **büyük** harfler tam (Ğ İ Ş Ö Ü Ç),
  küçükler hiç yok. Buna rağmen beş metin kicker olarak küçük harfle çiziliyordu:
  `focusRunning` ("odak sürüyor"), `focusPaused` ("duraklatıldı"), `breakRunning`,
  `breakTipsHeading` ve `storyCardBrandFooter`. Flutter eksik glifte sessizce sistem
  fontuna düşüyor — yani odak ve mola ekranlarının etiketi Michroma değil **Roboto**
  çiziliyordu. Kullanıcının gördüğü "farklı font" tam olarak buydu.
  - İlk dördü ARB'de büyük harfe alındı; dosyanın kendi konvansiyonu zaten öyleydi
    (`breakLong: "UZUN MOLA"`, `breakReturnToFocus: "ODAĞA DÖN"`) — bu dördü ondan
    sapmıştı, yani düzeltme tasarımı değiştirmiyor, **onarıyor**.
  - Marka altbilgisi ayrı tutuldu: "focussayaç" küçük harfli yazılıyor, büyütmek marka
    adını değiştirirdi. O satır kicker'dan çıkarılıp Inter'e alındı, tracking kicker'la
    aynı bırakıldı. Önemi: bu satır export edilen 1080×1920 PNG'ye gömülüyor, yani font
    düşüşü paylaşılan her kartta kalıcı oluyordu.
  - **Genel ders:** `AppTypography.kicker` çağıran her yerin metni büyük harf olmak
    zorunda ve bunu tip sistemi zorlamıyor. `KickerLabel` kendisi `toUpperCase()`
    yapıyor; doğrudan `kicker(...)` kullanan çağrı yerleri bu güvenceden yoksun.

- **Space Grotesk ile Inter aynı boyutta çarpışıyordu.** `display` çağrılarının 38'inden
  20'si ≤15.5px'ti, `body` ise tamamen 11.5–15px bandındaydı. Ayarlar'da satır etiketi
  Inter 13.5 iken diyalog aksiyonu Space Grotesk 13.5'ti — aynı boy, farklı yüz, ayırt
  edici kural yok. Space Grotesk'i okunur kılan sıkı negatif tracking'i ancak başlık
  ölçeğinde işe yarıyor; altında "başlık" diye değil yalnızca "başka font" diye okunuyor.
  - Kural `AppTypography` doküman yorumuna yazıldı: **≥16px → Space Grotesk**
    (`display`/`counter`), **<16px → Inter** (yeni `label` rolü). 24 çağrı yeri taşındı.
  - `label`ın `height`i 1.12, yani `display`inkiyle birebir — devralma dikey kayma
    üretmiyor. `display`in `fontSize * -0.045` tracking'i **taşınmadı**; o sıkışma Space
    Grotesk'in geniş gövdesi için var, Inter bu boyutlarda nötr tracking'de okunuyor.
  - **SPEC §0'dan bilinçli sapma.** Kural 1 "yazı tipini değiştirme" diyor. Değişen font
    değil, hangi fontun hangi ölçekte kullanıldığı; üç aile de duruyor ve 16px üstündeki
    her şey prototipteki gibi. Sapmanın nedeni prototipin kendi kuralını netleştirmek.

- **Doğrulama.** `flutter analyze` 0/0, 259 test geçiyor. Emülatörde (API 36, Impeller)
  geri sayım, odak seansı, iptal diyaloğu ve ayarlar açık temada tarandı: "ODAK SÜRÜYOR"
  artık üstündeki "ODAK 1/4" ile aynı yüz; iptal diyaloğunda "DEVAM ET" ve "Seansı iptal
  et" ikisi de Inter; hiçbir yerde `RenderFlex` taşması yok — genişleyen etiketler
  (nav hapı, odak CTA'sı, sınav adı) kutularına sığıyor.
  - **Ölçüm tuzağı:** genişlik farkını `flutter test` içinde `TextPainter` ile ölçmek
    yanıltıcı. Test ortamı gerçek fontları yüklemiyor, sabit genişlikli test fontu
    kullanıyor — çıkan sabit +4.7% yalnız tracking kaybını gösteriyor, gerçek
    Inter/Space Grotesk metrik farkını değil. Taşma sorusu ancak cihazda cevaplanıyor.

## Tipografi ikinci tur — Michroma çıktı, boyut ölçeği geldi

Aynı geri bildirim ("yazı tipleri farklı farklı kullanılmış") bir tur sonra tekrar
geldi. Yukarıdaki tur küçük harf düşüşünü onarmıştı ama his geçmemişti; ikinci tarama
sebebi ailelerde değil **ölçekte** buldu.

- **33 farklı `fontSize` vardı, 107 çağrı yerinde.** 20 başlık için 12 ayrı boyut
  (16/17/19/20/21/22/23/24/26/28/34/42), etiketlerde 15.5/14.5/13.5, gövdede
  12.5/11.5, kicker'da 9.5/8.5/7.5. Hiçbiri bir adımın parçası değildi — her ekran
  kendi boyutunu elle seçmişti. Aileler tutarlıyken bile arayüzün "farklı fontlar"
  gibi okunmasının asıl sebebi buydu. `AppTextSize` ile **17 adıma** indi; 106 çağrının
  104'ü artık sabit kullanıyor (kalan ikisi parametre geçişi: `KickerLabel.fontSize`
  ve story kartının `style.bigFontSize`'ı).
- **16px eşiği yerini rol eksenine bıraktı.** Eşik, aynı boyutta iki aile yan yana
  gelince hangisinin seçileceğini söyleyemiyordu. Yeni kural tek eksen:
  **Space Grotesk → gösterim** (`display`/`counter`/`kicker`),
  **Inter → okuma** (`label`/`body`). `label` ile `body` ayrımı da netleşti: satır
  sarabilen düzyazı `body`, tek satırlık arayüz metni `label`. Ayarlar'ın satır
  başlığı/değeri ve `add_exam`'ın elips'li satırı `body`den `label`a taşındı.

- **SPEC §0 kural 1'den sapma — Michroma paketten çıkarıldı.** Kural yazı tipini
  donduruyor; bu sapma kullanıcı kararıyla alındı. İki gerekçe:
  1. *Stilistik:* Michroma geniş, sci-fi bir gösterim yüzü. Space Grotesk zaten
     karakterli bir geometrik grotesk, Inter nötr UI grotesk'i — Michroma ikisiyle
     aynı sistemin parçası gibi okunmuyordu, 8–10px'te `.26em` tracking'le "üçüncü
     ve alakasız font" oluyordu.
  2. *Teknik:* subset'i 49 glifti — `cmap`'i okunduğunda kapsam
     `%-./0-9:A-Z·ÇÖÜĞİŞ` çıktı. Küçük harflerin **tamamı**, virgül, uzun tire,
     kesme işareti ve `Î` yok. Kicker'a giren böyle bir karakter kelimenin ortasında
     sessizce sistem fontuna düşüyordu. Bir önceki tur bunu tek tek onarmıştı;
     kural tip sistemiyle zorlanamadığı için mayın yerinde duruyordu
     (ör. `examPickerVerifyOfficial` = "RESMÎ TAKVİMDEN DOĞRULA" kicker'a taşınsa
     `Î` düşerdi).
  - Kicker artık Space Grotesk. Tracking `.26em` → `.2em`: `.26` Michroma'nın zaten
    geniş gövdesi için ölçülmüştü, Space Grotesk'in dar kapitallerinde harfleri
    dağıtıyordu. Bundle 15.3 KB küçüldü; `Michroma-Regular.ttf` ve OFL metni silindi.
  - Story kartının marka altbilgisi (`focussayaç`, küçük harfli) bir önceki turda
    Michroma'nın küçük harf boşluğu yüzünden `label`a alınmıştı — o kısıt kalktığı
    için `kicker` rolüne döndü.
  - `prototype_palette_test.dart` sapmayı **sabitliyor**: prototipin `--mono`su hâlâ
    Michroma, uygulamanın kicker ailesi ise `AppFonts.display`. Test artık eşitlik
    değil, kasıtlı ayrışma iddia ediyor.

- **Doğrulama.** `flutter analyze` 0/0, **260 test geçiyor**. Ölçek uygulanırken
  `widget_test` dahil 15 test kırıldı: geri sayım kahramanının altındaki
  `saat:dakika:saniye · sınav tarihi` satırı (yatay `Row`, `mainAxisSize.min`, 316px)
  9.8px taştı, çünkü o satır 12.5 → 13'e çıkmıştı. `git stash` ile temel ölçüm
  alınarak taşmanın bu turdan geldiği doğrulandı. Satır `sm`ye (12) indirildi —
  kahramanın altındaki meta bilgi için doğru basamak zaten oydu ve "beraberlikte
  aşağı yuvarla" kuralına uyuyor.
  - **Bilinçli olarak dokunulmadı:** `height` override'ları (1.28/1.45/0.88/0.95).
    Bunlar da dağınık ama satır yüksekliğini değiştirmek yükseklik kısıtlı
    kartlarda taşma riski taşıyor ve kullanıcının şikâyeti boyut/aile eksenindeydi.
    Ayrı bir tur konusu.
  - Emülatör taraması yapılmadı: test fontu gerçek metrikleri yansıtmadığı için
    (yukarıdaki "ölçüm tuzağı") cihazda görsel doğrulama hâlâ açık iş.

## Seri koruma — haftalık telafi hakkı

- **Neden.** Alışkanlık uygulamalarında en büyük terk anı serinin bir anda 0'a düşmesi:
  kullanıcı "zaten bozuldu" deyip geri dönmüyor. `streak_calculator` bugüne kadar hiç
  affetmiyordu — tek bir kaçırılan gün, aylık bir seriyi sıfırlıyordu.

- **Kural.** Ardışıklık `kStreakGraceIntervalDays` (7) günde bir kez, **tek günlük** bir
  boşlukla bozulmuyor. Dün kaçırıldıysa seri kırılmıyor, `StreakState.protected` oluyor;
  ertesi gün tek bir pomodoro onu geri kazandırıyor. İki boşluk üst üste affedilmiyor.

- **Telafi günü seriye eklenmiyor.** "4 gerçek gün + 1 telafi = 5" demek, kullanıcıya
  çalışmadığı bir günü satmak olurdu; `StreakStatus.days` yalnızca gerçekten çalışılmış
  günleri sayıyor, koruma bilgisi ayrı bir eksende (`state`) taşınıyor.

- **Hak saklanmıyor, türetiliyor.** Ne yeni bir tablo ne de bir sayaç var: geriye doğru
  yürürken son telafi gününün tarihi tutuluyor ve bir sonraki boşluk yedi günden yakınsa
  seri orada kesiliyor. Aynı geçmiş her zaman aynı sonucu veriyor (idempotent, tamamen
  yerel). Geçmişteki boşlukların da aynı hakla kapanması şart: aksi hâlde dün affedilen
  gün, gün dönünce seriyi yeniden keserdi.

- **Rozetler dokunulmadan kaldı.** `calculateLongestStreak` değişmedi; SPEC §5.4'ün
  "7 gün üst üste" kuralı harfiyen geçerli, koruma günleriyle rozet şişirilemiyor.
  `badge_rules` ve Ekran 06'nın "en uzun seri" istatistiği bu yüzden etkilenmiyor.

- **Görsel dil: sönmüyor, soluklaşıyor.** Rozet `AnimatedOpacity` ile 0.45'e iniyor;
  alev ikonu ve `ember` tokenı yerinde duruyor. Alevi griye çevirmek "seri bitti"
  demekti — kastedilen tam tersi. Geri kazanıldığı kare rozet tam parlaklığa dönüyor.
  İpucu metni de değişiyor: korumadayken "serin 7'ye çıkar" yanlış vaat olurdu
  (bugünkü pomodoro seriyi büyütmüyor, dünkü boşluğu telafi ediyor).

- **Erişilebilirlik.** Soluklaşma tek başına bir sinyal olarak yeterli değil; rozet
  `Semantics(label: …)` ile sarıldı ve korumadayken "{n} gün seri, korumada" okunuyor.
  Etiket ayrıca `RollingNumber`ın karakter karakter böldüğü metnin tek okunabilir
  bütünü — widget testi de rozeti bu etiketten buluyor.

- **`streakProvider` kırılmadı.** Yeni `streakStatusProvider` durumu taşıyor;
  `streakProvider` onun `days` alanına inen bir `int` kısayolu olarak kaldı, böylece
  hikâye kartı, ana ekran widget'ı, iptal diyaloğu ve bildirim zamanlaması
  değişmeden çalışıyor ve koruma durumu değişip sayı sabit kaldığında yeniden
  çizilmiyorlar.

- **Test tuzağı.** Widget testinde seans akışı `broadcast` denetleyicisiyle
  verilince seri hep 0 görünüyordu: Riverpod akışa ilk kareden sonra abone oluyor,
  yayın denetleyicisi ise dinleyicisiz eklenen olayı düşürüyor. Tamponlayan
  (normal) `StreamController` gerekiyor. Denetleyici test gövdesinde kapatılamıyor
  da: `close()` ancak `done` olayı aboneye ulaşınca tamamlanıyor, sahte zaman
  kipinde o olay pompalanmadan gelmiyor ve bekleyiş 10 dakikalık test zaman
  aşımına kadar kilitleniyor — kapatma tear-down'da, gerçek zamanda yapılıyor.

- **Doğrulama.** `flutter analyze` temiz, **278 test geçiyor**; 16'sı yeni
  `streak_calculator_test.dart` (telafi hakkının yenilenme aralığı, üst üste iki
  boşluk, geçmişteki boşluklar, rozet kuralının etkilenmemesi) ve 1'i
  `streak_protection_badge_test.dart` (rozet soluklaşıyor → bugünkü pomodorodan
  sonra tam parlaklığa dönüyor). Emülatörde görsel doğrulama yapılmadı; açık iş.

---

## Son düzlük — geri sayımın işaretini çevirmek

**Sorun.** Ekran 02'nin kahraman sayısı sınav yaklaştıkça giderek daha korkutucu
okunuyordu: 247 → 12. Kullanıcının bırakmaya en yakın olduğu anda uygulamanın en
büyük tipografisi kaygıyı büyütüyordu. Aynı veride tersi bir okuma da var ve
uygulama onu hiçbir yerde kahraman yapmıyordu: biriken emek. Kümülatif toplam
yalnızca Ekran 06'da, haftalık grafiğin yanında duruyor.

- **Eşik iki koşullu, tek değil.** `isFinalStretch(days, examFocusSeconds)` —
  kalan gün ≤ 30 **ve** biriken emek ≥ 1 saat. İkinci koşul olmadan kural kendi
  amacına ters düşüyordu: emeği olmayan kullanıcıda ekran "12 gün kaldı"dan
  **"0 SAAT ODAKLANDIN"a** düşerdi. Sınavını yeni değiştirmiş kullanıcı da
  (biriken saat sınav başına) bu dalda geri sayımda kalıyor.

- **Sayı sınav başına, tüm zamanların toplamı değil.** `examFocusSeconds`
  `PomodoroSessions.examId` üzerinden filtreliyor; o sütun seans açılırken zaten
  yazılıyordu (`PomodoroController.startFocus`), yeni alan gerekmedi. Gerekçe:
  sayının anlattığı cümle sınav adıyla kuruluyor ("ALES'e hazırlanırken 148 saat
  odaklandın") — başka bir hedef için harcanmış saatleri o toplama katmak,
  kullanıcının kendi verisi hakkında yanlış bir şey söylemek olurdu.
  `FocusStats.cumulativeSeconds` bu yüzden kullanılmadı, Ekran 06'nınki olarak
  kaldı. Aktif sınav yokken açılan seansların `examId`'si `null`, hiçbir toplama
  girmiyorlar.

- **Kalan gün kaybolmuyor, bir satır aşağı iniyor.** Halka içindeki meta satırı
  iki parçadan üçe çıkıyor: `12 GÜN • 04:22:31 • 12 Haziran 2027`. Burası bir
  geri sayım uygulaması; günü ekrandan tamamen kaldırmak veri saklamak olurdu.
  Gün sayısı orada da `RollingNumber` (azalan değer, gece yarısı zıplamıyor;
  sabit "GÜN" eki kımıldamıyor). Saniye sayacı kaldırılmadı — nabız, tersine
  çevirmenin hedefi olan "kahraman tipografi" değil.

- **Satır taşma güvencesi.** Üç parçalık satır halkanın kesik çizgili iç
  çemberini (224px) aşabiliyor. 316'lık `Stack` içinde taşma **hatası** çıkmıyor
  ama satır çemberi kesebilirdi; `SizedBox(width: 284)` + `FittedBox(scaleDown)`
  bu durumda kırpmak yerine küçültüyor. Aynı sarmalayıcı eski iki parçalık
  satırı da koruyor (uzun sınav adları, farklı tarih biçimleri).

- **Halkanın oranı değişmedi.** `progressRatio` yine `clamp(1 - days/400, …)`.
  O gösterge zaten sınava yaklaştıkça **dolan**, yani baştan ileriye bakan bir
  işaret taşıyordu; onu da çevirmek ekranda iki ayrı hikâye yaratırdı.

- **`ProviderFamily` tipi yazılamadı.** `examFocusSecondsProvider`
  `Provider.family<int, int>` ama `flutter_riverpod` 3.1.0 `ProviderFamily`yi
  dışa vermiyor (yalnızca `package:riverpod/misc.dart`). Dosyadaki diğer
  sağlayıcıların aksine tip çıkarıma bırakıldı, gerekçe kod içinde duruyor.
  Aile `activeExamProvider`'ı kendi içinde okumuyor, `examId` ile anahtarlanıyor:
  tek çağıran zaten aktif sınavı elinde tutan `_CountdownBody` ve bu yön
  `domain/stats` → `domain/exams` bağımlılığını hiç kurmuyor.

- **Font subset'i tarandı.** Yeni iki dize (`SAAT ODAKLANDIN` kicker'ı Space
  Grotesk 500, `12 GÜN` meta'sı Inter 500) `cmap`e karşı kontrol edildi; eksik
  glif yok, sessiz Roboto düşüşü olmuyor.

- **Doğrulama.** `flutter analyze` temiz, **284 test geçiyor** (+6): 5'i
  `test/domain/countdown/final_stretch_test.dart` (sınav başına filtre, eşiğin
  iki ucu, sınav günü, emek eşiği), 1'i
  `test/features/countdown/final_stretch_hero_test.dart` — tek ağaçta üç yayın:
  T-12 + 9sa10dk → kahraman "9" ve "SAAT ODAKLANDIN"; emek 25 dakikaya düşünce
  geri sayıma dönüş; T-31'de emek yeterliyken bile geri sayım. Emülatörde görsel
  doğrulama yapılmadı; açık iş.

---

## Görünen ilerleme — kilitli rozet ve saat merdiveni

**Sorun.** Ekran 04'ün kilitli kartı yalnızca kuralı yazıyordu ("Kümülatif 100
saat odak"). Kural, ulaşılamaz bir duvar olarak okunuyordu: kullanıcı 61 saat
biriktirmiş olsa bile kart ilk gündeki kartla birebir aynı görünüyordu. Üstelik
yedi rozet bitince hedef tükeniyordu ve saat ekseninde tek bir eşik vardı (100),
yani ilk haftalarda o rozet hiçbir şey söylemiyordu.

- **İlerleme kuralın kendisinden türüyor, ayrı bir eşik listesinden değil.**
  `evaluateEarnedBadgeKeys` artık `evaluateBadgeProgress`in `earned` süzülmüş
  hâli. Ters yön (önce açık rozetler, sonra ayrıca bir "ilerleme" hesabı) iki
  eşik listesi demekti; halkanın dolduğu an ile rozetin açıldığı anın
  ayrışmaması ancak tek kaynakla garanti ediliyor. `badge_rules_test.dart`'taki
  "açılmış rozet kümesi ilerlemenin süzülmüş hâli" testi bunun kilidi.

- **Hedefi 1 olan rozette halka yok.** Sabah Yıldızı / Gece Nöbeti / İlk
  Kıvılcım için "0/1" bir ilerleme değil, kuralın daha kötü yazılmış hâliydi.
  `BadgeProgress.isCountable` (hedef > 1) bu ayrımı tek yerde tutuyor.

- **Sayaçta birim yazmıyor ("61/100").** Hemen üstündeki kural metni birimi
  zaten söylüyor; "61/100 saat" aynı cümleyi iki kez kurardı. Ekran okuyucuya
  ise eğik çizgi bölme gibi okunmasın diye sözlü karşılığı veriliyor
  (`badgeProgressSemantics`).

- **Saat merdiveni: 10 → 50 → 100 → 250.** Dördü de aynı `totalHours` sayısına
  bakıyor, yalnızca hedefleri farklı; yani yeni bir alan ya da göç gerekmedi.
  `hundred_hours` anahtarı ve adı ("100 Saat Kulübü") aynen duruyor — yayınlanmış
  bir `badgeKey` DB'de metin olarak saklanıyor, değiştirilemez. Yeni anahtarlar
  `ten_hours` / `fifty_hours` / `two_fifty_hours` katalogda artan sırada.
  İkonlar tırmanışı anlatıyor: kum saati → madalya → kupa → taç.

- **Kart durumu DB kaydının ve kuralın birleşimi.** `UserBadges` satırı ancak
  seans bittiğinde düşüyor (`BadgeUnlockService`). Güncellemeden önce 61 saat
  biriktirmiş bir kullanıcının 10 ve 50 saat kartları, bir sonraki seansına
  kadar kilitli kalsaydı **"61/10"** yazan ve halkası taşmış kartlar
  gösterirlerdi. Ekran 04 bu yüzden `unlockedKeys`i ikisinin birleşimi olarak
  kuruyor. Açılış **anı** (bildirim, halo, haptik) yine DB tarafında kalıyor:
  burada değişen yalnızca ekranın kullanıcının kendi verisi hakkında doğruyu
  söylemesi. `unlockedBadgesProvider`ın tek tüketicisi bu ekran olduğu için
  birleşim başka hiçbir sayıya sızmıyor.

- **İlerleme akışı `allSessionsProvider`dan.** Rozet ilerlemesi için ayrı bir
  sorgu açmak, aynı sayının Ekran 02/06 ile farklı anlarda güncellenmesi
  demekti. Süzgeç (`completed` + `focus`) DAO'nun SQL süzgecinin aynısı.

- **İkon dairesi meğer hiç çizilmiyormuş.** Kartın 48px'lik `DecoratedBox`u
  çocuksuzdu; `Stack`in gevşek kısıtlarında `RenderProxyBox` çocuksuz kalınca
  `constraints.smallest`e, yani sıfıra iniyor. Halkanın geometrisi zaten bu
  yığında kurulduğu için daire diyalogdaki gibi bir `SizedBox` çocukla
  ölçülendirildi — kilitli/açık ayrımının renk tarafı ancak şimdi görünüyor.

- **Halka ayrı bir painter.** Ekran 02'nin `CountdownRingPainter`'ı ekranın
  kahramanı (9px, üç duraklı gradyan, kesik çizgili iç çember); onu 56px'lik bir
  karta ölçeklemek yerine `BadgeProgressRingPainter` yazıldı: 2px, tek renk,
  saat 12'den saat yönüne.

- **Doğrulama.** `flutter analyze` temiz, **296 test geçiyor** (+12): 7'si
  `test/domain/badges/badge_rules_test.dart` (merdivenin dört basamağı, boş
  geçmişte kataloğun eksiksizliği, 61/100, tam saate yuvarlama, hedefi 1 olanlar,
  taşmayan oran, iki API'nin ayrışmaması), 4'ü
  `test/features/badges/badge_progress_test.dart` (61/100 ve 61/250 sayaçları,
  "61/10" çıkmaması + üstteki sayacın 4/10 olması, halkanın yalnızca kilitli ve
  sayılabilir dört kartta olması, boş geçmişte yedi boş halka). Emülatörde
  görsel doğrulama yapılmadı; açık iş.

## Meşale kademe avatarı

**Sorun.** Meşale yalnızca seans içinde büyüyüp seans bitince sıfırlanan bir
süstü — kümülatif odak saatine bağlı kalıcı bir kimlik yoktu; rozetler 7/7
bitince ilerleme ekseni de tükeniyordu; ve ana ekranda uygulamayı geri
açtıracak "sonraki kademeye N saat" diyen bir yüzey yoktu. Tasarım:
`docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md`.

- **Seans ekseni boyuttan bilerek ayrıldı.** `FlameWidget.intensity` (seans
  0→1) alevin boyutunu değiştirmiyor, yalnızca çekirdek parlaklığını, titreşim
  genliğini ve kıvılcım yoğunluğunu sürüyor. Gerekçe: K9→K10 arasındaki oran
  farkı yalnızca %6; seans şişmesi bu küçük farkın üstüne binseydi "kademe
  atladım mı, yoksa seans mı ısındı?" sorusu görsel olarak ayrışmaz hale
  gelirdi. Seans bitince alev kademenin dinlenme boyutuna döner, **asla
  altına inmez** — kalıcılık vaadinin tamamı bu kural.
- **Rozet merdiveniyle hizalama, "rozetleri yut" değil.** Eşikler (K4=10sa,
  K6=50sa, K7=100sa, K9=250sa) saat rozetleriyle (`badge_rules.dart:76-79`)
  birebir hizalandı; rozet kademenin belgesi oldu. Elenen alternatif —
  kademe rozetleri yutsun, yani saat rozetlerini kaldırıp yerine yalnızca
  kademe göstergesini koymak — `UserBadges` tablosundaki kayıtlı satırların
  kataloglarında karşılığı kalmaması demekti: `badgeByKey()` böyle bir
  satırda fırlar, kazanılmış bir rozet DB'de dururken uygulamada geri
  alınmış olurdu.
- **Merdiven Kotlin'de ikinci kez tanımlı, senkron testiyle korunuyor.**
  `FlameTierLadder.kt` çizim için zorunlu — widget kendi süreç ve dilinde
  çalışıyor, Dart'a erişemiyor — bu da merdiveni iki dilde, iki kez elle
  tutmak demek. Faz 16'nın palet senkronuyla aynı kalıp tekrarlandı:
  `test/android/flame_tier_sync_test.dart` Kotlin dosyasını metin olarak
  ayrıştırıp Dart tablosuyla karşılaştırıyor.
- **`cumulativeFocusSeconds` ham gönderiliyor.** Kademe, kalan saat ve oran
  Dart'tan değil Kotlin'de hesaplanıyor — `FocusWidgetSnapshot.kt:11`'in
  "türetilmiş değer Dart'tan okunmaz" kuralının aynısı. Oranı da Dart'tan
  göndermek, merdiven zaten çizim için Kotlin'de bulunmak zorunda olduğundan,
  ikinci bir gerçek kaynağı açardı.
- **Rozet kartındaki alev titremiyor.** İlk tasarım kararı kartta hafif bir
  titreşimdi (`flickering: true`, düşük genlik) — seans dışı olduğu için
  SPEC.md §6 kural 4'ün dekoratif animasyon yasağının burayı kapsamadığı
  düşünülmüştü. Uygulama sırasında `test/features/badges/badge_progress_test.dart`
  ve `badge_unlock_dialog_test.dart`ın `pumpAndSettle` kullandığı ortaya
  çıktı: sonsuz tekrarlı bir tikleyici bu testleri zaman aşımına düşürüyor.
  Kart artık `flickering: false`; durağan bir portre kimlik için zaten daha
  doğru ve pil için bedava.
- **`boxHeight` gerçekten kutuyu dolduruyor.** İlk sürümde `FlameWidget`,
  64×98 sabit `_FlameShape`e `Transform.scale(scale: tier.scale)` uyguluyordu.
  `Transform` paint'i etkiler, layout'u etkilemez — bu yüzden `boxHeight`
  alevi yalnızca **kırpabiliyordu**, hiç **büyütemiyordu**: kahraman kartın
  `boxHeight: 120`si, odak ekranının 98'iyle birebir aynı boyutta çizilip
  22px boş alan bırakırdı. Düzeltme: `fillScale = (boxHeight /
  _kShapeHeight) * tier.scale`, `_kShapeHeight = 98` sabiti `_FlameShape`in
  kendi `SizedBox`ının yanında duruyor. `FlameTier.scale`'ın doküman yorumu
  "yüzeyin verdiği kutuya oranı" diyor; uygulama artık bu sözleşmeyi tutuyor.
  98 dışında bir `boxHeight` (rozet kartının 120'si) ayrı bir regresyon
  testinde doğrulandı.
- **`FlameTierStatus` `==`/`hashCode` gerektiriyor.** `flameTierProvider` bir
  Riverpod `Provider`; Riverpod hesaplanan değerleri `==` ile karşılaştırıp
  dinleyicileri ancak o zaman uyarıyor. Override olmadan her istatistik tiki
  kimlikçe farklı bir nesne üretir, odak ekranı + kahraman kart + widget
  anlık görüntüsü birlikte gereksiz yeniden kurulurdu. Emsal `StreakStatus`
  (`lib/domain/streak/streak_calculator.dart`) ve `WeeklySummary`
  (`lib/domain/stats/weekly_summary.dart`) — ikisi de aynı gerekçeyle aynı
  override'ı taşıyor.
- **Kotlin senkron testi merdivenin tek bağımsız kanıtı.**
  `flame_tier_test.dart`'ın sınır testi beklentilerini `kFlameTierLadder`'ın
  kendisinden türetiyor, yani yanlış bir **değeri** yakalayamaz — yalnızca
  bozuk bir aramayı yakalar. Rozet hizalama testi (yukarıda) K4/K6/K7/K9'u
  `badge_rules.dart`'a, bağımsız bir kaynağa karşı pinliyor. Geri kalan altı
  basamak (K1/K2/K3/K5/K8/K10) **yalnızca**
  `test/android/flame_tier_sync_test.dart`'ın Kotlin tablosuna karşı kıyasıyla
  sınanıyor. Gelecekteki bakımcı için not: **Kotlin merdiveni bir gün Dart
  dosyası kopyalanarak yeniden üretilirse bu kanıt sessizce ortadan kalkar** —
  Kotlin tarafı bu spesifikasyondan (tasarım belgesinden), `flame_tier.dart`'tan
  değil, elle transkribe edilmeli.
- **Riverpod 3.1 test tuzağı.** Dinleyicisi olmayan çıplak bir
  `ProviderContainer`'da `await container.read(bir StreamProvider'ın .future)`
  hiç tamamlanmıyor ve 30 sn'de zaman aşımına düşüyor — `StreamProvider`
  elemanı kuruluyor ama teslim edilen değere hiç bağlanmıyor.
  `test/domain/flame/flame_providers_test.dart`'taki çözüm:
  `container.listen(allSessionsProvider, (_, _) {});` çağrısını
  `addTearDown(container.dispose)`den hemen sonra eklemek. Bunun yükleme
  durumunu maskelemediği ayrıca doğrulandı — `Stream.value` yine bir
  microtask'la teslim ettiği için beklenmeyen bir okuma da yükleme yolunu
  gözlemliyor. Gerçek ağaç pompalayan widget testleri bu tuzaktan etkilenmiyor.
- **`getMaxScaleOnAxis()` `Transform.scale`i ölçmek için kullanılamıyor.**
  Matrisin en büyük sütun uzunluğunu döndürüyor; `Transform.scale` z eksenini
  1.0'da bırakıyor, yani 1.0'ın altındaki her kademe ölçeği için z sütunu
  kazanıyor ve yardımcı sabit `1.0` raporluyor — hiçbir şeyi ayırt etmiyor.
  `test/core/widgets/flame_widget_test.dart` bunun yerine
  `transform.getColumn(0).length` okuyor, gerekçesi yorumla birlikte.

**Emülatör doğrulaması (Task 13).** Android 16 / API 36, release APK,
ekran görüntüleri `.verify/mesale/`de.

Doğrulanan: alev seans ilerlerken kademe boyutunu koruyor (04:55 ve 02:42'de,
halka ~%46 doluyken, alev boyut ve konumda birebir aynı) — özelliğin merkezî
vaadi. Ekran 04 kahraman kart (MEŞALEN kicker'ı, kırpılmamış alev, "Kıvılcım",
"0 / 1 sa", "Sonraki kademeye 1 saat", rozet ızgarası altta bozulmadan). Açık
**ve** koyu temada alev ucu doğru renk (`_lightBody` amber / `_darkBody`
krem) — kontrast düzeltmesi iki yönde de çalışıyor. Duraklamada alev tamamen
gri (`ColorFiltered`), boyut değişmiyor. Widget seçicide "Meşale" adı, 2×2
boyutu ve açıklamasıyla listeleniyor; gerçek `FlameRenderer` bitmap'i, kademe
adı, ilerleme çubuğu ve "Sonraki: 1 sa" ile canlı çiziliyor. Widget'a
dokunmak uygulamayı Rozetler'de açıyor — Kotlin `WidgetRoutes.BADGES` →
`WidgetLaunchHandler` → `BadgesScreen` zinciri uçtan uca çalışıyor. Tüm
Türkçe glifler (Ş, ş, ı, İ, ç, ö, ü) doğru çiziliyor, sessiz font-subset
düşüşü yok.

**Doğrulanamayan — gerçek boşluk.** Emülatörde yalnızca K1 hiç görüldü.
Emülatör üretim imajı (`adb root` reddedildi), debuggable APK için depolama
yetersizdi ve host'ta `sqlite3` yoktu — geçmiş seed'lenemedi. Sonuç:
**`FlameRenderer`'ın közlü taban (K4+), kıvılcım (K6+) ve hâle (K8+) dalları
hiçbir yerde hiç çalıştırılmadı** — Kotlin tarafında birim testi yok, tek
koşum K1'de ve orada üçü de kapalı. Aynı durum kahraman kartın sıfırdan
farklı bir `ratioInTier`'ı ve widget'ın `isTopTier` dalı için de geçerli.
Önerilen takip: ya seed'li geçmişle bir debug koşumu, ya da `FlameRenderer`
için Kotlin/Robolectric birim testleri.

**Tasarım gözlemi, düzeltilmedi.** K1'de kahraman kart kicker ile alev
arasında büyük bir boşluk bırakıyor: 120px'lik sahne sabit ama K1 alevi onun
yalnızca %35'ini dolduruyor. "Sabit sahne, büyüyen alev" modelinin doğal
sonucu, kusur değil — ama düşük kademelerde dengesiz görünüyor, bir
tasarımcının gözden geçirmesi değer katar.

**Doğrulama.** `flutter analyze` temiz, 359 test geçiyor, `flutter build apk
--release` derleniyor.

---

## Haftalık hedef (ROADMAP madde 24)

Tasarım: `docs/superpowers/specs/2026-09-13-haftalik-hedef-design.md`.
371 test geçiyor (+12), `flutter analyze` temiz.

**Hafta tanımı yazılmadı — asıl karar bu.** `weeklySummaryProvider`
(`domain/stats/stats_providers.dart`) bugünle biten kayan yedi uygulama
gününün odak saniyesini zaten yayınlıyor ve pazar kapanış bildirimi de aynı
saf fonksiyonu (`calculateWeeklySummary`) çağırıyor. Hedef bu sağlayıcıyı
**tüketiyor**, kendi pencere hesabını kurmuyor. ROADMAP'in "iki farklı hafta
kavramı çıkmasın" şartı böylece testle değil **kurguyla** sağlanıyor:
sapabilecek ikinci bir hesap yok. `WeeklyGoalProgress` bu yüzden yalnızca iki
`int` alıyor (`goalSeconds`, `focusedSeconds`) ve içinde hiç tarih geçmiyor.

**0 = kapalı.** Slider 0–30 saat; 0'da değer alanı "Kapalı" yazıyor ve
Ekran 02'deki satır hiç çizilmiyor. Kapatılamayan bir ilerleme çubuğu,
hafta boyunca %8'de duran bir kullanıcıya "eşlik eden" değil "ölçen" bir ton
kurardı — `weekly_summary.dart`'ın yüzde yerine farkı seçme gerekçesiyle aynı
yerden geliyor. `isReached` kapalı hedefte hiçbir zaman `true` olmuyor:
kullanıcının koymadığı bir hedefi kutlamak anlamsız.

**Birim ikiye ayrıldı, bilinçli.** Kolon dakika tutuyor (tablodaki diğer üç
süre alanıyla aynı), slider saat gösteriyor (haftalık bir hedefi dakikayla
konuşmak okunmaz). Çeviri tek yerde, Ekran 07'de.

**Boş haftada gizlenmiyor.** BUGÜN kartının dört noktası ve günlük çubuğu ilk
pomodoro tamamlanana kadar gizli ("0/4" bir eksik bildirimi). Haftalık çubuk
için aynı şey geçerli değil: pazartesi sabahı %0'da olmak eksiklik değil,
haftanın başıdır ve satırın bütün işlevi o noktadan sonrasını göstermek.

### Yolda çıkan gerçek sorun — Ekran 02'nin dikey bütçesi yokmuş

Satır eklenince `banner_placement_test` 34px taşma yakaladı. Ölçüldü:
390×844 ekranda **90dp'lik** adaptive banner'la (gerçek telefonların çoğunun
döndürdüğü yükseklik) Ekran 02'nin toplam boşluğu **26px**, hedef satırı ise
en sıkı hâliyle 43px istiyor. Yani ekran bir tampona değil, tam oturmaya
dayanıyormuş — bu madde olmadan da büyük sistem yazı tipinde taşardı.

Seçenekler tartıldı: halkayı 316'dan küçültmek, prototipin dikey aralıklarını
kısmak, satırı yalnız çubuğa indirmek. Üçü de prototip ölçülerini ya da
hedefin asıl bilgisini ("4sa 30dk / 5sa") feda ediyordu.

**Seçilen: gövde yalnızca sığmadığında kayıyor.** `LayoutBuilder` +
`SingleChildScrollView` + `ConstrainedBox(minHeight: maxHeight)`. Uzun
ekranlarda içerik eskisi gibi yerleşiyor, görünüm birebir aynı; yer
kalmayınca taşma yerine kayıyor. Prototipin hiçbir ölçüsüne dokunulmadı.

- **`IntrinsicHeight` denendi ve düştü** — ağaçtaki bir öğe intrinsic
  ölçümü desteklemiyor (`RenderFlex._getIntrinsicSize` patladı).
- **Çözüm `Spacer`ı kaldırmak oldu.** Banner artık kaydırma alanının
  **dışında**, dış bir `Column`un son çocuğu. İki kazanç: `Spacer` olmadığı
  için sınırsız yükseklik altında flex hatası doğmuyor, ve reklam kaydırılıp
  gözden kaybolmuyor — yuvası eskisi gibi altta duruyor.
- Diff büyük görünüyor ama `git diff -w` ile 134 satır: gerisi sarmalayıcının
  getirdiği girinti kayması.

### Testler

- `test/domain/stats/weekly_goal_test.dart` (+8): oran kırpma (hedefi üçe
  katlayan kullanıcıda çubuk rayını taşmıyor), `isReached` sınırı **dahil**,
  kalan sürenin tabanda kırpılması, kapalı hedef, `==`. İki test de hafta
  sınırını `calculateWeeklySummary`ye karşı çiviliyor — pencerenin dışındaki
  bir seans ikisini de aynı anda etkilemiyor.
- `test/features/countdown/weekly_goal_row_test.dart` (+1): tek testte üç
  durum (ilerliyor → tamamlandı → kapalı), ayar akışı canlı olduğu için
  ekran her yazımda kendiliğinden yeniden çiziliyor. Dosya başına tek test,
  `countdown_glow_test.dart`'taki drift göçü tuzağı yüzünden.
- `test/services/storage/weekly_goal_migration_test.dart` (+2): v4 → v5,
  mevcut satır 300 varsayılanını alıyor ve komşu ayarlar korunuyor.
- `settings_screen_test.dart` (+1): saat → dakika çevirisi, "Kapalı" hâli.
- **Güncellenen iki test.** `first_session_invite_test`in "hiç
  `LinearProgressIndicator` yok" iddiası artık günlük çubuğa özel
  (`kWeeklyGoalProgressKey` ile ayrışıyor); `settings_screen_test`in slider
  sayısı 3 → 4.

**Kapsam dışı bırakıldı:** pazar bildiriminin hedefe göre konuşması
("hedefinin %80'i"). Bildirim gövdesinin dört varyantı sekize çıkardı ve
"%80" cümlesi hedefi kaçıran kullanıcıya pazar akşamı tam da
`weekly_summary.dart:17-20`'nin reddettiği ölçen tonda bir not verirdi.
Madde 24'ün Kabul listesinde de yok.

**Doğrulanmadı:** emülatör görsel doğrulaması yapılmadı — açık iş.

---

## Madde 25 — Interstitial'ın yeri: mola başlangıcından döngü kapanışına

377 test geçiyor (+6). SPEC.md §7.2 ve Ekran 09 binding tablosu güncellendi.

- **Yeni an `PomodoroController._completeBreak`.** Mola dolup uygulama
  `idle`'a döndüğü an — kullanıcının hiçbir sayaca bakmadığı tek an.
  `AppReviewService.requestIfEligible` zaten tam orada duruyordu ve gerekçesi
  kelimesi kelimesine aynıydı; reklamın oraya taşınması yeni bir kural değil,
  var olan kuralın ikinci tüketicisi.
- **Neden mola başlangıcı yanlıştı.** İki ayrı gerekçe aynı saniyede
  birleşiyordu: (a) molanın ilk saniyesi ürünün korumayı vaat ettiği andı,
  (b) rozet/seri kutlaması da tam orada sunuluyordu — yani reklam hem molayı
  hem kutlamayı basıyordu. İkincisi için konmuş `badgeUnlocked` bastırması,
  hastalığı değil belirtiyi tedavi ediyordu.
- **Taşıma gösterim sayısını düşürmüyor.** Sıklık kuralının sayacı
  gösterimler değil tamamlanan **odak** seansları
  (`getAllCompletedFocusSessions()`); aynı kullanıcı aynı sayıda reklam
  görüyor, yalnızca birkaç dakika sonra. Gelirin aynı kalması bu maddenin ön
  şartıydı.
- **Yeni ve gerçek çakışma: değerlendirme istemi.** İkisi de **3.** tamamlanan
  odak seansında düşüyor (`minCompletedFocusSessions = 3` ile
  `showEveryNCompletedFocusSessions = 3`), yani çakışma istisna değil kural.
  Eski yerleşimde ikisi farklı anlardaydı ve kimse fark etmemişti. Çözüm:
  `requestIfEligible()` artık `Future<void>` değil `Future<bool>` —
  "istem gerçekten istendi mi" — ve `_completeBreak` bunu
  `maybeShowOnCycleComplete(otherPromptShown: ...)` kapısına veriyor.
  Değerlendirme istemi öncelikli: o **bir kez** sorulabiliyor, reklamın üç
  seans sonra yeni bir şansı var.
- **`requestIfEligible` iyimser davranmıyor.** Eşik tutmadığında, istem daha
  önce gösterilmişse ya da eklenti kanalı yoksa `false`. `true` dönmek
  reklamı bastırdığı için buradaki her yanlış `true` sessizce gösterim
  kaybıdır; testle çivilendi (`app_review_service_test.dart`, `InAppReview`i
  `implements` eden sahte — gerçek nesne testte hep `MissingPluginException`
  atıp "istem gösterildi" dalına hiç girmiyordu).
- **`ODAĞA DÖN` (`endBreakEarly`) reklam çıkarmıyor.** Teknik olarak o da
  `idle`'a dönüş, ama niyeti okumak gerekiyor: molayı erken bitiren kullanıcı
  odağa dönüyor, yani hâlâ ritüelin içinde. Değerlendirme istemi de aynı
  gerekçeyle orada tetiklenmiyordu — yeni tetikleyiciyi ona hizalamak, iki
  ayrı kural yerine tek kural bırakıyor. Molasını hep erken bitiren bir
  kullanıcı hiç interstitial görmeyecek; bilinçli kabul edilen maliyet.
- **`badgeUnlocked` → `otherPromptShown`.** Parametrenin anlamı zaten "üstüne
  binilmemesi gereken bir istem var"dı (yorumda yazılıydı); adı artık onu
  söylüyor. `BadgeUnlockService.evaluateAfterFocusCompletion()`in açılan
  anahtarları döndürmesi **korunuyor** — kutlamanın kendisi hâlâ ona bağlı,
  yalnızca reklam kapısı bu bilgiden koptu.
- **`_offerCelebration` artık `Future<void>`.** Dönüş değerinin tek tüketicisi
  interstitial kapısıydı.
- **Doğrulama.** `pomodoro_controller_test.dart`e iki test: 3. odak tamamlanıp
  **mola başlarken** hiçbir reklam isteği atılmıyor (eski kodda tam orada
  çıkardı), mola bitip döngü kapanınca tam bir istek atılıyor. Sayı üçe
  çivili çünkü sıklık kuralı ilk kez orada tutuyor.

**Doğrulanmadı:** emülatörde gerçek reklamla görsel doğrulama yapılmadı —
açık iş.

---

## Madde 26 — Dönüş yolu

Üç gün odaklanmayan kullanıcıya tek bir bildirim ve döndüğünde onu suçlamayan
bir karşılama satırı. Tasarım:
`docs/superpowers/specs/2026-09-17-donus-yolu-design.md`.

- **Bildirim neden ileriye kuruluyor.** Mevcut iki zamanlı bildirim (seri
  riski, haftalık özet) bugünün içinde bir ana kuruluyor; yokluk çağrısı ise
  tanımı gereği kullanıcı uygulamayı **açmazken** düşmeli. SPEC §1 backend/cloud
  sync'i ve dolayısıyla geleceğe dönük bir arka plan işini yasakladığı için tek
  yol, son değerlendirme noktasında (açılış + her odak tamamlanışı) üç gün
  sonrasına önden kurmak. Altyapı değişmedi: `_zonedSchedule` zaten ileri
  tarihli tek seferlik kurulum yapıyor, "iptal et → kapılar → kur" kalıbı da
  aynen korundu.
- **Pencere neden tek gün.** `reminderAtUtc` son seans gününün üç gün
  sonrasının 21:00 TSİ anıdır; o an geçmişse `null` döner ve bildirim
  kurulmaz. Böylece on gün yok olan kullanıcı, uygulamayı açtığında birikmiş
  bir bildirim yığınıyla karşılaşmıyor. Winback dizisi (3./7./14. gün) bilerek
  yazılmadı: ürünün tonu "geri dön" diye üstelemek değil.
- **Eşik neden üç tamamlanmış seans.** `AppReviewService`in
  `minCompletedFocusSessions`i ile aynı sayı ve aynı gerekçe. Uygulamayı bir
  kez deneyip bırakan kullanıcıya geri çağrı göndermek, ürünün kaçındığı
  winback tonuna kayardı; üç seans "alışkanlık kurmayı gerçekten denedi"
  eşiğinin zaten kabul edilmiş karşılığı.
- **Ayar neden paylaşılıyor.** Kapı `streakReminderEnabled`, kanal mevcut
  `streakRisk` (ve sessiz ikizi). İkisi de aynı sözü veriyor — seri/alışkanlık
  hatırlatması — ve günlük hatırlatmayı kapatan kullanıcının üç gün sonra
  rahatsız edilmek istediğini varsaymak için sebep yok. Ayrı bir anahtar drift
  v6 göçü + Ekran 07'de dördüncü satır demekti; ayrı bir Android kanalı ise
  kullanıcının kapattığı kategoriyi ikiye bölerdi.
- **Şerit neden bayraksız.** `_ComebackRow` görünürlüğünü
  `comebackStatusProvider` üzerinden geçmişten türetiyor: ilk odak tamamlandığı
  anda `absentDays` sıfırlanır ve satır ağaçtan çıkar. "Gösterildi mi" bayrağı,
  kapatma butonu ve yeni kalıcı alan yok — `streak_calculator.dart`ın telafi
  hakkıyla aynı ilke (aynı geçmiş her zaman aynı sonucu verir).
- **Şerit nereye kondu.** `BUGÜN` kartının içinde, haftalık hedef satırının
  üstünde. Ayrı bir kart Ekran 02'nin birincil eylemini ekran dışına iterdi;
  tam ekran bir dönüş hâli ise dönen kullanıcının "bir pomodoro"ya giden
  yoluna kapatma adımı eklerdi.
- **Kademe ve süre tek kaynaktan.** Hem bildirim gövdesi hem şerit
  `flameTierFor(kümülatif) + spellFocusDuration` kullanıyor; iki yüzey aynı
  anda farklı sayı söyleyemiyor. Bunun için `notification_service.dart`
  `domain/flame/flame_tier.dart`ı import ediyor — `domain/time` gibi saf bir
  yaprak olduğu için servisin `services/storage`den kaçınma kuralı bozulmuyor.

**Doğrulandı (2026-09-17):** cihaz saati üç gün ileri alınarak gözlendi.
`dumpsys alarm` bildirimi tam üç gün sonrasının 21:00 TSİ anına kurulu
gösterdi; saat o ana geldiğinde bildirim `streak_risk` kanalında id `1006` ile
düştü, uygulama açılınca karşılama şeridi çıktı, ilk odak tamamlanınca kapandı.
Ayrıntı ve yöntem: "Madde 21-22-24-25-26 — emülatör doğrulaması".

---

## Madde 21-22-24-25-26 — emülatör doğrulaması

Beş maddede birikmiş "emülatör doğrulaması yapılmadı" açık işi tek oturumda
kapandı. Karar, **doğrulamayı ayrı bir AVD'ye taşımak** oldu.

**Neden ayrı AVD.** Mevcut `Medium_Phone_API_36.1` `google_apis_playstore`
imajı; Play Store imajları her zaman `user` build olduğu için `adb root`
reddediliyor ve cihaz saati değiştirilemiyor. Ayrıca 6G'lik veri bölümü başka
projelerin debug kurulumlarıyla %92 doluydu, 170 MB'lık debug APK sığmıyordu.
Kullanıcının uygulamalarını silmek yerine `focussayac_verify` adında
`android-36/google_apis` tabanlı, 8G veri bölümlü ayrı bir AVD açıldı — bu
imaj `adb root` veriyor, dolayısıyla saat ileri alınabiliyor ve uygulama
veritabanına doğrudan erişilebiliyor.

**Zamanı sıçratmak seansı tamamlıyor.** Pomodoro bitişi duvar saatine bakan
bir son tarihe bağlı; `date -s @<epoch>` ile saati ileri almak 25 dakikalık
seansı anında tamamlıyor. Beş pomodoro döngüsü böyle dakikalar içinde koştu.
Geriye alma zaten korumalı (SPEC DoD), ileriye alma meşru tamamlanma.

**Geçmişi tohumlama.** `FlameTier` merdiveni 400 saate kadar çıkıyor; bu
geçmiş elle üretilemez. Veritabanı `adb pull` ile çekiliyor, host'ta Python
`sqlite3` ile `pomodoro_sessions`a tamamlanmış odak satırları yazılıyor
(`break_extensions=99` işaretiyle, her turda silinip yeniden kuruluyor),
`adb push` ile geri konuyor. Betik `.verify/seed_tier.py` — `.verify/`
gitignore'da, depoya girmiyor.

**Tuzak: `adb shell cat` ikili veriyi bozuyor.** Veritabanı ilk seferde
`run-as <pkg> cat …` ile çekildi; dosya 28672 yerine 28673 bayt geldi ve
sqlite `database disk image is malformed` dedi. Uygulama açılış ekranında
kilitlendi ve kademe taraması sessizce **splash ekranını** fotoğrafladı —
ekranda hata yok, uygulama sadece hiç açılmıyor. `adb pull` ikili güvenli;
`integrity_check` ile teyit edilmeli.

**Play Store'suz imajın yan etkisi faydalı çıktı.** `google_apis` imajında
`com.android.vending` yok, bu yüzden `requestInAppReview` servise bağlanamıyor.
Madde 25'in çakışma kararı tam da bu yüzden görünür oldu: mola sonunda önce
değerlendirme istemi çağrıldı, düştü, sonra interstitial açıldı — yani
`otherPromptShown` kapısı çalışıyor ve istem gösterilebilseydi reklam
bastırılacaktı.

**Çıkan hata.** Madde 21'in meta satırı son düzlükte halkanın altına giriyor —
ROADMAP madde 32.

**Kapanmayan.** Kotlin `FlameRenderer` hâlâ çalıştırılamadı: widget'ı ana
ekrana koymak adb ile sürülemiyor (`appwidget` yalnızca `grantbind`
destekliyor, `cmd appwidget` yok). ROADMAP madde 31 bu tek parçaya daraldı.

---

## Madde 27 — Geri sayım halkasının emek ekseni

**Sorun.** Halka `clamp(1 - days/400, 0.06, 1)` ile çiziliyordu: sınava 300 gün
kalan kullanıcıda aylarca ~%25'te duruyor. 40 saat çalışsa da kıpırdamıyor —
geçen zamanı gösteriyor, harcanan emeği değil.

**Asıl karar: halkayı değiştirmek değil, ikinci bir eksen eklemek.** ROADMAP üç
yol bırakmıştı (halkayı emeğe bağla / ikinci eksen / ölçeği yeniden eşle).

- **Halkayı tamamen emeğe bağlamak** "hedef saat" diye yepyeni bir kural icat
  etmeyi gerektiriyordu (kalan gün × günlük tempo gibi) ve ekran sınava kalan
  zamanı görsel olarak anlatmayı bırakırdı. Uygulamanın adı geri sayım.
- **Ölçeği yeniden eşlemek** (sınavın eklendiği andan sınav gününe oranla) en
  küçük koddu ama şikâyetin özünü hiç çözmüyordu: halka yine yalnızca geçen
  zamanı gösterirdi, emek hiçbir dalda içeri girmezdi.
- **İkinci eksen** ikisini de koruyor: zaman yayı aynen duruyor, emeğin kendi
  yayı oluyor.

**Emeğin paydası haftalık hedef — çünkü kullanıcının koyduğu tek emek hedefi
o.** Madde 24 zaten `AppSettings.weeklyGoalMinutes`i ve
`weeklyGoalProgressProvider`ı kurmuştu. Yeni ayar, yeni kolon, drift göçü ve
ikinci bir hesap yok; halkanın yayı ile `BUGÜN` kartının çubuğu **aynı**
`WeeklyGoalProgress` örneğinden besleniyor, yani iki yüzey ayrışamaz. Bunun
bedeli bilinçli: pencere kayan yedi gün olduğu için yay ileri gittiği gibi geri
de gidebiliyor (eski seanslar pencereden düşerse). Bu dürüst — kartın çubuğu da
tam olarak bunu yapıyor ve iki yüzeyin farklı davranması daha kötü olurdu.

**Hedef kapalıyken `null`, `0.0` değil.** Yay da izi de hiç çizilmiyor. Boş bir
yay "hedefinin %0'ındasın" der; oysa kullanıcının koyduğu bir hedef yok.
`_WeeklyGoalRow`un kapalı hedefte satırı tamamen gizlemesiyle aynı karar —
kapatılamayan bir gösterge "eşlik eden" tonu "ölçen" tona çevirir.

**Prototipin hiçbir ölçüsü değişmedi.** Emek yayı var olan boş banda yerleşti:
zaman izinin iç kenarı 125.5 (130 − 9/2), kesikli dekoratif çember 112. Yay
r=119, kalınlık 4 (117–121) → iki komşuya da ~4.5px. Zaman yayının yarıçapı,
9px kalınlığı ve üç duraklı gradyanı aynen korundu.

**Emek yayı gradyansız.** Zaman yayı `sky → accent400 → ember` gradyanıyla
dekoratif; emek yayı tek düz ton. İkisi aynı boyayı paylaşsaydı göz onları tek
bir göstergenin iki parçası sanırdı — oysa bunlar iki ayrı eksen. Ton
`_WeeklyGoalRow`unkiyle aynı: hedefe giderken `ember`, dolunca `mint`
(uygulamanın tamamlanma dili).

**Sıfır uzunluklu yay çizilmiyor.** `StrokeCap.round` ile sıfır süpürme açısı
ekranda açıklanamayan bir nokta bırakırdı; haftanın başında iz zaten ekseni
gösteriyor.

**Yeni ekran okuyucu etiketi yok — bilerek.** Yay, `BUGÜN` kartındaki
`_WeeklyGoalRow`un zaten seslendirdiği sayıların görsel yankısı ("Bu hafta 2
saat, haftalık hedef 5 saat"). İkinci kez duyurmak ekran okuyucu kullanıcısına
aynı bilgiyi iki kez okutmak olurdu. Yay dekoratif katmanda kalıyor, bilgi
kaybı yok.

**İki tween, tek painter.** Zaman oranı gün dönümünde, emek oranı her seans
bitişinde değişiyor; tek `TweenAnimationBuilder` iki değeri taşıyamaz. Emek
tween'inin süresi ve eğrisi `_WeeklyGoalRow`unkiyle aynı (`AppMotion.slow` +
`AppMotion.standard`), böylece halkanın yayı ile kartın çubuğu aynı hızda
yürüyor.

**Kapsam dışı.** Ana ekran widget'ının Kotlin ikizi `RingRenderer.kt` bu eksene
dokunmadı: widget yalnızca zaman yayını çiziyor. Emek yayını oraya taşımak
payload'a haftalık hedef verisi eklemeyi gerektirir ve "türetilmiş değer
Dart'tan okunmaz" kuralı gereği oranın Kotlin'de hesaplanmasını ister — ayrı
madde olmalı.

**Doğrulandı (2026-09-17).** Kabul ölçütü cihazda birebir kuruldu: aktif sınav
+300 güne alındı, yani zaman yayı `1-300/400` = %25'e çivilendi ve yalnızca
emek ekseni oynadı. Yeni yardımcı `.verify/seed_week.py` — `seed_tier.py`nin
kısa ufuklu kardeşi: o betik seansları 400 gün geriye yazıyor (kümülatif kademe
merdiveni için) ve **kayan yedi günlük** pencereyi hiç doldurmuyor. Tohum
satırları 1–3 gün geriye, `break_extensions=99` işaretiyle konuluyor; bu aralık
hem pencerenin içinde hem de dönüş şeridini (madde 26) kapalı tutuyor, yani
şerit kartı örtüp ölçümü bozmuyor.

Dört durum gözlendi (`.verify/m27_a_bos|b_kismi|c_dolu|d_kapali.png`): hafta boş
→ yalnızca soluk iz, `effort > 0` kapısı sayesinde leke yok; %42 → köz yayı
~150°, kartın çubuğuyla aynı sayı; %100 → nane yay + "Hedef tamam"; hedef
kapalı → yay da izi de yok, halka madde 27 öncesiyle birebir aynı. Zaman yayı
dördünde de %25'te kaldı.

**İki tuzak.** (1) Git Bash `/data/data/...` yolunu Windows yoluna çeviriyor ve
`adb pull` "failed to stat remote object 'C:/Program Files/Git/data/...'" diyor;
`MSYS_NO_PATHCONV=1` gerekiyor. (2) Drift tablosunun adı `app_settings` değil
**`app_settings_table`**; ilk betik sessizce `no such table` ile düştü.
Veritabanı `adb pull`/`adb push` ile taşındı (`shell cat` ikiliyi bozuyor,
"Madde 21-22-24-25-26" bölümünde belgeli) ve her yazımdan sonra
`chown u0_a216:u0_a216` + `restorecon` uygulanıp `-wal`/`-shm` silindi.

**Yan bulgu — madde 27'den değil.** Zaman yayının 12 yönündeki başlangıç ucunda
küçük bir köz lekesi var: `SweepGradient` + `StrokeCap.round` birleşimi yuvarlak
ucu başlangıç açısının biraz gerisine taşıyor ve gradyanı ~360°'de, yani
`ember` durağında örnekliyor. Kaynağı kesin, çünkü hedef kapalı karesinde emek
yayı hiç çizilmediği hâlde leke duruyor. Bu maddede düzeltilmedi — zaman
yayının boyasına dokunmak madde 27'nin kapsamı değil, ayrı madde olmalı.

---

## Madde 28 — Alt gezinme çubuğunun bilgi mimarisi

**Sorun.** Beş kalıcı yuvadan birini `storyCard` tutuyordu: nadiren kullanılan
bir dışa aktarma aracı. Karşılığında uygulamanın **birincil eylemi** —odak
seansı başlatmak— yalnızca Ekran 02'deydi; rozetler, veriler ya da ayarlar
ekranındaki kullanıcı önce sayaca dönmek zorundaydı.

**Asıl karar: yuva silinmedi, eyleme dönüştü.** Dörde inmek en küçük değişiklikti
ama yol haritasının kabulü "slot birincil bir eyleme geçmiş" diyordu ve dörde
inmek boşluğu yalnızca genişletirdi. Yuva yerinde duruyor, artık bir yere
**gitmiyor**, bir şey **yapıyor**.

- **Sekme değil eylem.** `AppNavTab` dört üyeye indi (`countdown`, `badges`,
  `stats`, `settings`); eylem yuvasının enum üyesi yok, aktif hâli yok, hapı
  yok, `Hero` uçuşuna katılmıyor. "Aktif sekme" bir konum bildirir; odak ekranı
  zaten çubuğu göstermeyen bir üst kat olduğu için bu yuvanın "buradasın" hâli
  hiçbir zaman doğru olmazdı.
- **Boyası Ekran 02'nin düğmesinin küçültülmüş hâli** — köz kenarlık, yukarıdan
  aşağı sönen `emberDeep` gradyanı, dolu `play` ikonu. Aynı eylem iki yüzeyde
  aynı görünsün diye: kullanıcı yuvanın ne yaptığını öğrenmek zorunda kalmıyor.
  Etiketi yok (beşte birlik payda `ODAKLAN` okunmaz boyuta iniyordu); adı
  `Semantics` ile veriliyor, pasif sekmelerdeki kalıbın aynısı. Dokunma hedefi
  sekmelerle aynı 48px, görünen kutu aktif hapla aynı 46px.
- **Prototipin ölçüleri korundu:** beş yuva, aktif `flex:16`, diğerleri
  `flex:10`. Çubuğun geometrisinde tek piksel değişmedi.
- **Kural tek yerde: `startFocusFromNav`.** Sekmelerin `navigateToNavTab`ı gibi
  eylem de `bottom_nav_bar.dart`ta duruyor ve `BottomNavBar` bunun için
  `ConsumerWidget` oldu. Dört ekrana ayrı ayrı `onStartFocus` bağlamak aynı
  kararı dörde kopyalamak olurdu; kuralın çubuğun kendi dosyasında durması,
  gezinme kurallarının zaten orada olmasıyla tutarlı.
- **Faz boş değilse `startFocus` çağrılmıyor.** Süren bir seansın (ya da molanın)
  üstünde ikinci kez çağırmak sayacı sıfırlardı; o durumda yuva "devam et"
  düğmesine dönüşüp yalnızca odak ekranını açıyor — Ekran 02'nin aktif seansı
  kurtaran yönlendirmesiyle aynı davranış.
- **Rota `push`, `pushReplacement` değil.** Odak ekranı bir sekme değil,
  bulunulan ekranın üstüne binen bir kat: seans bitip `pop` edildiğinde kullanıcı
  başladığı yere dönüyor. Emülatörde rozetler ekranından başlatılan seans iptal
  edilince kullanıcı sayaca değil rozetlere düştü.

**Ekran 05 artık kazanım anına bağlı bir üst kat.**

- Rotası `_tabPage` yerine `_pushedPage`: geçiş dili de sekme dilinden çıkıp
  Ekran 11 ve odak seansıyla aynı "aşağıdan yukarı" hâline geldi.
- Çubuğu kaldırıldı; sol üstte Ekran 11'in kapatma düğmesinin **birebir aynısı**
  var (38px daire, `fillMedium` kenarlık, `x` ikonu). İki ekran da alt çubuğu
  olmayan, üste binen bir kat — farklı görünmeleri için sebep yok. Alt boşluk
  `kBottomNavReservedSpace`ten 26px'e indi.
- Girişleri madde 19'da zaten kurulmuştu ve aynen duruyor: rozet dialogundaki
  "BAŞARI KARTINI OLUŞTUR", rozet açılışı kutlaması, seri eşiği kutlaması (SERİ
  şablonunu önermeye devam ediyor). Rozet dialogunun geri düşüşü
  `navigateToNavTab` yerine düz `context.push` oldu — kart sekme olmadığı için
  "kökün tek kat üstünde dur" kuralı ona uymuyor; kapatma düğmesi kullanıcıyı
  rozetlere bırakıyor, sekmeyken yığında rozetlerin **yerini** alıyordu.
- `navStoryCard` ("BAŞARI") ARB'den çıktı, yerine `navFocus` ("ODAKLAN") geldi.

**Kademe atlama kutlaması kapsam dışı bırakıldı.** Yol haritasının kapsam
cümlesi üç kazanım anı sayıyordu; ikisi (rozet, seri) madde 19'dan hazır,
üçüncüsü **hiç yok** — yeni bir `SessionCelebration` türü, kalıcı "son kutlanan
kademe" anahtarı, yeni dialog ve rozetle çakışma kuralı demek. Maddenin kabul
ölçütlerinin hiçbiri bunu istemiyor; ROADMAP madde 34 olarak ayrıldı.

**Test altyapısı: veritabanı `runAsync` içinde kurulmalı.** Yeni gezinme
testleri tek başına geçip takımda düşüyordu. İz sürünce sebep çıktı:
`countdown_navigation_test`in `_pumpApp`ı `AppDatabase.forTesting(NativeDatabase.memory())`i
**sahte zaman kuşağında** kuruyordu ve dosyanın ilk testinden sonraki her taze
veritabanı hiç açılmıyor, tek-seferlik ilk `Future` (`startFocus()`ün ayar
okuması) sonsuza kadar bekliyordu. Kare sayısını artırmak da, dokunuştan sonra
`runAsync` ile beklemek de çözmedi — kurulumun kendisi gerçek kuşakta olmalı.
Depodaki `story_card_screen_test` aynı şeyi zaten yapıyordu (`_newDatabase` →
`tester.runAsync`), kalıp oradan alındı. Ekranlar bugüne kadar yalnızca `watch`
akışlarıyla çizildiği için hata görünmemişti.

**Emülatör doğrulaması (2026-09-17, `emulator-5554`, 1080×2400).** Kabul
ölçütleri tek tek: çubuk açık temada `.verify/m28_a_sayac.png`, koyu temada
`m28_f_koyu.png` (köz kenarlık iki temada da okunuyor); rozetler ekranından
ODAKLAN 25:00'lık seansı açtı (`m28_c_odak.png` — ilk seansın 5 dakikası değil,
ayardaki süre); iptal kullanıcıyı rozetlere geri bıraktı (`m28_d_donus.png`);
rozet dialogundan açılan kart çubuksuz ve kapatma düğmeli (`m28_e_kart.png`),
"1080 × 1920 PNG" satırı artık hiçbir şeyin altında kalmıyor, kapatınca yine
rozetlere döndü. `m28_b_veriler.png` veriler sekmesinin çubuğu: aktif hap
genişleyince eylem yuvası sola kayıyor, oranlar bozulmuyor.

---

## Madde 29 — Aylık ısı haritası

**Sorun.** İstatistik ekranının tek grafiği 7 günlük bar chart'tı. Kullanıcı
kendi **ritmini** — hangi günler çalıştığını, boşluğun nerede açıldığını —
hiçbir yerde göremiyordu. Veri zaten elde: `PomodoroSessions` tablosundaki
tamamlanmış odak seansları. Yeni alan, agregat tablo, drift göçü gerekmedi.

### 1. Neden takvim düzeni, GitHub tarzı değil

Sütunlar Pzt–Paz, satırlar haftalar. GitHub'ın 7 satır × haftalar düzeni bir ay
için yalnızca 4-5 sütun bırakıyor ve ızgara yatayda cılız kalıyor; o düzen asıl
yıllık pencerede kazanıyor. Takvim düzeni "hangi gün" sorusunu doğrudan
cevaplıyor, ayın başındaki boş hücreler de ayın şeklini veriyor.

### 2. Seviye eşikleri neden mutlak

`kHeatmapLevelThresholds = [1, 25, 50, 90]` dakika; ayın en yoğun gününe göre
ölçeklenmiyor. `WeeklyFocusBarPainter` sütunları kendi haftasının en yüksek
gününe göre ölçekliyor ("sabit bir tavan az çalışılan bir haftada tüm sütunları
okunmaz kılardı") ama ızgarada aynı kural yanlış bir şey söylerdi: ayda tek bir
5 dakikalık günü olan kullanıcı o günü **en koyu** tonda görürdü. Sınırlar 25
dakikalık varsayılan pomodoronun 1 / 2 / 3+ katları ve dakikada sabit oldukları
için iki ay birbiriyle karşılaştırılabiliyor.

### 3. Gelecek günler neden hiç çizilmiyor

Ayın henüz gelmemiş günleri, baştaki boşluklar gibi yalnızca yer tutuyor; ızgara
da bugünün satırında bitiyor, ayın sonunda değil.

Tasarımda önce soluk bir dolgu vardı (`fillFaint` gelecek, `fillSubtle` boş
geçmiş gün). Emülatörde ikisi ayırt edilemedi — fark %5 ile %9 beyaz — ve ayın
ortasında kartın altında iki satır yüksekliğinde ölü alan kaldı. Boş bırakmak
hem kesin bir sinyal hem zaten tanıdık bir kalıp; kart ay ilerledikçe büyüyor.

Kararın kökü ton: ayın 2'sinde kullanıcıya 28 boş kutu göstermek, henüz
yaşanmamış günleri kaçırılmış gün gibi okuturdu.

### 4. Başlık neden ayın adı değil, `BU AY`

`DateFormat.yMMMM` ya 12 yeni ARB anahtarı ya da karta `intl` bağımlılığı demek.
`shortDayNames`in yorumunda yazılı kısıt burada da geçerli: kart
`initializeDateFormatting` çağrılmadan da çizilmek zorunda —
`stats_screen_test`in üç testinden ikisi onu çağırmıyor. Kicker
`statsWeeklyClosingLabel` ("BU HAFTA") ile aynı kalıpta duruyor.

Ayın toplamı **boş ayda hiç yazılmıyor**: haftalık kapanış kartının gerekçesinin
aynısı — "0 dakika" eşlik eden bir tondan ölçen bir tona geçiş. Izgaranın
kendisi boş ayda da çiziliyor; doldurulmayı bekleyen ızgara maddenin asıl fikri.

### 5. Neden `CustomPainter` değil widget ağacı

42 hücre statik ve bir `RepaintBoundary` içinde; karşılığında her hücre
`find.byKey` ile testten görünüyor. Madde 31 zaten bir painter'ın
(`FlameRenderer`) doğrulanamamasından açık — ikinci bir doğrulama boşluğu
açılmadı.

### 6. Ekran okuyucu: tek özet cümle

Izgaranın tamamı tek bir `Semantics` kabı (`_ComebackRow` / `_WeeklyGoalRow`
kalıbı): *"Bu ay 30 günün 12 gününde odaklandın, toplam 3 saat 40 dakika."*
Hücre hücre gezinme, TalkBack kullanıcısını tek bir karttan geçmek için 30
durak aşmaya zorlardı ve boş günler de durak olurdu.

### 7. Alt çubuğun payı `BannerAdSlot`tan yerleşime taşındı

Ekran 06 bu maddede kaydırmaya geçti (madde 24'te Ekran 02'ye uygulanan kalıp:
`Expanded` + `LayoutBuilder` + `ConstrainedBox(minHeight:)`, banner kaydırma
alanının dışında). Kaydırma, gizli bir kusuru görünür yaptı.

`BannerAdSlot` reklam **hiç istenmediğinde** (onay yok ya da premium) tamamen
kapanıyor — ve `bottomMargin: 88`i, yani alt gezinme çubuğunun payını da
götürüyor. Sabit yerleşimde bu farkı `Spacer` yutuyordu. Kaydırmalı gövdede ise
içeriğin sonu çubuğun arkasına giriyor: emülatörde ızgaranın alt iki satırı
görünmüyordu. Pay artık `StatsScreen._navBarFootprint` olarak yerleşimde,
`BannerAdSlot` yalnızca kendi yüksekliğini ayırıyor.

**Ekran 02'de aynı gizli kusur duruyor.** Orada içerik henüz çubuğun payı kadar
uzamıyor, o yüzden bu maddede dokunulmadı.

### 8. Kapsam dışı

- **Ay gezinme okları.** Seçili ayı tutan bir durum, ilk seansın ayından önceye
  ve gelecek aya geçişin kapatılması, üç yeni widget testi demek. Kabul ölçütü
  (boş / kısmi / yoğun ay) içinde bulunulan ayla karşılanıyor.
- **Hücreye dokunma, tooltip, gün detayı.** Izgaranın işi ritmi bir bakışta
  vermek; gün başına sayı bar chart'ta zaten var.
- **Yıllık pencere.** 7 satır × 52 sütun düzeni yatay kaydırma ve ayrı bir
  yoğunluk ölçeği ister.

---

## Madde 30 — Ders bazlı seans

Tasarım belgesi: `docs/superpowers/specs/2026-09-17-ders-bazli-seans-design.md`.
440 test geçiyor (+24). Sınav öğrencisinin asıl takip ettiği metrik ders
dağılımıydı ve uygulamada hiç yoktu; listedeki en çok iş, en savunulabilir
farklılaşma.

### 1. Katalog sınava göre ve kodda

`presetKey` → ders anahtarı listesi (`domain/subjects/subject_catalog.dart`),
rozet kataloğunun kalıbı: DB yalnızca anahtarı tutuyor, ad ARB'den geliyor.
Yeni tablo yok, **tek yeni sütun**.

Anahtarlar sınavlar arasında **paylaşılıyor**: YKS'nin ve LGS'nin "Matematik"i
aynı `math`, KPSS'in "GY Matematik"i de. Ayrı anahtar, sınav değiştiren
kullanıcının geçmişini iki ayrı derse böler ve ARB'ye aynı şeyi söyleyen ikinci
bir ad eklerdi. 18 anahtar; preset'i olmayan sınav (kullanıcının kendi eklediği)
ve tanınmayan preset genel katalogu alıyor — boş liste hapı ölü bir düğmeye
çevirirdi.

### 2. İki nullable sütun, şema v6

`PomodoroSessions.subjectKey` ve `AppSettingsTable.activeSubjectKey`, ikisi de
**varsayılansız** nullable. Önceki dört göçün kalıbı (kolon varsayılanı mevcut
satıra da uygulanır) burada yanlış olurdu: göç alan kullanıcının seansları
gerçekten dersiz, onlara bir ders atamak veri uydurmak olur. `null` =
"belirtilmemiş" ve ekranlarda kendi dilimi var.

Ders **yalnızca odak** seansına yazılıyor; mola satırları `null`. Alternatif
(molanın dersi odaktan devralması) `PomodoroPhase`e freezed alan, prefs
kodlaması ve kurtarma yolu demekti — karşılığında hiçbir yüzeye veri vermeden.

Seçim `SharedPreferences`ta değil `AppSettings`te: aktif sınav zaten orada, ikisi
aynı anda okunuyor ve aynı anda geçersizleşiyor. Sınav değişince ayar
**sıfırlanmıyor**, okuma anında doğrulanıyor (`resolveActiveSubject`) — YKS'de
Kimya seçip LGS'ye bakan kullanıcı YKS'ye dönünce dersini geri buluyor, aradaki
LGS seansları ise yanlış bir derse değil dersiz yazılıyor.

### 3. Yapışkan hap, zorunlu bir adım değil

Ekran 02'de ODAKLAN'ın üstünde hap; dokununca alt sayfa. ODAKLAN tek dokunuşla
seansı başlatmaya devam ediyor. Her ODAKLAN'da alt sayfa açmak her seansa bir
dokunuş eklerdi ve Hızlı Odak widget'ı ile onboarding'in ilk seansı o akışa hiç
giremezdi. Ders seçilmemişken hap bir davet (`Ders seç`) — maddenin asıl riski
kimsenin ders seçmemesi.

Alt sayfanın seçim yüzeyi satır listesi değil **hap ızgarası** (`Wrap`): adlar
kısa, sayıları 2-11; satır listesi YKS'de kaydırma gerektirirdi.

### 4. `startFocus` sınavı DAO'dan okuyor (test sırasında çıktı)

Katalogu belirleyen sınav `activeExamProvider`ın akış değeri olamaz: o akış soğuk
başlangıçta (widget'tan açılan seans, ekran hiç kurulmadan) henüz yayın yapmamış
olabiliyor ve katalog genel listeye düşünce **geçerli bir ders sessizce
kayboluyordu**. Ders seçiliyken sınav `ExamDao.getActiveExam()` ile okunuyor;
seçim yokken fazladan sorgu yok. Controller testinde ortaya çıktı — sağlayıcı
akışına abone olmayan bir container'da kimya yazılmıyordu.

### 5. Tek pencere: son yedi uygulama günü

Dağılım da denge de ihmal de `calculateWeeklySummary` ile **birebir aynı**
pencereyi kullanıyor (bugünle biten yedi gün, karşılaştırma ondan önceki blok).
Dağılıma ayrı bir aylık pencere açmak tek ekranda iki farklı "şimdi" tanımı
demekti; Ekran 06 zaten bu pencereyi konuşuyor ("BU HAFTA" kartı, bar chart).

- **Denge:** en çok artan + en çok azalan ders. Önceki pencere boşken ikisi de
  yok — ilk haftasındaki kullanıcıya kendi sıfırıyla kıyas sunmak
  `WeeklySummary.hasComparison`ın reddettiği şey. Azalan uç **nötr** tonda,
  kırmızı yok.
- **İhmal:** katalogdaki dersler içinde, **daha önce çalışılmış** ama pencerede
  hiç çalışılmamış olanlardan en uzun süredir dokunulmayanı. Hiç çalışılmamış
  ders aday değil: YKS katalogunda 11 ders var, kullanıcı haftada 3-4'üne
  dokunuyor; "hiç çalışmadıkların" her hafta aynı yedi dersi sayan bir suçlama
  olurdu.
- **Belirtilmemiş dilim** dağılımda duruyor ama eşitlikte sona düşüyor ve denge
  uçlarına aday değil ("Belirtilmemiş +40 dk" bir şey söylemiyor). Kart yalnızca
  bu dilim varken hiç çizilmiyor.

### 6. Göç testlerinin kurgusu eksikmiş (yan kazanım)

v6 göçü `pomodoro_sessions`a da kolon eklediği için üç eski göç testi
(`theme_mode` / `weekly_summary` / `weekly_goal`) kırıldı: kurguları yalnızca
`app_settings_table` yaratıyordu, oysa gerçek bir v2-v5 veritabanında seans
tablosu v1'den beri duruyor. Üçüne de pre-v6 `pomodoro_sessions` eklendi.
Tarih sütunları `TEXT`: `build.yaml`'daki `store_date_time_values_as_text` ISO
metin yazıyor, `INTEGER` kurgu okuma anında `FormatException` veriyor.

### 7. Emülatör doğrulandı (2026-09-18)

Cihazda **gerçek yükseltme yolu** koştu: madde 29'dan kalan v5 veritabanı
açıldığında `user_version = 6`, eski seansların `subject_key`i `NULL`, hap boş
(`.verify/m30_a_hap_davet.png`). Alt sayfa YKS katalogunu 11 hapla açıyor
(`m30_b_alt_sayfa.png`), Kimya seçimi hapa ve ayara yazılıyor
(`m30_c_hap_secili.png`), başlatılan seans `subject_key = 'chemistry'` ile
düşüyor (DB `adb pull` ile doğrulandı). Tohumlanmış haftada Ekran 06:
`4sa 45dk` toplam, Matematik %42 / Türkçe %32 / Fizik %16 / Belirtilmemiş %11,
denge `Türkçe +1sa · Matematik −1sa`, ihmal `Kimya'ya 14 gündür dokunmadın.`
(`m30_g_ekran06_dagilim.png`); açık temada rampa ısı haritasıyla aynı yönde
dönüyor (`m30_h_ekran06_acik.png`).

Doğrulama sırasında iki taşma düzeltildi (ikisi de widget testinde yakalandı,
cihaza hiç gitmedi): kartın başlığı uzun süre metniyle 40px, alt sayfanın
başlığı uzun ipucuyla 52px taşıyordu. Başlıkta kısa süre biçimine geçildi,
denge iki satıra alındı, ipucu kısaltılıp esnek yapıldı.

### 8. Kapsam dışı

Ders başına hedef, ders bazlı rozet, geçmiş seansın dersini sonradan düzenleme,
kullanıcının kendi dersini yazması, ders bazlı bildirim.

---

## Madde 31 — `FlameRenderer` doğrulaması

Tasarım: `docs/superpowers/specs/2026-09-18-flame-renderer-dogrulama-design.md`

### 1. Neden ekran görüntüsü değil test

Madde 23'ten devreden boşluk Kotlin `FlameRenderer`ın hiç çalıştırılmamış
olmasıydı ve **emülatörle kapanamıyordu**: widget'ı ana ekrana koymak adb ile
sürülemiyor (`appwidget` kabuk komutu yalnızca `grantbind` destekliyor, `cmd
appwidget` yok). Çizim yolunu kodla çağırmak tek yol. `render` gerçek
`Bitmap`/`Canvas`/`Paint`/`Shader` istediği için düz JVM testi de yetmiyor —
stub `android.jar` hepsinde `RuntimeException("Stub!")` atar.

### 2. İki koşum evi, tek iddia gövdesi

Robolectric (`src/test`, NATIVE grafik kipi) cihazsız kalıcı kapı; instrumented
test (`src/androidTest`) bu maddenin emülatör kanıtı. İddiaların ikisinde de
ayrı yazılması zamanla ayrışma demekti, o yüzden hepsi
`src/sharedTest/kotlin/.../FlameRendererContract.kt`te ve `build.gradle.kts` bu
dizini iki kaynak kümesine de ekliyor. `@GraphicsMode` Robolectric'e özel
olduğu için sözleşmede değil koşucuda — `androidTest` classpath'ine Robolectric
girmiyor.

### 3. Altın görüntü değil, merdivene bağlı piksel sondası

Robolectric'in native grafiği ile gerçek cihazın yığını bayt bayt uzlaşmaz; iki
koşum evi bir altın görüntüde anlaşamaz. Bunun yerine her iddia geometriyi
`FlameTierLadder`a bağlıyor: gövde tepesi ≈ `heightPx * (1 - scale)`, köz
sondası ⇔ `emberBase`, hâle sondası ⇔ `haloOpacity > 0`, kıvılcım sayısı =
`sparkCount`.

Kıvılcım iddiası **konumdan bağımsız**: gövdenin dışındaki şeritte birbirine
bağlı lekeler taşma doldurmayla sayılıyor. Formülü tekrar etmek testi
düzeltmenin aynasına çevirirdi; leke sayımı merdivenin *sözünü* ("K6'dan sonra
kıvılcımlar") sınıyor.

Alfa eşikleri renderer'ın kendi alfalarından türüyor. Dikkat: shader kurulurken
`paint.color`un alfası duruyor ve shader'ı süzüyor — köz çizildikten sonra
gövde `emberBase` kademelerinde 0xB3 ile modüleleniyor, kozsuz kademelerde
0xFF. Hâle ise en fazla `0.34 * 255`; eşikler hâleyi gerçek çizimlerden
ayıracak şekilde seçildi.

### 4. Bulunan hata: üst kademelerde kıvılcımlar sessizce kırpılıyordu

Dart'ta şekil kutusu 64×98, gövde 44×86 ve tabana yapışık — tepede 12px hava
var. Kotlin'de `bodyHeight = heightPx * tier.scale`, yani `scale == 1.0`da
gövde kareyi tamamen yiyor, `top` sıfıra iniyor ve `if (y > 0f)` kıvılcımları
atıyordu. Üretim ölçüsünde (60×64dp ≈ 157×168px) **K8'de 3'ün 2'si, K9'da 4'ün
1'i, K10'da 5'in hiçbiri** çizilmiyordu. Hiç çalıştırılmamış kod olduğu için
kimse görmemiş; test ilk koşumunda üçünü birlikte bildirdi.

Düzeltme tek satır: kıvılcımlar tepeden **yukarı** yığılmak yerine tepeden
**aşağı** iniyor (`y = top + sparkRadius + bodyHeight * 0.08f * i`). Gövdenin
iki yanındaki dizilim her ölçekte kare içinde kalıyor.

**Gövde boyutuna dokunulmadı.** Dart'ın 12px havasını Kotlin'e taşımak
(`* 86f / 98f`) tüm kademelerde alevi %12 küçültür ve K10'da yine 5 kıvılcımın
2'sine yer açardı — hem görsel regresyon hem yarım çözüm. Kotlin dosya başında
belgeli bir sadeleştirme, Dart'la piksel paritesi hedef değil.

### 5. Türkçe yerel ayarı Robolectric'i açılışta düşürüyordu

İlk koşum `UnsatisfiedLinkError: no conscrypt_openjdk_jni-wındows-x86_64`
verdi — noktasız `ı`. Robolectric açılışta conscrypt yüklüyor, conscrypt de
kütüphane adını **varsayılan yerel ayarla** küçültüyor; tr-TR'de
`"Windows".lowercase()` → `wındows` ve pakette o adda kitaplık yok. Test JVM'i
bu yüzden `-Duser.language=en -Duser.country=US` ile koşuyor
(`tasks.withType<Test>`). Uygulamanın diliyle ilgisi yok, yalnızca JNI ad
çözümlemesi.

### 6. Emülatör doğrulandı (2026-09-18)

`focussayac_verify` AVD'sinde (Android 16) cihaz testinin üç testi de geçti,
sıfır hata. On bitmap PNG olarak döküldü ve `.verify/m31_k1..k10.png` olarak
çekildi; kontak sayfası `.verify/m31_tum_kademeler.png`. Gözle: K1–K3 sade,
K4'ten köz tabanı, K6/K7'de 2 ve 3 kıvılcım, K8'den hâle, K8/K9/K10'da
3/4/5 kıvılcım — merdivenle birebir.

Dökümü çekmek iki tuzak barındırıyor, ikisi de teşhisi yanlış yöne çekiyor:

- **AGP koşum sonunda iki APK'yı da kaldırıyor**, uygulamaya özel dış dizin de
  onunla siliniyor. `-Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true`
  şart, yoksa test yeşil ama PNG yok.
- `/sdcard/Android/data/<pkg>` **root kabukta bile** görünmüyor (FUSE kapsam
  kısıtı); dosyalar `/data/media/0/Android/data/<pkg>/files/` altından
  çekiliyor. Ayrıca Git Bash `/data/...` argümanını Windows yoluna çeviriyor ve
  `adb pull` "No such file or directory" diyor — `MSYS_NO_PATHCONV=1` gerekli.

Kontak sayfasını üretirken `format=rgb24` alfayı **harmanlamıyor, atıyor**:
Android'in ARGB_8888 PNG'si premultiplied değil, saydam pikselin RGB'si duruyor
ve hâle dolu turuncu kare gibi görünüyor. Koyu zemine `overlay` ile harmanlamak
gerekiyor — ilk montaj bu yüzden okunamaz çıktı.

### 7. Kapsam dışı

Widget'ı ana ekrana adb ile yerleştirmek (hâlâ mümkün değil), diğer
renderer'lar (`RingRenderer`, `StripRenderer`, `SparkRenderer`), Dart ↔ Kotlin
piksel paritesi.

---

## Madde 32 — Meta satırı halkanın izine giriyordu

Tasarım belgesi yok: tek ekran, tek satır, iki sabit. Gerekçe burada.

### 1. Sabit doğru sayıyı ölçüyordu, yanlış yerden

`countdown_screen.dart` satırın kapağını `SizedBox(width: 284)` ile koyuyordu ve
yorum 284'ü "halkanın 9px'lik izinin içinde kalan genişlik" diye
gerekçelendiriyordu. 284 gerçekten de izin içinde kalan genişlik — **halkanın
yatay çapında**. Satır ise merkezin ~75px altında duruyor ve dairenin kirişi
orada çok daha dar. Kapak sığacağını söylüyor, sığdırmıyordu.

Bu yüzden hata "eksik kontrol" değil: kontrol vardı, `FittedBox` de vardı,
ikisi de yanlış sayıya bakıyordu. Kapak 284'ken üç parçalı satır (~181px) hiç
küçülmüyordu — çünkü kapağın altında kalıyordu — ve kirişi aşarak izin altına
giriyordu.

### 2. Neden yalnızca son düzlükte görünüyordu

Meta satırı normalde iki parça (`08:59:51 • 29 Eylül 2026`, ölçülen 148px),
son düzlükte üç (`11 GÜN • 08:59:49 • 29 Eyl`, 181px). İki parçalı hâl o
yükseklikteki kirişin altında kalıyor, üç parçalı hâl aşıyor. Hata madde 21'in
emülatör doğrulamasında, yani son düzlük ilk kez gerçek cihazda görüldüğünde
çıktı (`.verify/v28_metarow_zoom.png`).

### 3. Ölçü zaman izine değil, **en içteki dolu yaya** bağlı

İlk düzeltme kapağı zaman izinin iç kenarına (125.5) göre hesapladı: kiriş 198,
kapak 186. Emülatör görüntüsü piksel piksel ölçülünce bunun hâlâ yarım olduğu
görüldü — madde 27'nin emek yayı 119 yarıçapta, 4px kalınlıkta, yani **117'den**
başlıyor ve zaman izinden daha içeride. 186'lık kapağın köşesi (119.3) tam o
şeridin içine düşüyordu. Yeni sabit o yüzden
`CountdownRingPainter.innerContentRadius` = 117 ve kapak 176.

`timeTrackInnerRadius` diye ikinci bir sabit bırakılmadı: halkanın içine yazı
koyan herkesi ilgilendiren tek sayı en içteki **dolu** yayın iç kenarı. İki
sabit olsaydı çağıran yanlışını seçebilirdi — nitekim ilk denemede seçti.

112'lik kesik çizgili çember kasten hesaba katılmıyor: 1px, %35 saydam, dönen
bir dekor ve satırın uçları onu madde 32'den **önce** de teğet geçiyordu.
Metni ona sığdırmak kirişi 167'ye indirip satırı gerçekten küçültmek demekti.

### 4. Tarih son düzlükte kısalıyor

176'lık kapak tek başına satırı %3 küçültürdü; tam tarih üç parçalıya eklenince
(~240px) küçülme %27'ye çıkardı, yani 12px yazı 8.8px'e inerdi. O yüzden son
düzlükte tarih `d MMM` ("29 Eyl"), normalde `d MMMM y`.

Kaybolan bilgi yıl ve ayın son harfleri. Son düzlük en çok otuz gün
(`kFinalStretchDays`), o pencerede "29 Eyl"in hangi yıl olduğu sorusu yok;
yılbaşını aşan sınavda da ("28 Ara" → "15 Oca") okunan tarih tek bir güne
işaret ediyor. Tam tarih sınav ekranında ve paylaşım kartında duruyor.

Türkçe ay kısaltmalarının hepsi tam adın ön eki ("Haziran" → "Haz"), yani font
altkümesine yeni glif girmiyor — sessiz Roboto'ya düşme tuzağı burada yok.

### 5. Kalan %3 küçülme bilinçli

Üç parçalı satır 181px, kapak 176; `FittedBox` aradaki farkı kapatıyor
(12px → 11.6px). Kapağı 186'ya açmak küçülmeyi tamamen kaldırırdı ama kapağın
köşesini emek yayının şeridine sokardı — yani kapak yine sığacağını söyleyip
sığdırmayan bir sayı olurdu. Ölçülemez bir küçülme, ölçülebilir bir yalandan
iyi.

### 6. Test genişliği değil geometriyi ölçüyor

`flutter test` gerçek fontları yüklemiyor (`flutter_test_config.dart` yok), her
glif aynı kutu: bu koşumda üç parçalı satır 373px çıkıyor, cihazda 181px.
Metin genişliğine dayanan bir iddia bu yüzden hem yanlış hem kırılgan olurdu.

`countdown_meta_row_test.dart` onun yerine kapağın dört köşesinin merkeze
uzaklığını `CountdownRingPainter.innerContentRadius` ile karşılaştırıyor.
Satırın dikey ofseti gerçek yerleşimden geliyor — kahraman sayı ya da kicker
büyürse satır aşağı kayar, kiriş daralır, iddia düşer. Eski 284 ile test
kırmızı ("sol üst köşe 152.5px"), 176 ile yeşil.

İkinci iddia kapağın o yükseklikteki kirişin çoğunu kullandığını söylüyor,
yoksa "hiç kesişmiyor" kapağı 10px'e indirerek de sağlanabilirdi. Payı gevşek
(%80): `FittedBox` en boy oranını koruduğu için metni küçülttüğünde kutunun
yüksekliği de düşüyor, `Column` kısalıyor, ortalanmış satır yukarı kayıyor ve
kiriş genişliyor — küçültmenin miktarı yüklü fonta bağlı.

### 7. Emülatör doğrulandı (2026-09-18)

`focussayac_verify` (Android 16), `.verify/seed_final_stretch.py` ile
tohumlandı (sınav 11 gün ileri, o sınava 11.25 saat odak — son düzlük iki
koşulu birlikte istiyor, o yüzden mevcut iki tohumlama betiği yetmedi).
Görüntüler piksel piksel ölçüldü: halkanın merkezi emek yayının **dikey**
ekseninden bulundu (yatay eksende yay, zaman yayının altında renk değiştirdiği
için çember uydurması 12px kayıyor), ölçek 1080/390 = 2.769 ile doğrulandı.

- Son düzlük, koyu (`m32_b_son_duzluk.png`, yakın çekim
  `m32_c_metarow_zoom.png`): `11 GÜN • 08:59:49 • 29 Eyl`, satır 164px,
  alt köşe merkezden **110.5px**, metinle emek yayı arasındaki en kısa mesafe
  **5.9px**. Kesişme yok.
- Normal, koyu (`m32_a_normal.png`, `m32_d_normal_zoom.png`):
  `08:59:51 • 29 Eylül 2026`, 148px, alt köşe 105.2px — tam tarih duruyor,
  küçülme yok, madde 32 öncesiyle aynı.
- Son düzlük, açık tema (`m32_e_acik_tema.png`, `m32_f_acik_zoom.png`): aynı
  geometri, aynı boşluk.

### 8. Kapsam dışı

Satırı halkanın dışına almak (normal durumu da değiştirirdi, prototipin halka
içi kompozisyonunu bozardı), kesik çizgili 112'lik çemberi de temizlemek,
`RollingNumber`ın ya da kicker'ın ölçüsüne dokunmak.

---

## Madde 33 — Zaman yayının başlangıcındaki köz lekesi

Tasarım belgesi yok: iki dosya, bir sabit. Gerekçe burada.

### 1. Leke yayın değil, gradyanın sarma noktası

`StrokeCap.round` yayın başlangıç ucunu başlangıç açısının `strokeWidth / 2`
kadar **gerisine** taşıyor — 130 yarıçapta 4.5px, yani 2°. `SweepGradient` o
2°'yi 360°'nin sağından örnekliyor, orada da son durak var: `ember`. Sonuç,
mavi yayın tam başında turuncu bir yarım daire.

İki şey bunu "yayın kendi rengi" sanmaktan kurtarıyor: leke yayın oranıyla
kımıldamıyor (%6'da da %25'te de aynı yerde — oysa gradyanın kendi renkleri
oranla birlikte kayar), ve madde 27'nin emek yayının hiç çizilmediği karede
de duruyor (`.verify/m27_d_kapali.png`).

### 2. Seçilen yol: gradyanı yayın gerisine kaydırmak

`GradientRotation(-π/2)` → `GradientRotation(-π/2 - _gradientBackshift)`,
`_gradientBackshift = (9/2 + 2) / 130` radyan = 2.9°.

0. durak (`sky`) artık kapağın altındaki açıyı da kapsıyor. Asıl kazanç şu:
sarma noktası — gradyanın közden gökyüzüne bir pikselde atladığı yer —
**hiç çizilmeyen** bir açıya düşüyor. Kapak 12'nin 2° gerisinde bitiyor, sarma
2.9° geride; arada 0.9°, yani 130 yarıçapta 2px. Kenar yumuşatma bir pikselden
geniş olmadığı için o boşluk payın tamamı.

Bedeli gradyanın 2.9° (turun %0.8'i) kayması. Üç durak da yerinde, yayın
geometrisi bir piksel oynamıyor, uçların ikisi de yuvarlak.

### 3. Neden (a) değil

"Gradyanı yayın süpürdüğü açıya sığdır" seçeneği lekeyi kaldırırdı ama yayın
**anlamını** değiştirirdi: o zaman yay hangi oranda olursa olsun közle biter.
300 gün kalan kullanıcı halkanın ucunda aciliyet rengini görürdü. Gradyan
prototipte turun tamamına yayılı, tam da bunun için: köz yaklaşan sınavın
rengi, uzaktakinin değil.

### 4. Neden (b) değil

"Başlangıç ucunu `butt` yap" seçeneği geometriyi siliyor ama sarmayı silmiyor:
`butt` kenarı da 0°'de duruyor ve o kenarın yumuşatma pikselleri, merkezleri
geometrinin bir tık gerisinde kaldığı için gradyanı yine sarma bölgesinden
örnekliyor. Kalan şey 4.5px'lik yarım daire yerine 1px'lik sıcak bir çizgi
olurdu — küçülmüş bir hata, düzeltilmiş bir hata değil. Üstüne prototipin
`stroke-linecap="round"`unu bir uçta kaybederdik.

### 5. Kotlin portu da düzeltildi

`RingRenderer.kt` widget halkasını aynı üç durakla, aynı `-90°` ile ve aynı
`Cap.ROUND` ile çiziyor; dosyanın başlığı "Ilerleme yayinin gradyani
uygulamayla AYNI" diyor. Dart'ı düzeltip Kotlin'i bırakmak bu cümleyi yalan
yapardı — kullanıcı aynı halkayı ana ekranda lekesiz, launcher'da lekeli
görürdü. Aynı formül, aynı yorum, iki dilde.

### 6. Depodaki ilk piksel testi

`countdown_ring_start_test.dart` painter'ı `PictureRecorder`a çizip
`toByteData` ile okuyor. Gerekçesi: bu hata painter'ın **alanlarında** yok,
boyasında. `effort_arc_test.dart`ın kalıbı (painter'ı bulup oranlarını okumak)
onu göremezdi; gölgelendiricinin ne renk ürettiğini ancak piksel söyler.

İddia eşiği renk değil **fark**: 12'nin 20° gerisinden 2° ilerisine, izin iki
kenarı arasında taranan hiçbir pikselin kırmızısı mavisini 12'den fazla
aşmıyor. Köz iki temada da +197/+163, gökyüzü −156/−160, nötr iz 0 — tek eşik
iki temayı birden tutuyor ve altın görüntüye gerek kalmıyor. Düzeltmeden önce
dört durum da 163'ün üstünde kırmızı.

İkinci test iki ucun da yuvarlak kaldığını söylüyor, yoksa lekeyi ucu
düzleştirerek "çözmek" birinciyi yeşil bırakırdı.

`RingRendererRobolectricTest` aynı iddiayı Kotlin tarafında tutuyor.
`FlameRenderer`daki gibi `sharedTest` sözleşmesi ve cihaz koşumu yok: madde
31'in derdi çizim yolunun cihazda gerçekten koşup koşmadığıydı, buradaki dert
gölgelendiricinin renk matematiği — o da Robolectric'in NATIVE Skia'sında
cihazdakiyle aynı. Kanıtı da var: sabit `0f` ile çarpılınca test kırmızı.

### 7. Emülatör doğrulandı (2026-09-18)

Host testi Skia ile çiziyor, cihazdaki Flutter Impeller ile — yani bu maddede
emülatör turu gerçekten yeni bilgi veriyor.

`focussayac_verify` (Android 16). Sınav `.verify/seed_final_stretch.py` ile 300
gün ileri alındı: yay %25'e iniyor ve bitiş ucu 3 yönüne gidiyor, böylece
başlangıç ucu ölçüde yalnız kalıyor. (İlk kare son düzlükteydi, orada yayın
**bitişi** de 12'nin solundaydı ve ölçüm ikisini ayıramazdı.) Ölçen betik
`.verify/m33_probe.py`.

- Önce (`m33_a_once.png`, 6× `m33_c_once_zoom.png`): 12'deki yuvarlak ucun
  tamamı köz, tepedeki piksel `(163,93,0)` — açık temanın `ember`ı. Yakın
  çekimde kahverengi yarım daire ile mavi yayın sınırı keskin.
- Sonra (`m33_b_sonra.png`, `m33_d_sonra_zoom.png`): aynı piksel
  `(31,110,192)` = açık temanın `sky`ı, 12'nin solundaki 130px'de en sıcak
  piksel −160. Kapak aynı koordinatta başlıyor, yani yay yerinden oynamadı.
- Koyu tema (`m33_f_koyu.png`, `m33_g_koyu_zoom.png`): `(100,180,255)`,
  en sıcak −154.
- Halkanın tamamı (`m33_e_halka.png`): iki uç da yuvarlak, yay 12'den 3'e,
  gradyan mavi-mor bandında — %25'te közün görünmemesi (a) seçeneğinin neden
  elendiğinin resmi.

### 8. Kapsam dışı

Widget halkasını launcher'da yeniden çekmek (ekranda bağlı örnek yoktu;
RemoteViews bitmap'i cihazda da Robolectric'teki yığınla çiziliyor), zaman
yayının gradyan duraklarına ya da renklerine dokunmak, `session_ring_painter`
ile `badge_progress_ring_painter` (ikisi de tek düz renk, sarma noktaları yok).

---

## Madde 34 — Kademe atlama kutlaması

Tasarım belgesi yok: kutlama mekanizması madde 19'da kurulmuştu, bu üçüncü
türü ekliyor. Açık olan tek soru çakışma kuralıydı; kullanıcıya soruldu.

### 1. Sorun: kutlanmayan tek kazanım

Kazanım anları kutlanıyordu (rozet açılışı, seri eşiği) ama **kademe atlama**
kutlanmıyordu: alev K1'den K10'a çıkarken kullanıcı bunu ancak Ekran 04'e
kendi girerse görüyordu. Oysa kademe uygulamanın kalıcı kimlik ekseni — rozet
"ne başardım", kademe "ben kimim" diyor (`flame_avatar_card.dart`).

### 2. Üçüncü `SessionCelebration` türü

`FlameTierCelebration` eşiğin saatini değil **`FlameTier` nesnesinin kendisini**
taşıyor: dialog alevi çizeceği için `scale`/`emberBase`/`sparkCount`/
`haloOpacity` de gerekiyor, merdiven `const` olduğu için aynı kademe her zaman
aynı nesne.

Kutlamanın görseli **ödülün kendisi**: dairenin içinde `FlameWidget`, tam o
kademede. Seri kutlamasındaki gibi bir Phosphor ikonu koymak, kademenin tek
görünür karşılığını (alevin büyümesi) kutlamanın dışında bırakırdı. Alev
titremiyor — dialog süresiz açık kalabilir (SPEC.md §6.4, `FlameAvatarCard`
ile aynı gerekçe).

Kademe adı **büyük harfe çevrilmiyor**. Dart'ın `toUpperCase`i yerelden
bağımsız: "Şenlik Ateşi" → "ŞENLIK ATEŞI", noktasız İ bozuluyor. Üst satırın
("KADEME 4") büyük harfleri ARB'de yazılı.

### 3. Çakışma kuralı: rozet → kademe → seri

Bu bir kenar durumu değil **kural**: K4/K6/K7/K9 eşikleri 10/50/100/250
saatlik rozetlerle birebir aynı (`flame_tier.dart` bunu zaten söylüyor).
Dokuz kademe atlamasının dördü bir rozetle birlikte düşüyor.

Rozetin öne geçmesi seçildi (kullanıcı kararı): saat rozetleri **yalnızca** o
anda kutlanabilir, kademenin görünür ödülü ise kalıcı — alev o andan sonra her
ekranda büyümüş duruyor ve Ekran 04'ün kahraman kartı onu adıyla söylüyor.
Çakışan seansta rozet aynı kazanımı (kümülatif saati) zaten kutluyor, yani
kutlamasız kalan bir an yok.

Elenen iki yol: **kademe öne geçsin** (o zaman 10/50/100/250 rozetleri hiç
dialog açamaz — oysa onların başka bir anı yok), **ikisi arka arkaya açılsın**
(kutlama tek yuva; üst üste iki farklı dialog kutlamayı kesintiye çevirir).

### 4. Yutulan kutlama yine de işaretleniyor

`_consumeFlameTierCelebration` işareti kutlama **gösterilmeden önce** ve
gösterilip gösterilmeyeceğinden **bağımsız** ilerletiyor. Aksi hâlde rozetin
yuttuğu kademe bir sonraki seansta, artık atlanmamış bir kademe için bayat bir
dialog açardı. Seri eşiğindeki "gösterilmeden önce işaretle" kuralının aynısı:
kaçırılan bir kutlama, her seans sonunda tekrar eden bir kutlamadan iyi.

### 5. İşaretin varsayılanı 0 değil 1

`kCelebratedFlameTierPrefsKey` okunurken `?? 1`: K1 kullanıcının **başlangıç
hâli**, atlanan bir kademe değil. 0 olsaydı ilk tamamlanan pomodoro "Kıvılcım'a
yükseldin" derdi. Buna karşılık K1'in üstündeki (güncelleyerek gelen) bir
kullanıcının ilk seansında güncel kademesi bir kez kutlanıyor — geriye dönük
yedi dialog açılmıyor, en yüksek kademe bir kez kutlanıp geçiliyor
(`streakMilestoneToCelebrate`in kuralıyla aynı).

"Verileri sıfırla" işareti de siliyor (`AppDataResetService`): geçmişi silinen
kullanıcının alevi K1'e dönüyor, işaret kalsaydı merdiveni bir daha hiç
kutlayamazdı.

### 6. Kart şablonu zorlanmıyor

Seri kutlaması SERİ şablonunu öneriyordu çünkü o şablon vardı. Kartın üç
şablonundan (GECE MEŞALESİ / MİNİMAL / SERİ) hiçbiri kademeyi göstermiyor;
uydurma bir öneri yerine rozet kutlamasının kuralı uygulanıyor — kullanıcının
seçtiği kart açılıyor. Yeni bir "KADEME" şablonu bu maddenin kapsamı değil.

### 7. Testler (+5, toplam 451)

Üçü `pomodoro_controller_test.dart`'ta, gerçek DB ve gerçek rozet servisiyle:
kademe atlayan seans kutlamayı sunuyor ve ikinci seans sunmuyor; K1 hiç
kutlanmıyor; rozet kademeyi yutuyor ama işaret yine de ilerliyor. İkisi
`session_celebration_test.dart`'ta: dialog alevi doğru kademede çiziyor
(`FlameWidget.tier` kimlikle karşılaştırılıyor), düğme şablon zorlamadan kartı
açıyor.

Geçmiş yazan yardımcı (`_seedCompletedFocusHours`) **gün** aralıklı satır
yazıyor ve hepsi bugünün saatinde. İlk sürüm saat aralıklıydı ve gece yarısını
kesen koşumda satırların bir kısmı düne düşüyordu: Maraton (8/gün) rastgele bir
seansta açılıp kutlamayı çalıyordu. Gün başına bir satır + ardışık olmayan
günler, gün sayısına bakan rozetleri de seri eşiklerini de erişilemez kılıyor.

### 8. Emülatör doğrulaması (2026-09-18)

`focussayac_verify` (Android 16), release derlemesi, `focus_minutes = 1` ve
`.verify/m34_seed.py` ile kümülatif toplam eşiğin bir dakika altına çekilerek.
Tek satır tohumlanıyor: gün sayısına bakan rozetler tetiklenip yuvayı
kapmasın.

- **K2 kutlaması** (`m34_a_kademe_k2.png`): 3540 sn + 60 sn'lik seans = tam
  1 saat → "KADEME 2 / Köz", gövdede "1 saat odak biriktirdin". Dairenin
  içindeki alev K2 ölçeğinde (0.42) — küçük duruyor, merdivenin kendi oranı.
  `flutter.celebrated_flame_tier_v1 = 2`.
- **Kart** (`m34_b_kart.png`): düğme kartı kullanıcının kendi şablonuyla
  (GECE MEŞALESİ) açıyor, öneri yok.
- **Çakışma** (`m34_c_rozet_onde.png`, `m34_d_rozet2.png`): 10 saate çıkan
  seansta "Odak Meşalesi" ve "10 Saat Kulübü" dialogları açıldı, kademe
  dialogu **açılmadı** — ama işaret 2'den **4'e** ilerledi.
- **İkinci kez yok** (`m34_e_ikinci_kez_yok.png`): aynı kademedeki sonraki
  seans hiçbir dialog açmıyor.
- **Koyu tema, uzun ad, büyük alev** (`m34_f_koyu_k8.png`): K4'ten K8'e
  atlayan seans (175 saat) tek kutlama açıyor; "Harman Ateşi" tek satıra
  sığıyor, hâle ve kıvılcımlar dairenin içinde kalıyor. İşaret 8.
- **Kartla eşleşme** (`m34_g_ekran04.png`): Ekran 04'ün kahraman kartı aynı
  adı ve "175 / 250 sa"yı gösteriyor — kutlamanın "meşalen büyüdü" iddiası
  yüzeyde karşılığını buluyor.

### 9. Kapsam dışı

Kademe için yeni bir başarı kartı şablonu, kademe atlamasının bildirimi
(kutlama uygulama içi bir an; `SessionCelebrationQueue` bilinçli olarak kalıcı
değil), widget'ın kademe görselinin yeniden çekilmesi (madde 31'de
doğrulanmıştı, bu madde çizimi değiştirmiyor).

---

## Madde 35 — Isı haritasında ay gezinme + gün seçimi

Tasarım belgesi: `docs/superpowers/specs/2026-09-18-isi-haritasi-etkilesim-design.md`.
Madde 29 ızgarayı getirirken ay gezinmeyi, hücreye dokunmayı ve yıllık
pencereyi açıkça kapsam dışı bırakmıştı; bu madde ilk ikisini yapıyor.

### 1. Ay, hesaplayıcının parametresi

`calculateMonthlyHeatmap` `int monthOffset = 0` alıyor (0 bu ay, −1 geçen ay)
ve ayı yine uygulama gününden türetiyor:
`DateTime.utc(today.year, today.month + monthOffset, 1)`. `DateTime.utc` ay
taşmasını iki yönde de normalize ediyor — ocakta −1 geçen yılın aralığı.

Hazır bir `DateTime month` parametresi elendi: 04:00 TSİ gün sınırı (SPEC §5.3)
o zaman çağıranın sorusu olurdu. Offset ile ay tanımı tek yerde kalıyor.

Geçmiş ay ek bir sorgu da değil — `monthlyHeatmapProvider`
`Provider.family<MonthlyHeatmap, int>` oldu ama hâlâ `allSessionsProvider`ın
aynı listesinden başka bir pencere kesiyor.

### 2. `isCurrentMonth` sessiz bir hatayı kapatıyor

Karttaki `_todayIndex` "gelecek **olmayan** son gün" diyor. Geçmiş ayda hiçbir
gün gelecek değil, yani bu ayrım olmadan ızgara 31 Ağustos'a bugünün ember
çerçevesini çizerdi. Aynı bayrak ızgaranın nerede bittiğini de belirliyor:
"bugünün satırında bitir" yalnızca içinde bulunulan ayın kuralı, geçmiş ay
son satırına kadar çiziliyor.

### 3. `hasEarlier` takvime değil veriye bakıyor

Geri okun kapısı "bu aydan önce **tamamlanmış odak seansı** var mı" — ızgaranın
kendi ölçütünün (`completed && focus`) aynısı. Takvim ayına bakılsaydı
uygulamayı bu ay kuran kullanıcı boş aylarda kaybolurdu; mola/iptal sayılsaydı
ok açılır ama ızgara boş çıkardı. İleri ok `hasLater` ile bu ayda kapanıyor:
gelecek aya gezinme yok, yaşanmamış gün gösterilmiyor (madde 29 kararı).

### 4. Seçili ay ve seçili gün ekranın kısa ömürlü durumu

İkisini de Ekran 06'daki `_HeatmapSection` tutuyor, kart saf kalıyor
(`heatmap`, `selectedDay`, `onDayTap`, `onMonthStep`) — madde 29'un "kartı
Riverpod kurmadan çizebil" kalıbı bozulmadı. Kalıcı depoya yazılmadı: ikisi de
bir bakışın süresi kadar yaşıyor, iki gün sonra Ekran 06'yı açan kullanıcı
seçili bir gün değil bugünü görmeli. Ay değişince seçim sıfırlanıyor — başka
ayın gününü gösteren satır ızgarayla çelişirdi. Aynı hücreye ikinci dokunuş
seçimi kaldırıyor: açılan bir şey yok, kapatma düğmesi de olmasın.

### 5. Ay adı `MaterialLocalizations`tan, büyük harfe çevrilmeden

Madde 29 başlığı `BU AY` yapmıştı çünkü `DateFormat` ya 12 yeni ARB anahtarı
ya da karta `intl` + `initializeDateFormatting` demekti. Üçüncü yol:
`MaterialLocalizations.formatMonthYear` → "Ağustos 2026"; delegeler zaten
bağlı, yeni anahtar yok. Bu ayın başlığı yine `BU AY` — gezinmeden sonra
"buradayım" demenin en kısa yolu.

Ay adı **büyük harfe çevrilmiyor**: Dart'ın `toUpperCase()`i Unicode
varsayılanını uygular, `"Ekim"` → `"EKIM"`, `"Nisan"` → `"NISAN"` olur ve
Türkçe noktalı İ kaybolur. Kicker'ların büyük harfi ARB metinlerinden
geliyordu; bu metin kütüphaneden geliyor.

### 6. Detay satırı efsanenin solunda

Seçilen gün `18 Eyl • 7dk` olarak efsane satırının soluna yazılıyor
(`formatShortMonthDay` + `compactFocusDuration`), odak yoksa `10 Ağu • odak
yok` — sayı uydurulmuyor. Süre kısa hâlde çünkü satırı efsaneyle paylaşıyor;
kartın sağ üstündeki ay toplamı uzun hâlde kalıyor.

Tooltip elendi (dokunmatikte uzun basış ister, kenar sütunlarda taşar, ekran
görüntüsüyle doğrulanamaz), alt sayfa elendi (yeni ekran + ARB + testler;
maddenin sorusu "bu kutu kaç dakika", günün dökümü değil).

Seçili hücre `colors.text` çerçeve alıyor. Bugünün ember çerçevesiyle
çakışınca **seçim kazanıyor**: kullanıcının az önceki dokunuşu, hep orada
duran işaretten daha taze.

### 7. Erişilebilirlik: ızgara yine tek durak

Madde 29'un `excludeSemantics: true`'su kabın tamamındaydı ve oklar onun
altında kalınca ekran okuyucuya **hiç** görünmüyordu (test bunu yakaladı).
Kapsam daraltıldı: kabın etiketi duruyor, ızgara + efsane `ExcludeSemantics`
içinde, oklar kendi durakları (`statsHeatmapPreviousMonth` / `…NextMonth`).
Başlık ve ay toplamı da dışlandı — özet cümlesi aynı sayıyı zaten söylüyor.
Bir gün seçiliyken özet cümlesinin sonuna "Seçili gün 9 Eyl: 1 saat 40
dakika." ekleniyor; süre orada **uzun** hâlde, "45dk" harf harf okunurdu.

### 8. Testler (+19, toplam 470)

Hesaplayıcıda dokuz test: offset −1 penceresi ve yerleşimi, yıl sınırı
(ocak → geçen yılın aralığı), geçmiş ayda `isFuture` yok, `isCurrentMonth`,
`hasEarlier`in dört hâli (bu ayın seansı yetmiyor / eski seans açıyor /
mola-iptal açmıyor / geçmiş aya gidince ölçüt o ayın başı) ve 04:00 TSİ
sınırının `hasEarlier`da da geçerli olması.

Kartta dokuz test: geçmiş ayın başlığı ve ay sonuna kadar dolan ızgara,
hiçbir hücrede ember çerçeve olmaması, okların adım bildirmesi ve
sınırlarda susması, hücre dokunuşunun günü bildirmesi, detay satırının iki
hâli, seçim çerçevesinin rengi ve bugünü yenmesi.

Ekran testinde bir tam tur: geri ok geçen ayı açıyor, hücre `45dk` yazdırıyor,
ileri ok hem bu aya dönüyor hem seçimi bırakıyor.

Kartın başlık satırı test yazı tipinde taştı (her karakter tam genişlikte);
ay toplamı `Expanded` + `ellipsis` oldu. Gerçek fontta taşma yoktu ama dar
ekranda "12 saat 30 dakika" + ay adı + iki ok gerçekten sığmayabilir.

### 9. Emülatör doğrulaması (2026-09-18)

`focussayac_verify` (Android 16), release derlemesi, `.verify/m35_seed.py` ile
üç aya yayılmış 15 seans. **Tuzak:** `adb push` edilen DB uid 10000'e ait
kalıyor, uygulama 10220 olarak açamıyor ve açılış ekranında donuyor —
`chown 10220:10220` + `restorecon` gerekiyor.

- **Bu ay** (`m35_a_bu_ay.png`): `‹ BU AY ›`, toplam "3 saat 47 dakika",
  bugünün (18 Eyl) ember çerçevesi yerinde, ızgara bugünün satırında bitiyor.
- **Geçen ay** (`m35_b_gecen_ay.png`, `m35_c_gecen_ay_tam.png`): başlık
  "Ağustos 2026" — Türkçe ay adı, noktalı harfler yerinde. Toplam "9 saat 55
  dakika" tohumun toplamıyla birebir. Izgara 31 hücre, son satırda tek gün
  (31 Ağustos pazartesi) ve **hiçbir hücrede ember çerçeve yok**.
- **Gün seçimi** (`m35_d_secim.png`): 11 Ağustos beyaz çerçeve aldı, satır
  "11 Ağu • 2sa 30dk" (tohum 150 dk).
- **Odaksız gün** (`m35_e_odak_yok.png`): "10 Ağu • odak yok".
- **İkinci dokunuş** (`m35_f_secim_kalkti.png`): çerçeve ve satır kalktı.
- **Geri sınırı** (`m35_g_temmuz.png`, `m35_h_sinir.png`): temmuza inince
  (en eski veri) geri ok soluk ve ikinci dokunuş hiçbir şey yapmıyor.
- **Ay değişimi seçimi bırakıyor** (`m35_i_temmuz_secim.png` →
  `m35_j_ay_degisti.png`): temmuzda seçili gün, ileri okla ağustosa geçince
  yok.
- **İleri sınırı ve bugünün çakışması** (`m35_k_bu_aya_donus.png`,
  `m35_m_ileri_pasif.png`, `m35_n_bugun_secili.png`): bu ayda ileri ok pasif;
  bugüne dokununca ember çerçeve beyaza dönüyor ve satır "18 Eyl • 7dk"
  diyor — Ekran 02'nin "0sa 7dk"siyle aynı sayı.
- **Açık tema** (`m35_q_acik_tema.png`, `m35_r_acik_secim.png`,
  `m35_s_acik_gecen_ay.png`): rampa tersine dönüyor, seçim çerçevesi koyu
  (`text`) ve ember çerçeveden ayrılıyor, "14 Eyl • 2sa".

### 10. Kapsam dışı

Yıllık pencere, hücreye uzun basma, seçili günün ders kırılımı, gelecek aya
gezinme, ay geçişinin animasyonu, ızgara dışındaki kartların geçmiş aya
bakması (bar chart ve haftalık kapanış yine bugünün penceresi).

---

## Madde 36 — Ekran 02'de alt çubuğun payı reklam yuvasına bağlıydı

### 1. Kusur madde 29'da yazılmıştı, düzeltilmemişti

Madde 29 Ekran 06'da aynı kusuru düzeltirken notuna şunu yazmıştı: "Ekran 02'de
aynı gizli kusur duruyor — orada içerik henüz o kadar uzamıyor." Bu madde o
cümlenin kapanışı.

Mekanizma şu: alt gezinme çubuğu `Positioned(bottom: 18)` ile `Stack`te yüzüyor,
yani yerleşimde yer kaplamıyor. İçeriğin onun altına girmemesi için ekranların
altta pay bırakması gerekiyor. Ekran 02'de bu pay `BannerAdSlot`ın kendi
`bottomMargin`indeydi:

    BannerAdSlot(bottomMargin: 88)

`BannerAdSlot` reklam **hiç istenmediğinde** — `canRequestAds()` false, yani
premium ya da UMP onayı yok — `SizedBox.shrink()` döndürüyor. Bu bilinçli bir
karar (Faz 11: "asla dolmayacak bir boşluğu ayırmak reklamsız sürümün alanını
geri vermemek olurdu"), ama yuva kapanınca `bottomMargin` de onunla gidiyor.
Sonuç: kaydırılan gövdenin sonu çubuğun arkasında kalıyor.

### 2. Neden bugüne kadar görünmedi

Madde 24'e (haftalık hedef) kadar Ekran 02 sabit yerleşimdeydi ve alttaki artan
boşluk farkı yutuyordu. Madde 24 ekranı kaydırmaya geçirince gövde artık tam
olarak içerik kadar uzun; kaydırma menzili içeriğin sonunda bitiyor ve altta
ayrılmış bir pay yoksa son öğe çubuğun altında kalıyor, **kaydırarak da
kurtarılamıyor**.

Ölçülen fark **−82px**: ODAKLAN'ın alt kenarı çubuğun üst kenarının 82px
altında, yani 60px'lik butonun tamamı ve üstündeki boşluk çubuğun arkasında.
Bu ekranın birincil eylemi.

### 3. Düzeltme: pay yuvanın değil yerleşimin işi

Ekran 06'nın madde 29'da yaptığının aynısı — pay kardeş bir `SizedBox`a taşındı:

    const Padding(padding: ..., child: BannerAdSlot()),
    const SizedBox(height: kBottomNavReservedSpace),

Yuva kapansa da açık kalsa da pay duruyor. Reklam istendiğinde ayrılan alan
yuvanın yüksekliği kadar **artıyor**; bu yönde bir hata görünürde kayıp değil.

### 4. Üç kaynak tek kaynağa indi

Aynı kavramın kodda üç ayrı ölçüsü vardı: Ekran 02'de çıplak `88` literali,
Ekran 06'da private `StatsScreen._navBarFootprint = 88`, Ekran 04 ve 07'de
paylaşılan `kBottomNavReservedSpace = 96`. Üçü de "çubuğun altta kapladığı yer"i
anlatıyor.

Ekran 02 ve 06 ortak sabite bağlandı. 88 → 96 sekiz piksel daha açıyor: çubuk
64px yükseklik + 18px alt konum = 82px, yani 88 altı piksel, 96 on dört piksel
nefes payı bırakıyor. Ekran 02 zaten kaydırmalı olduğu için sekiz piksel taşma
riski yaratmıyor; ikisini farklı bırakmak ise madde 36'nın kendisinin yeni bir
tutarsızlık üretmesi olurdu.

### 5. Test: geometriyi ölç, ama boşa koşmasın

`test/features/countdown/nav_bar_footprint_test.dart` 390x640'ta, reklam
istenmeyen hâlde (`AdService.disabled()`), kaydırmayı sonuna götürüp ODAKLAN'ın
altı ile çubuğun üstü arasındaki farkı ölçüyor.

İki koruma iddianın kendisinden önce geliyor:

- **`maxScrollExtent > 0`.** İçerik sığsaydı kaydırma hiç devreye girmez, CTA
  zaten çubuğun çok üstünde kalır ve test kusuru göremeden yeşil yanardı. Bu
  iddia testin gerçekten bir şey ölçtüğünü garanti ediyor. Ekranın uzun
  olduğu hâllerde (emülatörün 411x914dp'si) kusur gerçekten yok — testin kısa
  bir gövde seçmesinin sebebi bu.
- **`SingleChildScrollView` bulundu.** Gövde yerine yükleniyor hâli kalmışsa
  (drift tuzağı, aşağıda) iddialar boşa koşardı.

### 6. Karşı kontrol geometriyle değil mekanizmayla

Reklamın **istendiği** hâl ayrı bir `pumpWidget` istiyor ve orada deponun
belgelediği drift tuzağı devreye giriyor: aynı dosyada ikinci bir `testWidgets`
— hatta aynı testte ikinci bir `pumpWidget` — göçü yarıda bırakıyor, ekran
`CircularProgressIndicator`da donuyor ve koşum 10 dakikada zaman aşımına
düşüyor. Bu dosyanın ilk iki hâli sırayla tam olarak buna düştü.

Karşı kontrol bu yüzden kusurun **mekanizmasını** pinliyor:

    expect(tester.widget<BannerAdSlot>(...).bottomMargin, 0);

Pay yuvaya geri bağlanırsa reklam kapalıyken yine yok olur — test o anda düşer.
Reklamlı hâlde ayrılan alan yalnızca arttığı için, geometrik iddiayı geçen
yerleşim orada da geçiyor; ayrıca `banner_placement_test` yuvanın adaptive
yüksekliği ayırdığını zaten ölçüyor.

### 7. `banner_placement_test` eski mekanizmayı pinliyordu

"Ekran 02 banner istiyor" testi yuvanın yüksekliğini `_adaptiveSize.height + 88`
bekliyordu — yani payın yuvaya ait olduğunu bir iddia olarak tutuyordu. Pay
yerleşime taşınınca beklenti `_adaptiveSize.height` oldu. Bu bir testi "düzeltip
geçirmek" değil: iddia yer değiştirdi, payın gerçekten ayrıldığını artık yeni
test ölçüyor ve ikisi birlikte eski toplam garantiyi koruyor.

### 8. Emülatör doğrulaması — "önce" görüntüsü bedava geldi

`focussayac_verify` (Android 16), release. Madde 35'in doğrulamasından kalan
kurulu APK düzeltme **öncesi** hâl olduğu için kusurun görüntüsü yeniden
derlemeden alındı.

Koşulun iki ayağı var:

- **Yuva kapalı olmalı.** `.verify/m36_seed.py` `is_premium = 1` yazıyor;
  premium `canRequestAds()`i UMP'ye hiç sormadan kısa devre ettiriyor. UMP dalı
  ağ/onay durumuna bağlı olduğu için adb'den pinlenemezdi.
- **İçerik taşmalı.** Emülatörün varsayılan ekranı 411x914dp — orada içerik
  `font_scale 1.5` ile bile sığıyor ve kusur yok (`m36_a_kusur_ust.png` bunu
  gösteriyor). Gerçek bir küçük telefon sınıfı emüle edildi: `wm size 720x1440`
  + `wm density 320` → 360x720dp, `font_scale 1.3`. Uygulama yazı ölçeğini
  kırpmıyor (`textScaler`/`textScaleFactor` araması `lib/`de boş), yani bu
  uydurma değil yaşanabilir bir yapılandırma.

Sonuç: kaydırmanın sonunda "1 DAKİKA ODAKLAN" çubuğun arkasında, yalnızca
kenarlığı üstten sızıyor (`m36_b_kusur.png`). Düzeltilmiş APK birebir aynı
koşullarda CTA'yı tam görünür bırakıyor (`m36_c_duzeltme.png`); koyu temada
aynısı (`m36_f_koyu.png`).

### 9. Cihazda kapatılamayan dal: reklam açık

`is_premium = 0` ile koşulduğunda UMP onay formunun WebView'ü açılıyor ve
emülatörde ağ yok (`ping 8.8.8.8` %100 kayıp, logcat'te
`res_stats_usable_server: too many resolution errors`). Uygulama açılış
ekranında %82 CPU ile asılı kalıyor ve systemui ANR'ye düşüyor. Bu ortam
kısıtı — kodla ilgisi yok ve bu maddenin değiştirdiği hiçbir şeye dokunmuyor.
O dal test tarafında kapalı (§6, §7).

### 10. Kapsam dışı

`kBottomNavReservedSpace`in 96 değerinin çubuğun gerçek 82px'ine göre yeniden
ölçülmesi, Ekran 02'nin uzun ekranlarda `Spacer`sız üst hizalı duruşu,
banner'ın kaydırma alanının dışında kalması kuralı, Ekran 06'nın aynı
düzeltmesinin geriye dönük regresyon testi (madde 29'da yazılmamıştı; yeni test
yalnızca Ekran 02'yi ölçüyor).

---

## Madde 37 — Yıllık ısı haritası penceresi

Tasarım: `docs/superpowers/specs/2026-09-19-yillik-isi-haritasi-design.md`.

### 1. Neden ikinci bir pencere

Madde 29 aylık ızgarayı getirdi, madde 35 onu gezilebilir yaptı. İkisi birlikte
"bu ay hangi günler çalıştım" ve "geçen ay nasıldı"yı cevaplıyor. Cevaplanmayan
soru **ölçek**: ritim aylar boyunca nasıl gidiyor, sınav yaklaşırken yoğunlaştı
mı, yazın nerede koptu. Ayı ay ay gezerek bu görülmüyor — on iki ayrı bakış
tek bir şekil etmiyor.

Veri zaten bellekte. `allSessionsProvider` tüm kayıtları tutuyor, yani ikinci
pencere **yeni sorgu değil**, aynı listeden başka bir kesit — madde 35'in
`monthOffset` kalıbının aynısı.

### 2. Takvim yılı değil, yuvarlanan 52 hafta

52 sütun × 7 satır = 364 gün. Son sütun bugünün içinde bulunduğu hafta
(Pzt–Paz), ilk sütun ondan 51 hafta öncesi.

Takvim yılı (`2026`) elendi: ocakta pencere neredeyse boş olurdu ve yılın ilk
haftalarında ritim diye gösterilecek bir şey kalmazdı. Yuvarlanan pencere her
gün aynı miktarda geçmişi gösteriyor.

Gün sınırı `appDayKey` — 04:00 TSİ (SPEC §5.3), aylık hesaplayıcıyla **aynı
fonksiyon**. İkinci bir gün tanımı açılmadı. Gelecek günler (bu haftanın
kalanı) çizilmiyor: madde 29'un kuralı aynen, yaşanmamış günü boş kutu olarak
göstermek onu kaçırılmış gün gibi okuturdu.

Kullanıcının uygulamayı kurmasından önceki günler seviye 0 olarak çiziliyor,
pencereden kırpılmıyor — geçmiş bir aya bakmakla aynı davranış.

### 3. Eşikler: ROADMAP'in sorusu, yerleşimin cevabı

ROADMAP "madde 29'un mutlak seviye eşikleri (1/25/50/90 dk) yıllık ölçekte
yeniden düşünülmeli" diyordu. Düşünüldü: **aynı kalıyor**, ve bu artık bir
tercih değil, yerleşim kararının sonucu.

Şerit aylık ızgarayla aynı kartta duruyor ve kartın altındaki tek efsane
(`az ▫▪▪▪ çok`) ikisine birden hizmet ediyor. Tek efsane → tek rampa → tek eşik
takımı. İkinci bir takım aynı günü iki ızgarada iki farklı tonda gösterirdi ve
efsane hangisini anlattığını söyleyemezdi.

Madde 29'un "ayın en yoğun gününe ölçekleme" gerekçesi yıllık ölçekte daha da
güçlü: yılın tek 8 saatlik gününe göre ölçeklenen bir harita, 90 dakikalık
normal günlerin hepsini soluk gösterirdi. Eşikler dakikada sabit olduğu için
üstteki ayın koyu kutusu ile alttaki şeridin koyu kutusu aynı şeyi söylüyor.

`heatmapLevel` ve `kHeatmapLevelThresholds` paylaşıldı, kopyalanmadı.

### 4. Sığdırılmış şerit — etkileşim yok, bugün işareti yok

360dp ekranda kullanılabilir genişlik 268dp (360 − 2×26 ekran payı − 2×20 kart
payı). 52 sütun ve 1dp boşlukla hücre 4.17dp hesaplanıp **8px'e yuvarlanıyor**;
emülatörde ölçülen 4.0dp.

Bu boyut dokunma hedefi olarak imkânsız, o yüzden şerit `DecoratedBox`'tan
ibaret — jest ağacı hiç kurulmuyor. Bedel kayıp değil: "bu kutu kaç dakika"
sorusunu madde 35 zaten üstteki ızgarada cevapladı.

**Bugünün ember çerçevesi yok.** Gelecek günler çizilmediği için son çizilen
hücre zaten bugün; 4.2dp hücrede 1.5px çerçeve hücrenin üçte biri olurdu.

Elenen iki düzen:

- **Yatay kaydırmalı GitHub şeridi** — hücreyi 10dp'de tutar ve gün seçimini
  yıllık görünüme taşırdı, ama Ekran 06'nın gövdesi zaten dikey kaydırılıyor;
  içine yatay kaydırılan bir şerit koymak iki jesti birbirine düşürürdü.
- **12 mini ay ızgarası** — kartı ~500dp uzatıyor ve on iki takvim düzeni tek
  bir şekil olarak okunmuyor.

Başlıkta `AY / YIL` segmenti de elendi: yeni bir ekran durumu, yeni bir kontrol
ve "yıl görünümündeyken oklar ne yapar" sorusu getirirdi. Sabit şerit hiç
hareketli parça eklemiyor.

### 5. Ay adı etiketi yok

`MaterialLocalizations` kısa ay adı vermiyor (`formatMonthYear` var,
`formatShortMonth` yok). `DateFormat` ise madde 29 ve 35'in bilerek reddettiği
şey — 12 yeni ARB anahtarı ya da karta `intl` + `initializeDateFormatting`
bağımlılığı. Zaman çapası şeridin kendi geometrisi: sağ ucu her zaman "şimdi",
eni her zaman 52 hafta.

### 6. Paylaşılan ölçek kendi dosyasına çıktı

`HeatmapDay`, `heatmapLevel`, `kHeatmapLevels` ve `kHeatmapLevelThresholds`
`monthly_heatmap.dart`tan `heatmap_scale.dart`a taşındı. Alternatif, yıllık
hesaplayıcının aylıktan import etmesiydi — iki pencere arasında olmayan bir
bağımlılık uydururdu.

`monthly_heatmap.dart` bir `export 'heatmap_scale.dart';` satırı ekledi, böylece
mevcut beş import edenin (kart, ekran, sağlayıcılar, iki test) hiçbiri
değişmedi.

Ad `RollingYearHeatmap` — takvim yılı olmadığını adın kendisi söylüyor.
Sağlayıcı `Provider`, aile değil: pencere sabit, anahtarlanacak bir şey yok.
Kart parametresi `required`, opsiyonel değil: üretimde her zaman verilecek bir
alanın null hâli yalnızca testlerin yaşadığı bir kod yolu olurdu.

### 7. Erişilebilirlik ve bir yan bulgu

Şerit kartın mevcut `ExcludeSemantics` bölgesinde kaldı — madde 29 ızgarayı tek
durak yapmıştı, 364 hücre onu 394 durağa çıkarırdı. Kabın özet cümlesi üç
parçaya çıktı, görsel sırayla: ızgaranın özeti, şeridin özeti, seçili gün.

**Yan bulgu (düzeltilmedi):** ızgaranın özet cümlesi geçmiş ayda da "Bu ay …"
diyor (`statsHeatmapSemantics`). Madde 35'ten kalan bir ifade kusuru; ekran
okuyucu kullanıcısı ağustosa gidince "Bu ay 31 günün…" duyuyor. Madde 37'nin
kapsamı dışında bırakıldı — yeni ARB anahtarı ve geçmiş ay için ayrı bir cümle
gerektiriyor. ROADMAP madde 40'a yazıldı.

### 8. Emülatör doğrulaması (2026-09-19)

`focussayac_verify` (Android 16), release APK. `.verify/m37_seed.py` 52 haftanın
tamamını tohumluyor; desen iddiaların her birini görünür kılacak şekilde
seçildi.

- **Pencere sınırları:** uygulama 22 Eyl 2025 (Pzt) – 20 Eyl 2026 (Paz) penceresi
  çizdi — birim testinin hesabıyla birebir aynı.
- **Satır sırası Pzt..Paz:** piksel profili 6. satırı tekdüze seviye 1 (her
  cumartesi 20 dk) ve 7. satırı tekdüze `fillSubtle` (her pazar boş) gösterdi.
  Tohumlanan desenin aynısı.
- **Son çizilen hücre bugün:** bugün cumartesiydi; son sütunda pazar satırı
  **yok**, diğer 51 sütunda var (`m37_g_sag_uc.png`).
- **Sol kenar:** pencerenin ilk gününe konan 95 dk en koyu tonda çizildi, bir
  gün öncesine konan 240 dk hiç görünmedi ve toplama girmedi
  (`m37_h_sol_uc.png`).
- **Pencere ay gezinirken sabit:** ızgara Haziran 2026'ya götürüldüğünde ay
  toplamı 37 sa 15 dk oldu, şeridin toplamı 334 sa 9 dk olarak kaldı
  (`m37_k_gecen_ay_serit.png`).
- **Küçük telefon sınıfı:** `wm size 720x1440` + `wm density 320` → 360×720dp.
  Şerit okunur kaldı, ölçülen hücre 4.0dp (`m37_m_kucuk_serit.png`).
- **Koyu tema** aynı ekranda doğrulandı (`m37_p_koyu.png`).

**Yolda çıkan tuzak — `adb push` SELinux kategorisini bozuyor.** Tohumlanan DB
uygulamanın dizinine push edilince uygulama açılışta
`SqliteException(14): unable to open database file` ile splash'ta asılı kaldı.
Sebep MLS kategorisi: dizin `…:c220,c256,c512,c768`, push edilen dosya
`…:c216,…`. `restorecon` kategoriyi düzeltmiyor; dizinin bağlamını birebir
uygulamak gerekiyor:

    adb shell chcon u:object_r:app_data_file:s0:c220,c256,c512,c768 <db>

**Cihazda doğrulanamayan hâl:** reklamın açık olduğu dal (madde 36'nın notu —
emülatörde ağ yok, UMP onay formunun WebView'ü asılı kalıyor). Şerit reklam
yuvasından bağımsız olduğu için bu dal şeridi etkilemiyor.

### 9. Kapsam dışı

Yıl gezinme (geriye bir 52 hafta daha), şeritte gün seçimi, ay sınırı etiketleri
ya da çentikleri, tam genişliğe taşan şerit (hücreyi 4.9dp'ye çıkarırdı ama iki
ızgaranın hizasını bozardı), şeridin aylık ızgarada açık olan ayı vurgulaması,
şeridin giriş animasyonu, diğer kartların yıllık pencereye bakması.

---

## Madde 38 — Yayın engelleyicileri: mağaza görselleri

Maddenin üç ayağı vardı (imzalama anahtarı, AdMob kimlikleri, mağaza
görselleri) ve üçü de **dış kaynak** bekliyordu. Bu turda yalnızca üçüncüsü
kapandı; ilk ikisi bilinçli olarak açık bırakıldı (§4).

### 1. Ekran görüntüleri: 9:20 değil, zorlanmış 9:16

Play'in kabul ettiği en büyük en-boy oranı 2:1. Emülatörün kendi çözünürlüğü
1080×2400, yani 9:20 — olduğu gibi çekilen bir ekran görüntüsü Console'a
yüklenemiyor. Çekim öncesi `wm size 1080x1920` ile tam 9:16'ya zorlanıyor.

Alternatif, 9:20 çekip alt/üstten kırpmaktı; elendi, çünkü kırpma yerleşimi
yalan söyler: uygulamanın gerçekte o cihazda nereye ne koyduğunu değil, bizim
neyi kestiğimizi gösterirdi. Boyutu önceden zorlamak uygulamanın kendi düzen
kararlarını 9:16'da almasını sağlıyor.

Durum çubuğu SystemUI'nin demo kipinde (`9:41`, dolu pil, bildirim yok).
Uygulamanın çizdiği bir şey değil; tek amacı beş karede tutarlı bir üst şerit.

Beş kare ASO §5'in beş altyazısıyla **birebir aynı sırada**: `01` geri sayım,
`02` odak seansı, `03` rozetler, `04` istatistik, `05` başarı kartı. Altyazılar
Console'a ASO §5'ten giriliyor; görsellerin üstünde metin yok — gömülü metin
yerelleştirilemez ve her metin değişikliğinde beş PNG yeniden üretilirdi.

### 2. Feature graphic: telefonun içi taklit değil

`tool/generate_feature_graphic.py` kompozisyonu ASO §6'dan alıyor (koyu lacivert
zemin, mor ışıma, solda dev gün sayısı, ortada telefon, sağ altta ad).

Telefon çerçevesinin içine elle çizilmiş bir taklit değil, **`02_odak.png`'nin
kendisi** yerleştiriliyor. Taklit zamanla uygulamadan ayrışırdı; aynı dosyayı
kullanmak banner ile mağaza görüntüsünü tek kaynağa bağlıyor.

Banner'daki `132` rakamı ASO §6'nın örnek rakamı ve uygulamanın o anki geri
sayımına **bilerek bağlanmadı**: banner statik, sayaç her gün değişiyor. Bu
rakam prototipin demo sayılarından biri, ama DoD'nin yasağı kodda demo sayısı
bulunmamasıyla ilgili — pazarlama görselinin örnek rakamı o kuralın konusu
değil.

Yazı tipleri uygulamanın kendi dosyalarından geliyor ve subset edilmiş
olabilir. Eksik glifte PIL sessizce boş kutu çiziyor (madde 10'un font tuzağı),
o yüzden her dizge çizilmeden önce `cmap`e karşı doğrulanıyor.

### 3. Emülatörde çıkan gerçek hata: simge temayla renk değiştiriyordu

Mağaza simgesi ile cihazdaki simge aynı görsel olmak zorunda. Emülatörde
karşılaştırıldığında **olmadıkları** görüldü: Play'e gidecek 512×512 koyu
zeminli, cihazdaki simge krem zeminliydi.

Sebep `ic_launcher_background.xml`in zemini `@color/focus_bg`e bağlamasıydı. O
token niteleyiciye göre çözülüyor (`values/` açık `#F4F5FA`, `values-night/`
koyu `#0B0C14`) ve launcher simgeyi **sistem** temasıyla çözüyor — uygulama
içindeki tema seçimiyle değil. Yani simge, kullanıcının sistemi açık moddaysa
krem zeminle çiziliyordu.

Hata sessizdi: kaynak derleniyor, uygulama açılıyor, hiçbir test düşmüyor.
Yalnızca açık modda bir cihaza bakınca görülüyor — ve proje boyunca hep koyu
temada bakılmıştı.

Zemin artık düz hex (`#FF0B0C14`), yani temadan bağımsız. `focus_colors.xml`e
yeni bir token eklenmedi: o dosyanın anahtar kümesini `focus_palette_sync_test`
Dart paletine karşı birebir kilitliyor, eklenen her ad iki XML'de birden
karşılık ister. Simgenin zemini bir palet tokeni değil, tek bir sabit.

Yerine `test/android/launcher_icon_background_test.dart` kondu; üç kaynağı
birbirine bağlıyor: adaptive zemin, `tool/generate_app_icon.py`nin `BG` sabiti
(Play 512 ve API 26 öncesi mipmap'ler oradan rasterize ediliyor) ve
`AppColors.dark().bg`. Test ayrıca zeminin niteleyiciye göre çözülen bir tokene
**yeniden** bağlanmasını yasaklıyor — asıl hata buydu.

Splash ve ana ekran widget'ları `focus_bg`i kullanmaya devam ediyor; orada
sistem temasını izlemek doğru davranış (bkz. `values/focus_colors.xml` başlığı).
Değişen yalnızca launcher simgesi.

### 4. Açık bırakılanlar ve nedenleri

- **İmzalama anahtarı.** Üretilmedi. Anahtar kaybolursa uygulama
  güncellenemiyor; parola ve saklama kararı kullanıcının. Gradle tarafı hazır,
  `android/key.properties` görüldüğü anda devreye giriyor. AAB şu an hâlâ
  `CN=Android Debug` ile imzalı.
- **AdMob kimlikleri.** Google'ın resmî test kimlikleri kullanılmaya devam
  ediyor; gerçek kimlikler bir AdMob hesabı gerektiriyor. Kod değişikliği
  gerekmiyor, `--dart-define` tablosu `docs/play/RELEASE.md` §3'te.

### 5. Emülatör doğrulaması (2026-09-19)

`focussayac_verify` (Android 16), release APK.

- Simge düzeltmesi öncesi/sonrası Ayarlar'ın uygulama sayfasından ölçüldü.
  Zeminin ortalama RGB'si: önce `(225, 226, 231)` (krem), sonra `(57, 58, 65)`.
- Sistem **açık** moddayken (`cmd uimode night no`) ve **koyu** moddayken
  alınan iki kare aynı değeri verdi — simge artık temayla değişmiyor.
- Beş mağaza görüntüsü 1080×1920, feature graphic 1024×500, simge 512×512
  olarak doğrulandı.

### 6. Kapsam dışı

Tablet ve 7"/10" ekran görüntüleri (Play zorunlu tutmuyor, telefon seti
yeterli), tanıtım videosu, mağaza görsellerinin İngilizce sürümü, gerçek ARM
cihazda yeniden çekim (ASO §5'in çekim listesi cihazda da geçerli), Console'a
yükleme (elle).

---

## Madde 39 — Ring / Strip / Spark doğrulaması

Tasarım: `docs/superpowers/specs/2026-09-19-kotlin-renderer-dogrulama-design.md`

### 1. Kalıp madde 31'den kopyalandı, Gradle'a dokunulmadı

Üç renderer da yalnızca gerçek bir widget yerleştirildiğinde çalışıyor, o da
adb ile sürülemiyor — madde 31'in çıkarımı burada da geçerli: boşluk ekran
görüntüsüyle değil **testle** kapanıyor. İddialar `src/sharedTest` altında üç
sözleşme dosyasında, koşucular ince; `build.gradle.kts` bu dizini iki kaynak
kümesine zaten ekliyordu, yeni ayar gerekmedi.

Madde 33'ün iki iddiası (`yayin baslangicinda koz lekesi yok`,
`iki uc da yuvarlak kaliyor`) `RingRendererRobolectricTest`ten
`RingRendererContract`a taşındı. Orada sözleşmesiz ve cihazsız duruyorlardı;
gradyanın nerede örneklendiği gerçek grafik yığınında da sınanmalı.

### 2. Sondalar iki eksende, ikisi de temadan bağımsız

**Alfa:** iz `0x12`, kesikli çember `0x59`, çizilen yaylar/dolgular opak —
`0x80` eşiği "çizildi mi" sorusunu tek başına yanıtlıyor.
**Sıcaklık** (kırmızı − mavi): halkanın gradyanı `RingRenderer`da düz hex, köz
ise iki niteleyicide de sıcak (`#FFA35D00` / `#FFFFB03A`). Robolectric
varsayılan olarak **açık** temada koşuyor, emülatör koyuda — iddialar ikisinde
de aynı sayıyı veriyor, çünkü hiçbiri palet renginin kendisine bakmıyor.

Ölçüler sağlayıcıların `dp` sabitlerinden: halka 273², şerit 630×15, sütun
grafiği **iki** yerleşimde (seri 220×68, panorama 367×57). İkincisi önemliydi —
hata tam oradan çıktı.

### 3. Bulunan hata: sütun grafiğinin tabanı yatay eksenden geliyordu

`minHeight = radius * 2f` ve `radius = barWidth * 0.26f`, yani boş günün
bıraktığı taban **sütun genişliğine** bağlıydı. Panoramada sütunlar geniş, kare
alçak: taban grafiğin **%32'si**. Sonuç, 120 dakikalık bir haftada 20 dakika
odaklanılmış gün ile hiç odaklanılmamış günün **aynı** çizilmesi. Seri
yerleşiminde %16.

Bu, madde 31'in kıvılcım hatasıyla aynı sınıftan: kod derleniyor, açılıyor,
hiçbir test düşmüyor ve grafik sessizce yanlış şey söylüyor.

Düzeltme payı dikey eksene taşıyor — `minHeight = heightPx * 0.06f`. Taban
duruyor (boş hafta "veri yok" değil "sıfır" okunmalı, dosyanın kendi sözü) ama
artık bir günün odağı gibi görünmüyor. `radius`a dokunulmadı: onun küçük
tutulma gerekçesi ayrı ve dosyada belgeli.

### 4. Bulunan hata: halkanın kicker'ı izin üstünden geçiyordu

Kicker'ın puntosu sabitti (`sizePx * 0.058f`). "GÜN KALDI" (9) ve "BUGÜN" (5)
sığıyor; **"HEDEF SEÇİLMEDİ"** 238 px çiziliyor, o satırda izin iç kenarına
kadar kalan kiriş 183 px. Yazı halkanın stroke'unun üzerinden geçiyordu ve bu,
sınav seçmemiş kullanıcının — yani yeni kullanıcının — gördüğü tek hâl.
"SINAVIN GEÇTİ" de aynı şekilde taşıyordu.

Düzeltme `counterSizeFor`un rakama yaptığını kicker'a yapıyor: punto ölçülüp
kirişe sığacak kadar küçülüyor (`labelFitFor`, pay `LABEL_FIT = 0.94`). Kiriş
etiketin **tabanında** ölçülüyor, çünkü kicker merkezin altında ve en dar yeri
alt kenarı. Ölçü karakter sayısından değil `measureText`ten geliyor —
`counterSizeFor`un uzunluk tablosu bir çeviri uzadığında sessizce yanılırdı.

Sığan etiketler hiç küçülmüyor: yaygın durumda görünür değişiklik yok.

### 5. Emülatör doğrulandı (2026-09-19)

`focussayac_verify` (Android 16). `connectedDebugAndroidTest`: **20 test, sıfır
hata** (madde 31'in 3'ü + bu maddenin 17'si). Çıktılar PNG olarak döküldü ve
`.verify/m39_*.png` olarak çekildi; kontak sayfaları `m39_halka_tablosu.png`,
`m39_serit_tablosu.png`, `m39_sutun_tablosu.png`.

Gözle: halka merdiveni %10→%100 düzgün büyüyor, yayın başı her basamakta mavi
(köz lekesi yok), `muted` karesinde yay hiç yok, günlük yay kesikli çemberin
üstünde yeşil duruyor. Şerit merdiveninde %0 karesi bir kapak, gradyan soldan
sağa ısınıyor. Sütun grafiğinde artan hafta artık gerçek bir merdiven, boş
hafta ince bir taban çizgisi.

Madde 31'in iki tuzağı yine geçerliydi:
`-Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true` olmadan PNG
kalmıyor, ve dosyalar `/sdcard/...` yerine
`/data/media/0/Android/data/<pkg>/files/` altından, `MSYS_NO_PATHCONV=1` ile
çekiliyor.

### 6. Kapsam dışı

- Widget'ı ana ekrana adb ile yerleştirmek (hâlâ mümkün değil).
- Dart ↔ Kotlin piksel paritesi.
- `StripRenderer`ın `muted` davranışı: sınav seçilmemişken oran 0 gidiyor ve
  şerit boş iz yerine bir kapakla duruyor; halka o durumda yayı hiç çizmiyor.
  İkisi tam aynı dili konuşmuyor ama kapak grafiğin %2.4'ü ve "yüzde sıfır"
  okuması da doğru. Sözleşme davranışı sabitliyor, karar ayrı bir maddeye
  bırakıldı.
- Sağlayıcıların `RemoteViews` tarafı (metin, tıklama hedefi, yenileme).

---

## Madde 40 — Izgaranın özet cümlesindeki ay

### 1. Kusur: başlık ayı biliyordu, cümle bilmiyordu

Madde 35 ay gezinmeyi getirip kartın **başlığını** geçmiş ayda ay adına
çevirmişti (`BU AY` → `Ağustos 2026`), ama ekran okuyucunun duyduğu cümle
sabit kalmıştı: "**Bu ay** 31 günün 24 gününde odaklandın…". Gören kullanıcı
ağustosa baktığını başlıktan biliyor; ekran okuyucu kullanıcısı yalnızca bu
cümleden biliyor — üstelik gezinme okları onun da kullanabildiği iki durak
(madde 35 bunları bilerek durak yapmıştı), yani **kendi gittiği aya** yanlış
isim duyuyordu.

Boş ay dalı (`statsHeatmapEmptySemantics`) aynı kusuru taşıyordu.

### 2. Ay adı cümleye ekle değil iki noktayla bağlanıyor

Türkçenin doğal hâli "Ağustos 2026'da 31 günün…" olurdu ama bulunma eki
yıla göre değişiyor: `2026'da`, `2027'de`, `2023'te`. Ay adı
`MaterialLocalizations.formatMonthYear`den, yani yerelleştirme
kütüphanesinden geliyor; ekin ünlü uyumu kodda bilinemez. "Ağustos 2026
ayında" hem gereksiz hem kulağa takılıyor.

Seçilen kalıp `{month}: …` — kartın **kendi cümlesinde zaten var**
(`statsHeatmapDaySelectedSemantics`: "Seçili gün 9 Eyl: 1 saat 40 dakika.").
Tek utterance içinde iki farklı dilbilgisi kurmak yerine olanı tekrarlıyor,
TalkBack iki noktayı duraklama olarak okuyor.

İki yeni anahtar: `statsHeatmapPastMonthSemantics` ve
`statsHeatmapPastMonthEmptySemantics`. `MaterialLocalizations` kartın elinde
zaten vardı (başlık onu kullanıyor), yeni bağımlılık gerekmedi — madde 29/35'in
`intl` + `initializeDateFormatting` reddi bozulmadı.

### 3. Bu ay "Bu ay" demeye devam ediyor

Ayrım başlığınkiyle aynı kapıdan (`heatmap.isCurrentMonth`): içinde bulunulan
ayda cümle de başlık da "bu ay" diyor. Bugünün ayında ay adı yazmak kartın
`BU AY` başlığıyla çelişirdi ve "eylül" duyan kullanıcı geçmişe gittiğini
sanabilirdi.

### 4. Emülatör doğrulandı (2026-09-19)

`focussayac_verify` (Android 16, 1080×1920), bir yıllık tohumlanmış veri.
Doğrulama ekran görüntüsüyle **yapılamazdı** — cümle çizilmiyor, okunuyor.
TalkBack (`settings put secure enabled_accessibility_services …/TalkBackService`)
açılıp `uiautomator dump` ile platformun gördüğü `content-desc` okundu:

- Bu ay: `Bu ay 30 günün 16 gününde odaklandın, toplam 32 saat 33 dakika. Son
  52 haftanın 264 gününde odaklandın, toplam 337 saat 52 dakika.`
- Geri ok → `Ağustos 2026: 31 günün 24 gününde odaklandın, toplam 39 saat 15
  dakika. Son 52 haftanın …` — başlıktaki `Ağustos 2026` ve sağdaki
  `39 saat 15 dakika` ile birebir.

İki tuzak: (a) Flutter semantics ağacını yalnızca bir erişilebilirlik istemcisi
bağlıyken kuruyor — TalkBack açılmadan `uiautomator dump` 19 boş düğüm
veriyor; (b) emülatörün toybox `grep`i `\+` ile eşleşmiyor, XML host'a
çekilip orada taranmalı. Çıktılar `.verify/m40_*`.

### 5. Kapsam dışı

- Şeridin cümlesi (`SON 52 HAFTA`): penceresi ay gezinmesinden etkilenmiyor,
  "son 52 hafta" her ayda doğru.
- Boş geçmiş ay dalının emülatörde görülmesi: geri okun kapısı en eski seansa
  bağlı (`hasEarlier`), yani tohumlanmış veriyle boş bir geçmiş aya gezinmek
  mümkün değil. Dal widget testinde sabitlendi.

---

## Madde 41 — Widget'ın halkasındaki emek yayı

Madde 27'nin kapsam dışı bıraktığı iş. Geri sayım halkasına ikinci bir eksen
(haftalık hedefin emek yayı) eklenmişti ama yalnızca Ekran 02'ye;
`RingRenderer.kt` madde 27 öncesinin halkası olarak kaldı. Aynı halka iki
yüzeyde iki farklı şey anlatıyordu — üstelik widget'ın çizdiği tek "sınav" yayı
tam da madde 27'nin ölü aralık dediği, aylarca kıpırdamayan yaydı.

Tasarım: `docs/superpowers/specs/2026-09-19-widget-emek-yayi-design.md`.

### 1. Payload iki ham sayı taşıyor, oran taşımıyor

Yeni anahtarlar `weeklyGoalSeconds` ve `weeklyFocusedSeconds` —
`WeeklyGoalProgress`in iki alanının birebir karşılığı. Oran, "hedef kapalı" ve
"hedef doldu" Kotlin tarafında aynı formüllerle türetiliyor
(`FocusWidgetSnapshot.weeklyEffortRatio` / `weeklyGoalReached`).

Oranı hazır göndermek işe yaramazdı: oran `1.0`'da kırpılı, yani hedefi tam
tutturmakla üçe katlamak aynı sayı — `isReached` için ikinci bir anahtar yine
gerekirdi, ama bu kez türetilmiş olanı. İki operand gönderince Kotlin
`WeeklyGoalProgress`in üç sorusunu da kendisi cevaplıyor.

`weeklyMinutes`i (payloadda zaten duran 7 günlük liste) Kotlin'de toplamak da
reddedildi: pencere aynı pencere ama liste gün başına `saniye ~/ 60` taşıyor.
Bugün seanslar tam dakika olduğu için toplam tutuyor — emülatörde birebir
doğrulandı (`36300` = `0+0+117+124+131+138+95` × 60) — ama tutmadığı gün widget
ile Ekran 02 sessizce farklı bir yay çizerdi. Madde 27'nin "ikisi aynı örnekten
besleniyor, ayrışamazlar" güvencesi ancak sayı **aynı sayı** olursa taşınır.

Bu, `FocusWidgetSnapshot.kt`in "türetilmiş değer Dart'tan okunmaz" kuralıyla
çelişmiyor. O kuralın gerekçesi **bayatlama**: kalan gün ve meşale kademesi
zaman geçtikçe yanlışlaşır. `weeklyFocusedSeconds` zamanla değişmiyor, yalnızca
bir seans tamamlanınca değişiyor, o da zaten yeni bir push tetikliyor.

### 2. Geometri Ekran 02'den birebir; halka üç yaylı oldu

r=119, kalınlık 4, yuvarlak uç, 12 yönünden — madde 27'nin ölçüleri yeniden
ölçülmeden taşındı. Günün döngüsü yayı (r=112, madde 28) **yerinde kaldı**:
emek yayı onun yerine geçmiyor, ikisi farklı soruların cevabı (bugün ne yaptım
/ bu hafta hedefin neresindeyim). Yarıçap paritesi korunduğu için üçüncü yay
yeni bir bant açmadı; emülatörde üç yay rahat ayrılıyor, sıkışıklık yok.

Ton `_WeeklyGoalRow` ile aynı: hedefe giderken köz, dolunca nane. Gradyan yok —
zaman yayı üç duraklı gradyanla dekoratif, emek yayı tek düz tonla anlamsal.

### 3. `muted` emek yayını almıyor, hedef kapalı alıyor

Sınav seçilmemişken ve sınav geçtiğinde zaman yayı çizilmiyor ama emek yayı
çiziliyor: günün yayının gerekçesiyle aynı — geri sayım durmuş olabilir, odak
birikmeye devam ediyor ve bu yayın anlattığı şey sınav değil, hafta.

Hedef kapalıyken ise yay **da izi de** çizilmiyor (`effortRatio` `0.0` değil
`null`). Boş bir iz "hedefinin %0'ındasın" derdi, oysa kullanıcının koyduğu bir
hedef yok — `CountdownRingPainter`ın ve `_WeeklyGoalRow`un kararı.

### 4. Kicker'ın sığma kirişi 125.5'ten 117'ye indi

Madde 39 uzun durum adlarının izin üstüne binmesini `labelFitFor` ile çözmüştü;
kiriş zaman izinin iç kenarından ölçülüyordu. Halkanın en içteki dolu yayı artık
emek yayı, yani yeni sınır `EFFORT_RADIUS - EFFORT_STROKE/2` = 117 —
`CountdownRingPainter.innerContentRadius` ile aynı sayı.

Sınır **koşulsuz** indi, hedefin açık olmasına bağlanmadı: punto hedefe göre
değişseydi kullanıcı ayarı açıp kapattığında widget'ın yazısı boy değiştirirdi.
Sözleşmenin 8. iddiası yeni sınıra bağlandı ve dört kicker × beş sayı
kombinasyonunun hepsi daralmış sınırda da geçti — merkez yazısı için ek bir
küçültme gerekmedi.

### 5. Panorama kapsam dışı değil

`PanoramaWidgetProvider` halkayı aynı `RingRenderer` ile çiziyor (84dp). Orada
`effortRatio = null` geçmek, bu maddenin kapattığı ayrışmayı bu kez iki
widget'ın arasında kurardı.

### 6. Emülatör doğrulandı (2026-09-19)

`focussayac_verify` (Android 16, 1080×1920, açık tema). İki katman:

**a) Çizim yolu.** `RingRendererContract`a dört yeni iddia eklendi (emek
merdiveni, hedef kapalıyken o çemberde hiçbir şey yok, yayın kendi rengini
taşıması, zaman yayının etkilenmemesi); madde 39'un kalıbıyla hem Robolectric
hem cihaz koşuyor. 25 cihaz testi geçti, beş durumun PNG'si döküldü
(`.verify/m41/`).

**b) Uçtan uca.** Halka widget'ı gerçekten ana ekrana yerleştirildi (widget
seçiciden sürükleyerek — madde 39'un notu duruyor, `appwidget` kabuk komutu
widget koymuyor). Veritabanındaki `weekly_goal_minutes` üç kez değiştirilip
uygulama açıldı; `shared_prefs`te iki yeni anahtar göründü ve ana ekran
görüntüsünden yaylar piksel piksel ölçüldü:

| durum | payload | zaman | emek | gün |
| --- | --- | --- | --- | --- |
| hedef kapalı | `0 / 0` | %32.8 | yok | %75.3 |
| yolda | `36300 / 86400` | %32.8 | %42.6 köz | %75.3 |
| doldu | `36300 / 36000` | %32.8 | %100 nane | %75.3 |

Zaman yayı üçünde de kıpırdamadı (beklenen `1−274/400` = %31.5 + yuvarlak uç
payı) — iki eksen gerçekten bağımsız, madde 27'nin kabulünün widget
karşılığı. Ekran görüntüleri `.verify/m41_w_*.png`.

**Tuzak:** widget bir tur bayat çiziyordu. İlk kare hedef kapalı olması
gerekirken önceki hedefin oranını (%30.1) gösterdi; aynı durum daha uzun
beklemeyle tekrarlandığında %0 çıktı. Push ile launcher'ın yeniden çizmesi
arasında birkaç saniye var, ekran görüntüsü o aralığa düşmemeli.

### 7. Kapsam dışı

- `StripRenderer`ın haftalık hedefi: şeridin kendi dili var, ikinci bir eksen
  orada aynı boş bandı bulmuyor.
- Widget'ta hedefe kalan sürenin **metni** — halka widget'ının alt satırı zaten
  dolu (`5 gün seri · 3 pomodoro`).
- Dart ↔ Kotlin piksel paritesi (madde 39'dan beri kapsam dışı).

### 8. Yan bulgu: widget'ın izleri açık temada görünmüyor

`RingRenderer` iz renklerini düz beyaz-alfa hex olarak tutuyor (`0x17FFFFFF` /
`0x12FFFFFF`); madde 39'un sözleşmesi bunları bilerek temadan bağımsız sayıyor
ve sondaları buna göre kurulu. Açık temada widget zemini (212,212,213) ile izin
çizdiği renk (216,216,218) arasında dört ton var — yani üç iz de görünmüyor.

Sonucu emek ekseninde şu: hedef açık ama hafta boşken widget'ta o eksenin yeri
hiç görünmüyor, Ekran 02'de `colors.fillSubtle` ile görünüyor. Madde 41 bu
kusuru yaratmadı, mevcut iki ize üçüncüyü ekledi. Düzeltmek izleri
`FocusPalette`e bağlamayı ve madde 39'un "halkanın izleri temadan bağımsız"
varsayımını gözden geçirmeyi gerektiriyor — **madde 44** oldu.

---

## Madde 42 — Pazar bildirimi haftalık hedefi söylüyor

Madde 24'ün kapsam dışı bıraktığı iş. Haftalık hedef Ekran 07'nin slider'ında,
Ekran 02'nin çubuğunda ve (madde 41'den beri) widget'ın emek yayında duruyordu;
haftayı **kapatan** cümlede yoktu. `rescheduleWeeklySummary`nin imzasında hedef
diye bir şey yoktu (`seconds`, `previousSeconds`), yani hedefini tutturan
kullanıcı da tutturamayan da aynı dört gövdeden birini alıyordu.

Tasarım: `docs/superpowers/specs/2026-09-19-pazar-bildirimi-hedef-design.md`.

### 1. Hedef cümlesi kıyas cümlesinin **yerine** geçiyor, yanına değil

Madde 24 bu işi iki riskle kapsam dışı bırakmıştı: dört varyantı sekize
çıkarmak ve "yüzde değil fark" kararıyla çelişen bir dil kurmak. İkisinden de
kaçınan kural tek cümle — **hedef karşılandıysa gövde hedef cümlesidir**,
karşılanmadıysa bugünkü dört gövde aynen kalır. Hedef, varyantların yanına
ikinci bir cümle olarak eklenmediği için çarpım olmuyor: 4 → 5.

"Haftalık hedefin tamam — ayrıca geçen haftadan 40dk fazla" reddedildi: bir
bildirim gövdesinin taşıyabileceği tek bir haber var, ve hedefin tutması o
haftanın daha büyük haberi. Aynı gerekçeyle hedef dallanması kıyassızlık
dallanmasının **önünde**: ilk haftasında hedefini tutturan kullanıcı da hedef
cümlesini alıyor.

### 2. Eksiklik hiç dile getirilmiyor

Simetrik kural ("tutmadıysa hedefine X kaldı") bildirimin saatiyle aslında
uyumluydu: 20:00 TSİ'de pencere henüz kapanmamış (uygulama günü ertesi 04:00'te
biter) ve `kWeeklySummaryHour`un gerekçesi zaten "özeti gördükten sonra o akşam
hâlâ bir pomodoro vakti kalsın". Yine de reddedildi, çünkü aynı kural 20sa
hedefin 1sa'sinde duran kullanıcıya "hedefine 19sa kaldı" derdi — haftayı
kapatan bir bildirimde kapatılamaz bir eksiği okumak ölçen ton.

Eşik koymak (kalan ≤ bir odak seansı) bunu çözerdi ama maddenin kapsam dışı
notu "hedef dolmadığında ayrı bir hatırlatma bildirimi"ni zaten dışarıda
bırakmış; eksikliği konuşan her cümle o bildirimin küçük hâli. Bu karar onun
önünü kapatmıyor: bu madde yalnızca "tuttu" hâlini sahipleniyor.

### 3. "Tuttu mu" kararı `WeeklyGoalProgress`ten okunuyor

Bildirim kendi `>=`sini yazmıyor; `goalSeconds`/`focusedSeconds` ile bir
`WeeklyGoalProgress` kurup `isReached` soruyor. Madde 24'ün iki kararı orada
gömülü ve ikisi bildirim için de geçerli: sınır **dahil** (hedefi tam karşılayan
hafta tamamlanmış), ve kapalı hedef hiçbir zaman ulaşılmış sayılmıyor. Elle
yazılmış ikinci bir karşılaştırma bunları sessizce ayırabilirdi — Ekran 02'nin
çubuğu "tamam" derken bildirimin "geçen haftadan fazla" demesi.

Katman sınırı çiğnenmiyor: `services/notifications` `services/storage`e
bağlanmıyor (`NotificationPreferences`in var oluş sebebi bu) ama saf `domain`
yapraklarına bağlanıyor — `domain/time/duration_formatter` ve
`domain/flame/flame_tier` zaten import edilmiş. `domain/stats/weekly_goal.dart`
hiçbir şey import etmiyor, aynı sınıftan bir yaprak.

### 4. Hedef, saniyesiyle aynı yoldan geliyor

`rescheduleWeeklySummary` `goalSeconds` alıyor; servis ayarı kendisi okumuyor
(`NotificationPreferences` dışındaki her ayar çağıranın işi, eşleme tek yerde).
İki çağıran da değeri zaten ellerinde tutuyor: `main.dart` açılışta DAO'dan,
`PomodoroController._completeFocus` ise mola süresi için okuduğu `settings`ten
— ikinci bir sorgu açılmıyor.

### 5. Cümlede hedefin sayısı geçmiyor

`Bu hafta {total} odaklandın — haftalık hedefin tamam.` Mevcut dört gövdenin
iskeletine oturuyor (aynı baş, tireden sonra ikinci yarı), yani beşinci varyant
yeni bir cümle biçimi getirmiyor. "Haftalık" sıfatı Ekran 02'nin rozetinde
(`Hedef tamam`) yok çünkü orada satır zaten `BU HAFTA` yazıyor; bildirimde cümle
tek başına okunuyor. Hedefin sayısı yok: "10 saat 5 dakika odaklandın, hedefin
tamam" zaten hedefin o sayının altında olduğunu söylüyor.

### 6. Bayatlama: Ekran 07 bir yeniden kurma noktası değil

Bildirim kurulduğu **andaki** hedefle kuruluyor. Kullanıcı hedefi yükseltip
uygulamayı bir daha açmazsa ve o hafta hiç odak tamamlamazsa, kurulu "hedefin
tamam" cümlesi eski hedefe ait kalır.

Bu pencere yeni değil, mevcut mimarinin penceresi: Ekran 07 hiçbir ayar
yazısında bildirim yeniden kurmuyor — `notificationsEnabled`ı kapatmak bile
kurulmuş özeti açılışa ya da ilk odak tamamlanışına kadar iptal etmiyor. Hedef
de tam olarak o iki noktadan besleniyor, yani saniyelerle aynı tazelikte.
Ekran 07'yi üçüncü bir yeniden kurma noktası yapmak üç bildirimin (seri riski,
haftalık kapanış, dönüş) hepsini ilgilendiren ayrı bir karar, bu maddeye
sığmıyor.

### 7. Emülatör: kurulu alarm değil, **düşen** bildirim okundu

`focussayac_verify`de cihaz saati pazar 19:58'e çekilip uygulama açıldı ve
20:00'yi geçmesi beklendi; kanıt `dumpsys alarm`ın kurduğu alarm değil,
`dumpsys notification`ın gösterdiği gövde. Pencerenin gerçek toplamı 36300 sn
(10sa 5dk), önceki pencere 37800 sn:

| hedef | gövde |
| --- | --- |
| 10sa (tuttu) | `Bu hafta 10 saat 5 dakika odaklandın — haftalık hedefin tamam.` |
| 20sa (tutmadı) | `Bu hafta 10 saat 5 dakika odaklandın — geçen haftadan 25 dakika az.` |

İkinci satır karşı kontrol: hedef tutmayınca bugünkü dört varyant bozulmadan
duruyor, ve hedef cümlesi "her hâlde çıkan" bir metin değil.
