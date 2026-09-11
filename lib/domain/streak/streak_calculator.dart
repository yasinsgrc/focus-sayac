import '../../core/time/app_day.dart';

/// Telafi ("seri koruma") hakkının yenilenme aralığı: haftada bir.
/// İki telafi günü arasında en az bu kadar gün olmak zorunda.
const int kStreakGraceIntervalDays = 7;

/// Serinin o anki hâli.
enum StreakState {
  /// Canlı seri yok.
  none,

  /// Bugün ya da dün tamamlanmış bir odak seansı var; seri sağlam.
  active,

  /// Dün boş geçti ama haftalık telafi hakkı o günü kapattı: seri yaşıyor,
  /// alev soluk. Bugün tek bir pomodoro seriyi geri kazandırır; gelmezse
  /// yarın gerçekten kırılır (iki boşluk üst üste telafi edilemez).
  protected,
}

/// Seri sayısı + koruma durumu. Ekran 02 rozeti ikisini birden okuyor:
/// korumadaki seri sönmüş değil, soluk.
class StreakStatus {
  const StreakStatus({required this.days, required this.state});

  static const StreakStatus none = StreakStatus(days: 0, state: StreakState.none);

  /// **Gerçekten çalışılmış** ardışık gün sayısı — telafiyle kapatılan gün
  /// buna dâhil değil; kullanıcıya çalışmadığı bir gün satılmıyor.
  final int days;

  final StreakState state;

  bool get isProtected => state == StreakState.protected;

  /// Riverpod bu değeri `==` ile karşılaştırıp gereksiz yeniden çizimi
  /// eliyor — eskiden sağlanan çıplak `int` de aynı şeyi yapıyordu.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakStatus && other.days == days && other.state == state;

  @override
  int get hashCode => Object.hash(days, state);

  @override
  String toString() => 'StreakStatus(days: $days, state: $state)';
}

/// Seri hesaplayıcı — SPEC.md §5.3, saf fonksiyon, IO yok.
/// "Seri = ≥1 tamamlanmış odak seansı olan ardışık gün sayısı; bugün veya
/// dün biten seri canlıdır."
///
/// Faz 7'nin rozet kataloğuyla birlikte planlanmıştı ama Ekran 02 (Faz 4)
/// "6 gün seri" değerini gerçek veriden göstermek zorunda (DoD: demo
/// sayılar kodda olamaz) — bu yüzden yalnızca bu saf fonksiyon Faz 4'e
/// çekildi; rozet açma/kilit mantığı hâlâ Faz 7'de.
///
/// Kural buna ek olarak **affediyor**: ardışıklık [kStreakGraceIntervalDays]
/// günde bir kez tek günlük bir boşlukla bozulmuyor. Alışkanlık
/// uygulamalarında en büyük terk anı serinin bir anda 0'a düşmesi; bir gün
/// kaçıran kullanıcı seriyi kaybetmiş değil, korumaya alınmış oluyor. Hak
/// tamamen türetilmiş — saklanan bir sayaç yok, aynı geçmiş her zaman aynı
/// sonucu veriyor (SPEC §2 "Basitlik", yerel veri).
StreakStatus calculateStreakStatus({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
}) {
  final Set<DateTime> completedDays =
      completedFocusStartedAtUtc.map(appDayKey).toSet();
  if (completedDays.isEmpty) {
    return StreakStatus.none;
  }

  final DateTime today = currentAppDayKey(nowUtc);
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  final DateTime start;
  final StreakState state;
  // Geriye doğru yürürken en son hangi günü telafiyle kapattığımız; hak
  // yenilenene kadar ikinci bir boşluk seriyi kesiyor.
  DateTime? lastGraceDay;

  if (completedDays.contains(today)) {
    start = today;
    state = StreakState.active;
  } else if (completedDays.contains(yesterday)) {
    // Bugün henüz bitmedi — boşluk sayılmıyor, hak da harcanmıyor.
    start = yesterday;
    state = StreakState.active;
  } else if (completedDays.contains(yesterday.subtract(const Duration(days: 1)))) {
    // Dün boş geçti: hak dünü kapatıyor, seri korumada.
    start = yesterday.subtract(const Duration(days: 1));
    state = StreakState.protected;
    lastGraceDay = yesterday;
  } else {
    return StreakStatus.none;
  }

  int days = 0;
  DateTime cursor = start;
  while (true) {
    if (completedDays.contains(cursor)) {
      days += 1;
    } else if (lastGraceDay == null ||
        lastGraceDay.difference(cursor).inDays >= kStreakGraceIntervalDays) {
      // Geçmişteki boşluk da aynı haftalık hakla kapanıyor: aksi hâlde dün
      // affedilen gün, gün dönünce seriyi yeniden keserdi (hesap saklanan
      // değil türetilen bir değer). Döngü sonsuza gitmiyor: bir telafiden
      // sonraki boşluk yedi günden yakınsa `break` çalışıyor.
      lastGraceDay = cursor;
    } else {
      break;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return StreakStatus(days: days, state: state);
}

/// Kutlanmaya değer seri eşikleri. Bilinçli olarak **seyrek**: her gün ya da
/// her beş günde bir kutlama, "seriyi agresif kovalama" tuzağı olurdu —
/// kutlama nadir olduğu sürece kutlama kalıyor. 3 ilk alışkanlık eşiği (ilk
/// terk dalgasının kırıldığı yer), 7 "Haftalık Seri" rozetiyle aynı gün, 30 ve
/// 100 ise gerçekten anlatılacak sayılar.
///
/// 7'de rozet de açılıyor; çağıran rozet kutlamasını öne aldığı için aynı gün
/// iki kutlama üst üste binmiyor (bkz. `PomodoroController`).
const List<int> kStreakMilestones = <int>[3, 7, 30, 100];

/// [days] ile geçilmiş ama [lastCelebrated]'dan büyük **en yüksek** eşiği
/// döndürür; kutlanacak yeni bir eşik yoksa `null`.
///
/// Saf: "daha önce kutlandı mı" bilgisi girdi olarak geliyor (çağıran onu
/// `SharedPreferences`te tutuyor). Aksi hâlde eşik gününde tamamlanan her
/// seans aynı kutlamayı yeniden açardı — seri gün boyunca aynı sayıda kalıyor.
///
/// Eşiği **geçmiş** olmak da sayılıyor (`days >= milestone`), tam denk gelmek
/// değil: serisi 30 günken güncellenen bir kullanıcıda 3 ve 7 hiç kutlanmamış
/// olur; o durumda geriye dönük üç dialog açılmıyor, en yüksek eşik bir kez
/// kutlanıp geçiliyor.
int? streakMilestoneToCelebrate({required int days, required int lastCelebrated}) {
  int? reached;
  for (final int milestone in kStreakMilestones) {
    if (days >= milestone && milestone > lastCelebrated) {
      reached = milestone;
    }
  }
  return reached;
}

/// [calculateStreakStatus]'un yalnızca gün sayısını isteyen çağrıcıları için
/// kısayol (bildirim zamanlaması, hikâye kartı, ana ekran widget'ı).
int calculateStreak({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
}) {
  return calculateStreakStatus(
    completedFocusStartedAtUtc: completedFocusStartedAtUtc,
    nowUtc: nowUtc,
  ).days;
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
