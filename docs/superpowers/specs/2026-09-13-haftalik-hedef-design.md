# Haftalık hedef — tasarım

ROADMAP madde 24. Tarih: 2026-09-13.

## Sorun

Uygulamada iki zaman ufku var ve ikisinin arası boş:

- **"Bugün"** (Ekran 02'nin `BUGÜN` kartı) — bir günü kaçıran kullanıcı için o
  gün zaten kapanmış, telafi edilemez.
- **"Sınava kalan gün"** — kapatılamayacak kadar uzak, günlük davranışa
  bağlanmıyor.

Haftalık hedef aradaki ufku açıyor: kaçırılan gün hafta içinde telafi
edilebilir hâle geliyor ve hafta içinde ikinci bir seans başlatmaya somut bir
sebep doğuyor.

`weeklyGoal` / `weeklyTarget` kodda hiç geçmiyor; `AppSettings`
(`lib/services/storage/tables.dart:50-79`) yalnızca `focusMinutes`,
`shortBreakMinutes`, `longBreakMinutes`, `selectedTemplateIndex`,
`activeExamId` ve anahtarları tutuyor.

## Hafta tanımı — yeni hesap kurulmuyor

Bu maddenin en önemli kararı, yazılmayan koddur.

`weeklySummaryProvider` (`lib/domain/stats/stats_providers.dart:41`) **bugünle
biten kayan `kStatsWeekLength` (7) uygulama günü** penceresinin tamamlanmış
odak saniyesini zaten yayınlıyor. Aynı saf fonksiyonu (`calculateWeeklySummary`)
pazar kapanış bildirimi de hedef pazarla çağırıyor
(`lib/main.dart:164`, `lib/domain/pomodoro/pomodoro_controller.dart:412`).

Haftalık hedef bu sağlayıcıyı **tüketir**, kendi pencere hesabını kurmaz.
ROADMAP'in "hafta tanımı `weekly_summary.dart`'taki mevcut hafta sınırıyla
**aynı** olmalı — iki farklı 'hafta' kavramı çıkmasın" şartı böylece test
edilerek değil **kurgu gereği** sağlanıyor: sapabilecek ikinci bir hesap yok.
Kabul kriterinin istediği test yine yazılıyor, ama regresyon kilidi olarak.

Takvim haftası (Pzt–Paz) **kullanılmıyor** — gerekçe `weekly_summary.dart:64-69`
içinde zaten yazılı ve burada aynen geçerli: yarım kalmış bir takvim haftasını
tam bir haftayla kıyaslamak her pazartesi hedefi ulaşılamaz gösterirdi.

## Veri — tek kolon, drift v4 → v5

`AppSettingsTable`'a:

```dart
IntColumn get weeklyGoalMinutes => integer().withDefault(const Constant(300))();
```

Göç `themeMode` (v3) ve `weeklySummaryEnabled` (v4) ile birebir aynı kalıp
(`app_database.dart:50-61`): `m.addColumn(...)`, backfill yok. `withDefault`
mevcut tek satıra da uygulanıyor, yani güncelleme alan kullanıcı hedefi
5 saatte açık bulur.

**Neden dakika, saat değil:** tablodaki diğer üç süre alanı da dakika. Kullanıcı
arayüzünde saat gösteriliyor (haftalık bir hedefi dakikayla konuşmak okunmaz),
ama depolama birimi tabloyla tutarlı kalıyor — iki birim kavramı çıkmıyor.

**Varsayılan 300 dk = 5 sa/hafta** (günde ~45 dk). 10 sa/hafta sınav öğrencisi
için gerçekçi ama yeni kullanıcıyı ilk hafta %30'da bırakırdı; ulaşılabilir
hedef ulaşılamaz hedeften daha çok seans başlatır.

## Saf katman — `lib/domain/stats/weekly_goal.dart`

`focus_stats.dart` / `weekly_summary.dart` ile aynı desen: IO yok, saf
hesaplayıcı, `==` tanımlı (Riverpod gereksiz yeniden çizimi elesin).

```dart
class WeeklyGoalProgress {
  final int goalSeconds;
  final int focusedSeconds;

  bool get isOff => goalSeconds <= 0;
  double get ratio;            // clamp(focused / goal, 0, 1); isOff → 0
  int get remainingSeconds;    // max(0, goal - focused)
  bool get isReached;          // !isOff && focused >= goal
}
```

Yanında `weeklyGoalProgressProvider`: `weeklySummaryProvider`in `seconds`'ı +
ayar satırının `weeklyGoalMinutes`'i. Başka kaynak okumuyor.

`ratio` kırpılıyor (hedefi aşan kullanıcıda çubuk taşmasın), `remainingSeconds`
tabanda kırpılıyor (negatif "kalan" cümlesi kurulmasın).

## Ekran 07 — ayar

Süreler kartına (`settings_screen.dart:120-158`) dördüncü satır:
**"Haftalık hedef"**, aralık **0–30 saat**, adım 1, tint `colors.sky`.

- `ember` ve `mint` odak/mola sürelerinde, `sky` haftalık pencerenin Ekran
  06'daki rengi — hedef aynı pencereye baktığı için rengi de oradan alıyor.
- Üst sınır 30 sa (~4.3 sa/gün): slider'ın çözünürlüğünü kullanılabilir tutuyor.

**`_DurationSlider` genellemesi.** Bileşen bugün değer etiketini kendi içinde
kuruyor (`settings_screen.dart:411`, `settingsMinutesValue(minutes)`), yani
birimi dakikaya çivili. Etiket dışarıdan `valueLabel` (String) olarak veriliyor;
mevcut üç çağıran `settingsMinutesValue`'yu kendisi geçiyor, davranışları
değişmiyor. Bu, üzerinde çalışılan koda yapılan hedefli bir düzeltme — ilgisiz
bir refactor değil, saat birimi olmadan satır yazılamıyor.

**0 = kapalı.** Sıfırda değer alanı "Kapalı" yazıyor ve Ekran 02'deki satır hiç
çizilmiyor.

Gerekçe: uygulamanın tonu `DECISIONS.md`'de "eşlik eden, ölçen değil" diye
çivilenmiş (`weekly_summary.dart:35-37`'deki karşılaştırma kararı da aynı
yerden geliyor). Hafta boyunca %8'de duran ve **kapatılamayan** bir çubuk tam
tersini söyler. Tek `if` dalına mal oluyor; hedefi olmayan kullanıcı için de
uygulama eksiksiz çalışıyor.

## Ekran 02 — `BUGÜN` kartının ikinci satırı

Yeni kart açılmıyor. Ekran 02 zaten 316px halka + kart + CTA ile dolu; ikinci
bir kart birincil eylemi ekranın dışına iterdi.

Mevcut kart içeriğinin altına `colors.hairline` ayırıcı, sonra:

```
┌─────────────────────────────┐
│ BUGÜN              🔥 12    │
│ 2sa 15dk          ● ● ● ○   │
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔░░░░░░      │
│ ─────────────────────────── │
│ BU HAFTA        4sa 30dk/5sa│
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔░░       │
└─────────────────────────────┘
```

- **Kicker** `BU HAFTA` — mevcut `countdownToday` ile aynı stil
  (`AppTypography.kicker`, `colors.neutral600`).
- **Değer** `4sa 30dk / 5sa` — mevcut `formatFocusDuration` ile; yeni biçimleyici
  yok.
- **Çubuk** 4px, `TweenAnimationBuilder` + `AppMotion.slow` (madde 18'in oran
  geçişi kalıbı). Boşta kare üretmiyor: değer yalnızca bir seans bitince
  değişiyor, yani SPEC §6.4 ile sürtünme yok.

**Hedef tamamlandığında** çubuk `mint`'e dönüyor, sağdaki satır "Hedef tamam"
oluyor. `mint` uygulamanın tamamlanma dili (döngü noktaları
`countdown_screen.dart:672`, `_CompletionRing` madde 19); hedefe giderken
`ember`.

**Boş haftada gizlenmiyor.** BUGÜN kartındaki dört nokta ve günlük çubuk ilk
pomodoro tamamlanana kadar gizli (`countdown_screen.dart:655-658`: "0/4" bir
eksik bildirimi). Haftalık çubuk için aynı şey geçerli değil — pazartesi sabahı
%0'da olmak eksiklik değil, haftanın başıdır ve satırın bütün işlevi o noktadan
sonrasını göstermek. Tek gizlenme koşulu hedefin kapalı olması.

**Ekran okuyucu:** satır tek bir `Semantics` konteyneri; etiket sayıyı ve hedefi
sözle veriyor ("Bu hafta 4 saat 30 dakika, hedef 5 saat"), çubuk ayrıca
duyurulmuyor.

## Kapsam dışı — pazar bildiriminin hedefe göre konuşması

ROADMAP madde 24 şunu da listeliyor: *"Pazar özeti hedefe göre konuşabilir hâle
gelir: 'hedefinin %80'i'"*. **Bu maddeye alınmıyor.**

İki gerekçe:

1. **Yüzey maliyeti.** Bildirim gövdesinin bugün dört varyantı var
   (`Up`/`Down`/`Same`/karşılaştırmasız, `app_tr.arb:345-355`). Hedef kesişimi
   bunu sekize çıkarır — maddenin "Boyut: küçük" tanımını tek başına aşar.
2. **Ton çelişkisi.** `weekly_summary.dart:17-20` yüzde yerine **farkı** tutmayı
   açıkça seçiyor: "2 saatten 3 saate çıkmayı '%50 artış' diye anlatmak ölçen
   bir ton kuruyor". "Hedefinin %80'i" cümlesi hedefi kaçıran kullanıcıya pazar
   akşamı tam da o tonda bir not verir.

Madde 24'ün Kabul listesinde de yok. Ayrı bir madde olarak değerlendirilmeli.

## Testler

| Dosya | Ne çiviliyor |
|---|---|
| `test/domain/stats/weekly_goal_test.dart` | `ratio` kırpma (hedefi aşan kullanıcı), `isReached` sınırı (tam eşitlik açar), `remainingSeconds` tabanda kırpma, `isOff` |
| aynı dosya | **Hafta sınırı kabul kriteri:** aynı seans kümesinde ilerlemenin `focusedSeconds`'ı `calculateWeeklySummary(...).seconds` ile birebir eşit; pencere dışındaki bir seans ikisini de aynı anda etkilemiyor |
| `test/features/countdown/countdown_screen_test.dart` | satır görünüyor ve doğru metni yazıyor; hedef 0'da hiç çizilmiyor; hedef tamamlanınca mint + "Hedef tamam" |
| `test/features/settings/settings_screen_test.dart` | slider `weeklyGoalMinutes`'i yazıyor; 0'da "Kapalı"; mevcut üç slider'ın etiketi değişmemiş (genelleme regresyonu) |
| `test/services/storage/weekly_goal_migration_test.dart` | v4 → v5 göçü, mevcut satır 300 varsayılanını alıyor (`weekly_summary_migration_test.dart` örneği) |

Ayrıca yeni ARB dizelerinin glifleri font subset'lerinin `cmap`'inde
doğrulanacak — bu depoda daha önce sessiz Roboto düşüşü yaşandı (madde 21).

## Yeni ARB anahtarları

`countdownWeeklyGoalLabel` ("BU HAFTA"), `countdownWeeklyGoalValue`,
`countdownWeeklyGoalReached` ("Hedef tamam"), `countdownWeeklyGoalSemantics`,
`settingsWeeklyGoal` ("Haftalık hedef"), `settingsWeeklyGoalHours`,
`settingsWeeklyGoalOff` ("Kapalı").

`countdownWeeklyGoalLabel` metni Ekran 06'nın `statsWeeklyClosingLabel`'ı ile
aynı ("BU HAFTA") ama anahtar ayrı: iki yüzey birbirinden bağımsız
değişebilmeli, ve ARB'de kısa bir etiketin iki kez geçmesi bu depoda zaten
normal.

## Kabul (ROADMAP madde 24)

- [x] Hedef değiştirilebiliyor — Ekran 07, 0–30 sa slider
- [x] Ekran 02'de görünüyor — `BUGÜN` kartının ikinci satırı
- [x] Hafta sınırı `weekly_summary.dart` ile aynı, testle çivilenmiş —
      `weeklySummaryProvider` tüketiliyor, ikinci hesap yok
