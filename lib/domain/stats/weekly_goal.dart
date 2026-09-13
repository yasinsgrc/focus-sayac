/// Haftalık odak hedefinin ilerlemesi (ROADMAP madde 24).
///
/// **Hafta tanımı burada yok — olmaması bilinçli.** [focusedSeconds] her zaman
/// `calculateWeeklySummary`nin (`weekly_summary.dart`) ürettiği saniyedir; bu
/// sınıf kendi pencere hesabını kurmaz. Kursaydı uygulamada iki "hafta" kavramı
/// olurdu: Ekran 06'nın kartı ve pazar bildirimi kayan yedi uygulama gününe
/// bakarken hedef başka bir sınıra bakardı ve kullanıcı aynı ekranlarda iki
/// farklı sayı görürdü.
class WeeklyGoalProgress {
  const WeeklyGoalProgress({required this.goalSeconds, required this.focusedSeconds});

  static const WeeklyGoalProgress off =
      WeeklyGoalProgress(goalSeconds: 0, focusedSeconds: 0);

  /// Kullanıcının koyduğu hedef (saniye). 0 = hedef yok.
  final int goalSeconds;

  /// Pencerenin tamamlanmış odak süresi — `WeeklySummary.seconds`.
  final int focusedSeconds;

  /// Hedef kapalı. Ekran 02'deki satır bu hâlde hiç çizilmiyor: kapatılamayan
  /// bir ilerleme çubuğu "eşlik eden" tonu "ölçen" tona çevirirdi.
  bool get isOff => goalSeconds <= 0;

  /// 0..1 arası, **kırpılmış**. Hedefini üçe katlayan kullanıcıda çubuk kendi
  /// rayını taşmasın diye üstte, hedef kapalıyken bölme olmasın diye altta.
  double get ratio {
    if (isOff) return 0;
    return (focusedSeconds / goalSeconds).clamp(0.0, 1.0);
  }

  /// Hedefe kalan süre; tabanda kırpılıyor — hedefi aşmış kullanıcıya negatif
  /// bir "kalan" cümlesi kurulmaz.
  int get remainingSeconds {
    if (isOff) return 0;
    final int remaining = goalSeconds - focusedSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Sınır **dahil**: hedefi tam karşılayan hafta tamamlanmış sayılır.
  /// Kapalı hedef hiçbir zaman ulaşılmış olmuyor — kullanıcının koymadığı bir
  /// hedefi kutlamak anlamsız.
  bool get isReached => !isOff && focusedSeconds >= goalSeconds;

  /// `WeeklySummary` / `StreakStatus` ile aynı gerekçe: Riverpod bu değeri `==`
  /// ile karşılaştırıp gereksiz yeniden çizimi eliyor.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyGoalProgress &&
          other.goalSeconds == goalSeconds &&
          other.focusedSeconds == focusedSeconds;

  @override
  int get hashCode => Object.hash(goalSeconds, focusedSeconds);

  @override
  String toString() =>
      'WeeklyGoalProgress(goalSeconds: $goalSeconds, focusedSeconds: $focusedSeconds)';
}
