/// Geri sayım ekranının saf matematiği (SPEC.md Ekran 02, Faz 9 test
/// listesinde de adı geçen `daysTo` + `ratio` formülü). IO yok.
library;

/// Kalan süre; sınav geçmişse `Duration.zero` — sayaç asla negatife düşmez
/// (SPEC.md DoD).
Duration remainingDuration(DateTime targetUtc, DateTime nowUtc) {
  final Duration diff = targetUtc.difference(nowUtc);
  return diff.isNegative ? Duration.zero : diff;
}

/// Kalan tam gün sayısı — büyük gün rakamının kaynağı.
int daysTo(DateTime targetUtc, DateTime nowUtc) {
  return remainingDuration(targetUtc, nowUtc).inDays;
}

/// Dairesel ilerleme oranı — SPEC.md'nin birebir formülü:
/// `clamp(1 - days/400, 0.06, 1)`.
double progressRatio(int days) {
  final double raw = 1 - (days / 400);
  if (raw < 0.06) return 0.06;
  if (raw > 1) return 1;
  return raw;
}
