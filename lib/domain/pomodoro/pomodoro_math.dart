/// Odak/mola seansının saf wall-clock matematiği (SPEC.md §5.1): "Kalan süre
/// asla azalan sayaçtan okunmaz. Her zaman `startedAt + planned - now()`."
/// IO yok — `pomodoro_controller_test.dart` ve widget'lar bu tek fonksiyonu
/// paylaşır.
library;

/// Bir odak/mola fazının kalan süresi. Negatife düşmez (SPEC DoD: sayaç
/// asla negatife düşmez) — sıfıra ulaşınca `PomodoroController.tick()`
/// tamamlanma geçişini tetikler.
Duration phaseRemaining({
  required DateTime startedAtUtc,
  required int plannedDurationSec,
  required DateTime nowUtc,
}) {
  final Duration elapsed = nowUtc.difference(startedAtUtc);
  final Duration remaining = Duration(seconds: plannedDurationSec) - elapsed;
  return remaining.isNegative ? Duration.zero : remaining;
}

/// 0→1 ilerleme oranı — meşalenin büyümesi ve halkanın dolması bu değere
/// bağlı (SPEC.md §5.5 "progress 0→1 ile alev büyür").
double phaseProgress({
  required DateTime startedAtUtc,
  required int plannedDurationSec,
  required DateTime nowUtc,
}) {
  if (plannedDurationSec <= 0) return 1;
  final Duration elapsed = nowUtc.difference(startedAtUtc);
  final double ratio = elapsed.inMilliseconds / (plannedDurationSec * 1000);
  if (ratio < 0) return 0;
  if (ratio > 1) return 1;
  return ratio;
}

/// Duraklatılmış bir seans devam ettirildiğinde, "kaldığı yerden" devam
/// etmesi için kullanılacak sanal `startedAt`. Gerçek geçmiş `startedAt`
/// (DB'deki, seansın ilk başladığı an) değişmez — yalnızca kalan süre
/// hesaplamasında kullanılan bu değer, duraklatma anındaki kalan süreyi
/// korur (SPEC §5.1 formülü hâlâ birebir uygulanır, azalan bir sayaç
/// tutulmaz).
DateTime resumeVirtualStart({
  required DateTime nowUtc,
  required int plannedDurationSec,
  required Duration remainingAtPause,
}) {
  return nowUtc.subtract(Duration(seconds: plannedDurationSec) - remainingAtPause);
}

/// Saniyeyi prototipin `mm:ss` sayaç biçimine çevirir (odak 90 dk'ya kadar
/// çıkabildiği için dakika iki haneyi aşabilir, bu kasıtlı).
String formatClock(Duration duration) {
  final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Bir odak seansı tamamlandığında bir sonraki döngü konumu (1..4) ve uzun
/// mola olup olmadığı — SPEC §5.2 "Döngü: 4 odak → 1 uzun mola".
int nextCyclePosition(int completedCyclePosition) {
  return completedCyclePosition >= 4 ? 1 : completedCyclePosition + 1;
}

bool isLongBreakFor(int cyclePosition) => cyclePosition >= 4;
