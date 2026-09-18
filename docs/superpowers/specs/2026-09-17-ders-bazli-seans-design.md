# Ders bazlı seans — tasarım

ROADMAP madde 30. Sınav öğrencisinin asıl takip ettiği metrik ders dağılımı;
uygulamada hiç yok. Listedeki en çok iş, ama en savunulabilir farklılaşma.

## Sorun

`PomodoroSessions` tablosunda (`lib/services/storage/tables.dart:28-37`) alanlar:
`id`, `examId`, `type`, `startedAt`, `completedAt`, `plannedDurationSec`,
`completed`, `breakExtensions`. Ders sütunu yok. Kullanıcı 40 saat odaklandığını
görüyor ama o 40 saatin matematiğe mi kimyaya mı gittiğini göremiyor — sınav
hazırlığında asıl karar verdiren sayı bu.

## Kararlar (madde 30 açılışında sorulan üç soru)

1. **Katalog sınava göre, kodda sabit.** `presetKey` → ders anahtarı listesi.
   Yeni tablo yok, tek yeni sütun; rozet kataloğunun (`badge_definition.dart`)
   kalıbının aynısı — DB yalnızca anahtarı tutuyor, ad ARB'den geliyor.
2. **Yapışkan hap + değiştir.** Ekran 02'de ODAKLAN'ın üstünde son seçilen dersi
   gösteren bir hap; dokununca alt sayfa açılıyor. ODAKLAN tek dokunuşla seansı
   başlatmaya devam ediyor.
3. **Ekran 06'da üç yüzey:** ders dağılımı kartı, haftalık denge satırı,
   "en çok ihmal ettiğin ders" satırı.

## Depolama — iki nullable sütun, şema v6

```dart
// PomodoroSessions
TextColumn get subjectKey => text().nullable()();

// AppSettingsTable
TextColumn get activeSubjectKey => text().nullable()();
```

Kurallar:

1. **Nullable, varsayılansız.** `weeklyGoalMinutes` kalıbı (kolon varsayılanı
   mevcut satıra da uygulanır) burada yanlış olurdu: göç alan kullanıcının eski
   seansları gerçekten dersiz, onlara bir ders atamak veri uydurmak olur.
   `null` = "belirtilmemiş" ve ekranlarda kendi satırı var.
2. **Ders yalnızca odak seansına yazılıyor.** Mola seansları `null` kalıyor —
   dağılım zaten yalnızca tamamlanmış odak seanslarını sayıyor
   (`monthly_heatmap.dart` ile aynı filtre). Alternatif, molanın dersi odaktan
   devralmasıydı: `PomodoroPhase`e (freezed) alan eklemeyi, prefs kodlamasını ve
   kurtarma yolunu büyütür, karşılığında hiçbir yüzeye veri vermezdi.
3. **Seçim `AppSettings`te, `SharedPreferences`ta değil.** Aktif sınav zaten
   orada (`activeExamId`); ikisi aynı anda okunuyor ve aynı anda geçersizleşiyor.
4. **Geçersiz anahtar sessizce `null`.** Kullanıcı YKS'de Kimya seçip LGS'ye
   geçerse `activeSubjectKey` yeni katalogda yok. Ayarı sıfırlamak yerine
   **okuma anında** doğrulanıyor (`resolveActiveSubject`): sınavı geri
   değiştiren kullanıcı eski dersini geri buluyor.

Göç `from < 6` bloğunda iki `addColumn`. Temiz kurulum `onCreate`ten geçtiği için
yükseltme yolu ayrı bir testle çivileniyor (`subject_migration_test.dart`,
`weekly_goal_migration_test.dart` kalıbı).

## Katalog — `lib/domain/subjects/subject_catalog.dart`

Saf veri + saf fonksiyon, IO yok. Anahtarlar DB'de metin olarak saklandığı için
bir kez yayınlandıktan sonra **değiştirilemez** (`SessionType`, `BadgeKeys` ile
aynı kısıt).

```dart
abstract final class SubjectKeys {
  static const String math = 'math';           // ...18 anahtar
}

List<String> subjectsForExam(String? presetKey);  // preset yoksa genel katalog
String? resolveActiveSubject(String? key, List<String> catalog);
String subjectName(AppLocalizations l10n, String key);
```

Kurallar:

