import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import 'heatmap_scale.dart';

/// Şeridin sütun sayısı — pencerenin eni. `kRollingYearWeeks * 7` gün.
const int kRollingYearWeeks = 52;

/// Ekran 06'nın yuvarlanan yıl şeridi (ROADMAP madde 37).
///
/// Aylık ızgara "bu ay hangi günler çalıştım"ı cevaplıyor; bu pencere
/// **ölçeği**: ritim aylar boyunca nasıl gidiyor, sınav yaklaşırken yoğunlaştı
/// mı, yazın nerede koptu. Ayı ay ay gezerek görülmeyen şey.
class RollingYearHeatmap {
  const RollingYearHeatmap({
    required this.days,
    required this.totalMinutes,
    required this.activeDays,
  });

  /// `kRollingYearWeeks * 7` gün, **eskiden yeniye** ve pazartesi hizalı.
  ///
  /// Şerit sütun sütun çiziliyor: `days[sütun * 7 + satır]`. Hizanın
  /// pazartesiyle başlaması bu indeks aritmetiğinin tek şartı — aylık
  /// ızgaranın `leadingBlanks`i ve `shortDayNames` sırası da aynı kabulde.
  final List<HeatmapDay> days;

  final int totalMinutes;

  /// Yalnızca odak yapılmış günlerin sayısı.
  final int activeDays;

  /// Pencere boşken kartın yıl toplamı hiç yazılmıyor — ay toplamının ve
  /// haftalık kapanış kartının gerekçesinin aynısı: "0 dakika" eşlik eden bir
  /// tondan ölçen bir tona geçiş. Şeridin kendisi boş pencerede de çiziliyor.
  bool get isEmpty => totalMinutes == 0;
}

/// Saf hesaplayıcı — IO yok, `nowUtc` dışarıdan verilir.
///
/// Pencere **takvim yılı değil**: son sütun [nowUtc]'nin uygulama gününün
/// içinde bulunduğu hafta (Pzt–Paz), ilk sütun ondan
/// `kRollingYearWeeks - 1` hafta öncesi. Takvim yılı elenmişti — ocak ayında
/// pencere neredeyse boş olur ve ritim diye gösterilecek bir şey kalmazdı.
///
/// Gün sınırı `appDayKey`: 04:00 TSİ (SPEC.md §5.3), aylık hesaplayıcıyla
/// **aynı fonksiyon**. İkinci bir gün tanımı açılmıyor.
///
/// `monthOffset` benzeri bir parametre yok: pencere sabit, yıl gezinme madde
/// 37'nin kapsamı dışında. Gerekirse buraya bir `weekOffset` eklenir.
RollingYearHeatmap calculateRollingYearHeatmap({
  required List<PomodoroSession> sessions,
  required DateTime nowUtc,
}) {
  final Map<DateTime, int> secondsByDay = <DateTime, int>{};
  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) continue;
    final DateTime day = appDayKey(session.startedAt);
    secondsByDay[day] = (secondsByDay[day] ?? 0) + session.plannedDurationSec;
  }

  final DateTime today = currentAppDayKey(nowUtc);
  // `weekday` pazartesi için 1: bu haftanın pazartesisine inmek bir çıkarma.
  // Gün anahtarları UTC gece yarısı olduğu için tam gün aritmetiği güvenli —
  // yaz saati yok (`app_day.dart`).
  final DateTime thisMonday = today.subtract(Duration(days: today.weekday - 1));
  final DateTime first = thisMonday.subtract(const Duration(days: (kRollingYearWeeks - 1) * 7));

  final List<HeatmapDay> days = <HeatmapDay>[];
  int totalMinutes = 0;
  int activeDays = 0;
  for (int offset = 0; offset < kRollingYearWeeks * 7; offset++) {
    final DateTime day = first.add(Duration(days: offset));
    final int minutes = (secondsByDay[day] ?? 0) ~/ 60;
    totalMinutes += minutes;
    if (minutes > 0) activeDays += 1;
    days.add(
      HeatmapDay(
        dayKey: day,
        minutes: minutes,
        level: heatmapLevel(minutes),
        // Bu haftanın kalanı. Madde 29'un kuralı aynen: yaşanmamış günü boş
        // kutu olarak göstermek onu kaçırılmış gün gibi okuturdu.
        isFuture: day.isAfter(today),
      ),
    );
  }

  return RollingYearHeatmap(
    days: List<HeatmapDay>.unmodifiable(days),
    totalMinutes: totalMinutes,
    activeDays: activeDays,
  );
}
