import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import 'heatmap_scale.dart';

/// Ölçek madde 37'de `heatmap_scale.dart`a çıktı — yuvarlanan 52 haftalık
/// şerit de aynı eşikleri ve aynı [HeatmapDay]i kullanıyor. Buradan yeniden
/// dışa veriliyor ki bu dosyayı import eden kart, sağlayıcı ve testler
/// değişmek zorunda kalmasın.
export 'heatmap_scale.dart';

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