1. **Anahtarlar sınavlar arasında paylaşılıyor.** YKS'nin ve LGS'nin
   "Matematik"i aynı `math`. Sınav değiştiren kullanıcının geçmişi tek bir
   derste toplanıyor, ARB de 18 anahtarla kalıyor.
2. **Preset olmayan sınav genel katalogu alıyor** (Matematik, Türkçe, Fen,
   Sosyal, Yabancı Dil, Diğer). Kullanıcı kendi sınavını ekleyebiliyor
   (`add_exam_screen.dart`) ve o sınavın ders listesi bilinemez; boş liste
   göstermek hapı ölü bir düğmeye çevirirdi.
3. **Sıra katalogda sabit** — dağılım kartı kendi sırasını süreden türetiyor,
   ama alt sayfa her açılışta aynı sırayı göstermek zorunda.

Kataloglar:

| `presetKey` | dersler |
| --- | --- |
| `yks` | Matematik, Geometri, Türkçe, Fizik, Kimya, Biyoloji, Tarih, Coğrafya, Felsefe, Din Kültürü, Yabancı Dil |
| `lgs` | Matematik, Türkçe, Fen Bilimleri, İnkılap Tarihi, Din Kültürü, Yabancı Dil |
| `kpss_lisans` | Matematik, Türkçe, Tarih, Coğrafya, Vatandaşlık, Güncel Bilgiler |
| `ales` | Sayısal, Sözel |
| (diğer) | Matematik, Türkçe, Fen Bilimleri, Sosyal Bilimler, Yabancı Dil |

KPSS'in "GY Matematik"i ve LGS'nin "İngilizce"si ayrı anahtar **almadı**: ilki
`math`, ikincisi `foreign_language`. Ayrı anahtar, sınav değiştiren kullanıcının
geçmişini iki ayrı derse bölerdi ve ARB'ye aynı şeyi söyleyen ikinci bir ad
eklerdi. Toplam 18 anahtar.

## Saf hesap — `lib/domain/stats/subject_breakdown.dart`

```dart
class SubjectSlice {
  final String? key;        // null = belirtilmemiş
  final int seconds;
  final int previousSeconds;
  final double ratio;       // seconds / totalSeconds
}

class SubjectNeglect {
  final String key;
  final int daysSince;      // en son çalışıldığı günden bugüne
}

class SubjectBreakdown {
  final List<SubjectSlice> slices;   // süreye göre azalan, yalnızca > 0
  final int totalSeconds;
  final SubjectSlice? biggestRise;   // haftalık denge
  final SubjectSlice? biggestFall;
  final SubjectNeglect? neglect;
  bool get isEmpty => totalSeconds == 0;
}

SubjectBreakdown calculateSubjectBreakdown({
  required List<PomodoroSession> sessions,
  required List<String> catalog,
  required DateTime nowUtc,
});
```

Kurallar:

1. **Tek pencere: son `kStatsWeekLength` uygulama günü**, bugünle biten —
   `calculateWeeklySummary` ile birebir aynı tanım, karşılaştırma penceresi de
   ondan hemen önceki blok. Ekran 06 zaten bu pencereyi konuşuyor ("BU HAFTA"
   kartı, bar chart); dağılım için ayrı bir aylık pencere açmak tek kartta iki
   farklı "şimdi" tanımı demekti.
2. **`null` dersli seanslar `key: null` diliminde toplanıyor**, atılmıyor.
   Göçten gelen kullanıcının bu haftaki emeği dağılımın dışında kalırsa toplam
   ekranın geri kalanıyla çelişirdi.
3. **Denge:** en çok artan ve en çok azalan ders. Önceki pencere tamamen boşsa
   (`previousTotal == 0`) ikisi de `null` — ilk haftasındaki kullanıcıya kendi
   sıfırıyla kıyas sunmak `WeeklySummary.hasComparison`ın reddettiği şey.
4. **İhmal:** katalogdaki dersler içinde, **daha önce çalışılmış** ama pencere
   içinde hiç çalışılmamış olanlardan en uzun süredir dokunulmayanı. Hiç
   çalışılmamış ders aday değil: YKS katalogunda 11 ders var, kullanıcı haftada
   3-4'üne dokunuyor; "hiç çalışmadıkların" listesi her hafta aynı yedi dersi
   sayan bir suçlama olurdu. Geçmişi olan bir ders sustuğunda ise söylenen şey
   gerçek ve eyleme çevrilebilir.
