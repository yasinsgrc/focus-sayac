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
- **`BottomNavBar`'ın hem `flame` hem `medal` ikonu rozetler ekranına gidiyor** — prototipin alt
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
- **Interstitial kuralları tek yerde** (`InterstitialManager`): mola başlangıcı, 3 tamamlanan
  pomodoroda 1, iki gösterim arası min. 180 sn. "3'te 1" ile "180 sn" bağımsız iki sayaç; ikisini
  çağırana dağıtmak, ileride ikinci bir tetik noktası eklendiğinde sessizce iki kat reklam demekti.
  Son gösterim anı `SharedPreferences`ta kalıcı — uygulama öldürülüp hemen açılırsa kural yine
  geçerli. Damga yalnızca reklam **gerçekten gösterildiyse** atılıyor: yüklenemeyen bir reklam
  180 sn'lik pencereyi harcamamalı.
- **"3 tamamlanan pomodoro" sayısı `PomodoroSessionDao.getAllCompletedFocusSessions()`ten geliyor**,
  ayrı bir sayaç tutulmuyor — `AppReviewService` ve `BadgeUnlockService` de aynı kaynağı okuyor.
  İptal edilen seanslar (`completed = false`) doğal olarak sayıya girmiyor.
- **Rozet açılışı interstitial'ı bastırıyor** (SPEC §7.2 "asla binmez"). Bunun için
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
