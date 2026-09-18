import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';

/// Izgaranın dolu ton sayısı — [kHeatmapLevelThresholds] uzunluğuyla aynı
/// olmak zorunda (`monthly_heatmap_test.dart` bunu çiviliyor). `const`
/// kalabilmesi için ayrı yazıldı.
const int kHeatmapLevels = 4;

/// Seviye sınırları, dakika cinsinden ve **dahil**: 1–24 → 1, 25–49 → 2,
/// 50–89 → 3, ≥90 → 4.
///
/// Eşikler **mutlak**, ayın en yoğun gününe göre ölçeklenmiyor. Bar chart
/// sütunlarını kendi haftasının en yüksek gününe göre ölçekliyor
/// (`WeeklyFocusBarPainter`) ama ızgarada aynı şey yanlış bir şey söylerdi:
/// ayda tek bir 5 dakikalık günü olan kullanıcı o günü en koyu tonda görürdü.
/// Sınırlar 25 dakikalık varsayılan pomodoronun 1 / 2 / 3+ katları; dakikada
/// sabit oldukları için iki ay birbiriyle karşılaştırılabiliyor.
const List<int> kHeatmapLevelThresholds = <int>[1, 25, 50, 90];

/// Bir günün yoğunluk seviyesi (0 = hiç odak yok).
int heatmapLevel(int minutes) {
  int level = 0;
  for (final int threshold in kHeatmapLevelThresholds) {
    if (minutes >= threshold) level++;
  }
  return level;
}

/// Izgaranın tek bir hücresi.
class HeatmapDay {
  const HeatmapDay({
    required this.dayKey,
    required this.minutes,
    required this.level,
    required this.isFuture,
  });

  /// `appDayKey` çıktısı — 04:00 TSİ sınırlı uygulama günü.
  final DateTime dayKey;

  /// O gün **tamamlanmış** odak dakikası.
  final int minutes;

  /// 0..[kHeatmapLevels]; renk rampasının indeksi.
  final int level;

  /// Ayın henüz gelmemiş günü. Gelecek günler dolgusuz çiziliyor: ayın
  /// 2'sinde 28 boş kutu göstermek, yaşanmamış günleri kaçırılmış gün gibi
  /// okuturdu.
  final bool isFuture;
}

/// Ekran 06'nın aylık ısı haritası (ROADMAP madde 29). Pencere madde 35'ten
/// beri gezilebilir: `monthOffset` ile geçmiş aylar da açılıyor.
class MonthlyHeatmap {
  const MonthlyHeatmap({
    required this.month,
    required this.leadingBlanks,
    required this.days,
    required this.totalMinutes,
    required this.activeDays,
    required this.isCurrentMonth,
    required this.hasEarlier,
    required this.hasLater,
  });

  /// Gösterilen ayın 1'i (UTC). Kartın başlığı bundan türüyor.
  final DateTime month;

  /// Ayın 1'inden önce bırakılacak boş hücre sayısı (0..6). Hafta
  /// pazartesiyle başlıyor — `shortDayNames` sırasının aynısı.
  final int leadingBlanks;

  /// Ayın 1'inden son gününe, eksiksiz. Seans olmayan gün de `minutes = 0`
  /// ile listede: ızgara takvim düzeni olduğu için eksik bir gün kalan tüm
  /// hücreleri kaydırırdı.
  final List<HeatmapDay> days;

  final int totalMinutes;

  /// Yalnızca odak yapılmış günlerin sayısı.
  final int activeDays;

  /// Pencere içinde bulunulan ay mı. Kartın iki kuralı buna bağlı: bugünün
  /// çerçevesi ve ızgaranın bugünün satırında bitmesi. Geçmiş ayda hiçbir gün
  /// gelecek değil, yani bu ayrım olmadan ayın **son gününe** bugün çerçevesi
  /// çizilirdi.
  final bool isCurrentMonth;

