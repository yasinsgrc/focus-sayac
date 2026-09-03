import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import '../streak/streak_calculator.dart';

/// Ekran 06'nın bar chart'ı kaç uygulama günü gösterir (SPEC.md Ekran 06
/// "Son 7 gün").
const int kStatsWeekLength = 7;

/// "En verimli aralık" kovalarının genişliği (saat). Prototipin metni
/// `20:00–22:00` — iki saatlik kovalar.
const int kProductiveWindowHours = 2;

/// Bir kovanın "en verimli aralık" olarak gösterilebilmesi için gereken en az
/// odak seansı sayısı. Tek bir şanslı seansın `%100` ile tüm günü temsil
/// etmesini engeller; eşik altındaysa satır hiç gösterilmez.
const int kProductiveWindowMinSessions = 3;

/// Bar chart'ın tek bir günü — [dayKey] `appDayKey` çıktısıdır (04:00 TSİ
/// sınırlı uygulama günü), [minutes] o gün **tamamlanmış** odak dakikası.
class DailyFocus {
  const DailyFocus({required this.dayKey, required this.minutes});

  final DateTime dayKey;
  final int minutes;
}

/// "En verimli aralığın 20:00–22:00 — tamamlanma %94" satırının verisi.
/// [startHour] İstanbul duvar saatidir (0, 2, 4 … 22).
class ProductiveWindow {
  const ProductiveWindow({required this.startHour, required this.completionPercent});

  final int startHour;
  final int completionPercent;

  int get endHour => startHour + kProductiveWindowHours;
}

/// Ekran 06'nın tüm sayıları. Agregat tablo yok — hepsi ham
/// `PomodoroSession` kayıtlarından türetilir (SPEC.md Ekran 06).
class FocusStats {
  const FocusStats({
    required this.cumulativeSeconds,
    required this.lastWeek,
    required this.dailyAverageSeconds,
    required this.longestStreak,
    required this.completionPercent,
    required this.productiveWindow,
  });

  /// Tüm zamanların tamamlanmış odak süresi (saniye).
  final int cumulativeSeconds;

  /// Eskiden yeniye 7 gün; son eleman **bugün**. Seans olmayan günler de
  /// `minutes = 0` ile listede yer alır (chart'ta boş sütun).
  final List<DailyFocus> lastWeek;

  /// Son 7 günün toplamının 7'ye bölümü — seans olmayan günler de paydada.
  final int dailyAverageSeconds;

  final int longestStreak;

  /// Tamamlanan odak seansı / başlatılan odak seansı. Hiç odak seansı
  /// başlatılmadıysa `null` (oran tanımsız, ekranda `—` gösterilir).
  final int? completionPercent;

  /// Yeterli örneklem yoksa `null` — bkz. [kProductiveWindowMinSessions].
  final ProductiveWindow? productiveWindow;
}

/// Saf hesaplayıcı — IO yok, `nowUtc` dışarıdan verilir (SPEC.md §9 "boş veri,
/// tek gün, hafta sınırı" testleri bu fonksiyona bakar).
FocusStats calculateFocusStats({
  required List<PomodoroSession> sessions,
  required DateTime nowUtc,
}) {
  final List<PomodoroSession> focusSessions = sessions
      .where((PomodoroSession s) => s.type == SessionType.focus)
      .toList(growable: false);
  final List<PomodoroSession> completed =
      focusSessions.where((PomodoroSession s) => s.completed).toList(growable: false);

  int cumulativeSeconds = 0;
  final Map<DateTime, int> secondsByDay = <DateTime, int>{};
  for (final PomodoroSession session in completed) {
    cumulativeSeconds += session.plannedDurationSec;
    final DateTime day = appDayKey(session.startedAt);
    secondsByDay[day] = (secondsByDay[day] ?? 0) + session.plannedDurationSec;
  }

  final DateTime today = currentAppDayKey(nowUtc);
  final List<DailyFocus> lastWeek = <DailyFocus>[];
  int weekSeconds = 0;
  for (int i = kStatsWeekLength - 1; i >= 0; i--) {
    final DateTime day = today.subtract(Duration(days: i));
    final int seconds = secondsByDay[day] ?? 0;
    weekSeconds += seconds;
    lastWeek.add(DailyFocus(dayKey: day, minutes: seconds ~/ 60));
  }

  return FocusStats(
    cumulativeSeconds: cumulativeSeconds,
    lastWeek: lastWeek,
    dailyAverageSeconds: weekSeconds ~/ kStatsWeekLength,
    longestStreak: calculateLongestStreak(
      completedFocusStartedAtUtc:
          completed.map((PomodoroSession s) => s.startedAt).toList(growable: false),
    ),
    completionPercent: focusSessions.isEmpty
        ? null
        : ((completed.length * 100) / focusSessions.length).round(),
    productiveWindow: _findProductiveWindow(focusSessions),
  );
}

/// Odak seanslarını başlangıç saatlerinin İstanbul duvar saatine göre iki
/// saatlik kovalara ayırır ve tamamlanma oranı en yüksek kovayı döndürür.
/// Eşitlikte daha çok tamamlanmış seansı olan, o da eşitse günün erken
/// kovası kazanır (sonucun kayıt sırasından bağımsız olması için).
ProductiveWindow? _findProductiveWindow(List<PomodoroSession> focusSessions) {
  const int bucketCount = 24 ~/ kProductiveWindowHours;
  final List<int> totals = List<int>.filled(bucketCount, 0);
  final List<int> completedCounts = List<int>.filled(bucketCount, 0);

  for (final PomodoroSession session in focusSessions) {
    final int bucket = toIstanbulWallClock(session.startedAt).hour ~/ kProductiveWindowHours;
    totals[bucket] += 1;
    if (session.completed) completedCounts[bucket] += 1;
  }

  int? bestBucket;
  int bestPercent = -1;
  for (int bucket = 0; bucket < bucketCount; bucket++) {
    if (totals[bucket] < kProductiveWindowMinSessions) continue;
    final int percent = ((completedCounts[bucket] * 100) / totals[bucket]).round();
    if (bestBucket == null ||
        percent > bestPercent ||
        (percent == bestPercent && completedCounts[bucket] > completedCounts[bestBucket])) {
      bestBucket = bucket;
      bestPercent = percent;
    }
  }

  if (bestBucket == null) return null;
  return ProductiveWindow(
    startHour: bestBucket * kProductiveWindowHours,
    completionPercent: bestPercent,
  );
}
