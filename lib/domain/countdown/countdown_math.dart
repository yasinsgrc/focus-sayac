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

/// Son düzlüğün başladığı gün — bu eşiğin altında Ekran 02'nin hiyerarşisi
/// tersine döner (bkz. [isFinalStretch]).
const int kFinalStretchDays = 30;

/// Tersine çevirmenin ikinci koşulu: kahraman olmayı hak eden en az emek
/// (1 saat — 25 dakikalık iki pomodorodan fazlası).
const int kFinalStretchMinFocusSeconds = 3600;

/// Kahraman sayı "kalan gün" olmaktan çıkıp "biriken odak saati" olmalı mı?
///
/// Gerekçe: sınav yaklaştıkça geri sayım giderek daha korkutucu okunuyor
/// (247 → 12) ve tam da bırakma anında uygulama kaygı kaynağına dönüşüyor.
/// Son [kFinalStretchDays] günde aynı veri ters işaretle sunuluyor — kalan
/// gün küçülürken biriken emek büyüyor. Kümülatif toplam bugüne dek hiçbir
/// yerde kahraman değildi (Ekran 06 haftalık bakıyor).
///
/// İkinci koşul şart: emek eşiğin altındayken sayıyı çevirmek ekranı
/// "12 gün kaldı"dan **"0 saat odaklandın"a** düşürürdü, yani tersine
/// çevirmenin amaçladığının tam tersi bir mesaja. Sınavını yeni değiştirmiş
/// kullanıcı da (biriken saat o sınava ait) bu dalda geri sayımda kalır.
bool isFinalStretch({required int days, required int examFocusSeconds}) {
  return days <= kFinalStretchDays && examFocusSeconds >= kFinalStretchMinFocusSeconds;
}
