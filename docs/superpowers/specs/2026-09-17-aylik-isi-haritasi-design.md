# Aylık ısı haritası — tasarım

ROADMAP madde 29. Ekran 06'ya içinde bulunulan ayın katkı ızgarası: piksel
başına en çok hikâye anlatan grafik.

## Sorun

İstatistik ekranının tek grafiği 7 günlük bar chart. "Zinciri kırma"nın görsel
karşılığı olan ızgara yok; kullanıcı kendi ritmini (hangi günler çalışıyor,
nerede boşluk açılıyor) hiçbir yerde göremiyor. `heatmap` / `contributionGrid`
kodda geçmiyor.

Veri zaten elde: `PomodoroSessions` tablosundaki tamamlanmış odak seansları.
Yeni alan, agregat tablo, drift göçü gerekmiyor.

## Saf katman — `lib/domain/stats/monthly_heatmap.dart`

`weekly_summary.dart` / `weekly_goal.dart` ile aynı kalıp: ayrı dosya, ayrı saf
fonksiyon, ayrı sağlayıcı. `focus_stats.dart`ın içine bir alan olarak girmiyor —
o dosya zaten altı metrik taşıyor ve ızgara kendi eşiklerini, kendi takvim
yerleşimini getiriyor.

```dart
class HeatmapDay {
  final DateTime dayKey;  // appDayKey — 04:00 TSİ sınırlı uygulama günü
  final int minutes;      // o gün tamamlanmış odak dakikası
  final int level;        // 0..kHeatmapLevels
  final bool isFuture;    // ayın henüz gelmemiş günü
}

class MonthlyHeatmap {
  final int leadingBlanks;      // ayın 1'inden önceki boş hücre sayısı (0..6)
  final List<HeatmapDay> days;  // ayın 1'inden son gününe, eksiksiz
  final int totalMinutes;
  final int activeDays;
  bool get isEmpty => totalMinutes == 0;
}

MonthlyHeatmap calculateMonthlyHeatmap({
  required List<PomodoroSession> sessions,
  required DateTime nowUtc,
});
```

Kurallar:

1. Ay, `nowUtc`'nin **uygulama gününün** ayı (`currentAppDayKey`). 1 Eylül
   03:00 TSİ'de açılan uygulama hâlâ ağustosu gösterir; ekranın geri kalanıyla
   aynı gün tanımı.
2. `days` ayın her günü için bir eleman taşır — seans olmayan gün de
   `minutes = 0` ile listede. Izgara takvim düzeni olduğu için eksik gün
   hücreyi kaydırırdı.
3. `leadingBlanks = ayın 1'inin weekday - 1`. Hafta pazartesiyle başlıyor
   (`shortDayNames` sırası, `DateTime.weekday`). Ayın 1'i pazara düşerse 6.
4. `isFuture = dayKey.isAfter(bugün)`.
5. `activeDays` yalnızca `minutes > 0` günleri sayar.

### Seviye eşikleri mutlak — aya göre ölçeklenmiyor

| Dakika | Seviye |
|---|---|
| 0 | 0 (boş) |
| 1–24 | 1 |
| 25–49 | 2 |
| 50–89 | 3 |
| ≥90 | 4 |

