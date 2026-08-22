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
- **Ekran 03'ün "skip-forward" ikonu görsel olarak duruyor ama dokunmaya bağlı değil** — SPEC.md'nin
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