5. **Ton:** ihmal satırında kırmızı yok (`_WeeklyClosingCard`'ın düşen haftayı
   nötr tonda yazmasıyla aynı gerekçe); renk `sky` — ekranın veri rengi.

## Ekran 02 — hap

`_CountdownBody`de ODAKLAN butonunun hemen üstünde, 8px boşlukla. Hap:
nokta (ders rengi) + ders adı + `değiştir`. Ders seçili değilken tek satır:
`Ders seç`. Dokunma hedefi hapın tamamı, alt sayfayı açıyor.

`startFocus()` ayarı zaten okuyor (`focusMinutes`); aynı okumadan
`activeSubjectKey` de alınıyor ve aktif sınavın katalogunda doğrulanıp DAO'ya
veriliyor. Hızlı Odak widget'ı ve onboarding'in ilk seansı da aynı yoldan geçiyor
— ikisi de `startFocus()` çağırıyor, yani ders seçiliyse onlarda da yazılıyor.

Katalogu belirleyen sınav `activeExamProvider`ın **akış değeri değil**: o akış
soğuk başlangıçta (widget'tan açılan seans, ekran hiç kurulmadan) henüz yayın
yapmamış olabiliyor ve katalog genel listeye düşünce geçerli bir ders sessizce
kaybolurdu. Ders seçiliyken sınav `ExamDao.getActiveExam()` ile okunuyor; seçim
yokken fazladan sorgu da yok. (Controller testi bu yolu çiviliyor: sağlayıcı
akışına abone olmayan bir `ProviderContainer`da ders yine yazılıyor.)

Alt sayfa `exam_picker_sheet.dart`ın kabuğu: tutamak, başlık, seçim yüzeyi, en
altta ikincil çıkış (`Ders belirtme` → `activeSubjectKey = null`). Seçim yüzeyi
sınav listesindeki gibi satırlar değil **haplar** (`Wrap`): ders adları kısa ve
sayıları 2 ile 11 arasında; satır listesi YKS'de kaydırma gerektirirdi.

## Ekran 06 — dağılım kartı

Isı haritasının **üstünde**, bar chart'ın altında: haftalık pencereyi konuşan
kartlar yukarıda, aylık ritim aşağıda kalıyor.

- Başlık `DERS DAĞILIMI` + pencere toplamı (kicker + `sky` süre metni,
  `MonthlyHeatmapCard._header` ile aynı düzen). Toplam **kısa** biçimde
  (`4sa 45dk`): ısı haritasının kicker'ı `BU AY` ile kısa, buradaki uzun ve
  ikisi 296px'lik kart genişliğine uzun süre metniyle birlikte sığmıyordu.
  Ekran okuyucu yine uzun biçimi duyuyor (`Semantics` etiketi).
- Her satır: ders adı, süre, yüzde ve tam genişliğe oturan bir çubuk. Çubuk
  rengi sırasına göre `skyDeep → sky` rampası (`heatmapLevelColor` ile aynı
  fikir, yeni tema alanı açılmıyor); belirtilmemiş dilim `fillMedium` — nötr,
  çünkü bir ders değil.
- Denge satırı kartın içinde, `Divider`ın altında ve **iki satır**: kicker
  (`GEÇEN HAFTAYA GÖRE`) üstte, iki uç altta (`Türkçe +1sa · Matematik −1sa`).
  Tek satır denendi, 390px ekranda 40px taştı.
- İhmal satırı kartın altında ayrı bir yüzey: `Kimya'ya 14 gündür dokunmadın.`
  (`dativeSuffix` — `turkish_suffix.dart` zaten var).
- **Kart boş pencerede hiç çizilmiyor** (`isEmpty`): `_WeeklyClosingCard` ile
  aynı gerekçe. Tek dilim belirtilmemişse de çizilmiyor: henüz ders seçmemiş ya
  da göçten yeni gelmiş kullanıcıya `Belirtilmemiş %100` tek satırı bir dağılım
  değil, boş bir kutu gösterirdi.

## Kapsam dışı

Ders başına hedef, ders bazlı rozet, geçmiş seansın dersini sonradan düzenleme,
kullanıcının kendi dersini yazması, ders bazlı bildirim.

## Kabul (ROADMAP madde 30)

- Ders seçilebiliyor ve seçim seansa yazılıyor.
- Eski dersiz seanslar hiçbir ekranı kırmıyor (belirtilmemiş dilimi).
- Dağılım doğru toplanıyor (pencere toplamı = dilimlerin toplamı).