  /// Bu aydan önce tamamlanmış bir odak seansı var mı — geri okun kapısı.
  ///
  /// Ölçüt ızgaranınkiyle aynı (`completed && focus`): "geri gidince bir şey
  /// göreceksin" sözü, ızgaranın gösterdiği veriden çıkıyor. Takvim ayına
  /// bakılsaydı uygulamayı bu ay kuran kullanıcı boş aylarda kaybolurdu.
  final bool hasEarlier;

  /// İleri okun kapısı: pencere içinde bulunulan aydan önceyse açık. Gelecek
  /// aya gezinme yok — yaşanmamış gün gösterilmiyor (madde 29 kararı).
  final bool hasLater;

  /// Ay boşken kartın toplam metni hiç yazılmıyor — haftalık kapanış
  /// kartıyla aynı gerekçe: "0 dakika" eşlik eden bir tondan ölçen bir tona
  /// geçiş. Izgaranın kendisi boş ayda da çiziliyor.
  bool get isEmpty => totalMinutes == 0;
}

/// Saf hesaplayıcı — IO yok, `nowUtc` dışarıdan verilir.
///
/// Ay, `nowUtc`'nin **uygulama gününün** ayı: 1 Eylül 03:00 TSİ'de açılan
/// uygulama hâlâ ağustosu gösterir, çünkü o an henüz 31 ağustos uygulama
/// günüdür (SPEC.md §5.3). Ekranın geri kalanıyla aynı gün tanımı.
///
/// [monthOffset] pencereyi o günden geriye kaydırıyor (0 = bu ay, −1 = geçen
/// ay; ROADMAP madde 35). Parametre doğrudan bir `DateTime month` değil: ay
/// tanımı 04:00 TSİ sınırına bağlı ve o kural burada, tek yerde duruyor —
/// hazır bir ay verilseydi çağıran da aynı soruyu cevaplamak zorunda kalırdı.
MonthlyHeatmap calculateMonthlyHeatmap({
  required List<PomodoroSession> sessions,
  required DateTime nowUtc,
  int monthOffset = 0,
}) {
  final Map<DateTime, int> secondsByDay = <DateTime, int>{};
  DateTime? earliestDay;
  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) continue;
    final DateTime day = appDayKey(session.startedAt);
    secondsByDay[day] = (secondsByDay[day] ?? 0) + session.plannedDurationSec;
    if (earliestDay == null || day.isBefore(earliestDay)) earliestDay = day;
  }

  final DateTime today = currentAppDayKey(nowUtc);
  final DateTime currentMonth = DateTime.utc(today.year, today.month, 1);
  // `DateTime.utc` ay taşmasını iki yönde de normalize ediyor: ocakta −1
  // geçen yılın aralığı, aralıkta +1 gelecek yılın ocağı.
  final DateTime firstDay = DateTime.utc(today.year, today.month + monthOffset, 1);
  // Ay uzunluğu bir sonraki ayın 1'inden türetiliyor; gün farkı UTC'de tam
  // (yaz saati yok).
  final int dayCount =
      DateTime.utc(firstDay.year, firstDay.month + 1, 1).difference(firstDay).inDays;

  final List<HeatmapDay> days = <HeatmapDay>[];
  int totalMinutes = 0;
  int activeDays = 0;
  for (int dayOfMonth = 1; dayOfMonth <= dayCount; dayOfMonth++) {
    final DateTime day = DateTime.utc(firstDay.year, firstDay.month, dayOfMonth);
    final int minutes = (secondsByDay[day] ?? 0) ~/ 60;
    totalMinutes += minutes;
    if (minutes > 0) activeDays += 1;
    days.add(
      HeatmapDay(
        dayKey: day,
        minutes: minutes,
        level: heatmapLevel(minutes),
        isFuture: day.isAfter(today),
      ),
    );
  }

  return MonthlyHeatmap(
    month: firstDay,
    leadingBlanks: firstDay.weekday - 1,
    days: List<HeatmapDay>.unmodifiable(days),
    totalMinutes: totalMinutes,
    activeDays: activeDays,
    isCurrentMonth: firstDay == currentMonth,
    hasEarlier: earliestDay != null && earliestDay.isBefore(firstDay),
    hasLater: firstDay.isBefore(currentMonth),
  );
}