Bar chart sütunlarını **kendi haftasının** en yüksek gününe göre ölçekliyor
(`WeeklyFocusBarPainter`, "sabit bir tavan az çalışılan bir haftada tüm
sütunları okunmaz kılardı"). Izgarada aynı şeyi yapmak yanlış bir şey söylerdi:
ayda tek bir 5 dakikalık günü olan kullanıcı o günü **en koyu** tonda görürdü.
Eşikler 25 dakikalık varsayılan pomodoronun 1 / 2 / 3+ katları; kullanıcı
süresini değiştirse de sınırlar dakikada sabit kalıyor, yani iki ay
birbiriyle karşılaştırılabilir.

## Izgara — `lib/features/stats/widgets/monthly_heatmap_card.dart`

`CustomPainter` **değil**, widget ağacı: 7 sütun × 5–6 satır, her hücre bir
`DecoratedBox`. Gerekçe — madde 31 zaten `FlameRenderer`ın doğrulanamamasından
açık; ikinci bir painter ikinci bir doğrulama boşluğu açardı. Widget hücreleri
`find.byKey` ile testten görünüyor. Kart statik (animasyon yok) ve bir
`RepaintBoundary` içinde, 42 hücrenin maliyeti bir kez ödeniyor.

Yerleşim: her satır bir `Row`, her hücre
`Expanded(child: AspectRatio(aspectRatio: 1, ...))`, aralar sabit boşluk.
Hücreler kartın genişliğine göre kendiliğinden kareleniyor.

### Renk

| Hâl | Renk |
|---|---|
| Seviye 1–4 | `Color.lerp(colors.skyDeep, colors.sky, level / kHeatmapLevels)` |
| Boş **geçmiş** gün | `colors.divider` |
| Ayın **gelecek** günü | Dolgu yok, `colors.hairline` çerçeve |
| Bugün | Seviyesinden bağımsız `colors.ember` çerçeve |

`sky` tanımı gereği "veri, istatistik" (`app_colors.dart:188`) — bar chart da bu
rampayı kullanıyor. Yeni tema alanı açılmıyor, iki tema da mevcut tokenlardan
besleniyor.

Gelecek günlerin dolgusuz olması bir ton kararı: ayın 2'sinde kullanıcıya 28
tane boş kutu göstermek, henüz yaşanmamış günleri kaçırılmış gün gibi
okuturdu. Bugünün ember çerçevesi bar chart'ın bugünü ember yapmasıyla aynı.

### Başlık ayın adı değil `BU AY`

`DateFormat.yMMMM` ya 12 yeni ARB anahtarı ya da karta `intl` bağımlılığı
demek. `shortDayNames` yorumunda yazılı olan kısıt geçerli: bu kart
`initializeDateFormatting` çağrılmadan da çizilmek zorunda —
`stats_screen_test`in üç testinden ikisi onu çağırmıyor. Kicker
`statsWeeklyClosingLabel` ("BU HAFTA") ile aynı kalıpta: `BU AY`.

Sağ üstte ayın toplamı `spellFocusDuration` ile. **Boş ayda o metin hiç
yazılmıyor:** haftalık kapanış kartının "iki pencere de boşken hiç çizilmiyor"
gerekçesinin aynısı — "0 dakika" eşlik eden bir tondan ölçen bir tona geçiş.
Izgaranın kendisi boş ayda da çiziliyor (ROADMAP kabul ölçütü); doldurulmayı
bekleyen ızgara maddenin asıl fikri.

Gün harfleri mevcut `shortDayNames(l10n)`dan (P S Ç P C C P).

### Ekran okuyucu

Tek `Semantics` kabı, `excludeSemantics: true` — `_ComebackRow` (madde 26) ve
`_WeeklyGoalRow` (madde 24) kalıbı:

- Dolu ay: *"Bu ay 30 günün 12 gününde odaklandın, toplam 3 saat 40 dakika."*
- Boş ay: *"Bu ay henüz odak yok."*

Hücre hücre gezinme bilinçli olarak kapsam dışı: TalkBack kullanıcısı tek bir
karttan geçmek için 30 durak aşmak zorunda kalırdı ve boş günler de durak
olurdu.

## Ekran 06 kaydırmaya geçiyor

Ekran şu an kaydırmasız: `Column` + `Spacer()` + banner, 390×844'te zaten
sınırda. Yeni kart hiçbir düzenlemeyle sığmıyor.

Çözüm madde 24'te Ekran 02'ye uygulanan kalıbın aynısı: `Expanded` +
`LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight:
constraints.maxHeight)`. Banner kaydırma alanının **dışında** kalıyor — reklam
kaydırılıp gözden kaybolmuyor, yuvası eskisi gibi altta duruyor. `minHeight`
ekranın tamamı olduğu için uzun ekranlarda yerleşim birebir aynı kalıyor.

Kart en alta, "en verimli aralık" satırının ardına giriyor; `RiseIn` gecikmesi
sıradaki adım (`RiseIn.step * 7`).

## Sağlayıcı

```dart
final Provider<MonthlyHeatmap> monthlyHeatmapProvider = ...
```

`stats_providers.dart`e, diğerleriyle aynı biçimde `allSessionsProvider`
üzerinden. Ekran 06'nın tüm sayıları tek akıştan türediği için ızgaranın
toplamı kümülatif odakla ve bar chart'la sapamaz.

## Kapsam dışı

- **Ay gezinme okları.** Seçili ayı tutan bir durum, ilk seansın ayından
  önceye ve gelecek aya geçişin kapatılması, üç yeni widget testi demek.
  Kabul ölçütü (boş / kısmi / yoğun ay) içinde bulunulan ayla karşılanıyor.
- **Hücreye dokunma, tooltip, gün detayı.** Izgaranın işi ritmi bir bakışta
  vermek; gün başına sayı bar chart'ta zaten var.
- **Yıllık pencere.** GitHub tarzı 7 satır × 52 sütun düzeni yatay kaydırma ve
  ayrı bir yoğunluk ölçeği ister; ayrı bir madde.

## Testler

| Dosya | Ne çivileniyor |
|---|---|
| `test/domain/stats/monthly_heatmap_test.dart` | boş ay, kısmi ay, yoğun ay; `leadingBlanks` (ayın 1'i pazartesi → 0, pazar → 6); ay uzunluğu (28/30/31); eşik kenarları (24/25, 49/50, 89/90); 04:00 gün sınırı; `isFuture`; ay dışındaki seansların sayılmaması; `activeDays` / `totalMinutes` |
| `test/features/stats/monthly_heatmap_card_test.dart` | üç durumda da hücre sayısı ve seviye renkleri; boş ayda toplam metni yok; bugünün ember çerçevesi; `find.bySemanticsLabel` ile iki etiket |
| `test/features/stats/stats_screen_test.dart` | kart ekranda, mevcut üç test kaydırmalı gövdede de geçiyor |

## Yeni ARB anahtarları

| Anahtar | Değer |
|---|---|
| `statsHeatmapLabel` | `BU AY` |
| `statsHeatmapSemantics` | `Bu ay {dayCount} günün {activeDays} gününde odaklandın, toplam {duration}.` |
| `statsHeatmapEmptySemantics` | `Bu ay henüz odak yok.` |
| `statsHeatmapLegendLow` | `az` |
| `statsHeatmapLegendHigh` | `çok` |

## Kabul (ROADMAP madde 29)

- [ ] Boş ay, kısmi ay ve yoğun ay üç durumda da doğru çiziliyor.
- [ ] Ekran okuyucu karşılığı var.
- [ ] Izgaranın toplamı ekranın kümülatif odağıyla tutarlı.
- [ ] Ekran 06 kaydırılabilir; banner kaydırma dışında, uzun ekranda görünüm
      değişmiyor.
- [ ] `flutter analyze` 0/0, `flutter test` yeşil.
- [ ] Emülatör doğrulaması: açık/koyu tema, boş ve dolu ay.
