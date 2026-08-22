import '../../core/time/app_day.dart';

/// Seri hesaplayıcı — SPEC.md §5.3, saf fonksiyon, IO yok.
/// "Seri = ≥1 tamamlanmış odak seansı olan ardışık gün sayısı; bugün veya
/// dün biten seri canlıdır."
///
/// Faz 7'nin rozet kataloğuyla birlikte planlanmıştı ama Ekran 02 (Faz 4)
/// "6 gün seri" değerini gerçek veriden göstermek zorunda (DoD: demo
/// sayılar kodda olamaz) — bu yüzden yalnızca bu saf fonksiyon Faz 4'e
/// çekildi; rozet açma/kilit mantığı hâlâ Faz 7'de.
int calculateStreak({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
}) {
  final Set<DateTime> completedDays =
      completedFocusStartedAtUtc.map(appDayKey).toSet();
  if (completedDays.isEmpty) {
    return 0;
  }

  final DateTime today = currentAppDayKey(nowUtc);
  DateTime cursor;
  if (completedDays.contains(today)) {
    cursor = today;
  } else {
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    if (completedDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }
  }

  int streak = 0;
  while (completedDays.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Tüm zamanların en uzun serisi — [calculateStreak] yalnızca bugün/dün
/// canlıysa sayar, bu fonksiyon geçmişte kırılmış olsa bile en uzun ardışık
/// bloğu bulur. Ekran 06'nın "en uzun seri" istatistiği (Faz 9) ve
/// "Haftalık Seri" rozeti (Faz 7, `badge_rules.dart`) bu saf fonksiyonu
/// paylaşır — SPEC.md §5.4 rozet kuralı "ever" anlamında olduğu için
/// (bir kez kazanılan rozet serinin sonradan kırılmasıyla geri alınmaz).
int calculateLongestStreak({required List<DateTime> completedFocusStartedAtUtc}) {
  final List<DateTime> days = completedFocusStartedAtUtc.map(appDayKey).toSet().toList()..sort();
  if (days.isEmpty) {
    return 0;
  }

  int longest = 1;
  int current = 1;
  for (int i = 1; i < days.length; i++) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      current += 1;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}
